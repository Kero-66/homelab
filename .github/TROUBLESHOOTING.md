# Troubleshooting Guide (sanitised)

This file documents safe, repeatable troubleshooting commands for the homelab project.
Do NOT put real credentials in this file — use placeholders and reference your local, gitignored `.env` files or Infisical paths.

## Principles
- Never commit secrets. Store secrets in Infisical and inject at runtime.
- Infisical CLI requires a project ID for `infisical run`. Set `INFISICAL_PROJECT_ID` or pass `--projectId` to avoid the “projectSlug or workspaceId” error.
- Prefer adding defensive defaults in compose files (e.g., `${VAR:-default}`) to avoid parse-time errors.

## Recording successful fixes
- When you discover a reliable API call or troubleshooting command, add it here with sanitized paths/credentials and a short explanation so the next person can reuse it.
- Reference the gitignored credentials file for any service-specific secrets instead of copying them into this document.

## Common commands (sanitised)

### Validate merged compose config (Infisical injection)

Run from the project root:

```bash
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /media --projectId <PROJECT_ID> -- \
  docker compose -f media/compose.yaml -f apps/homepage/compose.yaml config
```

### Start homepage (Infisical injection)

```bash
cd apps/homepage
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose --profile homepage -f /mnt/library/repos/homelab/apps/homepage/compose.yaml up -d
```

### Stop homepage (Infisical injection)

```bash
cd apps/homepage
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose --profile homepage -f /mnt/library/repos/homelab/apps/homepage/compose.yaml down
```

### Start media stack (Infisical injection)

```bash
cd media
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /media --projectId <PROJECT_ID> -- \
  docker compose --profile media -f /mnt/library/repos/homelab/media/compose.yaml up -d
```

### Stop media stack (Infisical injection)

```bash
cd media
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /media --projectId <PROJECT_ID> -- \
  docker compose --profile media -f /mnt/library/repos/homelab/media/compose.yaml down
```

### View logs for services

```bash
# Media services (qbittorrent, jackett)
docker compose -f media/compose.yaml logs qbittorrent jackett --tail=200

# Homepage logs (Infisical injection for environment variables)
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose -f media/compose.yaml -f apps/homepage/compose.yaml logs homepage --tail=200
```

### Exec into a service to inspect config (as root)

```bash
docker compose -f media/compose.yaml exec --user root qbittorrent sh -c "ls -la /config && sed -n '1,200p' /config/qBittorrent/qBittorrent.conf"
```

### Unban homepage host in qBittorrent (preferred: use API where available)

1. Stop homepage to avoid repeated failed attempts.
2. Log in to qBittorrent and unban or restart qbittorrent.

```bash
# Stop homepage
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose -f media/compose.yaml -f apps/homepage/compose.yaml stop homepage

### Sync Homepage secrets from stack paths

If Homepage is missing API keys from other stacks, mirror them into `/homepage`:

```bash
INFISICAL_PROJECT_ID=<PROJECT_ID> \
bash security/infisical/sync_homepage_secrets.sh
```

# Restart qbittorrent service to clear temporary bans
docker compose -f media/compose.yaml restart qbittorrent

# Alternatively, use the qBittorrent API (login + unban)
# curl -c /tmp/qb-cookies -X POST -d "username=USER&password=PASS" http://localhost:8080/api/v2/auth/login
# curl -b /tmp/qb-cookies "http://localhost:8080/api/v2/commands/unbanHosts?hosts=172.39.0.21"
```

## Notes about assistant memory
- The assistant stores a private, non-repo memory entry with a sanitized list of commands to avoid repeating trial-and-error in future sessions.

## TrueNAS API (v25.10) — Verified Working Commands

All commands use inline Infisical key retrieval. Never store the API key in a shell variable from a literal.

### Authentication pattern
```bash
# Fetch key inline every time — never export or hardcode
TNAS_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null)
```

