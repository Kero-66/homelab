# Homelab Project Memory

**IMPORTANT:** First 200 lines only! Keep concise. Link to detailed docs.

- [Do not automate Bitwarden access](feedback_bitwarden_access.md) — scripts reading Bitwarden give Claude full vault access
- [Never run infisical secrets table form](feedback_no_secret_table_output.md) — always use `infisical secrets get <KEY> --plain`, NEVER bare `infisical secrets` (prints all secrets in cleartext)
- [No grep/head filtering on first run](feedback_no_grep_head.md) — always read raw output first, filter only if too large
- [Never print secret values in output](feedback_no_secret_output.md) — suppress `infisical secrets set` table output, never echo secret vars
- [Use service APIs not shell commands](feedback_use_apis.md) — Jellyfin/Sonarr/Bazarr all have APIs; reach for ffprobe/python only when APIs lack the data
- [Handoff files live in ai/](feedback_handoff_location.md) — always `ls ai/handoff*.md` before writing; append to today's file, never overwrite
- [Check docs before fixing](feedback_check_docs_before_fixing.md) — verify docs and established patterns before applying fixes, especially permissions/ownership

## Quick Reference
- **TrueNAS**: 192.168.20.22 (SSH as kero66@192.168.20.22) - **Version 25.10.1**
- **Workstation**: 192.168.20.66 (Fedora, cold spare)
- **JetKVM**: 192.168.20.25 (LAN, Tailscale enabled) — SSH as root@, key in Infisical `/networking/JETKVM_SSH_PRIVATE_KEY`
- **Pools**: `/mnt/Fast` (NVMe), `/mnt/Data` (HDD)
- **Configs**: `/mnt/Fast/docker/<service>/`
- **Media**: `/mnt/Data/media/{shows,movies,anime,music,tv,downloads}`
- **Downloads**: `/mnt/Data/downloads/{qbittorrent,sabnzbd,complete,incomplete}`

## Key Architecture Decisions
- **Security**: API-first approach, Infisical for infrastructure secrets, Bitwarden for personal passwords
- **Secrets management**: Infisical Agent renders `.env` → `/mnt/Fast/docker/{arr-stack,downloaders,jellyfin}/`
- **User access**: kero66 (UID 1000) for all daily ops, truenas_admin is break-glass only
- **TrueNAS deployment**: Web UI Custom Apps, NOT docker-compose CLI
- **Compose files in repo**: Reference/documentation only (except for updates)
- **Networking**: Cross-stack via explicit network joins (downloaders→arr-stack, jellyseerr→both)
- **DNS**: Router DHCP sends only 192.168.20.22 (AdGuard Home), no fallback (single point of failure accepted)

## AdGuard Home - Verified Details
- **Port**: 3080 (host) → 3000 (internal). NOT 3000 on host.
- **Username**: `kero66` (NOT `admin`)
- **Secret**: `ADGUARD_PASSWORD` in Infisical `/TrueNAS` — credentials are correct
- **Auth pattern**: `curl -u "kero66:$ADGUARD_PASS"` — credentials in variable, never printed
- **DNS rewrites**: `POST /control/rewrite/add` with `{"domain": "x.home", "answer": "192.168.20.22"}`
- **Manual fallback**: `http://adguard.home` → Filters → DNS rewrites

## Dockhand - Verified API
- **URL**: `http://192.168.20.22:30328/`
- **Credentials**: `DOCKHAND_USER` + `DOCKHAND_USER_PASSWORD` in Infisical `/TrueNAS`
- **Auth**: Session cookie — POST `/api/auth/login`, use `-c`/`-b "$COOKIEJAR"`
- **Deploy stack**: `POST /api/stacks` with `{"name": "...", "environmentId": 1, "compose": "<yaml>"}`
- **Environment ID**: always `1` (TrueNAS, via Docker socket)
- **⚠️ Never expose password in process listing**: pass via env vars to python3, not sys.argv
- **Job status**: `GET /api/jobs/<jobId>` → `{status, result, error}`

## Common Gotchas
- **NEVER run `infisical secrets --env dev --path /TrueNAS` without `--plain` on a specific key** - table output exposes ALL secrets in cleartext in tool results. Always use targeted `infisical secrets get <KEY> --env dev --path /path --plain`
- **ALWAYS check response type before piping to jq** - API endpoints may return HTML, not JSON
- Use `jq` not `python3 -m json.tool`
- SSH piped commands fail on TrueNAS → use separate steps
- Sonarr/Radarr cache health checks → trigger `CheckHealth` command via API
- qBittorrent doesn't create dirs at startup, only on first download
- `ix-*` networks are TrueNAS built-in, separate from compose networks
- **TrueNAS access**: Use kero66 user, NOT root. truenas_admin is break-glass only (can elevate to root if needed)
- **TrueNAS version**: 25.10.1 - don't discuss old versions (24.04/24.10) unless relevant to upgrade path
- **Infisical environments**: ALL secrets are in `--env dev` (no prod environment exists)
- **Infisical CLI pattern**: `infisical secrets get <NAME> --env dev --path /TrueNAS --plain`
- **Dockhand**: Deployed at http://192.168.20.22:30328/ — API IS documented (see MEMORY.md Dockhand section + PATTERNS.md)
- **AdGuard API**: HTTP Basic Auth `-u "kero66:$ADGUARD_PASS"` at port 3080. If 401 from Mac but works from TrueNAS, cause unknown — use SSH fallback

