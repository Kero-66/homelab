# Arr Stack & Downloaders Deployment Guide

Complete guide for migrating the *arr applications and download clients from workstation to TrueNAS Scale.

## ⚠️ Configuration Safety Guarantee

**This migration preserves ALL your existing setup - nothing will be lost!**

### What's Protected:
- ✅ **All Service Configurations**: Database files, settings, API keys copied intact
- ✅ **Complete Media Libraries**: Series/movie libraries migrated (metadata, watched status, quality profiles)
- ✅ **All Indexer Settings**: Prowlarr indexers with API keys preserved
- ✅ **Download Queue State**: qBittorrent and SABnzbd queues maintained
- ✅ **Custom Settings**: Quality profiles, language preferences, automation rules, release profiles
- ✅ **Working Connections**: Service integrations remain configured

### How Safety is Ensured:
1. **Backup Created First**: `~/arr_configs_backup_<timestamp>.tar.gz` before any migration
2. **Copy Not Move**: All configs copied from workstation (originals untouched)
3. **Media Files Safe**: rsync copies data without deleting source
4. **Workstation Stays Running**: Original services keep working during migration
5. **Rollback Available**: Can restart workstation services anytime

### What Changes:
- ⚙️ **Service URLs**: Some internal service URLs may need updating to TrueNAS container names
- ⚙️ **Secrets Source**: API keys/passwords fetched from Infisical (centrally managed)
- ⚙️ **Container Networking**: Services reference each other by Docker container names

### What Doesn't Change:
- ✅ Your series library and tracking (all downloaded episodes, quality, metadata)
- ✅ Your movie library and tracking (all downloaded movies, quality, metadata)
- ✅ Your quality profiles and preferences (exact same settings)
- ✅ Your indexer configurations (all indexers with API keys)
- ✅ Your automation rules (Recyclarr, Cleanuparr configs)
- ✅ Your watched/unwatched status and custom tags

**Bottom line:** Nothing is lost. Everything is copied. Workstation configs untouched. You can verify and rollback anytime.

---

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
ssh kero66@192.168.20.22 "du -sh /mnt/Data/media/*"
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

### 3. Config Backup (Automatic)
The deployment script will automatically:
- Create backup: `~/arr_configs_backup_<timestamp>.tar.gz`
- Copy ALL configs from workstation to TrueNAS
- Set correct ownership (1000:1000) on all files
- Preserve all settings, databases, and queues

**No manual backup needed** - the script handles everything!

## 🚀 Deployment Steps

### Step 1: Run Migration Script

The script will automatically handle EVERYTHING:
- ✅ Create backup of all your configs first
- ✅ Upload Infisical templates for secret rendering
- ✅ Update Infisical Agent configuration  
- ✅ **Copy ALL existing configurations to TrueNAS** (Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr, Cleanuparr, qBittorrent, SABnzbd)
- ✅ Create service config directories
- ✅ Set correct ownership (1000:1000) on all files

```bash
cd /mnt/library/repos/homelab
bash truenas/scripts/deploy_new_stacks.sh
```

Expected output:
```
[INFO] === Uploading Infisical Templates ===
[OK] Uploaded arr-stack.tmpl
[OK] Uploaded downloaders.tmpl
[OK] Uploaded tailscale.tmpl
[INFO] === Updating Infisical Agent Configuration ===
[OK] Updated agent-config.yaml on TrueNAS
[INFO] === Migrating Existing Service Configurations ===
[INFO] Creating backup of workstation configs...
[OK] Backup created: /home/kero66/arr_configs_backup_20260211_143022.tar.gz
[INFO] Copying prowlarr config...
[INFO] Copying sonarr config...
[INFO] Copying radarr config...
[INFO] Copying bazarr config...
[INFO] Copying qbittorrent config...
[INFO] Copying sabnzbd config...
[OK] All configurations migrated and ownership fixed
```

**Save your backup path!** You'll see it in the output for rollback if needed.

