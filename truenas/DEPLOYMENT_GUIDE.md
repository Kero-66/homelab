# TrueNAS Jellyfin Stack Deployment Guide

## Overview

This guide deploys Jellyfin, Jellyseerr, and Jellystat as Custom Apps on **TrueNAS Scale 25.10.1** with Infisical Agent for secrets management.

**Important:** Custom Apps cannot be created via the REST API. Use `midclt call -j app.create` via SSH — see `ai/PATTERNS.md` → "Create a new Custom App". The Web UI also works but is not required.

## Prerequisites

### Pre-Deployment

1. **Infisical Machine Identity** created and configured
   - See [INFISICAL_SETUP.md](../docs/INFISICAL_GUIDE.md) for details
   - Must have `Universal Auth` credentials ready

2. **TrueNAS API Key** stored in Infisical
   - Path: `/TrueNAS/truenas_admin_api`
   - Current system: 192.168.20.22 (HTTPS)

3. **Docker IPv6 Fix** applied
   - IPv6 address pools removed to force IPv4-only operation
   - This resolves image pull timeouts (home network lacks IPv6 routing)
   - **Status:** ✅ Applied via Job 5442

4. **Setup Agent Deployed**
   - Run: `bash truenas/scripts/setup_agent.sh`
   - This uploads all configs to `/mnt/Fast/docker/` on TrueNAS

## Step 1: Create infisical-agent Custom App (Web UI)

### Navigate to Apps

1. Open TrueNAS Scale Web UI: **https://192.168.20.22**
2. Go to **Apps** → **Discover**
3. Click **Custom App** (bottom right)

### Create App

1. **Release Name:** `infisical-agent`
2. **Version:** `1.0.0`
3. **Compose YAML:** Copy from [truenas/stacks/infisical-agent/compose.yaml](./stacks/infisical-agent/compose.yaml)

```yaml
services:
  infisical-agent:
    image: infisical/cli:latest
    container_name: infisical-agent
    restart: unless-stopped
    command: agent --config /config/agent-config.yaml
    volumes:
      # Agent config and templates (on Fast pool)
      - /mnt/Fast/docker/infisical-agent/config:/config:ro
      # Output directory - agent writes .env files here
      - /mnt/Fast/docker:/output
```

4. Click **Install**
   - Wait for job to complete (image pull should now work with IPv4-only Docker)
   - Container will start and begin rendering secrets

### Verify Deployment

1. Go to **Apps** → **Installed**
2. Look for **infisical-agent** in the list
3. Check status: **ACTIVE**

This app runs in the background and writes `.env` files to `/mnt/Fast/docker/` based on the templates it finds.

---

## Step 2: Create jellyfin Custom App (Web UI)

### Navigate to Apps

1. Apps → Discover → Custom App

### Create App

1. **Release Name:** `jellyfin`
2. **Version:** `1.0.0`
3. **Compose YAML:** Copy from [truenas/stacks/jellyfin/compose.yaml](./stacks/jellyfin/compose.yaml)

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"    # Web UI
      - "8920:8920"    # HTTPS (optional)
    environment:
      - TZ=America/Chicago
      - PUID=1000
      - PGID=1000
    volumes:
      # Jellyfin config (migrated from old system)
      - /mnt/Fast/docker/jellyfin/config:/config
      # Video cache
      - /mnt/Fast/docker/jellyfin/cache:/cache
      # Media library mounts
      - /mnt/Data/media/movies:/media/movies:ro
      - /mnt/Data/media/shows:/media/shows:ro
    devices:
      # GPU passthrough (if applicable — check GPU_PASSTHROUGH_CONTEXT.md)
      # - /dev/dri/renderD128:/dev/dri/renderD128

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    restart: unless-stopped
    ports:
      - "5055:5055"
    environment:
      - TZ=America/Chicago
      - PUID=1000
      - PGID=1000
    volumes:
      - /mnt/Fast/docker/jellyseerr/config:/app/config
```

4. Click **Install**
   - Image pull should complete successfully
   - Services will start on ports **8096** (Jellyfin) and **5055** (Jellyseerr)

### Verify Deployment

1. **Jellyfin:** Open http://192.168.20.22:8096
   - Library should contain migrated media (config restored)
2. **Jellyseerr:** Open http://192.168.20.22:5055
   - Configuration will need to be re-applied

---

## Step 3: Restore Jellystat Database (Manual)

After the Jellyfin app is running:

1. SSH to TrueNAS (if SSH is enabled) OR use the TrueNAS Web UI shell
2. Execute:

```bash
# Restore Jellystat DB dump
docker exec -i jellyfin-db mysql -u root -p$MYSQL_ROOT_PASSWORD jellystat < /mnt/Fast/docker/jellyfin/jellystat_db_dump.sql

