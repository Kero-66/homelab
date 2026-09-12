#!/usr/bin/env python3
"""Create/update a Jellyfin SmartLists playlist via the plugin's REST API.

Usage:
  JELLYFIN_KEY=... python3 smartlist.py external <name> <external-list-url> [--sort-desc]
  JELLYFIN_KEY=... python3 smartlist.py rules <name> <field=Contains:value> [<field=Contains:value> ...] [--sort-by=ReleaseDate] [--sort-desc]

Examples:
  smartlist.py external "Macross Continuity Order (IMDb)" https://www.imdb.com/list/ls560970728/
  smartlist.py rules "Gurren Lagann" SeriesName=Contains:Gurren Lagann Name=Contains:Gurren Lagann

Behavior:
  - Idempotent by Name: if a smart list with this exact name already exists, PUTs an
    update to it instead of creating a duplicate.
  - Always sets MediaTypes to ["Episode", "Movie"] and owner to the first Jellyfin user
    returned by /Plugins/SmartLists/users (override with JELLYFIN_OWNER_USERID env var
    if you have multiple users and want a specific one).
  - After create/update, triggers a refresh and polls /Status/History until it appears,
    then prints success/failure and item count. A 201/204 from the API is NOT proof the
    list actually populated -- this script always checks history, per
    .claude/memory/feedback_verify_actual_effect_not_deploy_success.md.
  - "external" mode requires the relevant provider API key already configured in the
    plugin (Dashboard -> Plugins -> SmartLists -> Settings -> External Lists, or via
    POST /Plugins/SmartLists/Configuration). This script does not configure those.

Field/operator/sort names must match the plugin's vocabulary exactly -- fetch
GET /Plugins/SmartLists/fields to check if a rule/sort silently 400s.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "http://jellyfin.home"
KEY = os.environ["JELLYFIN_KEY"]
AUTH = f'MediaBrowser Token="{KEY}"'


def call(path, method="GET", body=None, timeout=30):
    req = urllib.request.Request(
        f"{BASE}{path}",
        method=method,
        headers={"Authorization": AUTH, "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None,
    )
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        data = resp.read()
        return resp.status, (json.loads(data) if data else None)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        return e.code, detail


def owner_user_id():
    override = os.environ.get("JELLYFIN_OWNER_USERID")
    if override:
        return override
    status, users = call("/Plugins/SmartLists/users")
    if status != 200 or not users:
        raise SystemExit(f"could not fetch users: {status} {users}")
    return users[0]["Id"]


def find_existing(name):
    status, lists = call("/Plugins/SmartLists")
    if status != 200:
        raise SystemExit(f"could not list smart lists: {status} {lists}")
    for l in lists:
        if l["Name"] == name:
            return l["Id"]
    return None


def upsert(name, expression_sets, sort_by, sort_desc, media_types):
    body = {
        "Type": "Playlist",
        "Name": name,
        "MediaTypes": media_types,
        "UserPlaylists": [{"UserId": owner_user_id()}],
        "ExpressionSets": expression_sets,
        "Order": {"SortOptions": [{"SortBy": sort_by, "SortOrder": "Descending" if sort_desc else "Ascending"}]},
        "MaxItems": 500,
        "AutoRefresh": "OnLibraryChanges",
    }
    existing_id = find_existing(name)
    if existing_id:
        status, result = call(f"/Plugins/SmartLists/{existing_id}", method="PUT", body={**body, "Id": existing_id})
        action = "updated"
    else:
        status, result = call("/Plugins/SmartLists", method="POST", body=body)
        action = "created"
    if status not in (200, 201):
        raise SystemExit(f"{action} failed: {status} {result}")
    list_id = result["Id"]
    print(f"{action}: {name} -> {list_id}")
    return list_id


def refresh_and_verify(list_id, name, max_wait=90):
    status, result = call(f"/Plugins/SmartLists/{list_id}/refresh", method="POST", timeout=max_wait)
    if status != 200:
        raise SystemExit(f"refresh call failed: {status} {result}")

    deadline = time.time() + max_wait
    while time.time() < deadline:
        status, history = call("/Plugins/SmartLists/Status/History")
        entry = next((h for h in history if h["listId"] == list_id), None)
        if entry:
            break
        time.sleep(2)
    else:
        print(f"WARNING: no history entry appeared for {name} within {max_wait}s -- check manually")
        return

    if not entry["success"]:
        print(f"REFRESH FAILED for {name}: {entry.get('errorMessage')}")
        return

    status, detail = call(f"/Plugins/SmartLists/{list_id}")
    item_count = detail.get("ItemCount") if status == 200 else "?"
    print(f"refresh OK: {name} -> {item_count} items")


def parse_rule(spec):
    # field=Operator:value
    field, rest = spec.split("=", 1)
    operator, value = rest.split(":", 1)
    return {"MemberName": field, "Operator": operator, "TargetValue": value}


def main():
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    mode, name = sys.argv[1], sys.argv[2]
    rest = sys.argv[3:]
    sort_desc = "--sort-desc" in rest
    rest = [a for a in rest if a != "--sort-desc"]

    if mode == "external":
        url = rest[0]
        expression_sets = [{"Expressions": [{"MemberName": "ExternalList", "Operator": "Equal", "TargetValue": url}]}]
        sort_by = "External List Order Descending" if sort_desc else "External List Order Ascending"
        media_types = ["Episode", "Movie"]
    elif mode == "rules":
        sort_by = "ReleaseDate"
        for a in list(rest):
            if a.startswith("--sort-by="):
                sort_by = a.split("=", 1)[1]
                rest.remove(a)
        expression_sets = [{"Expressions": [parse_rule(r)]} for r in rest]
        media_types = ["Episode", "Movie"]
    else:
        raise SystemExit(__doc__)

    list_id = upsert(name, expression_sets, sort_by, sort_desc, media_types)
    refresh_and_verify(list_id, name)


if __name__ == "__main__":
    main()
