# Session Notes

This file captures active session context, decisions, and in-progress research to allow resuming work across sessions.

---

## Session 2026-05-29 - Trakt Integration (COMPLETED)

### What Was Done

1. **Trakt account created** by user, API app created at trakt.tv/oauth/applications
2. **Secrets stored in Infisical** at `/media`: `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`
3. **Jellyfin Trakt plugin** — already installed (v30.0.0.0, Active). Authenticated via Jellyfin web UI (Admin → Plugins → Trakt → Authenticate). Token valid until 2026-06-04 (auto-renews).
4. **Active config**: Scrobble=true, PostWatchedHistory=true, SynchronizeCollections=true

### Next Steps
- [ ] Monitor scrobbling — check Trakt profile after watching something
- [ ] Revisit Radarr/Sonarr Trakt import lists once watch history has built up (skipped for now — Jellyseerr handles requests, import lists add no value until Trakt has meaningful history)

### Key Facts

| Item | Value |
|------|-------|
| Trakt secrets | Infisical `/media` — `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET` |
| Jellyfin plugin | Trakt v30.0.0.0, plugin GUID `4fe3201ed6ae4f2e8917e12bda571281` |
| Plugin config endpoint | `GET/POST http://jellyfin.home/Plugins/4fe3201ed6ae4f2e8917e12bda571281/Configuration` |
| Auth method | OAuth via Jellyfin web UI (browser flow, not API-automatable) |
| Jellyfin user linked | `1ecfce63139f4501a4d498e372e1ee3d` |

---

## Session 2026-05-22 - Jellyfin Playback + Franchise Watch Order Research (COMPLETED)

### What Was Done

1. **Fixed Jellyfin "too many errors" on Omniscient Reader: The Prophecy**
   - Root cause: `EnableTonemapping: true` with `EnableVppTonemapping: false` → used OpenCL tonemapping, but OpenCL not available in container (`Failed to get number of OpenCL platforms: -1001`)
   - Fix: `EnableTonemapping: false`, `EnableVppTonemapping: true` → now uses Intel VAAPI VPP tonemapping (no OpenCL needed)
   - Applied via Jellyfin API POST `/System/Configuration/encoding`
   - N150 transcodes at 2.16x real-time speed — hardware is fine

2. **Diagnosed AndroidTV freezing at 5s**
   - Root cause: AndroidTV app bitrate cap was 20Mbps; file is ~30Mbps → forced transcode; transcode fast enough but WiFi at 20Mbps was unstable
   - Fix: Set AndroidTV app quality to **Auto** (dynamic bitrate adjustment) — or use 30Mbps which works fine on this WiFi
   - Note: 10Mbps and 30Mbps both work; 20Mbps was the unstable point

3. **Researched franchise watch order tools for Jellyfin**
   - No dedicated franchise-watch-order plugin exists
   - Best option: Trakt custom list (community Macross watch order exists) + **Synclet** to sync → Jellyfin collection
   - Alternative: **jellyfin-smartlists-plugin** (pulls from MDBList/Trakt/TMDB)
   - ClassicTV plugin does cross-series interleaving but round-robin only, not franchise-order aware

### Key Facts

| Item | Value |
|---|---|
| Jellyfin tonemapping | VPP (`EnableVppTonemapping: true`) — OpenCL unavailable in container |
| AndroidTV stable bitrates | 10Mbps ✅, 30Mbps ✅ (direct play), 20Mbps ❌ (WiFi instability) |
| Synclet | Trakt lists → Jellyfin collections sync tool |
| smartlists-plugin | GitHub: jyourstone/jellyfin-smartlists-plugin |

---

## Session 2026-05-22 - autobrr Crash Diagnosis + DB Repair (COMPLETED)

### What Was Done

1. **Diagnosed autobrr crash loop** — nil pointer panic at `indexer/service.go:414` on every start
   - Root cause: `seed_config.py` created indexers with `settings: {}` (or omitted)
   - autobrr stores settings as a BLOB; omitting them stores `X'6E756C6C'` (null bytes) not `X'7B7D'` (`{}`)
   - On startup, autobrr dereferences `settings.url` → nil → SIGSEGV
   - This affects ALL versions (v1.78.0 and v1.79.0), not a version regression

2. **DB repair journey**
   - `settings = {}` fix insufficient — panic persisted
   - Real fix: indexer POST requires `settings` as `map[string]string` with `url` (and optionally `api_key`)
   - torznab: `{"url": "http://prowlarr:9696/{id}/api", "api_key": "PROWLARR_KEY"}`
   - rss: `{"url": "http://prowlarr:9696/{id}/api?t=search&q=&apikey=KEY"}`
   - Orphaned feeds (indexer_id=0 or pointing to deleted indexers) also caused panics
   - Final fix: wiped `indexer`, `feed`, `filter_indexer` tables; kept filters/download_clients/actions

3. **seed_config.py fixes committed**
   - `ensure_indexer` now takes `settings` param (required, not optional `{}`)
   - `BASE` and `PROWLARR_BASE` now read from env vars (needed to run from Docker container on arr-stack network)
   - Run command: `docker run --rm --network ix-arr-stack_default -e AUTOBRR_BASE=http://autobrr:7474/api ...`

4. **Infisical updated**
   - `AUTOBRR_API_KEY` path was `/TrueNAS` (not `/media` as old notes said) — updated to correct value
   - Key: `238af46d5c776cf7d6e90251d2ac14b4`

5. **autobrr now on v1.79.0 (latest), running clean**
   - DB: download clients intact, 10 filters intact, 0 indexers/feeds (not yet re-seeded)

### Final State (COMPLETED 2026-05-23)

