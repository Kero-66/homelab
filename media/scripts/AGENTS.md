# media/scripts — Configuration Automation

## Purpose
Idempotent scripts for configuring the media stack services via their APIs. Owns initial setup and reconfiguration automation. Does NOT own compose files or live service data.

## Entry Points
- `watch_orders/smartlist.py` - Create/update a Jellyfin SmartLists plugin playlist via its REST API (external-list-driven or native-rules-driven). Idempotent by playlist name. See its docstring; requires `JELLYFIN_KEY` env var and the SmartLists plugin installed with any needed provider API key already configured. Preferred over `build_playlist.py` for any franchise with an existing curated external list (IMDb/MDBList/Letterboxd) — see `ai/todo.md` #125.
- `watch_orders/build_playlist.py` - Legacy: builds a plain (non-smart) Jellyfin playlist from a manually-curated YAML/JSON entry list. Still the right tool when no curated external list exists and the correct order isn't expressible as a simple field sort (e.g. a movie needs to slot mid-series).
- `watch_orders/README.md` - Status table of every franchise playlist built so far (method used, item count, verified date), the manual-vs-SmartLists decision rule, rerun triggers for manual playlists, and the external-list provider capability matrix (which providers support episode-level ordering) — check before starting a new franchise or investigating why an existing one might need attention.
- `automate_all.sh` - Runs all configuration scripts in order
- `configure_indexers.sh` - Prowlarr general indexer setup
- `configure_anime_indexers.sh` - Anime-specific indexers (Nyaa, DMHY, BakaBT, etc.)
- `configure_bazarr.sh` / `configure_bazarr_anime_profile.sh` - Bazarr language profiles
- `configure_download_clients.sh` - qBittorrent/SABnzbd client registration in *arr apps
- `seed_prowlarr_indexers.sh` / `seed_jackett_indexers.sh` - Seed indexers into SQLite

## Contracts & Invariants
- Scripts target services by localhost port — run from the same host as the containers or via SSH tunnel
- All API keys sourced from Infisical `/media` at runtime — never hardcoded
- Scripts are idempotent: safe to re-run (check-before-insert pattern)

## Patterns
- Prowlarr indexer seeding writes directly to SQLite (`prowlarr.db`) — not via API (API has limitations)
- FlareSolverr proxy configured in both Prowlarr and Jackett: `http://172.39.0.9:8191/`
- Anime config scripts require AniDB client registered in Infisical (`ANIDB_CLIENT_SUBS`)

## Anti-patterns
- DO NOT run these scripts against the live TrueNAS stack without SSH tunnel or direct host access
- DO NOT bypass idempotency checks — re-running blindly can duplicate indexer entries

## Related Context
- `media/AGENTS.md` - Parent context
- `media/docs/ANIME_CONFIG.md` - Anime indexer and profile documentation
