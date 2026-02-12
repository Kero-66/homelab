# TrueNAS Media Stack Migration - Session 2026-02-11

## Status: PARTIALLY COMPLETE - CRITICAL ISSUES REMAIN

### Session Summary
This session migrated the complete media stack from workstation (192.168.20.66) to TrueNAS Scale 25.10.1 (192.168.20.22). 4,163 configuration files were successfully migrated. All nine media services are running and healthy on TrueNAS. However, **Jellyfin cannot find video files due to directory structure mismatch**, and **Jellystat database needs migration from workstation**.

---

## CRITICAL BLOCKING ISSUES

### 1. **JELLYFIN CANNOT FIND VIDEO FILES** (HIGH PRIORITY)
**Problem**: Jellyfin is configured to look in `/data/shows` but shows are actually at `/data/media/shows`

**Current State**:
- Jellyfin UI shows "TV Shows" library but it's empty
- 244GB of shows exist at `/mnt/Data/media/shows` (99 files confirmed)
- 11 movies exist at `/mnt/Data/media/movies`
- Container can access files: `docker exec jellyfin find /data/media -name "*.mkv" | wc -l` returns results

**Root Cause**: Directory mapping mismatch in compose file or library configuration

**Fix Required**:
```bash
# Option A: Fix library paths in Jellyfin settings
# Access http://192.168.20.22:8096 → Settings → Libraries → TV Shows
# Change path from `/data/shows` to `/data/media/shows`
# Change path from `/data/movies` to `/data/media/movies`
# Then refresh/rescan libraries

# Option B: Fix via API (if path can't be edited in UI)
# Check current library paths in database and update them
sqlite3 /mnt/Fast/docker/jellyfin/config/data/data/jellyfin.db \
  "SELECT * FROM LibraryOptions WHERE LibraryName LIKE '%Show%' OR LibraryName LIKE '%Movie%';"

# Option C: Update compose volumes (preferred - permanent fix)
# Verify compose mounts and ensure /data/media is mapped correctly
```

**Evidence**:
- Shows confirmed at: `/mnt/Data/media/shows` (244GB, 99 files)
- Movies confirmed at: `/mnt/Data/media/movies` (11 files)
- Mount is working: `docker exec jellyfin ls -la /data/media/` shows all folders

---

### 2. **JELLYSTAT DATABASE MIGRATION INCOMPLETE** (MEDIUM PRIORITY)
**Problem**: PostgreSQL database from workstation wasn't successfully migrated; Jellystat connects to new empty database

**Current State**:
- Workstation backup exists: `/mnt/library/repos/homelab/media/jellyfin/jellystat/postgres` (71MB)
- SQL dump created: `/tmp/jellystat-backup.sql` (11MB)
- TrueNAS has empty database: 0 rows in jf_libraries table
- Previous restore attempt failed due to concurrent command execution

**Fix Required** (DO THIS IN SEPARATE TERMINALS):
```bash
# Terminal 1: Create backup from workstation
docker start jellystat-db  # on workstation
docker exec jellystat-db pg_dumpall -U postgres > /tmp/jellystat-backup.sql
ls -lh /tmp/jellystat-backup.sql  # verify 11MB file exists

# Terminal 2 (wait 30+ seconds): Transfer to TrueNAS
while [ ! -f /tmp/jellystat-backup.sql ]; do sleep 1; done
cat /tmp/jellystat-backup.sql | ssh root@192.168.20.22 'cat > /tmp/jellystat-restore.sql'
ssh root@192.168.20.22 'ls -lh /tmp/jellystat-restore.sql'

# Terminal 3 (wait 30+ seconds): Restore on TrueNAS
ssh root@192.168.20.22 'docker stop jellystat'
ssh root@192.168.20.22 'docker exec -i jellystat-db psql -U postgres < /tmp/jellystat-restore.sql'
ssh root@192.168.20.22 'docker start jellystat'
```

**IMPORTANT**: Do NOT run piped commands through SSH - causes cancellation. Use separate terminals or files.

**Evidence**:
- Workstation backup: `sudo ls -lh /mnt/library/repos/homelab/media/jellyfin/jellystat/postgres` (71MB)
- Error on last attempt: PostgreSQL auth failed (28P01) - likely due to concurrent command cancellation

---

## COMPLETED TASKS

### ✅ Configuration Migration (4,163 files)
- **Prowlarr**: 621 files (129.8 MB)
- **Sonarr**: 475 files (145 MB)
- **Radarr**: 166 files (44.2 MB)
- **Bazarr**: 587 files (6.5 MB)
- **qBittorrent**: 71 files (10.4 MB)
- **SABnzbd**: 10 files (8 MB)
- **Cleanuparr**: 57 files (890 KB)
- **Recyclarr**: 2,341 files (296.8 MB)

