# Homelab Project Memory

**IMPORTANT:** First 200 lines only! Keep concise. Link to detailed docs.

- [Do not automate Bitwarden access](feedback_bitwarden_access.md) — scripts reading Bitwarden give Claude full vault access
- [Never run infisical secrets table form](feedback_no_secret_table_output.md) — always use `infisical secrets get <KEY> --plain`, NEVER bare `infisical secrets` (prints all secrets in cleartext)
- [No grep/head filtering on first run](feedback_no_grep_head.md) — always read raw output first, filter only if too large
- [Never print secret values in output](feedback_no_secret_output.md) — suppress `infisical secrets set` table output, never echo secret vars
- [Use service APIs not shell commands](feedback_use_apis.md) — Jellyfin/Sonarr/Bazarr all have APIs; reach for ffprobe/python only when APIs lack the data
- [Handoff files live in ai/](feedback_handoff_location.md) — always `ls ai/handoff*.md` before writing; append to today's file, never overwrite
- [Check docs before fixing](feedback_check_docs_before_fixing.md) — verify docs and established patterns before applying fixes, especially permissions/ownership
- [Jellyfin plugin repos](service_jellyfin_plugins.md) — non-official plugin repos (e.g. JellyBridge) tracked here so dashboard-only additions aren't lost
- [Subtitle desync diagnosis](feedback_subtitle_desync_diagnosis.md) — check which stream index is actually playing and cue counts before touching timing; not every "out of sync" report is a sync bug
- [Dockhand compose network names](feedback_dockhand_network_names.md) — TrueNAS native app networks are prefixed `ix-` (e.g. `ix-jellyfin_default`), not the bare compose name — Dockhand deploys silently "succeed" (job status done, no error) while creating zero containers if an external network name is wrong
- [Never work around DNS with /etc/hosts](feedback_no_dns_workarounds.md) — if infisical.home or other `.home` domains fail to resolve in a shell, ask the user how to proceed; do not add hosts entries
- [TRaSH-Guides: check primary source first](feedback_trash_guides_primary_source.md) — fetch raw JSON from github.com/TRaSH-Guides/Guides directly, not WebSearch summaries or trash-guides.info doc-page fetches, which can be stale/wrong on trash_id/guide-only status
- [Verify before asserting](feedback_verify_before_asserting.md) — check actual data (history, config, results) before stating an explanation as fact, even when it sounds plausible; frame unverified theories as questions instead
- [Cleanuparr config lives in cleanuparr.db, not config.yml](service_cleanuparr_config.md) — the YAML file is stale/bootstrap-only; query the SQLite DB directly for real settings (queue_cleaner strike patterns, seeding rules, dry_run flag)
- [Sonarr history `data` field leaks Prowlarr API key](feedback_sonarr_history_data_field.md) — never dump the full `data` object from `/api/v3/history`; select specific fields only, downloadUrl/guid embed the live apikey
- [Never write secrets to disk, even scratchpad](feedback_no_secrets_to_disk_ever.md) — not a judgment call by key scope/severity; shell variables only
- [Prefer NZB over torrent when both available](feedback_prefer_nzb_over_torrent.md) — standing preference for a grab, not a hard requirement if only torrent exists
- [Robotech is not the same as its source shows](feedback_robotech_not_source_shows.md) — don't cross-reference Robotech against Macross/Southern Cross/Mospeada, it's a standalone release
- [Sonarr `/queue` hides unmatched downloads](feedback_sonarr_queue_hides_unmatched.md) — pass `includeUnknownSeriesItems=true` or manually-grabbed "Unknown Series" downloads won't show as in-progress
- [Answer questions, don't act on them](feedback_answer_questions_dont_act_on_them.md) — "how should we X" is not authorization to do X; reread terse messages literally, don't pattern-match to the prior topic
- [Media library gap survey](project_media_gap_survey.md) — in-progress audit of missing Sonarr episodes/Radarr movies, see `media/docs/SONARR_STRUCTURAL_AUDIT.md` for the durable findings
- [Sonarr↔Radarr movie migration](project_sonarr_radarr_movie_migration.md) — movies unmonitored in Sonarr specials still needing a file copy into Radarr
- [Verify queue before reporting zero results](feedback_verify_queue_before_reporting_zero_results.md) — don't trust one immediate post-search queue check, grabs can lag
- [Spot-check grab titles](feedback_spot_check_grab_titles.md) — after batch grabs, eyeball queue release titles against intended target, Radarr can mis-grab on a shared word
- [Unmonitor Sonarr after Radarr add](feedback_unmonitor_sonarr_after_radarr_add.md) — when adding a Radarr entry for a Sonarr special, unmonitor the Sonarr side proactively
- [Check quality profile per title](feedback_check_quality_profile_per_title.md) — batch-adding Radarr movies: pick qualityProfileId per title's genre, don't template from one movie
- [Check monitored before Radarr action](feedback_check_sonarr_monitored_before_radarr_action.md) — unmonitored Sonarr special means already deprioritized, not overlooked
- [Season 0 is not just movies](feedback_season0_not_just_movies.md) — Sonarr specials include short bonus/promo/recap content too; runtime is a triage signal, not a filter for what to check
- [Check correct config files](feedback_check_correct_files.md) — live TrueNAS configs are in `truenas/stacks/`, never push from `networking/.config/` (reference only)
- [Dockhand apps: no raw docker commands](feedback_dockhand_apps_no_raw_docker_commands.md) — use Dockhand API/docker compose for restarts, never bare `docker restart`
- [Movie specials: solve in Radarr first](feedback_movie_specials_solve_in_radarr_first.md) — for Sonarr movie-length (≥60min) specials, add/search in Radarr first, don't grab through Sonarr
- [Never dump full records with secret fields](feedback_never_dump_full_records_with_secret_fields.md) — don't jq-dump whole Sonarr objects when a nested field carries a live Prowlarr key
- [No OpenSubtitles](feedback_no_opensubtitles.md) — no longer free/personally usable, don't suggest it
- [No secrets to disk applies to session cookies](feedback_no_secrets_to_disk_applies_to_session_cookies.md) — Dockhand's cookie-jar pattern writes a live session cookie to disk; capture in a shell var instead
- [Queue cleanup respects seeding](feedback_queue_cleanup_respects_seeding.md) — don't removeFromClient/blocklist arr queue items unless genuinely dead; kills seeding
- [SSH pattern](feedback_ssh_pattern.md) — always use ssh-agent pattern from PATTERNS.md, never improvise SSH key handling
- [Never print secret fragments](feedback_never_print_secret_fragments.md) — no partial output of a secret is safe; not length, not a tail, not a hash — capture to a variable and use it directly, never display it
- [Check Sonarr monitored before Radarr action](feedback_check_sonarr_monitored_before_radarr_action.md) — unmonitored Sonarr special means already deprioritized, not overlooked; check before adding a Radarr entry
- [Read memory at session start](feedback_read_memory_at_session_start.md) — CLAUDE.md step 1 is not optional; skipping it caused repeat violations of 5+ already-documented lessons in one session (2026-08-24)
- [Verify API before calling](feedback_verify_api_before_calling.md) — check swagger/OpenAPI spec or source for correct method+body before guessing; a failed call's error response has no data, don't misparse it as an empty result

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
- **`/mnt/Fast` mounted into Dockhand** (added 2026-06-18) — `env_file: /mnt/Fast/...` now resolves correctly in all Dockhand stacks. To add/change Dockhand mounts, use REST API `PUT /api/v2.0/app/id/dockhand` with `{"values": {"storage": {...}}}` wrapper — `midclt call app.update` rejects all fields for catalog apps.

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
  --projectId "5086c25c-310d-4cfb-9e2c-24d1fa92c152" --domain http://192.168.20.22:8081 2>/dev/null > "$TMPKEY"
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
- **Domain**: `http://192.168.20.22:8081` (self-hosted on TrueNAS)
- **Auth**: user runs `infisical login -i --domain http://192.168.20.22:8081` manually (-i = terminal prompt, no browser) — Claude uses the session after
- **DO NOT automate Bitwarden access** — any script that reads Bitwarden gives Claude access to the entire vault
- **Project ID**: `5086c25c-310d-4cfb-9e2c-24d1fa92c152` (ALWAYS include `--projectId` and `--domain`)
- **Full pattern**: `infisical secrets get KEY --env dev --path /PATH --plain --projectId "5086c25c-310d-4cfb-9e2c-24d1fa92c152" --domain http://192.168.20.22:8081 2>/dev/null`
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