| Item | State |
|---|---|
| autobrr | Running v1.79.0, UP, no panics |
| DB — download clients | ✅ Sonarr, Radarr (qBittorrent removed — autobrr sends to Sonarr/Radarr only) |
| DB — filters | ✅ 10 filters (VOTOMS, VOTOMS OVAs, Robotech, Tekkaman Blade, Blue Gender, Macross, Trigun, Gasaraki, Gundam Wing, .hack) |
| DB — indexers/feeds | ✅ Nyaa.si (torznab) + AnimeTosho (rss), both linked to Prowlarr |
| DB — filter_indexer | ✅ All 10 filters attached to both indexers |
| autobrr lists | ✅ Pulling 92 Sonarr shows + 98 Radarr movies, auto-updating filter show lists |
| Feed polling | ✅ Verified at ~00:55 AEST — processing real Nyaa.si releases, rejecting correctly |
| seed_config.py | ✅ Idempotent upsert semantics — safe to re-run |
| Security review | ✅ No findings ≥0.8 confidence |

Re-seed run successfully. All indexers, feeds, and filter attachments restored.

**Run pattern if re-seeding needed**:
```bash
# TrueNAS has Python 3.11 natively — no Docker image pull needed
scp -i "$TMPKEY" truenas/stacks/autobrr/seed_config.py kero66@192.168.20.22:/tmp/seed_config.py
ssh -i "$TMPKEY" kero66@192.168.20.22 \
  "AUTOBRR_KEY='...' SONARR_KEY='...' RADARR_KEY='...' PROWLARR_KEY='...' \
   AUTOBRR_BASE=http://localhost:7474/api \
   PROWLARR_BASE=http://localhost:9696/prowlarr/api/v1 \
   python3 /tmp/seed_config.py && rm /tmp/seed_config.py"
```

### Key Facts — autobrr API (verified v1.78.0 + v1.79.0)

| Fact | Detail |
|---|---|
| Indexer settings format | `map[string]string` — NOT array, NOT `{}` |
| torznab required fields | `url`, optionally `api_key` |
| rss required field | `url` |
| Null settings | Stored as BLOB `X'6E756C6C'` → SIGSEGV on startup |
| AUTOBRR_API_KEY Infisical path | `/TrueNAS` (not `/media`) |
| Seed run context | Must run inside Docker on `ix-arr-stack_default` network |
| Prowlarr base URL (in-network) | `http://prowlarr:9696/prowlarr/api/v1` |
| autobrr base URL (in-network) | `http://autobrr:7474/api` |

---

## Session 2026-05-16 to 2026-05-22 - autobrr Setup + Missing Shows + Subtitle Fixes (COMPLETED)

### What Was Done

1. **autobrr fully configured** (was deployed but empty)
   - Download clients: qBittorrent, Sonarr, Radarr
   - Indexers/feeds: Nyaa.si (torznab via Prowlarr), AnimeTosho (rss identifier — one torznab limit)
   - Filters: VOTOMS, VOTOMS OVAs, Robotech, Tekkaman Blade, Blue Gender, Macross, Trigun, Gasarr, Gundam Wing, .hack
   - All filters push to Sonarr; monitored via Nyaa.si + AnimeTosho
   - Seed script `truenas/stacks/autobrr/seed_config.py` corrected and idempotent

2. **autobrr API quirks (v1.78.0)**
   - `POST /indexer` must exist before feed creation — feeds without `indexer_id` are orphaned (invisible via GET /feeds)
   - Actions via `POST /actions` with `filter_id` — NOT inline in filter body or via filter PUT
   - Filter indexers via `PUT /filters/{id}` — not in initial POST
   - Only one indexer per `identifier` (UNIQUE constraint) — Nyaa.si uses `torznab`, AnimeTosho uses `rss`
   - AnimeTosho RSS feed URL: `http://prowlarr:9696/3/api?t=search&q=&apikey=KEY` (Torznab search-as-RSS)

3. **Triggered SeriesSearch for all 22 missing series** in Sonarr

4. **Bazarr: added subf2m provider** (no account needed) for English subtitle support on Korean/Asian content
   - Config file edit required — `POST /system/settings` API ignores `enabled_providers` changes
   - Edit: `/mnt/Fast/docker/bazarr/config/config.yaml` → restart arr-stack via midclt

5. **Omniscient Reader: The Prophecy subtitle fixed**
   - Downloaded English sub from subf2m (AMZN KyoGo retail)
   - Shifted -6000ms (subs were 6s behind BD encode vs WEB-DL timing)
   - File: `.en.hi.srt` (SDH — full dialogue translation, sound descriptions included)
   - Backup: `.en.hi.srt.bak`

### Key Facts

| Item | Value |
|------|-------|
| autobrr URL | http://autobrr.home (port 7474) |
| autobrr API key | `AUTOBRR_API_KEY` in Infisical `/TrueNAS` (NOT `/media`) |
| Bazarr config file | `/mnt/Fast/docker/bazarr/config/config.yaml` |
| Bazarr enabled providers | animetosho, gestdown, bsplayer, subf2m |
| AnimeTosho Prowlarr ID | 3 |
| Nyaa.si Prowlarr ID | 1 |

### Outstanding
- Sonarr searches for missing series running — check http://sonarr.home/activity/queue for results
- autobrr compose.yaml pinned to v1.78.0 by user

### Omniscient Reader subtitle (2026-05-23) — RESOLVED
- Previous -6000ms manual shift was still off (subs late vs Korean audio)
- Triggered Bazarr subsync via `PATCH /bazarr/api/subtitles` with `reference=a:1` (Korean audio stream)
- Subsync applied additional ~-4.3s shift; file updated `May 23 00:01`
- Correct Bazarr sync API documented in PATTERNS.md → "Manually trigger subsync on an existing subtitle"

---

## Session 2026-05-16 - Hook Fixes + Ninja Kamui E05 Subtitle Sync (COMPLETED)

### What Was Done

1. **Fixed mempalace hooks failing at startup**
   - Root cause: `mempalace` Python package not installed — hooks couldn't find `mempalace` CLI binary
   - Fix: installed via `/usr/bin/python3 -m pip install mempalace` (system Python 3.9, NOT Homebrew 3.14 which has a broken libexpat)
   - Binary lands in `~/Library/Python/3.9/bin` which isn't on PATH in hook context
   - Fix: added `export PATH="$PATH:$HOME/Library/Python/3.9/bin"` to both wrapper hooks:
     - `~/.claude/hooks/mempalace-stop.sh`
     - `~/.claude/hooks/mempalace-precompact.sh`

