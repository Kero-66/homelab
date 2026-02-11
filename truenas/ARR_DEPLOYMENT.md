# Arr Stack & Downloaders Deployment Guide

Complete guide for migrating the *arr applications and download clients from workstation to TrueNAS Scale.

## 📋 Overview

This migration moves the following services to TrueNAS:

**Arr Stack:**
- Sonarr (TV series management)
- Radarr (Movie management)
- Prowlarr (Indexer manager)
- Bazarr (Subtitle management)
- Recyclarr (TRaSH Guides automation)
- FlareSolverr (Cloudflare CAPTCHA bypass)
- Cleanuparr (Queue cleanup automation)

**Downloader Stack:**
- qBittorrent (Torrent client)
- SABnzbd (Usenet client)

**Network Stack:**
- Tailscale (Secure remote access / subnet router)

## ✅ Prerequisites

### 1. Media Transfer Complete
Ensure media files are fully transferred:
```bash
# Check transfer progress
tail -f ~/truenas_media_transfer.log

# Verify transfer complete
ps aux | grep rsync | grep -v grep  # Should return nothing

# Verify media on TrueNAS
ssh root@192.168.20.22 "du -sh /mnt/Data/media/*"
```

### 2. Secrets in Infisical
Verify all required secrets exist in Infisical (`/media` path):

**Arr Stack:**
- `SONARR_API_KEY`
- `RADARR_API_KEY`
- `PROWLARR_API_KEY`
- `BAZARR_API_KEY`

**Downloaders:**
- `QBITTORRENT_USER`
- `QBITTORRENT_PASS`
- `SABNZBD_API_KEY`

**Tailscale:**
- `TAILSCALE_AUTHKEY` (in `/TrueNAS` path)

### 3. Config Backup
Backup existing configs from workstation (if needed):
```bash
# From workstation
cd /mnt/library/repos/homelab/media
tar czf ~/arr_configs_backup_$(date +%Y%m%d).tar.gz \
  sonarr/ radarr/ prowlarr/ bazarr/ recyclarr/ cleanuparr/ \
  qbittorrent/ sabnzbd/
```

## 🚀 Deployment Steps

### Step 1: Deploy New Templates

Run the deployment script to upload templates and configs:

```bash
cd /mnt/library/repos/homelab
bash truenas/scripts/deploy_new_stacks.sh
```

This script:
- ✅ Creates output directories on TrueNAS
- ✅ Uploads new Infisical Agent templates
- ✅ Uploads updated agent-config.yaml
- ✅ Creates service config directories
- ✅ Sets correct permissions (1000:1000)

### Step 2: Restart Infisical Agent

1. Open TrueNAS Web UI: https://192.168.20.22
2. Navigate to **Apps**
3. Find **infisical-agent** app
4. Click **⋮** → **Restart**
5. Wait 1-2 minutes for agent to start and render .env files

### Step 3: Verify .env Files Generated

```bash
# Check .env files exist
ssh root@192.168.20.22 'ls -la /mnt/Fast/docker/{arr-stack,downloaders,tailscale}/.env'

# Verify content (redacted)
ssh root@192.168.20.22 'head -5 /mnt/Fast/docker/arr-stack/.env'
```

Expected output:
```
# Arr stack secrets - rendered by Infisical Agent
# DO NOT EDIT - this file is auto-generated every 5 minutes
...
SONARR_API_KEY=...
```

### Step 4: Deploy Tailscale (Optional but Recommended)

**4a. Generate Tailscale Auth Key:**
1. Go to: https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Settings:
   - ✅ **Reusable** (container can restart)
   - ✅ **Pre-approved** (auto-join network)
   - Optional: **Ephemeral** (device removed when offline)
4. Copy the auth key (starts with `tskey-auth-...`)

**4b. Store in Infisical:**
```bash
infisical secrets set TAILSCALE_AUTHKEY <YOUR_KEY> \
  --env dev --path /TrueNAS
```

**4c. Verify agent rendered Tailscale .env:**
```bash
ssh root@192.168.20.22 'cat /mnt/Fast/docker/tailscale/.env | grep TS_AUTHKEY'
```

**4d. Deploy Tailscale App:**
1. TrueNAS UI → **Apps** → **Discover** → **Custom App**
2. **Name:** `tailscale`
3. **Custom Config:** Paste contents of `truenas/stacks/tailscale/compose.yaml`
4. Click **Install**
5. Wait for status: **RUNNING**