### System info
```bash
TNAS_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null) && \
  curl -s -H "Authorization: Bearer $TNAS_KEY" "http://192.168.20.22/api/v2.0/system/info" | jq '{version, hostname, timezone}'
```

### List pools
```bash
TNAS_KEY=$(...) && curl -s -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/pool" | jq '[.[] | {name, status, healthy, path}]'
```

### List datasets
```bash
TNAS_KEY=$(...) && curl -s -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/pool/dataset" | jq '[.[] | .id] | sort'
```

### Docker/Apps config
```bash
TNAS_KEY=$(...) && curl -s -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/docker" | jq '{pool, dataset, nvidia}'
```

### List deployed apps
```bash
TNAS_KEY=$(...) && curl -s -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/app" | jq '[.[] | {name, state, version}]'
```

### List non-builtin users
```bash
TNAS_KEY=$(...) && curl -s -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/user" | jq '[.[] | select(.builtin == false) | {username, uid, gid: .group.bsdgrp_gid, home}]'
```

### Filesystem: Create directory
```bash
TNAS_KEY=$(...) && curl -s -X POST -H "Authorization: Bearer $TNAS_KEY" \
  -H "Content-Type: application/json" \
  -d '{"path": "/mnt/Fast/docker/<dirname>"}' \
  "http://192.168.20.22/api/v2.0/filesystem/mkdir"
```

### Filesystem: Write file (multipart upload)
```bash
TNAS_KEY=$(...) && curl -s -X POST -H "Authorization: Bearer $TNAS_KEY" \
  -F 'data={"path": "/mnt/Fast/docker/<dirname>/<filename>"}' \
  -F 'file=@/path/to/local/file' \
  "http://192.168.20.22/api/v2.0/filesystem/put"
```

### Filesystem: Set permissions
```bash
TNAS_KEY=$(...) && curl -s -X POST -H "Authorization: Bearer $TNAS_KEY" \
  -H "Content-Type: application/json" \
  -d '{"path": "/mnt/Fast/docker/<dirname>/<filename>", "mode": "600"}' \
  "http://192.168.20.22/api/v2.0/filesystem/setperm"
```

### Filesystem: Set ownership
```bash
TNAS_KEY=$(...) && curl -s -X POST -H "Authorization: Bearer $TNAS_KEY" \
  -H "Content-Type: application/json" \
  -d '{"path": "/mnt/Fast/docker/<dirname>", "uid": 1000, "gid": 1000, "options": {"recursive": true}}' \
  "http://192.168.20.22/api/v2.0/filesystem/chown"
```

### Filesystem: List directory
```bash
TNAS_KEY=$(...) && curl -s -X POST -H "Authorization: Bearer $TNAS_KEY" \
  -H "Content-Type: application/json" \
  -d '{"path": "/mnt/Fast/docker/<dirname>"}' \
  "http://192.168.20.22/api/v2.0/filesystem/listdir" | jq '[.[] | {name, type, uid, gid}]'
```

### Filesystem: Stat (check if path exists)
```bash
TNAS_KEY=$(...) && curl -s -X POST -H "Authorization: Bearer $TNAS_KEY" \
  -H "Content-Type: application/json" \
  -d '{"path": "/mnt/Fast/docker/<path>"}' \
  "http://192.168.20.22/api/v2.0/filesystem/stat" | jq '{type, uid, gid, mode}'
```

### NOT AVAILABLE via API (as of 25.10.1)
- `app.create` with custom compose — TODO in their codebase. Custom Apps must be created via TrueNAS Web UI.

### SMB share management

