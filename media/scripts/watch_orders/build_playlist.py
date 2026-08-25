#!/usr/bin/env python3
"""Build/update a Jellyfin watch-order playlist from a YAML definition.

Usage: JELLYFIN_KEY=... python3 build_playlist.py macross.yaml

Each top-level key in the YAML (e.g. release_order, chronological_order)
becomes a playlist named "<Franchise> (<Key, title-cased with underscores as spaces>)".
Re-running deletes and recreates the playlist by name, so editing the YAML
and re-running is the whole maintenance workflow -- no manual Jellyfin ID lookups.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

BASE = "http://jellyfin.home"
KEY = os.environ["JELLYFIN_KEY"]


def call(path, method="GET", body=None):
    req = urllib.request.Request(
        f"{BASE}{path}",
        method=method,
        headers={"X-Emby-Token": KEY, "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None,
    )
    resp = urllib.request.urlopen(req)
    data = resp.read()
    return json.loads(data) if data else None


_series_cache = {}


def series_id(name):
    if name not in _series_cache:
        q = urllib.parse.quote(name)
        d = call(f"/Items?searchTerm={q}&IncludeItemTypes=Series&Recursive=true")
        matches = [i for i in d["Items"] if i["Name"] == name]
        if not matches:
            raise SystemExit(f"series not found in Jellyfin: {name!r}")
        _series_cache[name] = matches[0]["Id"]
    return _series_cache[name]


_episode_cache = {}


def season_episodes(name, season):
    key = (name, season)
    if key not in _episode_cache:
        sid = series_id(name)
        d = call(f"/Shows/{sid}/Episodes?Fields=IndexNumber,ParentIndexNumber")
        items = [e for e in d["Items"] if e.get("ParentIndexNumber") == season]
        items.sort(key=lambda e: e.get("IndexNumber") or 0)
        _episode_cache[key] = items
    return _episode_cache[key]


def resolve_entry(entry):
    if "movie" in entry:
        name = entry["movie"]
        q = urllib.parse.quote(name)
        d = call(f"/Items?searchTerm={q}&IncludeItemTypes=Movie&Recursive=true")
        matches = [i for i in d["Items"] if i["Name"] == name]
        if not matches:
            raise SystemExit(f"movie not found in Jellyfin: {name!r}")
        return [matches[0]["Id"]]
    if "series" in entry:
        eps = season_episodes(entry["series"], entry["season"])
        if not eps:
            raise SystemExit(f"no episodes found: {entry}")
        return [e["Id"] for e in eps]
    if "episode" in entry:
        eps = season_episodes(entry["episode"], entry["season"])
        needle = entry["name_contains"].lower()
        matches = [e for e in eps if needle in e["Name"].lower()]
        if not matches:
            raise SystemExit(f"no episode matched: {entry}")
        return [matches[0]["Id"]]
    raise SystemExit(f"unrecognised entry shape: {entry}")


def user_id():
    users = call("/Users")
    return users[0]["Id"]


def existing_playlist_id(name):
    d = call(f"/Items?IncludeItemTypes=Playlist&Recursive=true&SearchTerm={urllib.parse.quote(name)}")
    for i in d["Items"]:
        if i["Name"] == name:
            return i["Id"]
    return None


def build(json_path):
    spec = json.load(open(json_path))
    spec.pop("_comment", None)
    franchise = os.path.basename(json_path).rsplit(".", 1)[0].replace("_", " ").title()
    uid = user_id()

    for variant, entries in spec.items():
        ids = []
        for entry in entries:
            ids.extend(resolve_entry(entry))

        label = variant.replace("_", " ").title()
        playlist_name = f"{franchise} ({label})"

        old_id = existing_playlist_id(playlist_name)
        if old_id:
            call(f"/Items/{old_id}", method="DELETE")
            print(f"deleted existing playlist: {playlist_name}")

        result = call(
            "/Playlists",
            method="POST",
            body={"Name": playlist_name, "Ids": ids, "UserId": uid, "MediaType": "Video"},
        )
        print(f"created: {playlist_name} ({len(ids)} items) -> {result['Id']}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: build_playlist.py <path-to-json>")
    build(sys.argv[1])