**4e. Approve Subnet Routes:**
1. Go to: https://login.tailscale.com/admin/machines
2. Find device: **truenas**
3. Under **Subnet routes**, click **Approve** for `192.168.20.0/24`

**4f. Test Connectivity:**
```bash
# From another Tailscale device
ping <truenas-tailscale-ip>
curl http://<truenas-tailscale-ip>:8096  # Should reach Jellyfin
```

### Step 5: Migrate Arr Stack Configs (Optional)

If you want to preserve existing configurations:

```bash
# Upload Sonarr config
scp -r media/sonarr/* root@192.168.20.22:/mnt/Fast/docker/sonarr/

# Upload Radarr config
scp -r media/radarr/* root@192.168.20.22:/mnt/Fast/docker/radarr/

# Upload Prowlarr config
scp -r media/prowlarr/* root@192.168.20.22:/mnt/Fast/docker/prowlarr/

# Upload Bazarr config
scp -r media/bazarr/* root@192.168.20.22:/mnt/Fast/docker/bazarr/

# Upload Recyclarr config
scp -r media/recyclarr/config/* root@192.168.20.22:/mnt/Fast/docker/recyclarr/config/

# Fix ownership
ssh root@192.168.20.22 "chown -R 1000:1000 /mnt/Fast/docker/{sonarr,radarr,prowlarr,bazarr,recyclarr}"
```

### Step 6: Deploy Arr Stack

1. TrueNAS UI → **Apps** → **Discover** → **Custom App**
2. **Name:** `arr-stack`
3. **Custom Config:** Paste contents of `truenas/stacks/arr-stack/compose.yaml`
4. Click **Install**
5. Wait for all services to show status: **RUNNING** (may take 2-3 minutes)

**Verify Services:**
- Prowlarr: http://192.168.20.22:9696
- Sonarr: http://192.168.20.22:8989
- Radarr: http://192.168.20.22:7878
- Bazarr: http://192.168.20.22:6767
- FlareSolverr: http://192.168.20.22:8191
- Cleanuparr: http://192.168.20.22:11011

### Step 7: Migrate Downloader Configs (Optional)

```bash
# Upload qBittorrent config
scp -r media/qbittorrent/* root@192.168.20.22:/mnt/Fast/docker/qbittorrent/

# Upload SABnzbd config
scp -r media/sabnzbd/* root@192.168.20.22:/mnt/Fast/docker/sabnzbd/

# Fix ownership
ssh root@192.168.20.22 "chown -R 1000:1000 /mnt/Fast/docker/{qbittorrent,sabnzbd}"
```

### Step 8: Deploy Downloader Stack

1. TrueNAS UI → **Apps** → **Discover** → **Custom App**
2. **Name:** `downloaders`
3. **Custom Config:** Paste contents of `truenas/stacks/downloaders/compose.yaml`
4. Click **Install**
5. Wait for services to show status: **RUNNING**

**Verify Services:**
- qBittorrent: http://192.168.20.22:8080
- SABnzbd: http://192.168.20.22:8085

### Step 9: Connect Services

#### 9a. Connect Prowlarr to Apps

In Prowlarr UI:
1. **Settings** → **Apps**
2. **Add Application** → **Sonarr**
   - Name: `Sonarr`
   - Sync Level: `Full Sync`
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: (from Sonarr → Settings → General)
3. Repeat for **Radarr**
   - Radarr Server: `http://radarr:7878`

#### 9b. Connect Download Clients

In Sonarr and Radarr:
1. **Settings** → **Download Clients**
2. **Add** → **qBittorrent**
   - Host: `qbittorrent`
   - Port: `8080`
   - Username/Password: (from Infisical)
   - Category: `tv` (Sonarr) or `movies` (Radarr)
3. **Add** → **SABnzbd**
   - Host: `sabnzbd`
   - Port: `8080`
   - API Key: (from Infisical)
   - Category: `tv` (Sonarr) or `movies` (Radarr)

#### 9c. Connect Bazarr

In Bazarr:
1. **Settings** → **Sonarr**
   - Address: `http://sonarr:8989`
   - API Key: (from Sonarr)
2. **Settings** → **Radarr**
   - Address: `http://radarr:7878`
   - API Key: (from Radarr)

### Step 10: Run Recyclarr