2. **Fixed Ninja Kamui S01E05 subtitles out of sync**
   - File: `Ninja Kamui - S01E05 - 005 - Episode 5 Bluray-1080p x264 Opus 2.0 [JA] -BBF [tvdbid-420280].mkv`
   - Root cause: BBF is a Blu-ray encode; Bazarr downloaded an `.en.srt` timed for a WEB-DL release — BD timing is ~3.21s earlier
   - Diagnosed by extracting the embedded Italian ASS sub (correctly timed for BD) and comparing first dialogue timestamps
   - Fix: shifted all SRT timestamps back 3213ms using a Python script run via SSH on TrueNAS
   - Backup saved as `.en.srt.bak`
   - See PATTERNS.md → "BD Subtitle Timing Offset Fix" for the reusable pattern

### Key Facts

| Item | Value |
|------|-------|
| mempalace Python path | `~/Library/Python/3.9/bin/mempalace` (system Python 3.9) |
| Why not Homebrew Python | Homebrew Python 3.14 has broken libexpat (`dlopen` Symbol not found) |
| E05 timing offset | -3213ms (WEB sub → BD encode) |
| E05 reference sub | Embedded Italian ASS track (stream 0:2), correctly timed for BD |
| E05 SRT backup | Same path + `.bak` extension |

---

## Session 2026-05-29 - Watch Order Playlists (COMPLETED)

### Problem
User wants to watch anime series in correct watch order (including movies/OVAs interleaved) without manually hunting for what to watch next. Jellyfin has no native cross-series watch order support. No existing tool solves this end-to-end.

### Process (Manual — to be automated)

**Step 1: Look up correct watch order**
- Source: AniDB HTTP API (client: `kplaylists` v1) — fetch anime by AID, traverse `relatedanime` relations
- AniDB titles dump: `https://anidb.net/api/anime-titles.xml.gz` — search for AIDs by name

**Step 2: Check watch history via Jellystat**
```bash
JELLYSTAT_API_KEY=$(infisical secrets get JELLYSTAT_API_KEY --env dev --path /media --plain ...)
curl -s -X GET -H "x-api-token: $JELLYSTAT_API_KEY" \
  "http://jellystat.home/api/getHistory?size=200&page=1&search=<show>"
```

**Step 3: Get all Jellyfin item IDs**
```bash
JELLYFIN_API_KEY=$(infisical secrets get JELLYFIN_API_KEY --env dev --path /media --plain ...)
curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  "http://jellyfin.home/Items?searchTerm=<show>&Recursive=true&IncludeItemTypes=Series,Movie&fields=Name,ProductionYear"
curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  "http://jellyfin.home/Shows/{seriesId}/Episodes"
```

**Step 4: Create playlist**
```bash
curl -s -X POST -H "X-Emby-Token: $JELLYFIN_API_KEY" -H "Content-Type: application/json" \
  "http://jellyfin.home/Playlists" \
  -d '{"Name": "...", "Ids": [...], "UserId": "...", "MediaType": "Unknown"}'
```

### Playlists Created
- **Macross Watch Order** — 237 items, playlist ID `89f8fafd8409a0798569199b793da23f`
- **Tekkaman Blade Watch Order** — 66 items, playlist ID `e0d15ebfa210c1f47d9e43e147f4222f`
- **Playlist DB**: `media/playlists/` — YAML files with AniDB IDs, Jellyfin IDs, gaps marked `jellyfin_id: null`

### Key API Facts

| Service | Endpoint | Notes |
|---------|----------|-------|
| Jellystat | `GET /api/getHistory?search=X&size=N&page=N` | Global history search |
| Jellystat | `POST /api/getItemHistory` body `{id, page, size}` | Per-item history |
| Jellystat | `GET /swagger/swagger-ui-init.js` | Full swagger spec embedded in JS |
| Jellyfin | `GET /Shows/{id}/Episodes` | All episodes with season/episode numbers |
| Jellyfin | `POST /Playlists` body `{Name, Ids[], UserId, MediaType}` | Create playlist |
| AniDB HTTP | `http://api.anidb.net:9001/httpapi?request=anime&client=kplaylists&clientver=1&protover=1&aid=X` | Anime + relations |
| AniDB titles | `https://anidb.net/api/anime-titles.xml.gz` | Full titles dump for AID lookup |

### AniDB Client
- **API client name**: `kplaylists` (stored in Infisical `/media` as `ANIDB_CLIENT_PLAYLISTS`)
- **Software name** (display): AnimePlaylists — the API name differs, must use `kplaylists`
- **Version**: 1 (`ANIDB_CLIENT_PLAYLISTS_VER`)

---

## Session 2026-04-11 - Sonarr/Radarr Fixes + Recyclarr Sync (COMPLETED)

### What Was Done