```bash
# List existing SMB shares
curl -sf -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/sharing/smb" | jq '.[].path'

# Create an SMB share (purpose: DEFAULT_SHARE, LEGACY_SHARE, TIMEMACHINE_SHARE, etc.)
curl -sf -H "Authorization: Bearer $TNAS_KEY" \
  -X POST -H "Content-Type: application/json" \
  -d '{"path": "/mnt/Data/media", "name": "media", "purpose": "DEFAULT_SHARE"}' \
  "http://192.168.20.22/api/v2.0/sharing/smb" | jq '{id, name, path}'

# Check SMB (CIFS) service status
curl -sf -H "Authorization: Bearer $TNAS_KEY" \
  "http://192.168.20.22/api/v2.0/service" | jq '.[] | select(.service == "cifs") | {state, enable}'
```

### Dataset ownership fix (ZFS datasets don't inherit across mount boundaries)

```bash
# Must chown each dataset mount separately — recursive on parent stops at child dataset boundary
for path in "/mnt/Data/media" "/mnt/Data/media/movies" "/mnt/Data/media/shows" "/mnt/Data/media/music"; do
  curl -sf -H "Authorization: Bearer $TNAS_KEY" \
    -X POST -H "Content-Type: application/json" \
    -d "{\"path\": \"$path\", \"uid\": 1000, \"gid\": 1000, \"options\": {\"recursive\": true}}" \
    "http://192.168.20.22/api/v2.0/filesystem/chown"
done
```

### Mounting SMB from workstation (Fedora)

```bash
# Mount using inline Infisical creds (temp file, cleaned up immediately)
TMPCRED=$(mktemp)
echo "username=kero66" > "$TMPCRED"
echo "password=$(infisical secrets get kero66_password --env dev --path /TrueNAS --plain)" >> "$TMPCRED"
chmod 600 "$TMPCRED"
sudo mount -t cifs //192.168.20.22/media /mnt/truenas_media -o "credentials=$TMPCRED,uid=1000,gid=1000"
rm -f "$TMPCRED"
```

## TrueNAS SSH Commands (2026-02-11 Session)

### SSH Setup
ED25519 key-based auth configured for kero66 user:
```bash
# Generate key (if not exists)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "kero66@fedora"

# Add public key to TrueNAS root user via API (done once)
# Then test:
ssh kero66@192.168.20.22 "hostname"  # Should return: truenas
```

### File Transfer via SCP
```bash
# Upload single file
scp /local/file.yaml kero66@192.168.20.22:/mnt/Fast/docker/app/file.yaml

# Upload directory recursively
scp -r /local/dir kero66@192.168.20.22:/mnt/Fast/docker/app/
```

### Remote Command Execution
```bash
# Check dataset contents
ssh kero66@192.168.20.22 "ls -la /mnt/Fast/docker/jellyfin/"

# Check disk usage
ssh kero66@192.168.20.22 "du -sh /mnt/Data/media/*"

# Count files
ssh kero66@192.168.20.22 "find /mnt/Data/media/movies -type f | wc -l"

# Check running apps/containers
ssh kero66@192.168.20.22 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

### SMB Mount from Fedora Workstation
```bash
# Mount TrueNAS SMB share (assumes share created and SMB service running)
sudo mkdir -p /mnt/truenas_media
sudo mount -t cifs //192.168.20.22/media /mnt/truenas_media \
  -o "username=kero66,password=<PASSWORD>,uid=1000,gid=1000"

# Or use credentials file for security
TMPCRED=$(mktemp)
echo "username=kero66" > "$TMPCRED"
echo "password=$(infisical secrets get kero66_password --env dev --path /TrueNAS --plain)" >> "$TMPCRED"
chmod 600 "$TMPCRED"
sudo mount -t cifs //192.168.20.22/media /mnt/truenas_media -o "credentials=$TMPCRED,uid=1000,gid=1000"
rm -f "$TMPCRED"

# Verify mount
mountpoint -q /mnt/truenas_media && echo "Mounted" || echo "NOT mounted"

