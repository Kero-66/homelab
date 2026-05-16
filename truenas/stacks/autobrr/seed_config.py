#!/usr/bin/env python3
"""
autobrr pre-seed configuration script.
Configures download clients (Sonarr, Radarr, qBittorrent), Prowlarr Torznab feed,
and a VOTOMS filter.

All secrets read from environment variables — never passed as args.
"""
import os, sys, json, urllib.request, urllib.error

BASE = "http://localhost:7474/api"
AUTOBRR_KEY = os.environ["AUTOBRR_KEY"]
SONARR_KEY = os.environ["SONARR_KEY"]
RADARR_KEY = os.environ["RADARR_KEY"]
PROWLARR_KEY = os.environ["PROWLARR_KEY"]


def api(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
        headers={"X-API-Token": AUTOBRR_KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()}


def ensure_download_client(name, payload):
    clients = api("GET", "/download_clients")
    existing = next((c for c in clients if c["name"] == name), None)
    if existing:
        print(f"  download_client '{name}' already exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/download_clients", payload)
    if "error" in result:
        print(f"  ERROR adding {name}: {result}")
        return None
    print(f"  added download_client '{name}' (id={result['id']})")
    return result["id"]


def ensure_feed(name, payload):
    feeds = api("GET", "/feeds")
    existing = next((f for f in feeds if f["name"] == name), None)
    if existing:
        print(f"  feed '{name}' already exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/feeds", payload)
    if "error" in result:
        print(f"  ERROR adding feed {name}: {result}")
        return None
    print(f"  added feed '{name}' (id={result['id']})")
    return result["id"]


def ensure_filter(name, payload):
    filters = api("GET", "/filters")
    existing = next((f for f in filters if f["name"] == name), None)
    if existing:
        print(f"  filter '{name}' already exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/filters", payload)
    if "error" in result:
        print(f"  ERROR adding filter {name}: {result}")
        return None
    print(f"  added filter '{name}' (id={result['id']})")
    return result["id"]


print("=== autobrr: configuring download clients ===")

# qBittorrent (check if already exists from initial setup)
ensure_download_client("qBittorrent", {
    "name": "qBittorrent", "type": "QBITTORRENT", "enabled": True,
    "host": "qbittorrent", "port": 8080, "tls": False, "tls_skip_verify": False,
    "settings": {"basic": {}, "rules": {"enabled": False}, "auth": {}}
})

# Sonarr
sonarr_id = ensure_download_client("Sonarr", {
    "name": "Sonarr", "type": "SONARR", "enabled": True,
    "host": "sonarr", "port": 8989, "tls": False, "tls_skip_verify": False,
    "settings": {"apikey": SONARR_KEY, "basic": {}, "rules": {"enabled": False}, "auth": {}}
})

# Radarr
radarr_id = ensure_download_client("Radarr", {
    "name": "Radarr", "type": "RADARR", "enabled": True,
    "host": "radarr", "port": 7878, "tls": False, "tls_skip_verify": False,
    "settings": {"apikey": RADARR_KEY, "basic": {}, "rules": {"enabled": False}, "auth": {}}
})

print("\n=== autobrr: configuring feeds (Prowlarr Torznab) ===")

# Nyaa via Prowlarr Torznab (Prowlarr indexer ID 1 = Nyaa)
nyaa_feed_id = ensure_feed("Nyaa (Prowlarr)", {
    "name": "Nyaa (Prowlarr)",
    "type": "TORZNAB",
    "url": "http://prowlarr:9696/1/api",
    "api_key": PROWLARR_KEY,
    "enabled": True,
    "interval": 15,
    "timeout": 60
})

print("\n=== autobrr: configuring filters ===")

# VOTOMS - grab everything
votoms_filter = {
    "name": "VOTOMS - Grab All",
    "enabled": True,
    "shows": "Armored Trooper VOTOMS, VOTOMS, 装甲騎兵ボトムズ",
    "years": "",
    "resolutions": [],
    "sources": [],
    "codecs": [],
    "containers": [],
    "match_releases": "*VOTOMS*,*Votoms*,*votoms*,*ボトムズ*",
    "except_releases": "",
    "indexers": [{"id": nyaa_feed_id, "name": "Nyaa (Prowlarr)"}] if nyaa_feed_id else [],
    "actions": [
        {
            "name": "Send to qBittorrent",
            "type": "QBITTORRENT",
            "enabled": True,
            "client_id": 1,
            "save_path": "/data/downloads/complete/anime",
            "category": "anime",
            "tags": "votoms,autobrr"
        }
    ],
    "priority": 1
}
ensure_filter("VOTOMS - Grab All", votoms_filter)

print("\n=== Done ===")