# Or via mysql container if available
docker compose -f /some/path/compose.yaml exec -i db mysql -u root -p$MYSQL_ROOT_PASSWORD jellystat < /mnt/Fast/docker/jellyfin/jellystat_db_dump.sql
```

**Note:** If using Infisical Agent to render the database credentials, ensure the agent has completed before running this.

---

## Troubleshooting

### Image Pull Failures

If you see **"context deadline exceeded"** or **"network is unreachable"** errors:

1. **IPv6 is the culprit**
   - The home network lacks IPv6 routing
   - Docker tries AAAA (IPv6) records first and times out
   
2. **Fix Applied:**
   - Job 5442: Removed IPv6 address pools from Docker daemon config
   - Verified: `GET /api/v2.0/docker` shows only `172.17.0.0/12` (IPv4)

3. **If issues persist:**
   - Check TrueNAS Docker logs: `Apps → App > view logs`
   - Or from shell: `docker logs <app_name>`

### Agent Not Rendering Secrets

If `.env` files are not being created:

1. Verify `infisical-agent` is **ACTIVE** in Apps list
2. Check agent logs: **Apps** → **infisical-agent** → **Logs**
3. Verify config file exists on TrueNAS:
   ```bash
   # Via TrueNAS shell or mounted filesystem
   ls -la /mnt/Fast/docker/infisical-agent/config/
   ```
4. Ensure Infisical credentials are correct in `/config/agent-config.yaml`

### Services Not Starting

1. Check **Apps** → **Installed** for error status
2. Review logs for the app
3. Common issues:
   - Port conflicts (check if 8096, 5055 are already in use)
   - Volume mount failures (verify paths exist on TrueNAS)
   - Missing environment variables (check Infisical paths)

---

## Configuration Files

All files needed for deployment have been uploaded to TrueNAS by `setup_agent.sh`:

### Location on TrueNAS

```
/mnt/Fast/docker/
├── infisical-agent/
│   └── config/
│       ├── agent-config.yaml          # Updated with TrueNAS IP
│       └── jellyfin.tmpl              # Template for jellyfin.env
├── jellyfin/
│   ├── config/                        # Jellyfin app config (migrated)
│   ├── cache/                         # Cache directory
│   └── jellystat_db_dump.sql          # Database backup for restore
└── jellyseerr/
    └── config/                        # Jellyseerr config (to be reconfigured)
```

### Compose Files (in repo)

- [truenas/stacks/infisical-agent/compose.yaml](./stacks/infisical-agent/compose.yaml)
- [truenas/stacks/jellyfin/compose.yaml](./stacks/jellyfin/compose.yaml)

---

## Next Steps

1. ✅ Create **infisical-agent** Custom App (secrets rendering)
2. ✅ Create **jellyfin** Custom App (media server + Jellyseerr)
3. ✅ Restore Jellystat database
4. Configure Jellyseerr to connect to Sonarr/Radarr (manual)
5. Test media playback in Jellyfin

---

## References

- [GPU Passthrough Context](../.github/GPU_PASSTHROUGH_CONTEXT.md) — check before enabling GPU
- [Infisical Setup](../docs/INFISICAL_GUIDE.md) — Machine Identity setup
- [TrueNAS TROUBLESHOOTING](../.github/TROUBLESHOOTING.md) — API reference

---

## API Reference (For Future Automation)

### Docker Config Status

Check IPv6 pools are removed:

```bash
TNAS_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --domain "http://localhost:8081" --plain 2>/dev/null)
curl -sk "https://192.168.20.22/api/v2.0/docker" \
  -H "Authorization: Bearer $TNAS_KEY" 2>/dev/null | jq '.address_pools[].base'
```

**Expected output:** `172.17.0.0/12` only (no IPv6 pools)

### List Deployed Apps

```bash
curl -sk "https://192.168.20.22/api/v2.0/app" \
  -H "Authorization: Bearer $TNAS_KEY" 2>/dev/null | jq '[.[] | {release_name, status}]'
```

---

## Notes

- **TrueNAS 25.10.1 Limitation:** Custom Apps cannot be created programmatically; Web UI is required.
- **Media paths:** Adjust `/mnt/Data/media/` paths to match your actual TrueNAS pool/dataset structure.
- **Timezone:** Set `TZ` environment variable in compose files to match your location.

