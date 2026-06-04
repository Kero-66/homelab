# Media Stack

## Purpose
Reference compose files and setup automation for the homelab media stack (Jellyfin, *arr apps, downloaders, Bazarr). The **live stack runs on TrueNAS** under `truenas/stacks/` — this directory is reference/archive and setup automation. Do not deploy from here.

## Entry Points
- `compose.yaml` - Reference compose (NOT deployed directly — use truenas/stacks/ via midclt)
- `docs/` - Setup guides: anime config, usenet, manga pipeline, deployment checklist
- `scripts/` - Configuration automation (see `scripts/AGENTS.md` for detail — ~50k tokens)
- `jellyfin/` - Jellyfin-specific config templates and scripts

## Contracts & Invariants

**Live config paths on TrueNAS:**
- Media: `/mnt/Data/media/{shows,movies,anime,music,tv,downloads}`
- Downloads: `/mnt/Data/downloads/{qbittorrent,sabnzbd,complete,incomplete}`
- Configs: `/mnt/Fast/docker/<service>/`

**API keys — stored in Infisical `/media`:**
- `JELLYFIN_API_KEY`, `SONARR_API_KEY`, `RADARR_API_KEY`, `BAZARR_API_KEY`, `PROWLARR_API_KEY`
- AniDB clients: `ANIDB_CLIENT_SUBS` (Bazarr), `ANIDB_CLIENT_PLAYLISTS` (watch order script)
- Trakt: `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`

**Bazarr config — must not be changed:**
- `use_embedded_subs: false` — embedded subs in anime releases are wrong
- `ignore_ass_subs: true` — .ass causes multi-line overlap in Jellyfin
- `use_subsync: true` — auto-sync enabled (series 90%, movie 70% threshold)
- Bazarr POST `/system/settings` silently ignores `enabled_providers` — edit `config.yaml` directly

**Service quirks:**
- Sonarr/Radarr cache health checks — trigger `CheckHealth` via API after config changes
- qBittorrent doesn't create download dirs at startup — only on first download
- subdl provider disabled — upstream KeyError bug (re-enable per todo#81 when fixed)

## Patterns
- Use service APIs before reaching for shell commands or ffprobe:
  - Jellyfin: `/Items/{id}/PlaybackInfo`
  - Sonarr: `/episodefile?seriesId=X`
  - Bazarr: `/episodes?seriesid[]=X`
- Scripts in `scripts/` are idempotent where noted — safe to re-run
- Anime indexers via Prowlarr built-in: Nyaa, AniDex, AnimeTosho, Anirena

## Anti-patterns
- DO NOT deploy `media/compose.yaml` directly — use `truenas/stacks/` via midclt
- DO NOT use ffprobe/python to query media info when a service API exists
- DO NOT edit Bazarr `enabled_providers` via API — it silently ignores it
- DO NOT re-enable subdl until upstream bug is fixed (see todo#81)

## Related Context
- `truenas/stacks/arr-stack/` - Live arr stack compose
- `truenas/stacks/jellyfin/` - Live Jellyfin compose
- `truenas/stacks/downloaders/` - Live downloader compose
- `media/scripts/AGENTS.md` - Detail on configuration automation scripts
- `ai/todo.md` - Open items: #81 (subdl), #82 (arr-stack network), #83 (watch order script)
