# Homelab Project Memory

**IMPORTANT:** First 200 lines only! Keep concise. Link to detailed docs.

## Start Every Session Here
1. **Read:** `ai/SESSION_NOTES.md` - Current work in progress
2. **Read:** `ai/todo.md` - Pending tasks
3. **Read:** This file - Quick facts
4. **Before any command, check:** `ai/PATTERNS.md` - Verified copy-paste commands (saves tokens)

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
- **Dockhand**: Deployed at http://192.168.20.22:30328/ (credentials in Infisical)
- **Dockhand API**: Not well documented, use UI for stack management instead of API

## Critical Patterns
- **DO THE WORK, don't ask user to run commands** - Set up access/tools needed, then troubleshoot
- **ALWAYS check existing setup** before creating files (see truenas/DEPLOYMENT_GUIDE.md)
- **Research first, guess never** - Search codebase for patterns before attempting new approaches
- **Verify response types** before piping to tools like jq (check for HTML vs JSON)
- **Workstation → TrueNAS**: `.config/` → `/mnt/Fast/docker/<service>/`
- **Migration steps**: backup → mkdir → scp → chown 1000:1000 → deploy via Web UI
- **TrueNAS SSH**: Use kero66 key from Infisical (kero66_ssh_key). See secure pattern below.
- **NEVER store secrets in /tmp with predictable names** - use mktemp -d + cleanup

## TrueNAS SSH - Secure Pattern
```bash
# CORRECT: random temp dir, cleanup after use
TMPDIR_SAFE=$(mktemp -d) && chmod 700 "$TMPDIR_SAFE" && TMPKEY="$TMPDIR_SAFE/k"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null > "$TMPKEY" && chmod 600 "$TMPKEY"
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

## Tailscale (Remote Access) - Deployed 2026-02-26
- **Stack**: `truenas/stacks/tailscale/` — subnet router, host network mode
- **Subnet advertised**: `192.168.20.0/24`
- **Split DNS**: Tailscale admin → DNS → custom nameserver for domain `home` → TrueNAS Tailscale IP
- **Result**: All `*.home` services work identically over Tailscale as on LAN
- **Auth key secret**: `TRUENAS_TAILSCALE_AUTH_KEY` in Infisical at `/TrueNAS`
- **Deploy new apps**: `midclt call -j app.create` via SSH — NOT REST API. See PATTERNS.md.

## Jellyfin Hardware Transcoding (Intel N150)
- VAAPI with Intel iHD driver - confirmed working 2026-02-18, configured via API
- iHD driver bundled at `/usr/lib/jellyfin-ffmpeg/lib/dri/iHD_drv_video.so` (not system path)
- Compose: LIBVA_DRIVERS_PATH + LIBVA_DRIVER_NAME + group_add render(107)/video(44) - see compose.yaml
- Jellyfin API key in Infisical: **env dev, path `/media`** as `JELLYFIN_API_KEY` (NOT /TrueNAS, NOT /)
- TrueNAS app update: `PUT /api/v2.0/app/id/{name}` with `{"custom_compose_config": <dict>}` → job ID

## For Detailed Documentation
- **Verified commands**: `ai/PATTERNS.md` ← CHECK THIS FIRST before trial-and-error
- **Architecture**: `truenas/README.md`
- **Deployment**: `truenas/DEPLOYMENT_GUIDE.md`
- **Migration**: `truenas/MIGRATION_CHECKLIST.md`
- **Troubleshooting**: `.github/TROUBLESHOOTING.md`
- **Session work**: `ai/SESSION_NOTES.md`
- **Task tracking**: `ai/todo.md`
- **Doc structure**: `ai/DOCUMENTATION_STRUCTURE.md`

## Task Tracking (User Requirement)
- **Always use TaskCreate** for multi-step current session work
- **Always add** long-term items to `ai/todo.md`
- See `ai/DOCUMENTATION_STRUCTURE.md` for full workflow
