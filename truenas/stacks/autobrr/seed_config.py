#!/usr/bin/env python3
"""
autobrr pre-seed configuration script.
Configures download clients (Sonarr, Radarr, qBittorrent), Prowlarr Torznab feeds,
and a VOTOMS filter.

All secrets read from environment variables — never passed as args.

API notes (discovered against v1.78.0):
- Indexers: POST /indexer must exist before feed creation
- Feeds: POST /feeds with indexer_id — feeds without indexer_id are orphaned (invisible via GET)
- Filters: POST /filters creates shell; PUT /filters/{id} attaches indexers
- Actions: POST /actions with filter_id — NOT inline in filter body
- Prowlarr Torznab URL: http://prowlarr:9696/{prowlarr_indexer_id}/api
"""
import os, json, urllib.request, urllib.error

BASE = os.environ.get("AUTOBRR_BASE", "http://localhost:7474/api")
PROWLARR_BASE = os.environ.get("PROWLARR_BASE", "http://prowlarr:9696/prowlarr/api/v1")

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
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()}


def prowlarr_get(path):
    return api("GET", path, base=PROWLARR_BASE, token_header="X-Api-Key", token=PROWLARR_KEY)


def get_prowlarr_indexer_id(name):
    """Look up Prowlarr indexer ID by name — never hardcode IDs."""
    indexers = prowlarr_get("/indexer")
    match = next((i for i in indexers if i["name"].lower() == name.lower()), None)
    if not match:
        print(f"  WARNING: Prowlarr indexer '{name}' not found — skipping")
        return None
    return match["id"]


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


def ensure_indexer(identifier, name, settings=None):
    """Create autobrr indexer definition (required before feed).

    settings must be a dict[str,str] matching the indexer schema fields.
    torznab requires {"url": "...", "api_key": "..."}.
    rss requires {"url": "..."}.
    Omitting or passing {} leaves settings null in the DB → nil deref panic.
    """
    indexers = api("GET", "/indexer")
    existing = next((i for i in indexers if i["identifier"] == identifier and i["name"] == name), None)
    if existing:
        print(f"  indexer '{name}' already exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/indexer", {
        "identifier": identifier,
        "name": name,
        "identifier_external": name,
        "enabled": True,
        "settings": settings or {},
    })
    if "error" in result:
        print(f"  ERROR adding indexer {name}: {result}")
        return None
    print(f"  added indexer '{name}' (id={result['id']})")
    return result["id"]


def ensure_feed(name, indexer_id, prowlarr_indexer_id):
    """Create autobrr feed linked to indexer, using Prowlarr Torznab URL."""
    feeds = api("GET", "/feeds")
    existing = next((f for f in feeds if f["name"] == name), None)
    if existing:
        print(f"  feed '{name}' already exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/feeds", {
        "name": name,
        "type": "TORZNAB",
        "indexer_id": indexer_id,
        "url": f"http://prowlarr:9696/{prowlarr_indexer_id}/api",
        "api_key": PROWLARR_KEY,
        "enabled": True,
        "interval": 15,
        "timeout": 60,
    })
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
    # POST creates shell — indexers/actions attached separately
    result = api("POST", "/filters", {k: v for k, v in payload.items() if k not in ("actions", "indexers")})
    if "error" in result:
        print(f"  ERROR adding filter {name}: {result}")
        return None
    print(f"  added filter '{name}' (id={result['id']})")
    return result["id"]


def attach_filter_indexers(filter_id, filter_payload, indexers):
    """PUT /filters/{id} to attach indexers (list of {id, name} dicts)."""
    result = api("PUT", f"/filters/{filter_id}", {
        **filter_payload,
        "id": filter_id,
        "indexers": indexers,
    })
    if "error" in result:
        print(f"  ERROR attaching indexers to filter {filter_id}: {result}")
    else:
        names = [i["name"] for i in indexers]
        print(f"  attached indexers {names} to filter id={filter_id}")


def ensure_action(filter_id, action_name, payload):
    """POST /actions with filter_id — actions are NOT set via filter body."""
    actions = api("GET", "/actions")
    existing = next((a for a in actions if a.get("name") == action_name), None)
    if existing:
        print(f"  action '{action_name}' already exists (id={existing['id']})")
        return existing["id"]
    result = api("POST", "/actions", {**payload, "name": action_name, "filter_id": filter_id})
    if "error" in result:
        print(f"  ERROR adding action {action_name}: {result}")
        return None
    print(f"  added action '{action_name}' (id={result['id']})")
    return result["id"]


# ── Download clients ──────────────────────────────────────────────────────────

print("=== autobrr: configuring download clients ===")

ensure_download_client("qBittorrent", {
    "name": "qBittorrent", "type": "QBITTORRENT", "enabled": True,
    "host": "qbittorrent", "port": 8080, "tls": False, "tls_skip_verify": False,
    "settings": {"basic": {}, "rules": {"enabled": False}, "auth": {}}
})

