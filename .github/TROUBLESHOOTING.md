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
ssh root@192.168.20.22 "hostname"  # Should return: truenas
```

### File Transfer via SCP
```bash
# Upload single file
scp /local/file.yaml root@192.168.20.22:/mnt/Fast/docker/app/file.yaml

# Upload directory recursively
scp -r /local/dir root@192.168.20.22:/mnt/Fast/docker/app/
```

### Remote Command Execution
```bash
# Check dataset contents
ssh root@192.168.20.22 "ls -la /mnt/Fast/docker/jellyfin/"

# Check disk usage
ssh root@192.168.20.22 "du -sh /mnt/Data/media/*"

# Count files
ssh root@192.168.20.22 "find /mnt/Data/media/movies -type f | wc -l"

# Check running apps/containers
ssh root@192.168.20.22 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
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

## Want this in a PR?
- Adds this file to `.github/`
- Adds a short README note pointing to it