### Step 2: Run Verification Script

Confirm everything migrated correctly:

```bash
bash truenas/scripts/verify_migration.sh
```

This comprehensive check verifies:
- ✅ All service config directories exist on TrueNAS
- ✅ Key configuration files present (config.xml, databases, etc.)
- ✅ File ownership correct (1000:1000)
- ✅ File counts (so you know data actually copied)
- ✅ .env files generated by Infisical Agent
- ✅ Media paths accessible

Expected output:
```
[✓] Checking prowlarr...
[✓]   Directory exists: /mnt/Fast/docker/prowlarr
[✓]   Key file found: config.xml
[✓]   Ownership correct: 1000:1000
[✓]   Files migrated: 42

[✓] Checking sonarr...
[✓]   Directory exists: /mnt/Fast/docker/sonarr
[✓]   Key file found: config.xml
[✓]   Ownership correct: 1000:1000
[✓]   Files migrated: 138

... (similar for all services)

[✓] All critical configurations verified successfully!
```

If any issues are found, the script will show exactly what's missing.

### Step 3: Restart Infisical Agent

1. Open TrueNAS Web UI: https://192.168.20.22
2. Navigate to **Apps**
3. Find **infisical-agent** app
4. Click **⋮** → **Restart**
5. Wait 1-2 minutes for agent to start and render .env files

### Step 4: Verify .env Files Generated

```bash
# Check .env files exist
ssh kero66@192.168.20.22 'ls -la /mnt/Fast/docker/{arr-stack,downloaders,tailscale}/.env'

# Verify content (redacted)
ssh kero66@192.168.20.22 'head -5 /mnt/Fast/docker/arr-stack/.env'
```

Expected output:
```
# Arr stack secrets - rendered by Infisical Agent
# DO NOT EDIT - this file is auto-generated every 5 minutes
...
SONARR_API_KEY=...
```

### Step 4a: One More Configuration Check

Now that configs are migrated and .env files exist, do one final check:

```bash
# Check Sonarr config migrated (should see database files, config.xml, etc.)
ssh kero66@192.168.20.22 'ls -la /mnt/Fast/docker/sonarr/'

# Check Radarr config
ssh kero66@192.168.20.22 'ls -la /mnt/Fast/docker/radarr/'

# Check Prowlarr config
ssh kero66@192.168.20.22 'ls -la /mnt/Fast/docker/prowlarr/'

# Check qBittorrent config and queue
ssh kero66@192.168.20.22 'ls -la /mnt/Fast/docker/qbittorrent/'

# Verify ownership is correct (should be 1000:1000)
ssh kero66@192.168.20.22 'ls -ld /mnt/Fast/docker/sonarr'
```

**What should be preserved:**
- ✅ Sonarr: Series library, quality profiles, indexers, download clients
- ✅ Radarr: Movie library, quality profiles, indexers, download clients
- ✅ Prowlarr: All indexer configurations with API keys
- ✅ Bazarr: Language preferences, subtitle providers, service connections
- ✅ qBittorrent: Download queue, categories, settings (password from Infisical)
- ✅ SABnzbd: Server configs, queue, categories (API key from Infisical)
- ✅ Recyclarr: TRaSH Guides sync configuration

### Step 3b: Run Verification Script

Confirm everything migrated correctly:

```bash
bash truenas/scripts/verify_migration.sh
```

This checks:
- All service config directories exist
- Key configuration files present (config.xml, config.yaml, etc.)
- File ownership correct (1000:1000)
- .env files generated by Infisical Agent
- Media paths accessible

