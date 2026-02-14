# TrueNAS System Configuration - Beelink Mini S Pro

**Date**: 2026-02-11  
**System**: truenas (192.168.20.22)  
**Version**: TrueNAS Scale 25.10.1  
**Uptime**: 26+ hours  
**Timezone**: Australia/Brisbane

---

## Hardware Configuration

### Storage Drives

#### NVMe SSDs (3x ~1TB each)
| Device | Model | Serial | Size | Status |
|--------|-------|--------|------|--------|
| nvme0n1 | Lexar SSD NQ780 1TB | QBG1264114244P2237 | 953 GB | **In Pool "Fast"** |
| nvme1n1 | YMTC PC41Q-1TB-B | YMA61T0RA25370146E | 953 GB | **Boot Drive (OS)** |
| nvme2n1 | Lexar SSD NQ780 1TB | QBG1264113532P2237 | 953 GB | **In Pool "Fast"** |

**Total NVMe capacity for pools**: ~1.9 TB (2x 953 GB in Fast pool)  
**Boot pool capacity**: ~953 GB (nvme1n1 - TrueNAS OS)

#### HDDs (2x 8TB each)
| Device | Model | Serial | Size | Status |
|--------|-------|--------|------|--------|
| sda | WDC WD80EFPX-68C4ZN0 | WD-RD3PKMMG | 7452 GB | **In Pool "Data"** |
| sdb | WDC WD80EFPX-68C4ZN0 | WD-RD3PBYGG | 7452 GB | **In Pool "Data"** |

**Total HDD capacity**: ~14.5 TB (2x 7.45 TB)

### Network Interfaces

| Interface | Status | IP Addresses |
|-----------|--------|--------------|
| enp2s0 | UP (active) | *None configured* |
| enp3s0 | DOWN | None |

---

## Current Storage Configuration

### Existing Pool: "Data"

**Configuration:**
- Type: MIRROR (2-drive mirror)
- Devices: sda + sdb (both 8TB HDDs)
- Status: ONLINE ✓
- Health: Healthy ✓
- Mount: /mnt/Data
- Usable capacity: ~7.45 TB (50% of 14.9 TB raw)

**Characteristics:**
- ✅ **Redundancy**: Can lose 1 drive without data loss
- ✅ **Performance**: Good read performance
- ✅ **Reliability**: Excellent for bulk storage
- ⚠️ **Capacity**: 50% efficiency (expected for mirror)

---

## Storage Pools Configuration

### Pool 1: "Data" (HDD Mirror) ✅ ONLINE

**Purpose**: Bulk media storage  
**Devices**: 2x 8TB HDD (sda + sdb) in MIRROR  
**Capacity**: 7.45 TB usable  
**Status**: Configured and operational ✓

**Datasets:**
```
Data/
├── media/
│   ├── movies/      # Jellyfin movies library
│   ├── shows/       # Jellyfin TV shows library
│   └── music/       # Jellyfin music library
├── downloads/
│   ├── complete/    # Completed downloads
│   └── incomplete/  # In-progress downloads
└── backups/         # Backup storage
```

**Settings:**
- Record size: 1M (for large video files)
- Compression: LZ4
- Atime: off

### Pool 2: "Fast" (NVMe Mirror) ✅ ONLINE

**Purpose**: Fast storage for apps, containers, databases  
**Devices**: 2x 1TB NVMe (nvme0n1 + nvme2n1) in MIRROR  
**Capacity**: 953 GB usable  
**Status**: Configured and operational ✓

**Note**: nvme1n1 is the **boot drive** (TrueNAS OS) and is NOT available for pools.

**Datasets:**
```
Fast/
├── docker/
│   ├── jellyfin/     # Jellyfin config
│   ├── sonarr/       # Sonarr config
│   ├── radarr/       # Radarr config
│   ├── prowlarr/     # Prowlarr config
│   ├── bazarr/       # Bazarr config
│   ├── qbittorrent/  # qBittorrent config
│   ├── jellyseerr/   # Jellyseerr config
│   └── fileflows/    # FileFlows config
└── databases/
    └── jellystat/    # Jellystat PostgreSQL data
```