Recyclarr automatically syncs TRaSH Guides settings daily. To run manually:

```bash
# Check if config exists
ssh root@192.168.20.22 "ls -la /mnt/Fast/docker/recyclarr/config/"

# Run sync manually (one-time)
ssh root@192.168.20.22 "docker exec recyclarr recyclarr sync"
```

## 🧪 Testing

### Test Downloads

1. **Prowlarr:** Search for content, verify indexers return results
2. **Sonarr:** Add a TV series, verify it searches and queues download
3. **Radarr:** Add a movie, verify it searches and queues download
4. **qBittorrent:** Verify torrent appears and starts downloading
5. **SABnzbd:** Verify usenet download appears and starts
6. **Bazarr:** Verify it detects new media and searches for subtitles

### Test Automation

1. **Recyclarr:** Check logs for successful TRaSH Guides sync
2. **Cleanuparr:** Monitor queue, verify it removes stalled/failed downloads

## 🔧 Troubleshooting

### .env Files Not Generated

**Symptom:** Files missing in `/mnt/Fast/docker/<stack>/.env`

**Fix:**
1. Check agent logs: TrueNAS → Apps → infisical-agent → Logs
2. Verify templates uploaded: `ssh root@192.168.20.22 "ls /mnt/Fast/docker/infisical-agent/config/*.tmpl"`
3. Verify secrets exist in Infisical
4. Restart agent and wait 2 minutes

### Service Can't Read .env File

**Symptom:** Service fails with "environment variable not set"

**Fix:**
```bash
# Check .env file exists and is readable
ssh root@192.168.20.22 "ls -la /mnt/Fast/docker/<stack>/.env"

# Check file is not empty
ssh root@192.168.20.22 "wc -l /mnt/Fast/docker/<stack>/.env"

# Restart the app via TrueNAS UI
```

### Prowlarr Can't Connect to Sonarr/Radarr

**Symptom:** "Connection refused" or "Unable to connect"

**Fix:**
- Use container names (not `localhost`): `http://sonarr:8989`
- Verify services are in same Docker network (TrueNAS handles this)
- Check API keys match

### Download clients not connecting

**Symptom:** "Authentication required" or "Connection failed"

**Fix:**
1. Verify credentials in Infisical match qBittorrent/SABnzbd settings
2. Check `.env` file has correct credentials
3. Restart download client container
4. Test: `curl -u user:pass http://192.168.20.22:8080/api/v2/app/version`

### Tailscale not connecting

**Symptom:** Device doesn't appear in Tailscale admin

**Fix:**
1. Verify auth key is valid: https://login.tailscale.com/admin/settings/keys
2. Check `.env` file has `TS_AUTHKEY`
3. Check container logs: Apps → tailscale → Logs
4. Verify host network mode is enabled in compose

## 📊 Monitoring

After deployment, monitor services:

```bash
# Check all container status
ssh root@192.168.20.22 "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Check logs
ssh root@192.168.20.22 "docker logs sonarr --tail 50"
ssh root@192.168.20.22 "docker logs radarr --tail 50"
ssh root@192.168.20.22 "docker logs qbittorrent --tail 50"

# Check resource usage
ssh root@192.168.20.22 "docker stats --no-stream"
```

## 🎯 Next Steps

After successful deployment:

1. ✅ **Stop workstation services:** `docker compose -f media/compose.yaml down`
2. ✅ **Update Homepage:** Point widgets to TrueNAS IPs
3. ✅ **Update Caddy:** (if applicable) Point reverse proxy to TrueNAS
4. ✅ **Test remote access:** Via Tailscale from external network
5. ✅ **Monitor for 24-48 hours:** Ensure stability and downloads work
6. ✅ **Backup TrueNAS configs:** `ssh root@192.168.20.22 "tar czf /tmp/configs_backup.tar.gz /mnt/Fast/docker/"`

## 📝 Rollback Plan

If issues occur, rollback to workstation:

```bash
# Start services on workstation
cd /mnt/library/repos/homelab/media
docker compose --profile media up -d

# Stop TrueNAS apps
# TrueNAS UI → Apps → Select app → Stop
```

---

**Need Help?** Check:
- TrueNAS logs: Apps → <app name> → Logs
- Agent logs: Apps → infisical-agent → Logs
- [TROUBLESHOOTING.md](../../.github/TROUBLESHOOTING.md) for common issues