# Unmount when done
sudo umount /mnt/truenas_media
```

### Media Transfer via rsync
```bash
# Background rsync with logging (safe, resumable, no source deletion)
rsync -avh --progress --partial \
  --no-perms --no-owner --no-group \
  /mnt/wd_media/homelab-data/movies/ \
  /mnt/truenas_media/movies/ \
  > ~/truenas_media_transfer.log 2>&1 &

# Monitor progress
tail -f ~/truenas_media_transfer.log

# Check if still running
ps aux | grep rsync | grep -v grep
```

## TrueNAS Custom App Updates (2026-02-12 Discovery)

### Background
TrueNAS 25.10 Custom Apps can be updated without Web UI by directly editing compose files and recreating containers via SSH.

### Compose File Location
Custom App compose files are stored at:
```
/mnt/.ix-apps/app_configs/<APP_NAME>/versions/<VERSION>/templates/rendered/docker-compose.yaml
```

Example:
```bash
# Jellyfin app compose location
/mnt/.ix-apps/app_configs/jellyfin/versions/1.0.0/templates/rendered/docker-compose.yaml
```

### Update Process

**Step 1: Update compose file on TrueNAS**
```bash
# Upload updated compose from repo
scp truenas/stacks/jellyfin/compose.yaml \
  kero66@192.168.20.22:/mnt/.ix-apps/app_configs/jellyfin/versions/1.0.0/templates/rendered/docker-compose.yaml
```

**Step 2: Recreate affected containers**
```bash
# Recreate specific service (uses TrueNAS project name)
ssh kero66@192.168.20.22 'docker compose -p ix-jellyfin \
  -f /mnt/.ix-apps/app_configs/jellyfin/versions/1.0.0/templates/rendered/docker-compose.yaml \
  up -d jellystat'

# Or recreate all services in app
ssh kero66@192.168.20.22 'docker compose -p ix-jellyfin \
  -f /mnt/.ix-apps/app_configs/jellyfin/versions/1.0.0/templates/rendered/docker-compose.yaml \
  up -d'
```

**Step 3: Verify deployment**
```bash
# Check container status
ssh kero66@192.168.20.22 'docker ps | grep jellyfin'

# Check health status
ssh kero66@192.168.20.22 'docker inspect jellystat | jq -r ".[0].State.Health.Status"'
```

### Important Notes
- **Project name**: TrueNAS uses `ix-<APP_NAME>` as the docker compose project name
- **Networks**: Containers use `ix-<APP_NAME>_default` network, already created by TrueNAS
- **No need to stop**: `docker compose up -d` will recreate changed containers automatically
- **Preserves data**: Volume mounts remain unchanged, data persists across recreation

### Common Use Cases

**Fix health check (curl vs wget)**
```yaml
# Bad - container may not have curl
healthcheck:
  test: curl -sf http://localhost:3000/health || exit 1

# Good - use wget or CMD-SHELL array format
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1"]
```

**Update service image version**
```yaml
# Change in compose file
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:10.8.13  # was :latest

# Apply
ssh kero66@192.168.20.22 'docker compose -p ix-jellyfin -f /path/to/compose.yaml pull jellyfin'
ssh kero66@192.168.20.22 'docker compose -p ix-jellyfin -f /path/to/compose.yaml up -d jellyfin'
```

## Prowlarr Application Connection Fixes (2026-02-12)

### Problem
After TrueNAS migration, Prowlarr couldn't sync with Sonarr/Radarr due to old workstation Docker network IPs in database.

### Root Cause
Prowlarr database stores application connection URLs with IP addresses that changed during migration:
- Old: `http://172.39.0.3:8989` (workstation network)
- New: `http://sonarr:8989/sonarr` (TrueNAS network + URL base)

### Solution: Update via Database (when API unavailable)

**Before attempting database edits**, check Prowlarr API:
```bash
# Check Prowlarr API documentation
curl -s "http://192.168.20.22:9696/docs" | head -20

# List applications via API
curl -s "http://192.168.20.22:9696/api/v1/applications" \
  -H "X-Api-Key: <PROWLARR_API_KEY>" | jq '.'
```