## Critical Patterns
- **DO THE WORK, don't ask user to run commands** - Set up access/tools needed, then troubleshoot
- **ALWAYS check existing setup** before creating files (see truenas/DEPLOYMENT_GUIDE.md)
- **Research first, guess never** - Search codebase for patterns before attempting new approaches
- **Verify response types** before piping to tools like jq (check for HTML vs JSON)
- **Workstation → TrueNAS**: `.config/` → `/mnt/Fast/docker/<service>/`
- **Migration steps**: backup → mkdir → scp → chown 1000:1000 → deploy via Web UI
- **REPLICATE EXISTING PATTERNS** - Before doing anything new, read how existing working apps do it. Never invent a different approach.
- **NO /tmp for working files** - Download/stage files in the repo, SCP to TrueNAS from there. `/tmp` is for secrets only (mktemp -d, cleanup immediately). See PATTERNS.md → File Staging.

## TrueNAS App Management - CRITICAL RULES
- **NEVER use REST API `PUT /app/id/{name}`** to update compose — breaks running containers with port conflicts
- **Update compose**: `sudo midclt call -j app.stop` → `app.update` → `app.start` (see PATTERNS.md)
- **New app**: `midclt app.create` with `custom_compose_config_string` (compose as string, not dict)
- **Caddyfile**: `scp` to live location → `docker exec caddy caddy reload` (no app restart needed)
- **Port conflicts**: Check `ss -tlnp` BEFORE designing compose ports. TrueNAS nginx owns 80, 443, 8082
- **Check ports first**: Always verify free ports before assigning them in compose files
- **TrueNAS SSH**: Use kero66 key from Infisical (kero66_ssh_key). See secure pattern below.
- **NEVER store secrets in /tmp with predictable names** - use mktemp -d + cleanup
- **midclt REQUIRES sudo** — without `sudo`, calls run as `.UNAUTHENTICATED`, return job IDs but silently do nothing. TrueNAS audit log will show the failure.
- **Multi-service stacks (arr-stack, downloaders)**: midclt only operates at app level — no per-container restart. To restart one container, must stop/start the whole app.
- **NEVER use `docker start/stop` to manage containers** — use `sudo midclt call -j app.stop/start APP_NAME` instead. Docker commands bypass TrueNAS app lifecycle management.

## TrueNAS SSH - Secure Pattern
```bash
# CORRECT: random temp dir, cleanup after use
TMPDIR_SAFE=$(mktemp -d) && chmod 700 "$TMPDIR_SAFE" && TMPKEY="$TMPDIR_SAFE/k"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain \
  --projectId "5086c25c-310d-4cfb-9e2c-24d1fa92c152" --domain http://192.168.20.66:8081 2>/dev/null > "$TMPKEY"
chmod 600 "$TMPKEY"
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no kero66@192.168.20.22 "your command here"
rm -rf "$TMPDIR_SAFE"
```
- kero66 cannot access Docker socket directly - use `sudo docker ...`
- TrueNAS API user update endpoint: `PUT /api/v2.0/user/id/{id}` (not `/user/{id}`)
- API key in Infisical: `truenas_admin_api` (env dev, path /TrueNAS)
- kero66 user ID on TrueNAS: **72**

## TrueNAS API - Verified Patterns
```bash
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null)
# GET user: https://192.168.20.22/api/v2.0/user?username=kero66  (returns array)
# PUT user: https://192.168.20.22/api/v2.0/user/id/72  (note: /id/ in path)
# API requires HTTPS (http returns 308 redirect that drops auth header)
```