**Settings:**
- Record size: 128K (for containers/databases)
- Compression: LZ4
- Atime: off
- Sync: standard

---

## Services Status

| Service | Status | Auto-Start |
|---------|--------|------------|
| SMB (CIFS) | ✅ RUNNING | Enabled |
| NFS | ✅ RUNNING | Enabled |
| SSH | ❌ STOPPED | Disabled |

**Notes:**
- SMB is active for Windows/Mac file sharing
- NFS is active for Linux Docker host access
- SSH disabled for security (use Web UI for management)

---

## NFS Shares (For Docker Host)

| Share Path | Mount Point | Description | Access |
|------------|-------------|-------------|--------|
| 192.168.20.22:/mnt/Data/media | /data/media | Media files | kero66 (1000:1000) |
| 192.168.20.22:/mnt/Data/downloads | /data/downloads | Download directory | kero66 (1000:1000) |
| 192.168.20.22:/mnt/Fast/docker | /docker-configs | Container configs | kero66 (1000:1000) |

**Network**: 192.168.20.0/24 (local network only)

---

## User Accounts

| Username | UID | GID | Purpose | Location |
|----------|-----|-----|---------|----------|
| truenas_admin | 950 | system | Emergency admin (break-glass) | Infisical: /TrueNAS/truenas_admin |
| kero66 | 1000 | 1000 | Daily operations (Docker PUID/PGID) | Infisical: /TrueNAS/kero66_password |

**Security Note**: Use kero66 for all container operations. Only use truenas_admin for emergency access.

---

## Original Analysis (Historical)

### Before Configuration

This section preserved for historical reference.

**Datasets to create:**
```
Fast/
├── docker/
│   ├── jellyfin/     # Jellyfin config & metadata
│   ├── sonarr/       # Sonarr config
│   ├── radarr/       # Radarr config
│   ├── prowlarr/     # Prowlarr config
│   ├── bazarr/       # Bazarr config
│   ├── qbittorrent/  # qBittorrent config
│   └── jellyseerr/   # Jellyseerr config
├── databases/        # PostgreSQL, Redis, etc.
│   └── jellystat/    # Jellystat database
└── apps/             # Other app configurations
```

**Optimal settings:**
- Record size: 128K (default, good for configs)
- Record size: 16K (for databases/ dataset)
- Compression: LZ4
- Atime: off

---

## Migration Strategy for Jellyfin Stack

### Current Setup Analysis

Your Jellyfin stack includes:
- Jellyfin (media server)
- Sonarr, Radarr, Lidarr (media automation)
- Prowlarr (indexer manager)
- Bazarr (subtitles)
- qBittorrent (downloads)
- Jellyseerr (request management)
- Jellystat (statistics - uses PostgreSQL)

### Recommended Layout on TrueNAS

| Service | Storage Location | Why |
|---------|------------------|-----|
| **Media files** | Data/media/ | HDD mirror - large capacity for media |
| **Downloads** | Data/downloads/ | HDD mirror - large temporary files |
| **Jellyfin config** | Fast/docker/jellyfin/ | NVMe - fast metadata/database access |
| **Sonarr/Radarr/etc** | Fast/docker/ | NVMe - fast config/database access |
| **Jellystat DB** | Fast/databases/jellystat/ | NVMe - fast database I/O |

### Performance Benefits

- **Jellyfin metadata/thumbnails**: NVMe = instant library browsing
- **Arr app databases**: NVMe = fast searches and queue processing
- **Media playback**: HDD is plenty fast for video streaming
- **Downloads**: HDD has space for large files

---

## Next Steps

### Phase 1: Create Fast Pool (NVMe) ✅ Ready

```bash
# SSH into TrueNAS (enable SSH service first)
ssh kero66@192.168.20.22

# Or use the web UI: Storage → Create Pool
# - Name: Fast
# - Layout: Mirror
# - Devices: nvme0n1 + nvme1n1
# - Spare: nvme2n1
```

### Phase 2: Create Datasets ✅ Ready

Use the setup script or web UI to create datasets:

**On Data pool (HDD):**
- Data/media/movies (record size: 1M)
- Data/media/shows (record size: 1M)
- Data/media/music (record size: 256K)
- Data/downloads/complete (record size: 1M)
- Data/downloads/incomplete (record size: 1M)
- Data/backups (record size: 1M)

**On Fast pool (NVMe):**
- Fast/docker/* (record size: 128K)
- Fast/databases (record size: 16K)

### Phase 3: Configure Network Shares 📡

**Enable NFS** (recommended for Linux Docker host):
1. System Settings → Services → NFS → Enable
2. Create NFS shares for:
   - /mnt/Data/media → export to your Docker host
   - /mnt/Data/downloads → export to your Docker host
   - /mnt/Fast/docker → export to your Docker host

**SMB already enabled** ✓ (for Windows/Mac access)

### Phase 4: Migrate Jellyfin Stack 🚀

1. **Backup current setup** (on existing host)
2. **Mount TrueNAS shares** on Docker host (via NFS or run Docker on TrueNAS directly)
3. **Update docker-compose.yml** paths:
   ```yaml
   DATA_DIR=/mnt/Data/media
   CONFIG_DIR=/mnt/Fast/docker
   ```
4. **Start services** and verify

---

## Performance Considerations

### This Configuration is Excellent For:

✅ **Jellyfin transcoding** - NVMe for metadata, HDD for source media  
✅ **Multiple concurrent streams** - Mirror provides good read performance  
✅ **Arr app operations** - Fast SQLite databases on NVMe  
✅ **Downloads** - Plenty of HDD space  
✅ **Data safety** - Both pools are mirrored (redundant)

### Bottlenecks to Watch:

⚠️ **Network**: Gigabit Ethernet = ~125 MB/s maximum  
- 4K remux files can saturate this
- Consider 2.5GbE or 10GbE upgrade if needed

⚠️ **HDD write speed**: ~150-200 MB/s sustained  
- Fine for downloads and streaming
- Not ideal for random I/O (hence NVMe for databases)

---

## Monitoring Recommendations

### Regular Checks:

- **Pool health**: Dashboard → Storage
- **Scrub schedule**: Monthly (already automatic)
- **Disk SMART**: Check for failing drives
- **Capacity**: Keep pools below 80% full

### Alerts to Enable:

- Drive failures
- Pool degraded
- High temperature
- Low disk space

---

## Backup Strategy

### What to Backup:

**Critical** (must backup):
- Fast/docker/* - All container configs
- Fast/databases/* - Jellystat and other DBs

**Optional** (nice to have):
- Data/media/* - Media is replaceable (can re-download)
- Metadata only (Jellyfin libraries, posters, etc.)

### Backup Methods:

1. **ZFS Snapshots** (built-in):
   - Hourly snapshots of Fast pool (keep 24)
   - Daily snapshots of Data pool (keep 7)
   - Weekly snapshots (keep 4)

2. **Cloud Sync** (optional):
   - Fast/docker → Backblaze B2 / AWS S3
   - Encrypted before upload

3. **Replication** (if you have second TrueNAS):
   - Replicate snapshots to second system
   - Best option for disaster recovery

---

## Summary

### ✅ What You Have

- **TrueNAS Scale 25.10.1** - Latest stable version
- **5 drives total**: 3x 1TB NVMe + 2x 8TB HDD
- **1 pool configured**: "Data" (2x 8TB HDD mirror) = 7.45 TB usable
- **3 NVMe available**: Ready for fast pool
- **SMB enabled**: Ready for file sharing
- **API authenticated**: Ready for automation

### 🔨 What to Create

- **Fast pool**: 2x NVMe mirror (953 GB usable) + 1 hot spare
- **Datasets**: Organized structure for media/downloads/docker/databases
- **NFS shares**: For Docker host mounting
- **Snapshots**: Automated backup protection

### 🚀 Ready to Migrate

Your Jellyfin stack can now be migrated to TrueNAS with:
- Fast NVMe storage for configs/databases
- Large HDD storage for media
- Redundancy on both pools
- Excellent performance for streaming

---

*Collected: 2026-02-11*  
*TrueNAS: 192.168.20.22*  
*Status: ✅ Ready for pool creation and migration*