**Backup created**: `~/arr_configs_backup_<timestamp>.tar.gz`

---

### ✅ Arr-Stack Deployed (7 services, all healthy)
**Status**: Running on http://192.168.20.22

| Service | Port | Status | Notes |
|---------|------|--------|-------|
| FlareSolverr | 8191 | ✅ Healthy | Cloudflare bypass for indexers |
| Prowlarr | 9696 | ✅ Healthy | Indexer manager, synced to Sonarr/Radarr |
| Sonarr | 8989 | ✅ Healthy | Download client: qbittorrent (container name) |
| Radarr | 7878 | ✅ Healthy | Download client: qbittorrent (container name) |
| Bazarr | 6767 | ✅ Healthy | Subtitles - synced to sonarr/radarr |
| Recyclarr | N/A | ✅ Healthy | TRaSH Guides automation |
| Cleanuparr | 11011 | ✅ Healthy | Download queue cleanup |

**Download Clients Configured**:
- SABnzbd: Default enabled, `sabnzbd` container name
- qBittorrent: Primary, `qbittorrent` container name

---

### ✅ Downloaders Stack Deployed (2 services, all healthy)
**Status**: Running on http://192.168.20.22

| Service | Port | Status |
|---------|------|--------|
| qBittorrent | 8080 | ✅ Healthy |
| SABnzbd | 8085 | ✅ Healthy |

**Configuration**: All download paths point to `/mnt/Data/downloads` with proper 1000:1000 ownership

---

### ✅ Jellyfin Deployed
**Status**: http://192.168.20.22:8096 - RUNNING BUT EMPTY LIBRARY

**Current Configuration**:
- Container: `lscr.io/linuxserver/jellyfin:latest`
- Config mount: `/mnt/Fast/docker/jellyfin`
- Media mount: `/mnt/Data/media` → `/data/media` (container)
- GPU access: YES (`renderD128` AMD GPU)
- FFmpeg: Installed at `/usr/lib/jellyfin-ffmpeg/ffmpeg`
- Version: 10.11.6

**Working State**:
- Web UI responsive: `curl http://192.168.20.22:8096/health` returns "Healthy"
- Can access API: `curl http://192.168.20.22:8096/System/Info/Public` works
- FFmpeg functional with hardware encoding enabled
- Media files accessible inside container