1. **Fixed Jellyfin notification DNS error** (`NotificationService: Name jellyfin does not resolve`)
   - Root cause: Sonarr/Radarr/Bazarr not on `ix-jellyfin_default` network — Docker DNS can't cross network boundaries
   - Fix: added `networks: [default, ix-jellyfin_default]` to sonarr, radarr, bazarr in arr-stack compose, declared `ix-jellyfin_default` as external network
   - Pattern: mirrors how downloaders joins `ix-arr-stack_default` (consumer joins provider's network)

2. **Fixed Recyclarr never syncing**
   - Root cause: base URLs were `172.39.0.x` (old workstation IPs from pre-TrueNAS migration)
   - Fix: replaced with Docker service names `http://radarr:7878/radarr`, `http://sonarr:8989/sonarr`
   - Also removed stale `include:` blocks referencing templates that don't exist in the container

3. **Fixed invalid Repack2 trash_id** (Radarr line 90)
   - Wrong: `ae43b294c4a7a5ba8f4891e3e22e3e22`
   - Correct Radarr: `ae43b294509409a6a13919dedd4764c4`

4. **Fixed x265 (HD) blocking anime imports** (VCB-Studio, fansub encodes)
   - x265 default score is -10000 — correct for Standard/4K, wrong for Anime (BDs are almost always x265)
   - Split into per-profile scoring: score 0 for Anime (1080p), -10000 for Standard and Ultra-HD (4K)
   - Applied in both Radarr and Sonarr sections

5. **Ran `recyclarr state repair --adopt` then `recyclarr sync`** — succeeded
   - Radarr: 4 CFs updated, 3 profiles; Sonarr: 6 CFs updated, 3 profiles
   - Verified via API: Anime BD Tier 01-08 = 1400→700, Web Tier 01-06 = 600→100, x265 = 0 on Anime / -10000 on Standard+4K

6. **Created `truenas/scripts/import_downloads.sh`**
   - Scans qBittorrent + SABnzbd completed dirs, auto-imports matched files into Sonarr/Radarr
   - Reports unmatched/rejected files with reason; supports `--dry-run`
   - See PATTERNS.md → Manual Import Script

### Key Facts

| Item | Value |
|------|-------|
| Recyclarr config (live) | `/mnt/Fast/docker/recyclarr/config/recyclarr.yml` |
| Recyclarr config (repo, gitignored) | `media/recyclarr/config/recyclarr.yml` |
| Trash_id cache | `media/recyclarr/config/cache/resources/trash-guides/git/official/docs/json/` |
| Recyclarr cron | `@daily` — check: `sudo docker logs recyclarr --tail 50` |
| arr-stack network change | sonarr, radarr, bazarr now on `ix-jellyfin_default` |
| x265 (HD) Radarr trash_id | `dc98083864ea246d05a42df0d05f81cc` |
| x265 (HD) Sonarr trash_id | `47435ece6b99a0b477caf360e79ba0bb` |

---

## Session 2026-03-17 - Villainess Level 99 E08 Subtitle Fix + Bazarr Config (COMPLETED)

### What Was Done

1. **Fixed wrong subtitles in Villainess Level 99 S01E08**
   - Root cause: upstream mislabeling — every release (VARYG WEBDL, SubsPlease HDTV) shipped *Mr. Villain's Day Off* subs instead of the correct ones
   - Fix: downloaded correct English `.ass` from VARYG's REPACK on AnimeTosho, remuxed into existing MKV via `linuxserver/ffmpeg` Docker container on TrueNAS
   - All other language tracks and font attachments preserved

2. **Fixed Bazarr configuration**
   - `use_embedded_subs: false` — was `true`, causing Bazarr to skip downloading subs when any embedded track existed (even wrong ones)
   - `use_subsync: true` + thresholds enabled — auto-sync subtitles after download
   - Updated live config: `/mnt/Fast/docker/bazarr/config/config.yaml`
   - Updated repo reference: `media/.config/bazarr/config.yaml`

3. **Established new patterns** (documented in PATTERNS.md):
   - File staging: use repo `scratch/` dir, NOT `/tmp`, for working files
   - AnimeTosho feed API and subtitle attachment download workflow
   - Bazarr API patterns (full-object POST required for settings)

### Key Facts

| Item | Value |
|------|-------|
| AnimeTosho feed API | `https://feed.animetosho.org/json?q=<query>` |
| AnimeTosho attachment URL pattern | `https://animetosho.org/storage/attach/<hash>/<filename>.ass.xz` |
| Bazarr API base | `http://192.168.20.22:6767/bazarr/api` |
| Bazarr API key Infisical path | `/media` → `BAZARR_API_KEY` |
| Bazarr config on TrueNAS | `/mnt/Fast/docker/bazarr/config/config.yaml` (gitignored) |
| Bazarr config in repo | `media/.config/bazarr/config.yaml` |

### Lesson Learned

Used `/tmp` for working files (subtitle .ass, bazarr config) during the session — this was wrong. The correct pattern is to stage files in the repo and SCP from there to TrueNAS, keeping everything version-controlled. Updated PATTERNS.md and MEMORY.md with this rule.

---

## Session 2026-02-26 - JetKVM Tailscale + Caddy Integration (COMPLETED)

### What Was Done

Set up Tailscale on JetKVM and added it to the Caddy/AdGuard reverse proxy stack.

### Changes Made

1. **Infisical `/networking`** — stored `JETKVM_PW`, `JETKVM_SSH_PUBLIC_KEY`, `JETKVM_SSH_PRIVATE_KEY`
2. **JetKVM** — Developer Mode enabled, dedicated Ed25519 SSH key added
3. **Tailscale installed** on JetKVM via `https://jetkvm.com/install-tailscale.sh -y` with `TRUENAS_TAILSCALE_AUTH_KEY`
4. **`truenas/stacks/caddy/Caddyfile`** — added `jetkvm.home` block (`reverse_proxy 192.168.20.25:80`)
5. **Live Caddy reloaded** via `scp` + `caddy reload` (no restart)
6. **AdGuard DNS rewrite** added: `jetkvm.home` → 192.168.20.22 (done by user)
7. **`truenas/DEPLOYMENT_GUIDE.md`** — fully rewritten (was stale: said "cannot create programmatically")
8. **`truenas/FRONTEND_STACK_DEPLOYMENT.md`** — added `jetkvm.home` to DNS rewrite table
9. **`ai/reference.md`** — new JetKVM Tailscale section with SSH pattern and install command
10. **`ai/todo.md`** — item #80 added (completed)

### Key Facts

| Item | Value |
|------|-------|
| JetKVM LAN IP | 192.168.20.25 |
| JetKVM web UI | http://jetkvm.home (via Caddy) |
| JetKVM SSH user | `root` (key-based only) |
| SSH key in Infisical | `/networking/JETKVM_SSH_PRIVATE_KEY` |
| Tailscale auth key used | `TRUENAS_TAILSCALE_AUTH_KEY` at `/TrueNAS` |
| Caddy proxy | `reverse_proxy 192.168.20.25:80` (not container name — external device) |

### Pattern: Adding a New Non-Docker Device to Caddy

For devices that are not Docker containers (JetKVM, TrueNAS UI, etc.):

1. Add to `truenas/stacks/caddy/Caddyfile` using IP, not container name:
   ```
   http://device.home {
       reverse_proxy 192.168.20.X:PORT
   }
   ```
2. `scp` Caddyfile to TrueNAS + `caddy reload`
3. Add DNS rewrite in AdGuard: `device.home` → `192.168.20.22`

---

## Session 2026-02-26 - Tailscale + Caddy Remote Access (COMPLETED)

### What Was Done

Deployed Tailscale as subnet router on TrueNAS and configured Split DNS so all `.home` services work over Tailscale identically to LAN.

### Changes Made

1. **`truenas/stacks/infisical-agent/tailscale.tmpl`** — Fixed secret key name: `TAILSCALE_AUTHKEY` → `TRUENAS_TAILSCALE_AUTH_KEY` (matches actual Infisical secret)
2. **Tailscale deployed** via `midclt call -j app.create` (not Web UI, not REST API — see PATTERNS.md)
3. **Subnet routes approved** in Tailscale admin console for `192.168.20.0/24`
4. **Split DNS configured** in Tailscale admin → DNS → Custom nameserver: `100.98.14.66` restricted to domain `home`

### Key Facts

| Item | Value |
|------|-------|
| TrueNAS Tailscale IP | `100.98.14.66` |
| Hostname | `truenas` |
| Subnet advertised | `192.168.20.0/24` |
| Split DNS nameserver | `100.98.14.66` (AdGuard Home port 53) |
| Split DNS domain | `home` |
| Auth key secret | `TRUENAS_TAILSCALE_AUTH_KEY` at `/TrueNAS` in Infisical |
| State persisted | `/mnt/Fast/docker/tailscale` |

### How It Works

- Tailscale runs in host network mode (`network_mode: host`) — required for subnet routing
- When on Tailscale, DNS queries for `*.home` are routed to `100.98.14.66:53` (AdGuard) via Split DNS
- AdGuard resolves all `.home` entries to `192.168.20.22`
- Caddy on `192.168.20.22:80` proxies to the correct container
- Result: `http://jellyfin.home` works identically on LAN and over Tailscale

### Critical Discovery: midclt for App Creation

- **REST API** (`POST /api/v2.0/app`) cannot create Custom Apps — schema validation always fails
- **Web UI** is NOT required — use `midclt call -j app.create` via SSH instead
- See PATTERNS.md → "Create a new Custom App" for the exact command pattern

---

## Session 2026-02-18 - Jellyfin Playback Fix + VAAPI Hardware Transcoding (COMPLETED)

### What Was Done

**Problem**: Terminator (28GB Remux-1080p AVC DTS-HD MA 5.1) got stuck when playing in Jellyfin web client.

**Root Cause**: DTS-HD MA 5.1 is not supported by web browsers. Jellyfin was running in DirectStream mode (video passthrough, audio remux) but had no hardware transcoding configured. Without transcoding, the audio codec was incompatible with the client → stream stalled.

**Secondary issue**: Jellystat was permanently `unhealthy` due to a broken healthcheck (`curl` not installed in its container image).

---

### Diagnosis Steps

```bash
# SSH to TrueNAS using kero66 key from Infisical (secure pattern)
TMPDIR_SAFE=$(mktemp -d) && chmod 700 "$TMPDIR_SAFE" && TMPKEY="$TMPDIR_SAFE/k"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null > "$TMPKEY" && chmod 600 "$TMPKEY"
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no kero66@192.168.20.22 "sudo docker logs jellyfin --tail 100 2>&1"
rm -rf "$TMPDIR_SAFE"

# Check DRI devices available on host and in container
ssh ... "ls /dev/dri/ && sudo docker exec jellyfin ls /dev/dri/"
# Result: card0 (GID 44/video), renderD128 (GID 107/render) present in both

# Check GPU vendor
ssh ... "sudo cat /sys/class/drm/card0/device/vendor"  # 0x8086 = Intel
ssh ... "sudo cat /sys/class/drm/card0/device/device"  # 0x46d4 = Alder Lake-N (N150)

# Check VA drivers in container
ssh ... "sudo docker exec jellyfin ls /usr/lib/x86_64-linux-gnu/dri/"
# Result: only nouveau/radeon — no Intel drivers on system path

# Find Intel iHD driver in jellyfin-ffmpeg bundle
ssh ... "sudo docker exec jellyfin find / -name '*iHD*' 2>/dev/null"
# Result: /usr/lib/jellyfin-ffmpeg/lib/dri/iHD_drv_video.so  ← key finding

# Verify Intel VAAPI works with correct driver path
ssh ... "sudo docker exec -e LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri -e LIBVA_DRIVER_NAME=iHD jellyfin /usr/lib/jellyfin-ffmpeg/vainfo"
# Result: Intel iHD driver 25.4.4, H264/HEVC/VP9 decode+encode — CONFIRMED WORKING

# Check render group GID
ssh ... "stat -c '%G %g' /dev/dri/renderD128"  # render 107
ssh ... "getent group render video"              # render:x:107: video:x:44:
```

---

### TrueNAS API - Verified Endpoints

```bash
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null)
BASE="https://192.168.20.22/api/v2.0"

# List all Custom Apps
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/app"

# Get app details
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/app/id/jellyfin"

# Get current app compose config (returns structured dict)
curl -sk -X POST -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
  -H "Content-Type: application/json" -d '"jellyfin"' \
  "${BASE}/app/config"

# Update app compose config (returns job ID)
curl -sk -X PUT -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"custom_compose_config": <compose_dict>}' \
  "${BASE}/app/id/jellyfin"
# NOTE: endpoint is /id/{id}, NOT /app/{id}

# Check job status
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/core/get_jobs?id=<JOB_ID>"

# User management
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/user?username=kero66"  # GET user (returns array)
curl -sk -X PUT -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
  -H "Content-Type: application/json" -d '{"sshpubkey": "..."}' \
  "${BASE}/user/id/72"  # NOTE: /id/ in path, kero66 ID = 72
```

**API Notes**:
- HTTP → HTTPS redirect (308) drops Authorization header → always use HTTPS
- `PUT /api/v2.0/user/{id}` returns 404 — must use `PUT /api/v2.0/user/id/{id}`
- App updates are async jobs; poll `/core/get_jobs?id=<JOB_ID>` for status

---

### Jellyfin API - Verified Endpoints

```bash
JF_API_KEY=$(infisical secrets get JELLYFIN_API_KEY --env dev --path / --plain 2>/dev/null)
# NOTE: Jellyfin key is at root path /, not /TrueNAS

# Get encoding config
curl -sf -H "X-Emby-Token: ${JF_API_KEY}" "http://192.168.20.22:8096/System/Configuration/encoding"

# Set encoding config (HTTP 204 on success)
curl -sf -X POST -H "X-Emby-Token: ${JF_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '<encoding_json>' \
  "http://192.168.20.22:8096/System/Configuration/encoding"
```

---

### Changes Made

#### 1. `truenas/stacks/jellyfin/compose.yaml`

**Jellyfin service**:
- Added `LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri` (points libva to jellyfin-ffmpeg's bundled iHD driver)
- Added `LIBVA_DRIVER_NAME=iHD` (selects Intel iHD over default i965)
- Added `group_add: ["107", "44"]` (render + video group GIDs for `/dev/dri` access after privilege drop)
- Increased `mem_limit: 2g → 4g` (transcoding headroom)

**Jellystat healthcheck**:
- Changed from `curl` (not installed) → `wget 127.0.0.1:3000/` (using 127.0.0.1 avoids IPv6 ::1 connection attempt)

#### 2. Jellyfin encoding config (applied via API)

```json
{
  "HardwareAccelerationType": "vaapi",
  "VaapiDevice": "/dev/dri/renderD128",
  "EnableHardwareEncoding": true,
  "EnableDecodingColorDepth10Hevc": true,
  "EnableDecodingColorDepth10Vp9": true,
  "EnableTonemapping": true,
  "HardwareDecodingCodecs": ["h264", "hevc", "vp8", "vp9", "av1"]
}
```

---

### Infisical Secret Locations (dev env)

| Secret | Path | Notes |
|--------|------|-------|
| `kero66_ssh_key` | `/TrueNAS` | Private key for SSH to TrueNAS as kero66 |
| `truenas_admin_api` | `/TrueNAS` | TrueNAS REST API key |
| `JELLYFIN_API_KEY` | `/` (root) | Jellyfin API key |
| `JELLYFIN_USERNAME` | `/` (root) | `kero66` |
| `JELLYSTAT_API_KEY` | `/` (root) | Jellystat API key |

---

### Security Incident (Self-Inflicted)

**Incident**: During session, attempted to test TrueNAS API PUT with `{"sshpubkey": "test"}` which succeeded and overwrote kero66's authorized SSH key.

**Resolution**: Restored immediately by:
1. Retrieving private key from Infisical
2. Deriving public key with `ssh-keygen -y -f <key_file>`
3. Restoring via `PUT /api/v2.0/user/id/72` with correct public key

**Lesson**: Never test write endpoints with dummy data on production users. Always use dry-run or read-only operations first.

---

### Intel N150 VAAPI Summary

| Item | Value |
|------|-------|
| GPU vendor/device | 0x8086 / 0x46d4 (Intel Alder Lake-N) |
| Driver | iHD 25.4.4 (bundled in jellyfin-ffmpeg) |
| Driver path in container | `/usr/lib/jellyfin-ffmpeg/lib/dri/iHD_drv_video.so` |
| Render device | `/dev/dri/renderD128` |
| render group GID | 107 |
| video group GID | 44 |
| Supported decode | H264, HEVC, VP8, VP9, AV1 |
| Supported encode | H264, HEVC |

---

## Active Session: 2026-02-14 - Homepage Deployment via Dockhand

### 🚀 HANDOFF TO NEXT AGENT
**Current Blocker**: Homepage deployment requires Infisical Agent .env file
- Homepage compose references: `/mnt/Fast/docker/homepage/.env`
- Infisical Agent should generate this via template: `truenas/stacks/infisical-agent/homepage.tmpl`
- **Action needed**: Verify Infisical Agent is running and generating .env files

**What's Ready**:
- ✅ Homepage labels added to all services (committed to git)
- ✅ Dockhand authentication working (credentials in Infisical)
- ✅ SSH deploy keys configured in Dockhand UI
- ✅ Git repository configured in Dockhand UI (user confirmed)
- ✅ Infisical Agent config files exist in repo (agent-config.yaml, homepage.tmpl)
- ✅ SSH keys exist on workstation (~/.ssh/id_ed25519)

**What's Blocked**:
- ❌ SSH access from workstation to TrueNAS (publickey auth not configured)
- ❌ Homepage deployment (missing .env file from Infisical Agent)
- ❌ Dockhand API documentation (not publicly available, difficult to use programmatically)

**What's Pending**:
- ⏸️ Set up SSH key on TrueNAS for workstation access
- ⏸️ Verify Infisical Agent is deployed and running
- ⏸️ Verify /mnt/Fast/docker/homepage/ directory exists
- ⏸️ Verify .env file is being generated by agent
- ⏸️ Deploy Homepage stack via Dockhand
- ⏸️ Test GitOps auto-deployment workflow
- ⏸️ Original task: Tailscale migration (deferred)

**Quick Start for Next Agent**:
1. Set up SSH access: Copy workstation public key to TrueNAS authorized_keys
2. Verify Infisical Agent: `docker ps | grep infisical`
3. Check .env generation: `ls -la /mnt/Fast/docker/homepage/.env`
4. Deploy Homepage via Dockhand UI (API not practical)

### Context
**Current Task**: Deploy Homepage stack via Dockhand GitOps workflow
- User attempted to deploy Homepage via Dockhand UI
- Deployment blocked: missing `/mnt/Fast/docker/homepage/.env` file
- Root cause: Infisical Agent may not be running or not generating .env files
- Secondary issue: SSH access from workstation to TrueNAS not configured

**Previous Context**:
- Shifted from Tailscale migration to Dockhand GitOps implementation
- Dockhand already deployed at http://192.168.20.22:30328/
- Homepage migrated but missing auto-discovery labels (fixed)

### Key Problem: Tailscale without host network mode
**Issue**: Tailscale traditionally requires `network_mode: host` to function properly, but this:
- Breaks container isolation
- Prevents using Docker networks for service discovery
- Goes against Docker best practices

**Research/Attempts**:
1. Current implementation uses `network_mode: host` (line 30 in compose.yaml)
2. This breaks container isolation and Docker networking
3. Need alternative approach

**Current Status**:
- Investigating Tailscale userspace networking mode
- Exploring whether subnet routing works in bridge mode
- Goal: Allow Tailscale container to route traffic TO other containers without host mode

**Possible Solutions**: (See `truenas/TAILSCALE_HOST_MODE_ALTERNATIVES.md` for full details)
A) **Userspace networking** (`TS_USERSPACE=true`) - ⭐ RECOMMENDED FIRST
B) **Tailscale Serve/Funnel** - Share specific ports, not entire subnet
C) **macvlan** - Give container its own IP on LAN (e.g., 192.168.20.200)
D) **Keep host mode** - Accept the trade-off if alternatives don't work

