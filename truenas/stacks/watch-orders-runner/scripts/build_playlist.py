#!/usr/bin/env python3
"""Build/update a Jellyfin watch-order playlist from a YAML definition.

Usage: JELLYFIN_KEY=... python3 build_playlist.py macross.yaml

Playlist ownership defaults to the first user returned by /Users -- unusable for
unattended/scheduled runs since ordering isn't guaranteed to be a specific person.
Set JELLYFIN_OWNER_USERID to pin it explicitly (same override as smartlist.py).

An entry whose content isn't in Jellyfin yet (movie/series/episode not found, or an
episode-range with nothing in it) is SKIPPED, not fatal -- the playlist still gets
built from everything that DID resolve, printing which entries were skipped and why.
This matters for an in-progress franchise: a JSON with 20 entries where 3 are still
downloading gets a real 17-item playlist today, not nothing, and the missing 3 splice
in automatically on a later run once they land (see truenas/stacks/watch-orders-runner/).
Only a genuine bug (malformed entry shape, missing JELLYFIN_KEY) is still fatal.

Each top-level key in the YAML (e.g. release_order, chronological_order)
becomes a playlist named "<Franchise> (<Key, title-cased with underscores as spaces>)".
Re-running deletes and recreates the playlist by name, so editing the YAML
and re-running is the whole maintenance workflow -- no manual Jellyfin ID lookups.

Entry shapes:
  {"series": name, "season": N}                                  -- whole season, in order
  {"series": name, "season": N, "episodes": [start, end]}         -- inclusive episode-number range
  {"episode": series_name, "season": N, "name_contains": substr}  -- one episode by name match
  {"movie": exact_title}                                          -- one movie

Use this (manual curation) instead of SmartLists external-list rules when no reliable
curated external list exists, or when a movie/OVA needs to slot mid-season -- something
no simple field sort or external-list-order sort can express. See
truenas/stacks/watch-orders-runner/scripts/smartlist.py for the external-list-driven path, which is
preferred when it works.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

# jellyfin.home (via Caddy) works from a host shell (SSH session, workstation)
# where AdGuard resolves .home -- a container on the jellyfin_default network
# has no such guarantee, so it overrides this to the Docker service name
# instead (see truenas/stacks/watch-orders-runner/compose.yaml).
BASE = os.environ.get("JELLYFIN_BASE_URL", "http://jellyfin.home")
KEY = os.environ["JELLYFIN_KEY"]


class MissingContent(Exception):
    """Raised when an entry can't be resolved because the content isn't in
    Jellyfin yet -- NOT a config error. Caught per-entry in build() so one
    missing title doesn't block every other title in the file from getting a
    playlist; the missing entry is just skipped and picked up automatically
    on a later run once it's downloaded."""


def call(path, method="GET", body=None):
    req = urllib.request.Request(
        f"{BASE}{path}",
        method=method,
        headers={"Authorization": f'MediaBrowser Token="{KEY}"', "Content-Type": "application/json"},
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
            raise MissingContent(f"series not found in Jellyfin: {name!r}")
        _series_cache[name] = matches[0]["Id"]
    return _series_cache[name]


_episode_cache = {}


def season_episodes(name, season):
    """Episodes of one season that actually have a media file on disk.

    Jellyfin returns an entry for every episode Sonarr knows about, including ones
    with no file yet - those come back as LocationType "Virtual" and are unplayable.
    Without this filter they land in the playlist as dead entries: .hack had S1E1-E8
    as Virtual, so the built playlist began with 8 unplayable items (found 2026-09-18).
    Note MediaSources is still length 1 on a Virtual episode, so checking that instead
    does not work - LocationType is the field that distinguishes them.
    """
    key = (name, season)
    if key not in _episode_cache:
        sid = series_id(name)
        d = call(f"/Shows/{sid}/Episodes?Fields=IndexNumber,ParentIndexNumber,LocationType")
        in_season = [e for e in d["Items"] if e.get("ParentIndexNumber") == season]
        items = [e for e in in_season if e.get("LocationType") != "Virtual"]
        dropped = len(in_season) - len(items)
        if dropped:
            missing = ", ".join(
                f"E{e.get('IndexNumber')}" for e in in_season
                if e.get("LocationType") == "Virtual"
            )
            print(f"  - {name!r} season {season}: omitting {dropped} episode(s) with no file ({missing})")
        items.sort(key=lambda e: e.get("IndexNumber") or 0)
        _episode_cache[key] = items
    return _episode_cache[key]


def episode_range(name, season, start, end):
    """Inclusive episode-number range within one season, e.g. episodes 1-10."""
    eps = season_episodes(name, season)
    matches = [e for e in eps if start <= (e.get("IndexNumber") or 0) <= end]
    if not matches:
        raise MissingContent(f"no episodes in range {start}-{end}: {name!r} season {season}")
    return matches


def resolve_entry(entry):
    if "movie" in entry:
        name = entry["movie"]
        q = urllib.parse.quote(name)
        d = call(f"/Items?searchTerm={q}&IncludeItemTypes=Movie&Recursive=true")
        matches = [i for i in d["Items"] if i["Name"] == name]
        if not matches:
            raise MissingContent(f"movie not found in Jellyfin: {name!r}")
        return [matches[0]["Id"]]
    if "series" in entry and "episodes" in entry:
        start, end = entry["episodes"]
        eps = episode_range(entry["series"], entry["season"], start, end)
        return [e["Id"] for e in eps]
    if "series" in entry:
        eps = season_episodes(entry["series"], entry["season"])
        if not eps:
            raise MissingContent(f"no episodes found: {entry}")
        return [e["Id"] for e in eps]
    if "episode" in entry:
        eps = season_episodes(entry["episode"], entry["season"])
        needle = entry["name_contains"].lower()
        matches = [e for e in eps if needle in e["Name"].lower()]
        if not matches:
            raise MissingContent(f"no episode matched: {entry}")
        return [matches[0]["Id"]]
    raise SystemExit(f"unrecognised entry shape: {entry}")


def user_id():
    override = os.environ.get("JELLYFIN_OWNER_USERID")
    if override:
        return override
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
        skipped = []
        for entry in entries:
            try:
                ids.extend(resolve_entry(entry))
            except MissingContent as e:
                skipped.append(str(e))

        if skipped:
            print(f"skipping {len(skipped)} not-yet-available entr{'y' if len(skipped) == 1 else 'ies'} (will retry next run):")
            for msg in skipped:
                print(f"  - {msg}")

        label = variant.replace("_", " ").title()
        playlist_name = f"{franchise} ({label})"

        if not ids:
            print(f"skipped entirely: {playlist_name} (nothing resolved yet)")
            continue

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
