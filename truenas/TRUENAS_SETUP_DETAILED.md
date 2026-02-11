# TrueNAS Scale Setup Guide for Beelink Mini S Pro

## Hardware Overview

**Beelink Mini S Pro** - Compact NAS system ideal for home lab media server

This guide covers the complete setup process for TrueNAS Scale on your Beelink Mini S Pro, including:
- Drive configuration and pool setup
- Best practices for ZFS
- Network share configuration (SMB/NFS)
- Container migration from existing setup
- Jellyfin and media stack deployment

---

## Table of Contents

1. [Initial TrueNAS Configuration](#initial-truenas-configuration)
2. [Storage Pool Setup](#storage-pool-setup)
3. [Dataset Configuration](#dataset-configuration)
4. [Network Shares (SMB/NFS)](#network-shares-smbnfs)
5. [Apps/Container Setup](#appscontainer-setup)
6. [Jellyfin Stack Migration](#jellyfin-stack-migration)
7. [Best Practices](#best-practices)
8. [Backup Strategy](#backup-strategy)

---

## Initial TrueNAS Configuration

### First Boot Setup

1. **Access TrueNAS Web UI**
   - Default URL: `http://truenas.local` or `http://<IP-ADDRESS>`
   - Complete the initial setup wizard
   - Set admin password (store in password manager)
   - Configure timezone: `Australia/Brisbane` (or your timezone)

2. **System Settings**
   - Navigate to **System Settings → General**
   - Set hostname: `truenas-mini` (or your preference)
   - Set timezone and locale
   - Enable NTP for time synchronization

3. **Network Configuration**
   - Navigate to **Network**
   - Set static IP address (recommended for NAS)
   - Example: `10.0.0.50/24` with gateway `10.0.0.1`
   - Configure DNS servers (e.g., `1.1.1.1`, `8.8.8.8`)

4. **Update System**
   - Navigate to **System Settings → Update**
   - Check for updates and apply latest patches
   - Reboot if required

---

## Storage Pool Setup

### Understanding ZFS Pools

TrueNAS uses ZFS, which provides:
- Data integrity verification
- Snapshots and replication
- Compression
- RAID-like redundancy

### Recommended Pool Configurations

Choose based on your drive configuration in the Beelink:

#### Option 1: Mirror (2 drives - BEST for reliability)
- **Redundancy**: Can lose 1 drive
- **Capacity**: 50% of total (if 2x 4TB = 4TB usable)
- **Performance**: Good read, moderate write
- **Use case**: Primary data with redundancy

#### Option 2: RAIDZ1 (3+ drives - Good balance)
- **Redundancy**: Can lose 1 drive
- **Capacity**: (n-1) drives (if 3x 4TB = 8TB usable)
- **Performance**: Good for sequential reads
- **Use case**: Media storage

#### Option 3: RAIDZ2 (4+ drives - Best redundancy)
- **Redundancy**: Can lose 2 drives
- **Capacity**: (n-2) drives (if 4x 4TB = 8TB usable)
- **Performance**: Similar to RAIDZ1
- **Use case**: Critical data

#### Option 4: Stripe (No redundancy - NOT RECOMMENDED)
- **Redundancy**: None - any drive failure = data loss
- **Capacity**: 100%
- **Use case**: Only for temporary/cache data

### Creating Your Storage Pool

1. **Navigate to Storage**
   - Go to **Storage** in the sidebar
   - Click **Create Pool**

2. **Pool Configuration**
   - **Name**: `tank` (traditional ZFS naming for media storage)
   - **Layout**: Select your RAID type (Mirror or RAIDZ1 recommended)
   - **Encryption**: Optional (adds CPU overhead but secures data)
     - If enabled, **SAVE THE ENCRYPTION KEY** immediately
   - **Drives**: Select drives to include
   - **Ashift**: Auto (or 12 for drives with 4K sectors)

3. **Advanced Options** (recommended settings)
   - **Compression**: `LZ4` (default - minimal CPU, good space savings)
   - **Atime**: `Off` (improves performance, safe for media)
   - **Sync**: `Standard` (default)
   - **Deduplication**: `Off` (requires massive RAM - not worth it for media)

4. **Create and Confirm**
   - Review settings
   - Confirm creation (this will **WIPE all selected drives**)

---

## Dataset Configuration

Datasets are ZFS filesystems within your pool. Create organized datasets for different purposes.

### Recommended Dataset Structure

```
tank/
├── media/
│   ├── movies
│   ├── shows
│   ├── music
│   └── books
├── downloads/
│   ├── complete
│   └── incomplete
├── docker/
│   ├── jellyfin
│   ├── sonarr
│   ├── radarr
│   └── [other services]
├── backups/
└── scratch/  # temporary/expendable data
```

### Creating Datasets

1. **Navigate to Datasets**
   - Go to **Storage → Pools**
   - Click on your pool (`tank`)
   - Click **Add Dataset**

2. **Create Root Datasets**
   - Create `media` dataset:
     - Name: `media`
     - Compression: `LZ4` (inherited)
     - Record size: `1M` (optimal for large video files)
     - Case sensitivity: `Sensitive`
     - Share type: `Generic`
   
3. **Create Child Datasets**
   - Under `media`, create:
     - `movies` (record size: `1M`)
     - `shows` (record size: `1M`)
     - `music` (record size: `128K` - smaller files)
     - `books` (record size: `128K`)

4. **Create Downloads Dataset**
   - Name: `downloads`
   - Record size: `128K` (mixed file sizes)
   - Create subdirectories: `complete` and `incomplete`

5. **Create Docker Dataset**
   - Name: `docker`
   - Record size: `16K` (default - small config files)
   - **Important**: Create subdatasets for each service
   - Example: `docker/jellyfin`, `docker/sonarr`, etc.

### Dataset Permissions

Set appropriate permissions for each dataset:

1. **Create System User**
   ```bash
   # SSH into TrueNAS or use Shell
   # Note: It's better to do this via UI under Accounts → Users
   ```
   
   Via UI:
   - Go to **Accounts → Users → Add**
   - Username: `mediauser` (or your preference)
   - UID: `1000` (match your docker PUID)
   - Primary Group: Create new group `mediagroup` with GID `1000`
   - Home Directory: `/nonexistent` (not needed)
   - Disable password login (use SSH keys if needed)

2. **Set Dataset Ownership**
   - Select dataset → **Edit Permissions**
   - Owner: `mediauser`
   - Group: `mediagroup`
   - Apply permissions recursively (be careful with existing data)

---

## Network Shares (SMB/NFS)

### SMB Share (Windows/MacOS/Linux)

SMB is the most compatible option for cross-platform access.

#### Create SMB Share

1. **Navigate to Shares**
   - Go to **Shares → Windows (SMB) Shares**
   - Click **Add**

2. **Configure Share**
   - **Path**: `/mnt/tank/media` (browse to your dataset)
   - **Name**: `media`
   - **Purpose**: Default share parameters
   - **Description**: Media storage for Jellyfin/Plex
   - **Enabled**: Check

3. **Advanced Options**
   - **Access Based Share Enumeration**: Enable (users only see folders they can access)
   - **Export Read Only**: Uncheck (allow writes)
   - **Browseable to Network Clients**: Enable
   - **Guest Access**: Disable (require authentication)

4. **Repeat for Other Shares**
   - Create shares for `downloads`, `docker` as needed

#### Configure SMB Service

1. **Navigate to Services**
   - Go to **System Settings → Services**
   - Find **SMB** and click configure (pencil icon)

2. **SMB Settings**
   - **NetBIOS Name**: `TRUENAS-MINI` (or your hostname)
   - **Workgroup**: `WORKGROUP` (or your domain)
   - **Description**: TrueNAS Media Server
   - **Enable SMB1 support**: **Disabled** (security risk, only enable if you have ancient clients)
   - **NTLMv1 Auth**: **Disabled**

3. **Enable and Start Service**
   - Toggle **SMB** service to **Running**
   - Set **Start Automatically** to checked

### NFS Share (Linux/Unix - Better Performance)

NFS provides better performance for Linux systems (like your current Docker host).

#### Create NFS Share

1. **Navigate to Shares**
   - Go to **Shares → Unix (NFS) Shares**
   - Click **Add**

2. **Configure Share**
   - **Path**: `/mnt/tank/media`
   - **Description**: Media storage NFS
   - **Enabled**: Check

3. **Advanced Options**
   - **Maproot User/Group**: `mediauser` / `mediagroup`
   - **Networks**: `10.0.0.0/24` (restrict to your LAN)
   - **Hosts**: Leave empty (or specify specific IPs)

4. **Access Settings**
   - **Read Only**: Uncheck
   - Click **Add** next to Authorized Networks/Hosts
   - Add your Docker host IP: `10.0.0.100/32`

#### Configure NFS Service

1. **Navigate to Services**
   - Find **NFS** and enable it
   - Set to start automatically

---

## Apps/Container Setup

TrueNAS Scale uses Kubernetes (k3s) under the hood, but provides Docker Compose compatibility.

### Prerequisites

1. **Navigate to Apps**
   - Go to **Apps** in the sidebar
   - If first time, you'll need to **Choose Pool** for apps
   - Select your `tank` pool (or create separate SSD pool for apps if available)

2. **System Settings for Apps**
   - Navigate to **Apps → Settings**
   - **Kubernetes Settings**:
     - **Pool**: `tank` (or SSD pool if available)
     - **Node IP**: Your TrueNAS IP
   - Click **Save**

### Using Docker Compose (Recommended)

TrueNAS Scale supports Docker Compose through the "Custom App" feature.

#### Method 1: Custom App (Simple)

1. **Navigate to Apps → Discover Apps**
2. **Search for "Custom App"** or scroll down
3. **Click Install on "Custom App"**
4. You can paste your `compose.yaml` content here

#### Method 2: Docker Compose CLI (Advanced)

TrueNAS also allows direct Docker Compose usage:

1. **SSH into TrueNAS**
   ```bash
   ssh admin@truenas.local
   ```

2. **Navigate to Dataset**
   ```bash
   cd /mnt/tank/docker
   ```

3. **Clone Your Repo**
   ```bash
   git clone https://github.com/your-username/homelab.git
   cd homelab/media
   ```

4. **Configure Environment**
   ```bash
   cp .env.example .env
   nano .env
   ```
   
   Update these variables:
   ```env
   PUID=1000
   PGID=1000
   TZ=Australia/Brisbane
   DATA_DIR=/mnt/tank/media
   CONFIG_DIR=/mnt/tank/docker
   ```

5. **Start Services**
   ```bash
   docker compose up -d
   ```

---

## Jellyfin Stack Migration

### Current State Analysis

Based on your repo, you have:
- Jellyfin (media server)
- Jellyseerr (request management)
- Jellystat (statistics)
- Sonarr, Radarr, Lidarr, Prowlarr (media automation)
- Bazarr (subtitles)
- qBittorrent (downloads)

### Migration Strategy

#### Option A: Full Migration to TrueNAS (Recommended)

Run entire stack on TrueNAS using Docker Compose.

**Pros:**
- Centralized management
- Data and apps on same system
- Simplified networking
- Better performance (local storage access)

**Cons:**
- All resources from one machine
- System updates affect all services

#### Option B: Hybrid Approach

Keep compute-heavy services on separate machine, use TrueNAS for storage only.

**Pros:**
- Distribute load
- NAS focused on storage/network
- Easier to upgrade compute separately

**Cons:**
- Network overhead for data access
- More complex setup
- Need to manage two systems

### Migration Steps (Option A - Full Migration)

#### 1. Backup Current Setup

On your current system:

```bash
cd ~/repos/homelab/media
# Use the backup script from your repo
./backup.sh
# Or manual backup
tar -czf ~/jellyfin-backup-$(date +%F).tar.gz \
  jellyfin/ sonarr/ radarr/ lidarr/ prowlarr/ bazarr/ qbittorrent/
```

#### 2. Transfer Backup to TrueNAS

```bash
# From your current machine
scp jellyfin-backup-*.tar.gz admin@truenas.local:/mnt/tank/backups/
```

#### 3. Prepare TrueNAS

SSH into TrueNAS:

```bash
ssh admin@truenas.local
cd /mnt/tank/docker
```

Clone your repo:

```bash
git clone https://github.com/kieranmcjannett-coder/homelab.git
cd homelab/media
```

#### 4. Restore Configurations

```bash
# Extract backup
cd /mnt/tank/docker
tar -xzf /mnt/tank/backups/jellyfin-backup-*.tar.gz

# Or use restore script if you have one
# ./backup.sh --restore /mnt/tank/backups/jellyfin-backup-*.tar.gz
```

#### 5. Update Environment Variables

```bash
cd /mnt/tank/docker/homelab/media
cp .env.example .env
nano .env
```

Critical settings for TrueNAS:
```env
# User/Group (match TrueNAS user)
PUID=1000
PGID=1000

# Timezone
TZ=Australia/Brisbane

# Paths (TrueNAS dataset paths)
DATA_DIR=/mnt/tank/media
CONFIG_DIR=/mnt/tank/docker

# Network
SERVARR_SUBNET=172.39.0.0/24

# Service IPs (adjust if needed)
IP_JELLYFIN=172.39.0.10
IP_SONARR=172.39.0.3
IP_RADARR=172.39.0.4
# ... etc
```

#### 6. Start Services

```bash
# Start base stack
docker compose up -d

# Or with Jellyfin
docker compose --profile jellyfin up -d

# Check status
docker compose ps
docker compose logs -f jellyfin
```

#### 7. Verify Services

Check that all services are accessible:
- Jellyfin: `http://truenas.local:8096`
- Sonarr: `http://truenas.local:8989`
- Radarr: `http://truenas.local:7878`
- qBittorrent: `http://truenas.local:8080`

#### 8. Update DNS/Bookmarks

Update any bookmarks or DNS entries to point to your TrueNAS IP.

---

## Best Practices

### ZFS Maintenance

1. **Regular Scrubs**
   - Navigate to **Storage → Pools**
   - Click your pool → **Scrub Tasks**
   - Schedule monthly scrubs (automatically finds and repairs corrupted data)

2. **Snapshots**
   - Navigate to **Data Protection → Periodic Snapshot Tasks**
   - Create snapshot tasks for important datasets
   - Recommended schedule:
     - `docker` dataset: Hourly (keep 24), Daily (keep 7)
     - `media` dataset: Daily (keep 7), Weekly (keep 4), Monthly (keep 6)
   - Snapshots are instant and space-efficient

3. **Monitor Pool Health**
   - Check **Storage → Pools** dashboard regularly
   - Look for degraded drives
   - Monitor pool capacity (keep below 80% for optimal performance)

### Performance Tuning

1. **Memory/ARC**
   - ZFS uses system RAM for caching (ARC)
   - Rule of thumb: Leave at least 8GB for ZFS ARC
   - Monitor under **System → Memory**

2. **Network Performance**
   - Use jumbo frames (MTU 9000) if your network supports it
   - Enable SMB multichannel for better Windows performance
   - Consider NFS for Linux clients (lower overhead than SMB)

3. **SSD Cache (Optional)**
   - If you have spare SSDs, consider adding:
     - **L2ARC**: Read cache for frequently accessed data
     - **SLOG**: Write cache for sync writes
   - Most home users don't need this for media serving

### Security

1. **Firewall Rules**
   - Navigate to **Network → Firewall**
   - Only allow necessary ports:
     - SSH (22) - restrict to LAN
     - SMB (445) - LAN only
     - NFS (2049) - LAN only
     - Web UI (443/80) - LAN only
     - Jellyfin (8096) - LAN or WAN if needed

2. **Updates**
   - Enable automatic security updates
   - Check monthly for TrueNAS Scale updates
   - Keep Docker images updated: `docker compose pull && docker compose up -d`

3. **Backup Admin Password**
   - Store in password manager
   - Document recovery process

---

## Backup Strategy

### What to Backup

1. **TrueNAS System Configuration**
   - Navigate to **System Settings → General → Save Config**
   - Download configuration file monthly
   - Store off-site (cloud, external drive)

2. **Docker Configurations**
   - Already covered by dataset snapshots
   - Additionally, use your existing `backup.sh` script
   - Schedule weekly backups to external drive or cloud

3. **Media Files**
   - **Option 1**: Replication to second TrueNAS or external system
   - **Option 2**: Cloud backup (expensive for large media)
   - **Option 3**: Accept risk (media is replaceable)
   - **Recommended**: At minimum, backup irreplaceable media (personal videos, etc.)

### Backup Destinations

1. **External USB Drive**
   - Plug in USB drive
   - Create rsync task under **Data Protection → Rsync Tasks**
   - Schedule weekly backups of `docker` dataset

2. **Cloud Backup** (if available)
   - Use **Data Protection → Cloud Sync Tasks**
   - Supports: AWS S3, Backblaze B2, Google Drive, etc.
   - Encrypt before upload
   - Consider costs for large datasets

3. **Another TrueNAS/Server** (ideal)
   - Use **Data Protection → Replication Tasks**
   - ZFS send/receive is incredibly efficient
   - Can replicate snapshots incrementally

---

## Recommended Services for TrueNAS

Based on your current setup, here's what should run on TrueNAS:

### High Priority (Run on TrueNAS)

| Service | Reason |
|---------|--------|
| Jellyfin | Direct access to media files - eliminates network overhead |
| Sonarr/Radarr/Lidarr | Manage downloads and media files directly |
| Prowlarr | Lightweight, complements Arr apps |
| Bazarr | Subtitle management, benefits from local file access |
| qBittorrent | Downloads directly to NAS storage |
| Jellyseerr | Lightweight, integrates with Jellyfin |
| Jellystat | Database can live on NAS with Jellyfin |

### Consider Keeping Separate (Optional)

| Service | Reason to Keep Separate |
|---------|-------------------------|
| VPN/Gluetun | If using on main desktop for other purposes |
| Monitoring | If monitoring multiple systems, centralize elsewhere |

### Might Add to TrueNAS

| Service | Purpose |
|---------|---------|
| Tautulli | Jellyfin monitoring and statistics |
| Nginx Proxy Manager | Reverse proxy for external access |
| Watchtower | Auto-update Docker containers |
| Portainer | Docker management GUI |

---

## Troubleshooting

### Common Issues

#### Permissions Errors

```bash
# Fix dataset permissions
chown -R 1000:1000 /mnt/tank/media
chown -R 1000:1000 /mnt/tank/docker

# Check permissions
ls -la /mnt/tank/media
```

#### Cannot Access Shares

```bash
# Check SMB service status
systemctl status smb

# Check NFS exports
showmount -e truenas.local

# Verify firewall rules
# Via UI: Network → Firewall
```

#### Docker Networking Issues

```bash
# Restart Docker network
docker network prune
docker compose down
docker compose up -d

# Check network
docker network inspect servarrnetwork
```

#### Pool Performance Issues

```bash
# Check pool status
zpool status tank

# Check ARC statistics
arc_summary

# Monitor disk I/O
iostat -x 1
```

---

## Next Steps After Setup

1. **Test Jellyfin playback** from different devices
2. **Configure automated backups** (snapshots + external)
3. **Set up monitoring** (consider Grafana + Prometheus)
4. **Configure external access** (reverse proxy + VPN)
5. **Optimize transcoding** if Beelink has Intel QuickSync
6. **Document your setup** (update this file with your specific config)

---

## Additional Resources

- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
- [ZFS Best Practices](https://docs.oracle.com/cd/E19253-01/819-5461/6n7ht6r06/index.html)
- [Servarr Wiki](https://wiki.servarr.com/)
- [Your existing repo documentation](../media/README.md)
- [TRaSH Guides](https://trash-guides.info/)

---

## Questions to Consider

Before proceeding, gather this information:

1. **How many drives** does your Beelink Mini S Pro have installed?
2. **What capacity** are the drives?
3. **What's already on them** - any data to preserve?
4. **Network setup** - what IP range do you use? (e.g., 192.168.1.x, 10.0.0.x)
5. **Current Jellyfin data location** - where is your media currently stored?
6. **Desired redundancy** - can you afford to lose a drive, or need mirroring?

---

*This guide was created for your Beelink Mini S Pro TrueNAS Scale setup. Update with your specific configuration as you go!*