sonarr_id = ensure_download_client("Sonarr", {
    "name": "Sonarr", "type": "SONARR", "enabled": True,
    "host": "sonarr", "port": 8989, "tls": False, "tls_skip_verify": False,
    "settings": {"apikey": SONARR_KEY, "basic": {}, "rules": {"enabled": False}, "auth": {}}
})

ensure_download_client("Radarr", {
    "name": "Radarr", "type": "RADARR", "enabled": True,
    "host": "radarr", "port": 7878, "tls": False, "tls_skip_verify": False,
    "settings": {"apikey": RADARR_KEY, "basic": {}, "rules": {"enabled": False}, "auth": {}}
})

# ── Indexers + feeds (via Prowlarr Torznab) ───────────────────────────────────

print("\n=== autobrr: configuring indexers + feeds ===")

# Look up Prowlarr indexer IDs dynamically — never hardcode
nyaa_prowlarr_id = get_prowlarr_indexer_id("Nyaa.si")
animetosho_prowlarr_id = get_prowlarr_indexer_id("AnimeTosho")

autobrr_indexers = {}

if nyaa_prowlarr_id:
    idx_id = ensure_indexer("torznab", "Nyaa.si", {
        "url": f"http://prowlarr:9696/{nyaa_prowlarr_id}/api",
        "api_key": PROWLARR_KEY,
    })
    ensure_feed("Nyaa.si (Prowlarr)", idx_id, nyaa_prowlarr_id)
    autobrr_indexers["Nyaa.si"] = idx_id

if animetosho_prowlarr_id:
    at_rss_url = f"http://prowlarr:9696/{animetosho_prowlarr_id}/api?t=search&q=&apikey={PROWLARR_KEY}"
    idx_id = ensure_indexer("rss", "AnimeTosho", {"url": at_rss_url})
    ensure_feed("AnimeTosho (Prowlarr)", idx_id, animetosho_prowlarr_id)
    autobrr_indexers["AnimeTosho"] = idx_id

# ── Filters ───────────────────────────────────────────────────────────────────

print("\n=== autobrr: configuring filters ===")

VOTOMS_BASE = {
    "name": "VOTOMS - Grab All",
    "enabled": True,
    "priority": 1,
    "shows": "Armored Trooper VOTOMS, VOTOMS, 装甲騎兵ボトムズ",
    "match_releases": "*VOTOMS*,*Votoms*,*votoms*,*ボトムズ*",
    "announce_types": ["NEW"],
    "resolutions": [],
    "sources": [],
    "codecs": [],
    "containers": [],
}

def setup_filter(name, shows, match_releases, client_id):
    base = {
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
    }
    fid = ensure_filter(name, base)
    if fid and autobrr_indexers:
        attach_filter_indexers(fid, base, [{"id": iid, "name": n} for n, iid in autobrr_indexers.items()])
    if fid and client_id:
        ensure_action(fid, "Send to Sonarr", {"type": "SONARR", "enabled": True, "client_id": client_id})
    return fid


# VOTOMS (main series + OVAs — all monitored in Sonarr)
setup_filter(
    "VOTOMS - Grab All",
    "Armored Trooper VOTOMS, VOTOMS, 装甲騎兵ボトムズ",
    "*VOTOMS*,*Votoms*,*votoms*,*ボトムズ*",
    sonarr_id,
)
setup_filter(
    "VOTOMS OVAs",
    "Armored Trooper VOTOMS: Pailsen Files, Armored Trooper VOTOMS: Phantom Chapter, Armored Trooper VOTOMS: Shining Heresy",
    "*VOTOMS*,*Votoms*,*Pailsen*,*Phantom Chapter*,*Shining Heresy*,*ボトムズ*",
    sonarr_id,
)

# Obscure old anime missing from Sonarr — autobrr catches uploads as they appear on Nyaa/AnimeTosho
setup_filter("Robotech", "Robotech", "*Robotech*", sonarr_id)
setup_filter(
    "Tekkaman Blade",
    "Tekkaman Blade",
    "*Tekkaman*,*宇宙の騎士テッカマン*",
    sonarr_id,
)
setup_filter("Blue Gender", "Blue Gender", "*Blue Gender*,*ブルージェンダー*", sonarr_id)
setup_filter(
    "Macross",
    "Macross 7, Macross Dynamite 7, Macross, Macross Zero, Macross Plus, Macross II, Macross Frontier",
    "*Macross*,*マクロス*",
    sonarr_id,
)
setup_filter("Trigun", "Trigun", "*Trigun*,*トライガン*", sonarr_id)
setup_filter("Gasaraki", "Gasaraki", "*Gasaraki*,*ガサラキ*", sonarr_id)
setup_filter(
    "Gundam Wing",
    "Mobile Suit Gundam Wing",
    "*Gundam Wing*,*ガンダムW*,*Gundam W*",
    sonarr_id,
)
setup_filter(".hack", ".hack", "*.hack*", sonarr_id)

print("\n=== Done ===")