**If API doesn't support updates, use database:**
```bash
# Stop Prowlarr
ssh kero66@192.168.20.22 'docker stop prowlarr'

# Update Sonarr connection (include URL base if configured)
ssh kero66@192.168.20.22 "sqlite3 /mnt/Fast/docker/prowlarr/prowlarr.db \"
UPDATE Applications
SET Settings = replace(Settings, '\"baseUrl\": \"http://172.39.0.3:8989\"', '\"baseUrl\": \"http://sonarr:8989/sonarr\"')
WHERE Name = 'Sonarr';
\""

# Update Radarr connection (include URL base if configured)
ssh kero66@192.168.20.22 "sqlite3 /mnt/Fast/docker/prowlarr/prowlarr.db \"
UPDATE Applications
SET Settings = replace(Settings, '\"baseUrl\": \"http://172.39.0.4:7878\"', '\"baseUrl\": \"http://radarr:7878/radarr\"')
WHERE Name = 'Radarr';
\""

# Verify changes
ssh kero66@192.168.20.22 "sqlite3 /mnt/Fast/docker/prowlarr/prowlarr.db \"
SELECT Name, json_extract(Settings, '$.baseUrl') FROM Applications;
\""

# Start Prowlarr
ssh kero66@192.168.20.22 'docker start prowlarr'

# Test connectivity from Prowlarr container
ssh kero66@192.168.20.22 'docker exec prowlarr curl -sf http://sonarr:8989/sonarr/api/v3/system/status -H "X-Api-Key: <SONARR_API_KEY>" | jq .appName'
```

### Important: Check URL Bases First
```bash
# Verify Sonarr/Radarr have URL bases configured
ssh kero66@192.168.20.22 'grep -i "urlbase" /mnt/Fast/docker/sonarr/config.xml'
# Output: <UrlBase>/sonarr</UrlBase>

ssh kero66@192.168.20.22 'grep -i "urlbase" /mnt/Fast/docker/radarr/config.xml'
# Output: <UrlBase>/radarr</UrlBase>

# If URL base is set, include it in Prowlarr's baseUrl
# If NOT set, use just: http://sonarr:8989 (no /sonarr suffix)
```

## Sonarr/Radarr Health Check Fixes (2026-02-12)

### Trigger Manual Health Checks
```bash
# Force health check refresh (cached results may be stale)
curl -s -X POST "http://192.168.20.22:8989/sonarr/api/v3/command" \
  -H "X-Api-Key: <SONARR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"name": "CheckHealth"}'

curl -s -X POST "http://192.168.20.22:7878/radarr/api/v3/command" \
  -H "X-Api-Key: <RADARR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"name": "CheckHealth"}'

# Wait a few seconds, then check results
sleep 5
curl -s "http://192.168.20.22:8989/sonarr/api/v3/health" \
  -H "X-Api-Key: <SONARR_API_KEY>" | jq '.[] | select(.type == "error")'
```

### Fix Recycle Bin Permissions
```bash
# Problem: Sonarr/Radarr run as UID 1000, but .recycle owned by root
# Error: "Unable to write to configured recycling bin folder: /data/.recycle"

# Check ownership
ssh kero66@192.168.20.22 'ls -la /mnt/Data/media/ | grep recycle'
# drwxr-xr-x 27 root   root   27 Feb 12 00:59 .recycle  # BAD

# Fix ownership
ssh kero66@192.168.20.22 'chown -R 1000:1000 /mnt/Data/media/.recycle'

# Verify
ssh kero66@192.168.20.22 'ls -la /mnt/Data/media/ | grep recycle'
# drwxr-xr-x 27 kero66 kero66 27 Feb 12 00:59 .recycle  # GOOD

# Trigger health check to clear error
curl -s -X POST "http://192.168.20.22:8989/sonarr/api/v3/command" \
  -H "X-Api-Key: <SONARR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"name": "CheckHealth"}' > /dev/null
```