**Testing Strategy:**
1. Try userspace mode first (simplest, most secure)
2. If subnet routing fails, try macvlan
3. Last resort: accept host mode with documented trade-offs

**Documentation Created:**
- `truenas/TAILSCALE_HOST_MODE_ALTERNATIVES.md` - Full research and implementation guides
- `ai/SESSION_NOTES.md` - This file (session continuity)
- `ai/DOCUMENTATION_STRUCTURE.md` - Documentation hierarchy and AI workflow guidelines

### Claude Code Interface Investigation (RESOLVED)
**Discovery**: User was running Claude Code CLI in VSCode terminal, assuming it had VSCode integration
**Reality**:
- CLI = Standalone tool, no VSCode integration, no access to VSCode MCP servers
- Extension (chat panel) = Integrated with VSCode, may have MCP access
**VSCode MCP Servers Found**:
- Context7 (mcp.config.usrlocal.context7)
- Upstash Context7 (upstash.context7-mcp)
- Pylance (ms-python.vscode-pylance)
- GitHub Copilot MCP
**Decision**: User switching to VSCode chat panel to test MCP integration
**Status**: User testing chat panel (item #72 in todo.md)

### Caddy HTTPS Issue (RESOLVED)
**Problem**: Port 443 was removed from Caddy compose.yaml, causing HTTPS warnings
**Root cause**: Unknown - may have been accidental removal during conflict resolution
**Solution**: Restored ports 443/tcp and 443/udp to Caddy compose.yaml
**Fixed**: 2026-02-14

### AdGuard Home Port Conflict (RESOLVED)
**Change**: DoH port changed from 443 → 4443 to avoid conflict with Caddy
**Reason**: Caddy needs 443 for automatic HTTPS certificate management
**Fixed**: 2026-02-14

### DNS Resolution Issue - systemd-resolved (RESOLVED)
**Problem**: Linux clients couldn't resolve `.home` domains (e.g., `jellyfin.home`)
**Root Cause**: systemd-resolved was preferring Cloudflare DNS (1.1.1.1) over AdGuard Home (192.168.20.22) when both were configured via DHCP
- DHCP sent both DNS servers: Primary=192.168.20.22, Secondary=1.1.1.1
- systemd-resolved treated them as alternatives, not primary/fallback
- Chose Cloudflare for queries, which doesn't know about `.home` domains
**Solution**: Removed secondary DNS (1.1.1.1) from router DHCP configuration
- Router now only sends 192.168.20.22 (AdGuard Home) via DHCP
- AdGuard Home uses 1.1.1.1 as upstream, maintaining internet DNS fallback
**Trade-off Accepted**: Single point of failure - if AdGuard goes down, DNS fails network-wide
**Alternative**: Deploy second AdGuard Home instance on workstation (192.168.20.66) for HA
**Fixed**: 2026-02-14

### Documentation Cleanup (COMPLETED)
**Issue**: Documentation was using `root@192.168.20.22` instead of `kero66@192.168.20.22`
**Action**: Audited and updated 81 instances across all truenas/ documentation
**Principle**: kero66 (UID 1000) is standard user for all daily operations
- truenas_admin is break-glass account only
- API-first approach for infrastructure
- Infisical for infrastructure secrets, Bitwarden for personal passwords
**Updated**: MEMORY.md, ARR_DEPLOYMENT.md, FRONTEND_STACK_DEPLOYMENT.md, and 8 other docs
**Completed**: 2026-02-14

### Homepage Auto-Discovery Labels (COMPLETED)
**Problem**: Homepage dashboard not auto-discovering migrated services
**Root Cause**: Docker labels missing from compose files after migration
**Solution**: Added homepage.* labels to 9 services across 3 stacks:
- arr-stack: Sonarr, Radarr, Prowlarr, Bazarr
- downloaders: qBittorrent, SABnzbd
- jellyfin: Jellyfin, Jellyseerr, Jellystat
**Labels Added**: homepage.group, homepage.name, homepage.icon, homepage.href, homepage.description, homepage.widget.*
**Status**: Committed to git, ready for deployment testing
**Completed**: 2026-02-14

### Agent-Agnostic Documentation Structure (COMPLETED)
**Issue**: AI documentation was in global Claude directory, not in repo
**Problem**: Not version controlled, not accessible to other AI agents (Copilot, etc.)
**Solution**: Created `.claude/INSTRUCTIONS.md` in repository
- Contains all quick reference, patterns, gotchas, and architecture decisions
- Version controlled and agent-agnostic
- Replaces reliance on global `~/.claude/memory/MEMORY.md`
**Files Created**:
- `.claude/INSTRUCTIONS.md` - Main AI agent instructions (in repo, version controlled)
**Completed**: 2026-02-14

### Dockhand GitOps Setup (IN PROGRESS - UPDATED 2026-02-14)
**Goal**: Configure Dockhand for GitOps management of Homepage stack

**Completed This Session**:
- ✅ SSH deploy keys generated and stored in Infisical
  - Private key: `/TrueNAS/DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE`
  - Public key: `/TrueNAS/DOCKHAND_GITHUB_DEPLOY_KEY_PUBLIC`
  - Keys removed from local system after storing in Infisical
  - Public key added to GitHub (read-only access)
  - Private key configured in Dockhand UI
- ✅ **Architecture Decision**: Simplified approach - NO `deployments/` directory
  - Dockhand points directly at `truenas/stacks/<stack>/compose.yaml`
  - No symlinks needed (avoids cross-platform issues, reduces complexity)
  - Single source of truth for compose files
  - Existing `truenas/stacks/` structure used as-is
- ✅ DOCKHAND_GITOPS_GUIDE.md completely rewritten
  - Removed symlink/deployments approach
  - Updated all examples to use Homepage
  - Documented simpler configuration
  - Added Quick Reference section

**Key Decision - Direct Path Structure (2026-02-14)**:
```
REJECTED APPROACH (overly complex):
homelab/
├── deployments/truenas/homepage/
│   └── docker-compose.yaml → ../../../truenas/stacks/homepage/compose.yaml (symlink)
└── truenas/stacks/homepage/compose.yaml

APPROVED APPROACH (simple & clean):
homelab/
└── truenas/stacks/homepage/compose.yaml  ← Dockhand points here directly
```

**Rationale for Simpler Approach**:
1. Dockhand accepts any git path - no mandatory structure
2. Symlinks add complexity without benefit
3. Windows compatibility issues with git symlinks
4. Single source of truth is easier to maintain
5. No duplicate directory structure to manage

**Authentication Patterns Established**:
```bash
# Dockhand credentials
DOCKHAND_USER=$(infisical secrets get DOCKHAND_USER --env dev --path /TrueNAS --plain 2>/dev/null)
DOCKHAND_PASSWORD=$(infisical secrets get DOCKHAND_USER_PASSWORD --env dev --path /TrueNAS --plain 2>/dev/null)

# Deploy key retrieval
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE --env dev --path /TrueNAS --plain
```

**Still Pending**:
- Configure git repository in Dockhand UI (Settings → Git Integration)
- Create Homepage stack pointing to `truenas/stacks/homepage`
- Test GitOps auto-deployment workflow with test commit
- Verify Infisical Agent .env files work with GitOps deployments

**Status**: Ready for UI configuration - all prerequisites complete

---

## Instructions for AI
1. **Start each session** by reading this file first
2. **Update this file** with key decisions, research findings, and blockers
3. **When blocked**, document the blocker here before ending session
4. **Link related items** to todo.md for tracking
5. **Clear completed sections** after items are fully resolved and documented elsewhere

---

### Session 2026-02-14 Afternoon - Homepage Deployment Attempt

**Goal**: Deploy Homepage via Dockhand GitOps

**Discovery - TrueNAS Version**:
- System running: **TrueNAS Scale 25.10.1** (found in truenas/HARDWARE_CONFIG.md)
- AI agent was discussing old versions (24.04 Dragonfish, 24.10 Electric Eel)
- **Lesson**: Always verify current software versions before providing advice
- **Action**: Added TrueNAS version to MEMORY.md

**Deployment Blocker**:
- Homepage deployment requires `.env` file at `/mnt/Fast/docker/homepage/.env`
- File should be auto-generated by Infisical Agent from `homepage.tmpl`
- Unknown if Infisical Agent is deployed/running on TrueNAS
- Cannot verify without SSH access to TrueNAS

**Technical Challenges**:
1. **SSH Access**: Workstation has SSH keys but not authorized on TrueNAS
2. **Dockhand API**: No public documentation, difficult to use programmatically
   - Attempted to create stack via API: `/api/stacks` endpoint exists but unclear parameters
   - API returned "Compose file content is required" - may not support git-based creation via API
   - Conclusion: Use Dockhand UI for stack management, API not practical
3. **Remote Troubleshooting**: Cannot diagnose Infisical Agent status without TrueNAS access

**Next Steps**:
1. Configure SSH access from workstation to TrueNAS
2. Verify Infisical Agent deployment status
3. Ensure .env files are being generated
4. Deploy Homepage via Dockhand UI

---

## Lessons Learned (AI Performance Issues)

### Session 2026-02-14 - Critical Failures
**Issue**: AI agent repeatedly failed to follow established patterns and documentation
**Examples**:
1. **Infisical CLI usage**: Tried multiple wrong approaches (wrong environment, wrong path, export commands) despite established pattern existing in codebase: `infisical secrets get <NAME> --env dev --path /TrueNAS --plain`
2. **jq failures**: Repeatedly piped HTML responses to jq without checking response type first, causing parse errors
3. **Research vs guessing**: Guessed at solutions instead of searching existing code for patterns (e.g., Grep for "infisical secrets get")
4. **Documentation location**: Updated global `~/.claude/memory/` instead of repo's `.claude/` folder, missing agent-agnostic requirement

**Root Cause**: Not following DOCUMENTATION_STRUCTURE.md workflow:
- Should have searched codebase for existing patterns FIRST
- Should have verified response types before piping to tools
- Should have read established documentation before attempting new approaches

**Corrective Actions**:
- Created `.claude/INSTRUCTIONS.md` with "Research first, guess never" principle
- Added "Always verify response type before piping to jq" to Common Gotchas
- Documented Infisical CLI pattern explicitly in Critical Patterns section

**For Future AI Agents**:
- READ `.claude/INSTRUCTIONS.md` at session start
- SEARCH codebase with Grep/Glob before attempting new patterns
- VERIFY tool inputs/outputs before chaining commands
- DOCUMENT failures in SESSION_NOTES.md for future learning

---

## Previous Sessions Archive

### Session 2026-02-12: Arr Stack Migration Complete
- Successfully deployed arr-stack, downloaders, and Jellyfin to TrueNAS
- Fixed Prowlarr URL issues, recycle bin permissions
- Documented fixes in TROUBLESHOOTING.md
- See todo.md items 48-58 for details

