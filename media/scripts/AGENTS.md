# media/scripts — Configuration Automation

## Purpose
Idempotent scripts for configuring the media stack services via their APIs. Owns initial setup and reconfiguration automation. Does NOT own compose files or live service data.

## Entry Points
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