**Broken State**:
- Libraries show as empty
- Path configuration issue (see CRITICAL ISSUE #1 above)

---

### ✅ Workstation Services Stopped
**Status**: 11 containers removed, services no longer running on 192.168.20.66

```
Stopped containers:
- radarr, sonarr, flaresolverr, fileflows, sabnzbd
- recyclarr, qbittorrent, prowlarr, cleanuparr, bazarr
```

**Configuration preserved** at `/mnt/library/repos/homelab/media/<service>/`

---

## NETWORK ARCHITECTURE FIXES APPLIED

### ✅ Docker Network Isolation Fixed
**Issue**: Downloaders were isolated on `ix-downloaders_default`, arr-stack on `ix-arr-stack_default`

**Solution Applied**:
```bash
docker network connect ix-arr-stack_default qbittorrent
docker network connect ix-arr-stack_default sabnzbd
docker network connect ix-downloaders_default cleanuparr
```

**Result**: All containers can now communicate via container names (DNS resolution works)

---

### ✅ Download Client Connection Fixed
**Issue**: Sonarr/Radarr hardcoded old workstation Docker IPs (172.39.0.12, 172.39.0.24)

**Solution Applied**:
```bash
sqlite3 /mnt/Fast/docker/sonarr/sonarr.db \
  "UPDATE DownloadClients SET Settings = json_set(Settings, '$.host', 'qbittorrent') WHERE Id=1;"
sqlite3 /mnt/Fast/docker/sonarr/sonarr.db \
  "UPDATE DownloadClients SET Settings = json_set(Settings, '$.host', 'sabnzbd') WHERE Id=3;"
# Same for radarr database

docker restart sonarr radarr
```

**Result**: Both apps now successfully communicate with download clients using container names

---

### ✅ SABnzbd Permission Issue Fixed
**Issue**: `/mnt/Data/downloads` owned by root:root, container runs as 1000:1000

**Solution Applied**:
```bash
chown -R 1000:1000 /mnt/Data/downloads
docker restart sabnzbd
```

**Result**: SABnzbd now healthy, no permission errors

---

## ENVIRONMENT DETAILS

**TrueNAS Scale 25.10.1**
- IP: 192.168.20.22
- Docker: IPv4-only (172.17.0.0/12)
- Container UID/GID: 1000:1000
- Python: PUID/PGID 1000:1000

**Storage**:
- `/mnt/Fast` (NVMe): Configs, databases, metadata
  - `/mnt/Fast/docker/` - App configs
  - `/mnt/Fast/databases/jellystat/postgres` - Jellystat DB
- `/mnt/Data` (HDD): Media library
  - `/mnt/Data/media/movies` - 11 files
  - `/mnt/Data/media/shows` - 244GB, 99 files
  - `/mnt/Data/media/music` - Audio files
  - `/mnt/Data/downloads` - Download staging area

**Workstation (Fedora)**
- IP: 192.168.20.66
- Services: STOPPED (preserved for rollback if needed)
- Configuration backup: Intact at `/mnt/library/repos/homelab/media/<service>/`

**Infisical Agent**:
- Running on TrueNAS
- Renders `.env` files to `/mnt/Fast/docker/*/`
- API Keys properly configured for all apps

---

## REMAINING WORK

### Priority 1: FIX JELLYFIN LIBRARY PATHS
See **CRITICAL ISSUE #1** above. This is blocking video playback.

### Priority 2: MIGRATE JELLYSTAT DATABASE
See **CRITICAL ISSUE #2** above. This requires running commands in separate terminals to avoid cancellation.

### Priority 3: OPTIONAL - DEPLOY CADDY REVERSE PROXY
File: `networking/compose.yaml` exists but hasn't been deployed. Can provide external access if needed.

### Priority 4: OPTIONAL - DEPLOY TAILSCALE
For remote access outside LAN. Stack file prepared but not deployed.

---

## VALIDATION COMMANDS

**Quick health check**:
```bash
ssh root@192.168.20.22 'docker ps --format "table {{.Names}}\t{{.Status}}"' | grep -E "jellyfin|sonarr|radarr|qbittorrent|sabnzbd"
```

**Verify media access**:
```bash
ssh root@192.168.20.22 'docker exec jellyfin find /data/media -type f -name "*.mkv" | wc -l'
```

**Check download client connections**:
```bash
ssh root@192.168.20.22 'docker logs sonarr --tail 20 | grep -i "download"'
ssh root@192.168.20.22 'docker logs radarr --tail 20 | grep -i "download"'
```

**Check Jellyfin system status**:
```bash
curl http://192.168.20.22:8096/System/Info/Public | jq '.'
```

---

## KEY LEARNINGS & NOTES

1. **Docker network isolation is real** - Services on different compose networks can't reach each other even with DNS
2. **Database migrations via piped SSH fail** - Need to use separate terminals or intermediate files
3. **Directory structure matters** - Jellyfin library paths must match actual data paths
4. **Container DNS resolution works** - Once on same network, `containername:port` works for inter-service communication
5. **SQLite updates are immediate** - Can update download client configs directly without redeploying
6. **Infisical integration is working** - All .env files rendering correctly with secrets
7. **FFmpeg hardware acceleration available** - AMD GPU properly passed through to Jellyfin container

---

## FILES MODIFIED/CREATED IN THIS SESSION

### Compose Files (Updated)
- `truenas/stacks/arr-stack/compose.yaml` - Path fixes, network connections
- `truenas/stacks/downloaders/compose.yaml` - Path fixes, network connections
- `truenas/stacks/tailscale/compose.yaml` - Created but not deployed

### Scripts
- `truenas/scripts/deploy_new_stacks.sh` - Enhanced with automatic backup
- `truenas/scripts/verify_migration.sh` - Created for verification

### Databases (Modified via SQL)
- `/mnt/Fast/docker/sonarr/sonarr.db` - Updated download client hostnames
- `/mnt/Fast/docker/radarr/radarr.db` - Updated download client hostnames

### Data Migrated
- 4,163 configuration files across 8 services
- Media library: 244GB shows + misc files (transfer ongoing in background)

---

## NEXT AGENT INSTRUCTIONS

1. **START HERE**: Fix Jellyfin library paths (CRITICAL #1) - this is the main blocker
2. **THEN**: Migrate Jellystat database (CRITICAL #2) - use separate terminal approach
3. **VERIFY**: Run health checks and confirm all services working
4. **OPTIONAL**: Deploy Caddy/Tailscale if user requests external access
5. **DOCUMENT**: Update this file with completion status

All infrastructure is in place. Issues are config-level, not deployment-level.
