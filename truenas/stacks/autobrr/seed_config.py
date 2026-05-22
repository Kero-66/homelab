#!/usr/bin/env python3
"""
autobrr seed configuration script.
Idempotent — safe to re-run. Uses upsert semantics throughout.

Verified against autobrr v1.79.0 API docs.

Key API facts:
- Download client host: full URL "http://host:port" (port field is Deluge-only)
- Indexers: POST /indexer before feed; settings must be map[str,str] with url
- Filters: PATCH /filters/{id} sets indexers + actions in one call
- Actions: inline in filter PATCH payload, not via separate POST /actions

Run from TrueNAS (Python 3.11 available natively):
  AUTOBRR_KEY=... SONARR_KEY=... RADARR_KEY=... PROWLARR_KEY=... \\
  AUTOBRR_BASE=http://localhost:7474/api \\
  PROWLARR_BASE=http://localhost:9696/prowlarr/api/v1 \\
  python3 seed_config.py
"""
import os, json, urllib.request, urllib.error

BASE = os.environ.get("AUTOBRR_BASE", "http://localhost:7474/api")
PROWLARR_BASE = os.environ.get("PROWLARR_BASE", "http://localhost:9696/prowlarr/api/v1")

AUTOBRR_KEY = os.environ["AUTOBRR_KEY"]
SONARR_KEY = os.environ["SONARR_KEY"]
RADARR_KEY = os.environ["RADARR_KEY"]
PROWLARR_KEY = os.environ["PROWLARR_KEY"]


def api(method, path, body=None, base=BASE, token_header="X-API-Token", token=None):
    url = base + path
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json", token_header: token or AUTOBRR_KEY}
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read()
            return json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()}


def prowlarr_get(path):
    return api("GET", path, base=PROWLARR_BASE, token_header="X-Api-Key", token=PROWLARR_KEY)


def get_prowlarr_indexer_id(name):
    indexers = prowlarr_get("/indexer")
    if isinstance(indexers, dict) and "error" in indexers:
        print(f"  ERROR reaching Prowlarr: {indexers}")
        return None
    match = next((i for i in indexers if i["name"].lower() == name.lower()), None)
    if not match:
        print(f"  WARNING: Prowlarr indexer '{name}' not found")
        return None
    return match["id"]


# ── Download clients ──────────────────────────────────────────────────────────

def upsert_download_client(name, payload):
    """PUT update if exists, POST create if not."""
    clients = api("GET", "/download_clients")
    existing = next((c for c in clients if c["name"] == name), None)
    if existing:
        result = api("PUT", "/download_clients", {**payload, "id": existing["id"]})
        if "error" in result:
            print(f"  ERROR updating {name}: {result}")
            return None
        print(f"  updated download_client '{name}' (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/download_clients", payload)
    if "error" in result:
        print(f"  ERROR adding {name}: {result}")
        return None
    print(f"  added download_client '{name}' (id={result['id']})")
    return result["id"]


print("=== download clients ===")

sonarr_id = upsert_download_client("Sonarr", {
    "name": "Sonarr",
    "type": "SONARR",
    "enabled": True,
    "host": "http://sonarr:8989",
    "settings": {"apikey": SONARR_KEY, "basic": {"auth": False}},
})

upsert_download_client("Radarr", {
    "name": "Radarr",
    "type": "RADARR",
    "enabled": True,
    "host": "http://radarr:7878",
    "settings": {"apikey": RADARR_KEY, "basic": {"auth": False}},
})


# ── Indexers + feeds ──────────────────────────────────────────────────────────

def upsert_indexer(identifier, name, settings):
    """Create indexer; skip if identifier already exists (settings rarely change)."""
    indexers = api("GET", "/indexer")
    existing = next((i for i in indexers if i["identifier"] == identifier), None)
    payload = {
        "identifier": identifier,
        "name": name,
        "identifier_external": name,
        "enabled": True,
        "settings": settings,
    }
    if existing:
        print(f"  indexer '{name}' exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/indexer", payload)
    if "error" in result:
        print(f"  ERROR adding indexer {name}: {result}")
        return None
    print(f"  added indexer '{name}' (id={result['id']})")
    return result["id"]


def upsert_feed(name, indexer_id, url, api_key=None, feed_type="TORZNAB"):
    """Create feed; update URL/indexer if it already exists."""
    feeds = api("GET", "/feeds")
    payload = {
        "name": name,
        "type": feed_type,
        "indexer_id": indexer_id,
        "url": url,
        "enabled": True,
        "interval": 15,
        "timeout": 60,
    }
    if api_key:
        payload["api_key"] = api_key
    existing = next((f for f in feeds if f["name"] == name), None)
    if existing:
        result = api("PUT", f"/feeds/{existing['id']}", {**payload, "id": existing["id"]})
        if "error" in result:
            print(f"  ERROR updating feed {name}: {result}")
            return None
        print(f"  updated feed '{name}' (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/feeds", payload)
    if "error" in result:
        print(f"  ERROR adding feed {name}: {result}")
        return None
    print(f"  added feed '{name}' (id={result['id']})")
    return result["id"]


print("\n=== indexers + feeds ===")