Expected output:
```
[✓] prowlarr: Directory exists, key file found, ownership correct
[✓] sonarr: Directory exists, key file found, ownership correct
[✓] radarr: Directory exists, key file found, ownership correct
...
[✓] All critical configurations verified successfully!
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
ssh kero66@192.168.20.22 'cat /mnt/Fast/docker/tailscale/.env | grep TS_AUTHKEY'
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

### Step 5: Configuration Migration Already Complete ✅

**The deployment script already migrated all your configurations!**

Your setup included:
- ✅ Created backup: `~/arr_configs_backup_<timestamp>.tar.gz`
- ✅ Copied all Sonarr configurations (series library, quality profiles, indexers)
- ✅ Copied all Radarr configurations (movie library, quality profiles, indexers)
- ✅ Copied all Prowlarr configurations (indexers with API keys)
- ✅ Copied all Bazarr configurations (language preferences, providers)
- ✅ Copied all Recyclarr configurations (TRaSH Guides settings)
- ✅ Copied all Cleanuparr configurations (cleanup rules)
- ✅ Set correct ownership (1000:1000) on all configs

**Nothing was lost - everything is preserved!**

If you need to verify or re-copy any service:
```bash
# Example: Re-copy Sonarr config if needed
scp -r media/sonarr/* kero66@192.168.20.22:/mnt/Fast/docker/sonarr/
ssh kero66@192.168.20.22 "chown -R 1000:1000 /mnt/Fast/docker/sonarr"
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

### Step 7: Downloader Configuration Already Migrated ✅

**The deployment script already migrated downloader configurations!**

Your setup included:
- ✅ qBittorrent: Download queue, categories, save paths, upload/download limits
- ✅ SABnzbd: Usenet servers, download queue, categories, category paths
- ✅ Set correct ownership (1000:1000) on both configs

**Important:** Login credentials come from Infisical (not config files):
- qBittorrent uses: `QBITTORRENT_USER` and `QBITTORRENT_PASS` from `.env`
- SABnzbd uses: `SABNZBD_API_KEY` from `.env`

If you need to re-copy:
```bash
# Example: Re-copy qBittorrent config
scp -r media/qbittorrent/* kero66@192.168.20.22:/mnt/Fast/docker/qbittorrent/
ssh kero66@192.168.20.22 "chown -R 1000:1000 /mnt/Fast/docker/qbittorrent"
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
ssh kero66@192.168.20.22 "ls -la /mnt/Fast/docker/recyclarr/config/"

# Run sync manually (one-time)
ssh kero66@192.168.20.22 "docker exec recyclarr recyclarr sync"
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
2. Verify templates uploaded: `ssh kero66@192.168.20.22 "ls /mnt/Fast/docker/infisical-agent/config/*.tmpl"`
3. Verify secrets exist in Infisical
4. Restart agent and wait 2 minutes

### Service Can't Read .env File

**Symptom:** Service fails with "environment variable not set"

**Fix:**
```bash
# Check .env file exists and is readable
ssh kero66@192.168.20.22 "ls -la /mnt/Fast/docker/<stack>/.env"

# Check file is not empty
ssh kero66@192.168.20.22 "wc -l /mnt/Fast/docker/<stack>/.env"

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
ssh kero66@192.168.20.22 "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Check logs
ssh kero66@192.168.20.22 "docker logs sonarr --tail 50"
ssh kero66@192.168.20.22 "docker logs radarr --tail 50"
ssh kero66@192.168.20.22 "docker logs qbittorrent --tail 50"

# Check resource usage
ssh kero66@192.168.20.22 "docker stats --no-stream"
```

## 🎯 Next Steps

After successful deployment:

1. ✅ **Stop workstation services:** `docker compose -f media/compose.yaml down`
2. ✅ **Update Homepage:** Point widgets to TrueNAS IPs
3. ✅ **Update Caddy:** (if applicable) Point reverse proxy to TrueNAS
4. ✅ **Test remote access:** Via Tailscale from external network
5. ✅ **Monitor for 24-48 hours:** Ensure stability and downloads work
6. ✅ **Backup TrueNAS configs:** `ssh kero66@192.168.20.22 "tar czf /tmp/configs_backup.tar.gz /mnt/Fast/docker/"`

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