### Fix Docker Daemon Startup Failure (Orphaned Process)

```bash
# Problem: Docker won't start, logs show "process with PID XXXX is still running"
# Symptom: systemd shows "failed to start daemon, ensure docker is not running or delete /var/run/docker.pid"

# Check if PID in error message is actually running
ps aux | grep <PID>

# If orphaned dockerd process exists, kill it
sudo kill <PID>

# Start Docker service
sudo systemctl start docker

# Verify Docker is running
sudo systemctl status docker

# Check if dependent containers started (e.g., Infisical)
docker ps --format "table {{.Names}}\t{{.Status}}"

# If Infisical Agent on TrueNAS was affected, restart it
ssh kero66@192.168.20.22 'docker restart infisical-agent'

# Wait 30 seconds for secrets to render, then verify
sleep 30
ssh kero66@192.168.20.22 'ls -lh /mnt/Fast/docker/arr-stack/.env /mnt/Fast/docker/downloaders/.env /mnt/Fast/docker/jellyfin/.env'
```

### DNS Resolution Issue - systemd-resolved Preferring Fallback DNS

**Problem**: Linux clients can't resolve `.home` domains (e.g., `jellyfin.home`) even though AdGuard Home is configured.

**Symptom**:
```bash
resolvectl query jellyfin.home
# jellyfin.home: Name 'jellyfin.home' not found

resolvectl status wlp9s0
# Current DNS Server: 1.1.1.1  <-- Using Cloudflare instead of AdGuard Home
# DNS Servers: 192.168.20.22 1.1.1.1
```

**Root Cause**:
- systemd-resolved treats multiple DNS servers as alternatives, not primary/fallback
- When both `192.168.20.22` (AdGuard Home) and `1.1.1.1` (Cloudflare) are configured, systemd-resolved may choose Cloudflare
- Cloudflare doesn't know about internal `.home` domains

**Solution 1** (Recommended - Router DHCP Change):
```bash
# Remove secondary DNS (1.1.1.1) from router DHCP configuration
# Configure router to only send: 192.168.20.22

# After DHCP change, renew lease on client:
sudo nmcli connection down "<WiFi-Name>"
sudo nmcli connection up "<WiFi-Name>"

# Verify only AdGuard Home is configured:
resolvectl status | grep "DNS Servers"
# DNS Servers: 192.168.20.22  <-- Only one server

# Test resolution:
resolvectl query jellyfin.home
# jellyfin.home: 192.168.20.22  <-- Success!
```

**Solution 2** (Per-Client Fix - Linux Only):
```bash
# Configure routing domain to force .home queries to AdGuard Home
sudo nmcli connection modify "<WiFi-Name>" ipv4.dns-search "~home"
sudo nmcli connection up "<WiFi-Name>"

# Verify routing domain is set:
resolvectl domain
# Link 3 (wlp9s0): ~home  <-- Tilde means "routing domain"
```

**Trade-offs**:
- **Solution 1**: If AdGuard Home goes down, DNS fails network-wide
  - Mitigation: Run second AdGuard Home instance for high availability
- **Solution 2**: Must configure each Linux device individually
  - Other devices (Windows, macOS, phones) typically respect primary DNS properly

**Verification**:
```bash
# Test DNS resolution
dig @192.168.20.22 jellyfin.home +short
# 192.168.20.22  <-- AdGuard Home resolves correctly

# Test via systemd-resolved
resolvectl query jellyfin.home
# jellyfin.home: 192.168.20.22  <-- Now works!

# Test actual HTTP access
curl -I http://jellyfin.home
# Should return HTTP headers from Caddy/Jellyfin
```

**Fixed**: 2026-02-14

---

## Want this in a PR?
- Adds this file to `.github/`
- Adds a short README note pointing to it