nyaa_prowlarr_id = get_prowlarr_indexer_id("Nyaa.si")
animetosho_prowlarr_id = get_prowlarr_indexer_id("AnimeTosho")

autobrr_indexers = {}

if nyaa_prowlarr_id:
    idx_id = upsert_indexer("torznab", "Nyaa.si", {
        "url": f"http://prowlarr:9696/{nyaa_prowlarr_id}/api",
        "api_key": PROWLARR_KEY,
    })
    if idx_id:
        upsert_feed(
            "Nyaa.si (Prowlarr)", idx_id,
            url=f"http://prowlarr:9696/{nyaa_prowlarr_id}/api",
            api_key=PROWLARR_KEY,
            feed_type="TORZNAB",
        )
        autobrr_indexers["Nyaa.si"] = idx_id

if animetosho_prowlarr_id:
    at_url = f"http://prowlarr:9696/{animetosho_prowlarr_id}/api?t=search&q=&apikey={PROWLARR_KEY}"
    idx_id = upsert_indexer("rss", "AnimeTosho", {"url": at_url})
    if idx_id:
        upsert_feed(
            "AnimeTosho (Prowlarr)", idx_id,
            url=at_url,
            feed_type="TORZNAB",
        )
        autobrr_indexers["AnimeTosho"] = idx_id


# ── Filters ───────────────────────────────────────────────────────────────────

def upsert_filter(name, shows, match_releases):
    """Create or PATCH filter with indexers. Actions managed separately via DELETE+POST.

    PATCH appends actions (not idempotent) and ignores actions:[].
    So actions are managed by: delete all existing, then POST the correct one.
    """
    filters = api("GET", "/filters")
    existing = next((f for f in filters if f["name"] == name), None)

    # No actions in PATCH payload — PATCH only appends, never replaces
    filter_payload = {
        "name": name,
        "enabled": True,
        "priority": 1,
        "shows": shows,
        "match_releases": match_releases,
        "announce_types": ["NEW"],
        "resolutions": [],
        "sources": [],
        "codecs": [],
        "containers": [],
        "indexers": [{"id": iid, "name": n} for n, iid in autobrr_indexers.items()],
    }

    if existing:
        fid = existing["id"]
        result = api("PATCH", f"/filters/{fid}", {**filter_payload, "id": fid})
        if "error" in result:
            print(f"  ERROR updating filter '{name}': {result}")
            return None
        print(f"  updated filter '{name}' (id={fid})")
    else:
        result = api("POST", "/filters", filter_payload)
        if "error" in result:
            print(f"  ERROR adding filter '{name}': {result}")
            return None
        fid = result["id"]
        api("PATCH", f"/filters/{fid}", {**filter_payload, "id": fid})
        print(f"  added filter '{name}' (id={fid})")

    # Actions: PATCH appends (never replaces), POST /api/actions doesn't link.
    # Pattern: delete all existing → PATCH once with desired action.
    full_filter = api("GET", f"/filters/{fid}")
    for action in full_filter.get("actions", []):
        api("DELETE", f"/actions/{action['id']}")

    patch_with_action = api("PATCH", f"/filters/{fid}", {
        **filter_payload,
        "id": fid,
        "actions": [{
            "name": "Send to Sonarr",
            "type": "SONARR",
            "enabled": True,
            "client_id": sonarr_id,
        }],
    })
    if "error" in patch_with_action:
        print(f"  ERROR setting action on filter '{name}': {patch_with_action}")
    else:
        print(f"  set action 'Send to Sonarr' (client_id={sonarr_id}) on filter '{name}'")

    return fid


print("\n=== filters ===")

upsert_filter("VOTOMS - Grab All",
    "Armored Trooper VOTOMS, VOTOMS, 装甲騎兵ボトムズ",
    "*VOTOMS*,*Votoms*,*votoms*,*ボトムズ*")
upsert_filter("VOTOMS OVAs",
    "Armored Trooper VOTOMS: Pailsen Files, Armored Trooper VOTOMS: Phantom Chapter, Armored Trooper VOTOMS: Shining Heresy",
    "*VOTOMS*,*Votoms*,*Pailsen*,*Phantom Chapter*,*Shining Heresy*,*ボトムズ*")
upsert_filter("Robotech", "Robotech", "*Robotech*")
upsert_filter("Tekkaman Blade", "Tekkaman Blade", "*Tekkaman*,*宇宙の騎士テッカマン*")
upsert_filter("Blue Gender", "Blue Gender", "*Blue Gender*,*ブルージェンダー*")
upsert_filter("Macross",
    "Macross 7, Macross Dynamite 7, Macross, Macross Zero, Macross Plus, Macross II, Macross Frontier",
    "*Macross*,*マクロス*")
upsert_filter("Trigun", "Trigun", "*Trigun*,*トライガン*")
upsert_filter("Gasaraki", "Gasaraki", "*Gasaraki*,*ガサラキ*")
upsert_filter("Gundam Wing", "Mobile Suit Gundam Wing", "*Gundam Wing*,*ガンダムW*,*Gundam W*")
upsert_filter(".hack", ".hack", "*.hack*")

print("\n=== Done ===")