## AniDB API Clients (Infisical `/media`)
- **AnimeSubs** (v1) — used by Bazarr for subtitle matching → `ANIDB_CLIENT_SUBS` / `ANIDB_CLIENT_SUBS_VER`
- **AnimePlaylists** (v1) — for watch order playlist script (todo #83) → `ANIDB_CLIENT_PLAYLISTS` / `ANIDB_CLIENT_PLAYLISTS_VER`
- AniDB auth = client name + user credentials, no API key generated

## Trakt Integration - Deployed 2026-05-29
- **Secrets**: `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET` in Infisical `/media`
- **Jellyfin plugin**: v30.0.0.0, Active — GUID `4fe3201ed6ae4f2e8917e12bda571281`
- **Auth**: OAuth via Jellyfin web UI (browser flow only, not API-automatable)
- **Config**: Scrobble=true, PostWatchedHistory=true, SynchronizeCollections=true
- **Next**: Add Radarr/Sonarr import lists (Settings → Import Lists → Trakt)

## autobrr (Release Automation) - Deployed 2026-05-11
- **Stack**: `truenas/stacks/autobrr/` — separate stack (not arr-stack), deployed via Dockhand
- **URL**: `http://autobrr.home` (port 7474)
- **Networks**: joins `ix-arr-stack_default` + `ix-downloaders_default` (can reach Sonarr, Radarr, qBittorrent)
- **Config**: `/mnt/Fast/docker/autobrr/config/` on TrueNAS
- **Purpose**: Grabs releases that Sonarr/Radarr block (packs, niche fansubs, non-parseable releases)
- **To update**: edit compose → redeploy via Dockhand API (see PATTERNS.md → Dockhand)

## Tailscale (Remote Access) - Deployed 2026-02-26
- **Stack**: `truenas/stacks/tailscale/` — subnet router, host network mode
- **Subnet advertised**: `192.168.20.0/24`
- **Split DNS**: Tailscale admin → DNS → custom nameserver for domain `home` → TrueNAS Tailscale IP
- **Result**: All `*.home` services work identically over Tailscale as on LAN
- **Auth key secret**: `TRUENAS_TAILSCALE_AUTH_KEY` in Infisical at `/TrueNAS`
- **Deploy new apps**: `midclt call -j app.create` via SSH — NOT REST API. See PATTERNS.md.

## Bazarr (Subtitle Management) - Config 2026-05-10
- Config file: `/mnt/Fast/docker/bazarr/config/config.yaml` (live) — gitignored, contains API keys
- Sanitized template in repo: `truenas/stacks/arr-stack/bazarr-config.yaml.template`
- **Edit config**: SSH sed directly on TrueNAS, then `sudo midclt call -j app.stop/start arr-stack`
- **API limitation**: some settings (e.g. `ignore_ass_subs`) don't persist via API — must edit YAML
- `use_embedded_subs: false` — must stay false; embedded subs are often wrong (e.g. bad anime releases)
- `ignore_ass_subs: true` — prevents .ass downloads; .ass causes multi-line overlap in Jellyfin
- `use_subsync: true` — auto-sync enabled with thresholds (series 90, movie 70)
- Bazarr API key in Infisical: `BAZARR_API_KEY` path `/media`
- AnimeTosho subtitle attachments: `https://animetosho.org/view/<slug>` → scrape for `.ass.xz` links
- AnimeTosho feed search: `https://feed.animetosho.org/json?q=<query>` (returns JSON)

## Infisical CLI - MacBook Air Setup (2026-05-10)
- **Domain**: `http://192.168.20.66:8081` (self-hosted on workstation, NOT cloud)
- **Auth**: user runs `infisical login -i --domain http://192.168.20.66:8081` manually (-i = terminal prompt, no browser) — Claude uses the session after
- **DO NOT automate Bitwarden access** — any script that reads Bitwarden gives Claude access to the entire vault
- **Project ID**: `5086c25c-310d-4cfb-9e2c-24d1fa92c152` (ALWAYS include `--projectId` and `--domain`)
- **Full pattern**: `infisical secrets get KEY --env dev --path /PATH --plain --projectId "5086c25c-310d-4cfb-9e2c-24d1fa92c152" --domain http://192.168.20.66:8081 2>/dev/null`
- **Media secrets path**: `/media` (Bazarr, Jellyfin, Sonarr, Radarr, Prowlarr API keys)
- **TrueNAS secrets path**: `/TrueNAS` (kero66_ssh_key, truenas_admin_api, Tailscale auth)

## Jellyfin Hardware Transcoding (Intel N150)
- VAAPI with Intel iHD driver - confirmed working 2026-02-18, configured via API
- iHD driver bundled at `/usr/lib/jellyfin-ffmpeg/lib/dri/iHD_drv_video.so` (not system path)
- Compose: LIBVA_DRIVERS_PATH + LIBVA_DRIVER_NAME + group_add render(107)/video(44) - see compose.yaml
- Jellyfin API key in Infisical: **env dev, path `/media`** as `JELLYFIN_API_KEY` (NOT /TrueNAS, NOT /)
- TrueNAS app update: use `midclt app.stop/update/start` via SSH — NOT the REST API (causes port conflicts)

## For Detailed Documentation
- **Verified commands**: `ai/PATTERNS.md` ← CHECK THIS FIRST before trial-and-error
- **Architecture**: `truenas/README.md`
- **Deployment**: `truenas/DEPLOYMENT_GUIDE.md`
- **Migration**: `truenas/MIGRATION_CHECKLIST.md`
- **Troubleshooting**: `.github/TROUBLESHOOTING.md`
- **Session work**: `ai/SESSION_NOTES.md`
- **Task tracking**: `ai/todo.md`
- **Doc structure**: `ai/DOCUMENTATION_STRUCTURE.md`

## Troubleshooting Rule (ENFORCED)
- [Check logs first, never assume](../rules/troubleshooting.md) — `docker logs <container> --tail 30` BEFORE forming any hypothesis. Networking is rarely the cause.

