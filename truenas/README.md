# TrueNAS Scale Setup for Beelink Mini S Pro

Complete guide for setting up TrueNAS Scale on your Beelink Mini S Pro, configuring storage pools, and migrating your Jellyfin media stack.

> **Note**: This guide uses Infisical for secure credential management. See [Infisical Guide](../docs/INFISICAL_GUIDE.md) for details on retrieving TrueNAS credentials.

---

## 🚀 Current Status (Jellyfin Stack Deployment)

**System:** TrueNAS Scale 25.10.1 at 192.168.20.22 (HTTPS)

### Completed ✅
- ✅ SSH key-based auth configured (kero66 → root@192.168.20.22)
- ✅ SMB shares mounted on workstation (/mnt/truenas_media)
- ✅ Infisical Agent configuration deployed to `/mnt/Fast/docker/`
- ✅ Infisical Agent template syntax fixed and tested
- ✅ Jellyfin stack deployed (jellyfin, jellyseerr, jellystat, jellystat-db)
- ✅ All services RUNNING and healthy (verified 2026-02-11)
- ✅ Docker IPv6 issue resolved (Job 5442: removed IPv6 pools, forcing IPv4-only)
- ✅ Template fixes committed to git (7c0f8ea)
- 🔄 Media transfer in progress: 203GB movies + 1.9TB shows (rsync via SMB)

### Next Steps 🔄

**Jellyfin Stack (Completed):**
- ✅ See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for Jellyfin setup

**Arr Stack & Downloaders (Ready to Deploy):**
- 📦 See [ARR_DEPLOYMENT.md](./ARR_DEPLOYMENT.md) for complete migration guide
- Services ready: Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr, FlareSolverr, Cleanuparr
- Downloaders ready: qBittorrent, SABnzbd
- Tailscale ready: Secure remote access / subnet router
- Run: `bash truenas/scripts/deploy_new_stacks.sh` to begin

### Key Fix: IPv6 Removed from Docker
- **Issue:** Home network lacks IPv6 routing → Docker image pulls timed out
- **Solution:** Removed IPv6 pools (`fdd0::/48`, `fdd0::/64`) from Docker config
- **Verified:** ✅ Now using IPv4-only (`172.17.0.0/12` only)
- **Impact:** Image pulls now work without "context deadline exceeded" errors

---

## Quick Start

### 0. Test API Connection (Optional)

Before setup, verify you can access TrueNAS API:

```bash
# Get system info using Infisical credentials
bash scripts/get_system_info.sh 10.0.0.50

# This will show:
# - System information (version, hostname, uptime)
# - Storage pools (if any configured)
# - Disks (available drives)
# - Network interfaces
# - Running services
```

### 1. First-Time Setup

After installing TrueNAS Scale on your Beelink Mini S Pro:

```bash
# On your local machine, copy the setup script to TrueNAS
scp scripts/setup_storage.sh admin@<TRUENAS_IP>:/tmp/

# SSH into TrueNAS
ssh admin@<TRUENAS_IP>

# Run discovery to see your disks
bash /tmp/setup_storage.sh --discover

# Review the disk layout, then create everything
bash /tmp/setup_storage.sh --all
```

### 2. Configure Environment

```bash
# In this directory (truenas/)
cp .env.sample .env
nano .env
```

Fill in your TrueNAS IP and customize pool names if desired.

### 3. Set Up Shares (SMB/NFS)

See [Network Shares](#network-shares) section below for detailed instructions.

### 4. Deploy Containers

See [Container Migration](#container-migration) section for migrating your Jellyfin stack.

---

## Table of Contents

1. [Hardware Overview](#hardware-overview)
2. [Storage Architecture](#storage-architecture)
3. [Initial Configuration](#initial-configuration)
4. [Pool Setup](#pool-setup)
5. [Dataset Structure](#dataset-structure)
6. [Network Shares](#network-shares)
7. [Container Migration](#container-migration)
8. [Jellyfin Stack Setup](#jellyfin-stack-setup)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Hardware Overview

**Beelink Mini S Pro** specifications:
- Compact form factor ideal for home NAS
- Multiple drive bays (document your specific configuration)
- Network: Gigabit Ethernet (minimum)
- CPU: Intel (QuickSync for Jellyfin transcoding)

**Document your drive configuration:**
- How many NVMe slots?
- How many SATA bays?
- Current drives installed?

Example configuration:
- 2x 1TB NVMe (for apps/containers)
- 2x 8TB HDD (for media/bulk storage)

---

## Storage Architecture

### Recommended Layout

The `setup_storage.sh` script creates two mirrored pools:

#### Fast Pool (NVMe Mirror)
- **Purpose**: App configs, databases, container storage
- **Layout**: 2x NVMe drives in MIRROR
- **Datasets**:
  - `fast/apps` - Container configurations
  - `fast/databases` - PostgreSQL, Redis, etc.
  - `fast/docker` - TrueNAS app/container runtime

#### Bulk Pool (HDD Mirror)
- **Purpose**: Media files, backups, bulk storage
- **Layout**: 2x HDD drives in MIRROR
- **Datasets**:
  - `bulk/media` - Movies, TV shows, music (Jellyfin library)
  - `bulk/photos` - Photo library (future: Immich)
  - `bulk/cloud-sync` - Cloud storage mirrors
  - `bulk/backups` - Backup target
  - `bulk/downloads` - Download staging area

### Why Mirrors?

For a 2-drive setup, **MIRROR** is the best choice:
- **Redundancy**: Can lose 1 drive without data loss
- **Performance**: Excellent read performance
- **Rebuild time**: Faster than RAIDZ
- **Capacity**: 50% (2x 8TB = 8TB usable)

**Alternative:** If you have 3+ drives, consider RAIDZ1 for better capacity (n-1 drives usable).

---

## Initial Configuration

### 1. Install TrueNAS Scale

1. Download TrueNAS Scale ISO from https://www.truenas.com/truenas-scale/
2. Create bootable USB (use Rufus on Windows, `dd` on Linux)
3. Boot Beelink from USB and follow installer
4. Set root password during installation
5. Choose boot drive (smallest drive or dedicated USB)

### 2. Network Setup

1. **Console Configuration** (via keyboard/monitor):
   - Configure network interface
   - Set static IP: `10.0.0.50/24` (adjust for your network)
   - Set gateway: `10.0.0.1` (your router)
   - Set DNS: `1.1.1.1, 8.8.8.8`

2. **Web UI Access**:
   - Navigate to `http://10.0.0.50` (or your configured IP)
   - Login with root account
   - Complete initial setup wizard

### 3. System Settings

Navigate through the web UI:

1. **System Settings → General**:
   - Hostname: `truenas-mini`
   - Timezone: `Australia/Brisbane` (or your timezone)
   - Language: English
   - Console: Enable SSH (if you want remote access)

2. **System Settings → Services**:
   - Enable SSH service (for scripting and remote management)
   - **Security Note**: Use SSH keys, not password auth

3. **System Settings → Update**:
   - Check for updates
   - Apply latest stable version
   - Reboot if required

---

## Pool Setup

### Automated Setup (Recommended)

Use the provided script to create pools and datasets:

```bash
# Copy script to TrueNAS
scp scripts/setup_storage.sh admin@<TRUENAS_IP>:/tmp/

# SSH into TrueNAS
ssh admin@<TRUENAS_IP>

# Discover your disks
bash /tmp/setup_storage.sh --discover
```

**Output example:**
```
Name       Serial                    Size         Type     Model                               Pool      
----------------------------------------------------------------------------------------------------
nvme0n1    S5GVNG0R123456           1000 GiB     NVME     Samsung 980 PRO                     available 
nvme1n1    S5GVNG0R789012           1000 GiB     NVME     Samsung 980 PRO                     available 
sda        WD-ABC123456789          8000 GiB     HDD      WDC WD80EFZX                        available 
sdb        WD-DEF987654321          8000 GiB     HDD      WDC WD80EFZX                        available 
```

**Review the disks**, then create pools:

```bash
# Create all pools and datasets
bash /tmp/setup_storage.sh --all

# Or step by step:
bash /tmp/setup_storage.sh --create-pools
bash /tmp/setup_storage.sh --create-datasets
bash /tmp/setup_storage.sh --verify
```

### Manual Setup (Alternative)

If you prefer using the web UI or need custom configuration:

1. **Navigate to Storage**
2. **Create Pool → Add**
3. **Configure Pool**:
   - Name: `fast` or `bulk`
   - Layout: `Mirror`
   - Select disks
   - Encryption: Optional (disable for simplicity, enable for security)
   - Compression: `LZ4` (default, recommended)
4. **Create Pool**

Repeat for second pool.

---

## Dataset Structure

Datasets are created automatically by `setup_storage.sh`. Here's what they're for:

### Fast Pool Datasets

| Dataset | Purpose | Record Size | Use Case |
|---------|---------|-------------|----------|
| `fast/apps` | Container configs | 128K | Small config files, logs |
| `fast/databases` | PostgreSQL, Redis | 16K | Database page size optimized |
| `fast/docker` | TrueNAS app runtime | 128K | Docker layer storage |

### Bulk Pool Datasets

| Dataset | Purpose | Record Size | Use Case |
|---------|---------|-------------|----------|
| `bulk/media` | Jellyfin library | 1M | Large video files (movies, TV) |
| `bulk/photos` | Photo library | 256K | RAW images, thumbnails |
| `bulk/cloud-sync` | Cloud mirrors | 128K | Mixed file types |
| `bulk/backups` | Backup storage | 1M | Large backup archives |
| `bulk/downloads` | Download staging | 1M | Incomplete/complete downloads |

**Record Size Tuning:**
- **1M**: Best for large sequential files (video, backups)
- **128K**: Default, good for general use
- **16K**: Optimal for databases (matches PostgreSQL page size)

---

## Network Shares

### Create a User

First, create a dedicated user for file access:

1. **Accounts → Users → Add**
2. **Settings**:
   - Username: `mediauser`
   - UID: `1000` (matches Docker PUID)
   - Primary Group: Create new group `mediagroup` (GID 1000)
   - Home Directory: `/nonexistent`
   - Shell: `nologin` (no shell access needed)
   - Password: Set a strong password
   - Disable password login: Check (use SMB password instead)

### SMB Shares (Windows/Mac/Linux)

SMB provides the best compatibility.

#### Create Shares

1. **Shares → Windows (SMB) Shares → Add**

2. **Media Share**:
   - Path: `/mnt/bulk/media`
   - Name: `media`
   - Purpose: Default share parameters
   - Enabled: ✓
   - **Advanced**:
     - Export Read Only: ✗ (allow writes)
     - Browseable: ✓
     - Guest Access: ✗ (require authentication)

3. **Downloads Share**:
   - Path: `/mnt/bulk/downloads`
   - Name: `downloads`
   - Same settings as above

4. **Docker Share**:
   - Path: `/mnt/fast/docker`
   - Name: `docker`
   - Same settings as above

#### Configure SMB Service

1. **System Settings → Services → SMB**
2. **Settings**:
   - NetBIOS Name: `TRUENAS-MINI`
   - Workgroup: `WORKGROUP`
   - Enable SMB1: ✗ (security risk)
   - Enable: ✓
   - Start Automatically: ✓

#### Set SMB Passwords

```bash
# SSH into TrueNAS
ssh admin@<TRUENAS_IP>

# Set SMB password for your user
midclt call smb.set_smbpasswd mediauser 'your_password_here'
```

#### Test SMB Access

**From Windows:**
```
\\truenas-mini\media
# Or
\\10.0.0.50\media
```

**From Linux:**
```bash
# Install smbclient
sudo apt install smbclient

# List shares
smbclient -L //truenas-mini -U mediauser

# Mount share
sudo mount -t cifs //truenas-mini/media /mnt/media -o username=mediauser,password=yourpass,uid=1000,gid=1000
```

### NFS Shares (Linux - Better Performance)

NFS is faster for Linux hosts, ideal for Docker containers.

#### Create NFS Share

1. **Shares → Unix (NFS) Shares → Add**

2. **Configure**:
   - Path: `/mnt/bulk/media`
   - Description: `Media storage for Jellyfin`
   - **Networks**: Add authorized networks
     - `10.0.0.0/24` (your entire LAN)
     - Or specific IP: `10.0.0.100/32` (just your Docker host)
   - Maproot User: `mediauser`
   - Maproot Group: `mediagroup`
   - Read Only: ✗

3. **Repeat** for other datasets (`downloads`, `docker`)

#### Configure NFS Service

1. **System Settings → Services → NFS**
2. Enable and start automatically

#### Mount NFS on Docker Host

```bash
# Install NFS client
sudo apt install nfs-common

# Create mount point
sudo mkdir -p /mnt/truenas/media

# Add to /etc/fstab for persistent mount
sudo nano /etc/fstab
```

Add:
```
truenas-mini:/mnt/bulk/media  /mnt/truenas/media  nfs  defaults,_netdev  0 0
truenas-mini:/mnt/bulk/downloads  /mnt/truenas/downloads  nfs  defaults,_netdev  0 0
```

Mount:
```bash
sudo mount -a

# Verify
df -h | grep truenas
```

---

## Container Migration

### Strategy Overview

You have two main options:

#### Option A: Run Containers on TrueNAS (Recommended)

**Pros:**
- Single system to manage
- No network overhead (containers access storage locally)
- Simplified backup (system + data together)
- Better performance (direct disk access)

**Cons:**
- All resources from one machine
- System updates may affect all services

#### Option B: Separate Docker Host + NAS

**Pros:**
- Distribute workload
- Easier to upgrade compute separately
- NAS focused on storage/serving

**Cons:**
- Network bottleneck (especially for transcoding)
- More complex setup
- Two systems to maintain

**Recommendation:** Start with **Option A** (containers on TrueNAS). The Beelink should handle Jellyfin + *arr stack easily.

### Prerequisites (Option A)

TrueNAS Scale includes Docker/Kubernetes (k3s) built-in.

1. **Configure Apps Pool**:
   - Navigate to **Apps → Settings**
   - Choose pool for app storage: `fast` (recommended)
   - Save and wait for initialization

2. **Enable SSH** (if not already):
   - **System Settings → Services → SSH**
   - Enable and start automatically

### Migration Steps

#### 1. Backup Current Setup

On your **current Docker host**:

```bash
cd ~/repos/homelab/media

# Use your existing backup script
./backup.sh

# Or manual backup
tar -czf ~/jellyfin-backup-$(date +%F).tar.gz \
  jellyfin/ sonarr/ radarr/ lidarr/ prowlarr/ bazarr/ qbittorrent/ .env

# Include service configs
tar -czf ~/media-configs-$(date +%F).tar.gz \
  sonarr/ radarr/ lidarr/ prowlarr/ bazarr/ qbittorrent/
```

#### 2. Transfer to TrueNAS

```bash
# From your current machine
scp ~/jellyfin-backup-*.tar.gz admin@truenas-mini:/mnt/bulk/backups/
scp ~/media-configs-*.tar.gz admin@truenas-mini:/mnt/bulk/backups/
```

#### 3. Prepare TrueNAS

SSH into TrueNAS:

```bash
ssh admin@truenas-mini

# Create working directory
cd /mnt/fast/docker
mkdir -p homelab
cd homelab

# Clone your repo (or copy files manually)
git clone https://github.com/kieranmcjannett-coder/homelab.git .
cd media
```

#### 4. Restore Configurations

```bash
# Extract backup
cd /mnt/fast/docker/homelab/media
tar -xzf /mnt/bulk/backups/media-configs-*.tar.gz

# Or use your restore script if available
# ./backup.sh --restore /mnt/bulk/backups/jellyfin-backup-*.tar.gz
```

#### 5. Configure Environment

```bash
cd /mnt/fast/docker/homelab/media
cp .env.example .env
nano .env
```

**Critical settings for TrueNAS:**
```bash
# User/Group IDs (must match your TrueNAS user)
PUID=1000
PGID=1000

# Timezone
TZ=Australia/Brisbane

# Storage paths (use TrueNAS dataset paths)
DATA_DIR=/mnt/bulk/media
CONFIG_DIR=/mnt/fast/docker/homelab/media

# Network (default is fine)
SERVARR_SUBNET=172.39.0.0/24

# Service IPs (defaults are fine)
IP_JELLYFIN=172.39.0.10
IP_SONARR=172.39.0.3
IP_RADARR=172.39.0.4
IP_LIDARR=172.39.0.5
IP_BAZARR=172.39.0.6
IP_QBITTORRENT=172.39.0.12
IP_PROWLARR=172.39.0.8
```

#### 6. Create Data Directories

Ensure your media directories exist:

```bash
# Create subdirectories in media dataset
mkdir -p /mnt/bulk/media/{movies,shows,music,books}

# Create download directories
mkdir -p /mnt/bulk/downloads/{complete,incomplete}

# Set permissions
chown -R 1000:1000 /mnt/bulk/media
chown -R 1000:1000 /mnt/bulk/downloads
chown -R 1000:1000 /mnt/fast/docker
```

#### 7. Start Services

```bash
cd /mnt/fast/docker/homelab/media

# Start base stack (arr apps + qBittorrent)
docker compose up -d

# Or include Jellyfin stack
docker compose --profile jellyfin up -d

# Or everything (including VPN if configured)
docker compose --profile all up -d
```

#### 8. Verify Services

Check that containers are running:

```bash
docker compose ps
```

Check logs:

```bash
docker compose logs -f jellyfin
docker compose logs -f sonarr
```

Access services (use TrueNAS IP):
- Jellyfin: `http://10.0.0.50:8096`
- Sonarr: `http://10.0.0.50:8989`
- Radarr: `http://10.0.0.50:7878`
- qBittorrent: `http://10.0.0.50:8080`
- Prowlarr: `http://10.0.0.50:9696`

#### 9. Restore Jellyfin Data (if needed)

If you need to restore Jellyfin library/metadata:

```bash
# Stop Jellyfin
docker compose stop jellyfin

# Restore Jellyfin config
cd /mnt/fast/docker/homelab/media
tar -xzf /mnt/bulk/backups/jellyfin-backup-*.tar.gz jellyfin/

# Restart Jellyfin
docker compose start jellyfin
```

#### 10. Update DNS/Bookmarks

Update any bookmarks or local DNS to point to TrueNAS IP (`10.0.0.50`).

---

## Jellyfin Stack Setup

Your current Jellyfin stack includes:
- **Jellyfin** - Media server
- **Jellyseerr** - Request management
- **Jellystat** - Statistics dashboard
- **Sonarr/Radarr/Lidarr** - Media automation
- **Prowlarr** - Indexer manager
- **Bazarr** - Subtitles
- **qBittorrent** - Torrent client

All of these should run well on TrueNAS.

### Hardware Transcoding on TrueNAS

If your Beelink has Intel CPU with QuickSync:

1. **Pass GPU to Docker** (TrueNAS handles this automatically)

2. **Update Jellyfin compose.yaml**:
   ```yaml
   jellyfin:
     devices:
       - /dev/dri:/dev/dri  # Intel QuickSync
   ```

3. **Configure in Jellyfin UI**:
   - Dashboard → Playback → Transcoding
   - Hardware acceleration: Intel QuickSync (QSV)
   - Enable hardware decoding for: H264, HEVC, VP9

### Profiles and Configuration

Your existing `compose.yaml` already has profiles:

```bash
# Base stack only (no VPN, no Jellyfin)
docker compose up -d

# With VPN for qBittorrent
docker compose --profile vpn up -d

# With Jellyfin stack
docker compose --profile jellyfin up -d

# Everything
docker compose --profile all up -d
```

---

## Best Practices

### ZFS Maintenance

#### 1. Regular Scrubs

Scrubs verify data integrity and repair silent corruption:

1. **Storage → Pools → Your Pool → Scrub Tasks**
2. **Add Scrub Task**:
   - Schedule: Monthly (first Sunday at 2 AM)
   - Threshold: 35 days

**Or via CLI:**
```bash
# Manual scrub
zpool scrub fast
zpool scrub bulk

# Check scrub status
zpool status
```

#### 2. Snapshots

Snapshots are instant, space-efficient backups:

1. **Data Protection → Periodic Snapshot Tasks → Add**
2. **Example for docker dataset**:
   - Dataset: `fast/docker`
   - Schedule: 
     - Hourly (keep 24)
     - Daily (keep 7)
     - Weekly (keep 4)
   - Naming schema: `auto-%Y%m%d-%H%M`

3. **For media dataset** (less frequent):
   - Dataset: `bulk/media`
   - Schedule:
     - Daily (keep 7)
     - Weekly (keep 4)
     - Monthly (keep 6)

#### 3. Monitor Pool Health

Check regularly:
- **Storage → Pools** dashboard
- Watch for degraded drives
- Keep pool below 80% capacity (performance degrades above 80%)

### Performance Tuning

#### 1. ZFS ARC (Cache)

ZFS uses RAM for caching (ARC):
- Leave at least 8GB for ZFS
- Monitor: `arc_summary` command
- More RAM = better performance

#### 2. Network Performance

- **Jumbo Frames**: Set MTU to 9000 if your switch supports it
- **SMB Multichannel**: Enable for better Windows performance
- **NFS**: Use for Linux clients (lower overhead)

#### 3. Dataset Record Size

Already optimized by setup script:
- **1M**: Large sequential files (video)
- **128K**: Default, general purpose
- **16K**: Databases

### Security

#### 1. Firewall Rules

**Network → Firewall → Add Rule**

Allow only necessary services:
- SSH (22) - LAN only
- SMB (445) - LAN only
- NFS (2049) - LAN only
- Web UI (443/80) - LAN only
- Jellyfin (8096) - LAN or WAN if you set up reverse proxy

#### 2. SSH Hardening

```bash
# Generate SSH key on your client
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to TrueNAS
ssh-copy-id admin@truenas-mini

# Disable password auth (after confirming key works)
# System Settings → Services → SSH → Configure
# Disable: "Log in as Root with Password"
# Disable: "Allow Password Authentication"
```

#### 3. Regular Updates

- **System Settings → Update**
- Check monthly for TrueNAS updates
- Test in maintenance window
- Keep Docker images updated:
  ```bash
  docker compose pull
  docker compose up -d
  ```

### Backup Strategy

#### What to Backup

1. **TrueNAS Config**:
   - **System Settings → General → Save Config**
   - Download `.db` file monthly
   - Store off-site

2. **Container Configs**:
   - Use snapshots (automatic)
   - Additionally: `tar -czf backup.tar.gz /mnt/fast/docker`
   - Schedule weekly to external drive

3. **Media Files**:
   - Optional (media is replaceable)
   - Consider backing up:
     - Personal/irreplaceable content
     - Configurations/metadata only

#### Backup Destinations

##### External Drive (Simple)

1. Plug in USB drive to TrueNAS
2. **Storage → Import Disk** (format as ZFS or leave as ext4)
3. **Data Protection → Rsync Tasks → Add**:
   - Source: `fast/docker`
   - Destination: `/mnt/usbdrive/backups`
   - Schedule: Weekly

##### Cloud Backup (Flexible)

**Data Protection → Cloud Sync Tasks → Add**:
- Provider: Backblaze B2, AWS S3, etc.
- Encrypt: Yes (before upload)
- Folder: `fast/docker` → `cloud-bucket/truenas-backup`

**Cost warning:** Cloud storage for large media collections is expensive. Only backup configs/databases.

##### ZFS Replication (Best)

If you have a second TrueNAS or compatible system:

**Data Protection → Replication Tasks → Add**:
- Source: `fast/docker@auto-*` (snapshots)
- Destination: SSH to second NAS
- Schedule: Hourly/Daily

Benefits:
- Incremental (only sends changes)
- Preserves all snapshots
- Fast restoration

---

## Troubleshooting

### Common Issues

#### Permission Errors

```bash
# SSH into TrueNAS
ssh admin@truenas-mini

# Fix permissions on datasets
chown -R 1000:1000 /mnt/bulk/media
chown -R 1000:1000 /mnt/bulk/downloads
chown -R 1000:1000 /mnt/fast/docker

# Check current permissions
ls -la /mnt/bulk/media
ls -la /mnt/fast/docker
```

#### Cannot Access SMB Shares

```bash
# Check SMB service status
midclt call service.query '[["service", "=", "cifs"]]'

# Or via web UI:
# System Settings → Services → Check if SMB is running

# Verify share configuration
midclt call sharing.smb.query

# Check firewall rules
# Network → Firewall
```

#### Docker Containers Won't Start

```bash
# Check Docker service
systemctl status docker

# Check container logs
cd /mnt/fast/docker/homelab/media
docker compose logs jellyfin
docker compose logs sonarr

# Check network
docker network inspect servarrnetwork

# Restart Docker daemon
systemctl restart docker
docker compose up -d
```

#### Pool Performance Issues

```bash
# Check pool health
zpool status tank

# Check disk I/O
iostat -x 1

# Check ARC usage
arc_summary

# Check pool capacity (should be under 80%)
zpool list
```

#### NFS Mount Fails

```bash
# On TrueNAS, check NFS exports
showmount -e localhost

# On client, test mount
sudo mount -v -t nfs truenas-mini:/mnt/bulk/media /mnt/test

# Check NFS service status
midclt call service.query '[["service", "=", "nfs"]]'
```

### Getting Help

1. **Check TrueNAS logs**:
   - Web UI: System Settings → Advanced → Audit
   - CLI: `tail -f /var/log/middlewared.log`

2. **Check Docker logs**:
   ```bash
   docker compose logs -f [service_name]
   ```

3. **TrueNAS Community**:
   - Forums: https://www.truenas.com/community/
   - Discord: https://discord.gg/truenas

---

## What to Run on TrueNAS

Based on your existing setup, here's what makes sense to run on TrueNAS:

### High Priority ✅

| Service | Reason |
|---------|--------|
| **Jellyfin** | Direct local storage access, no network overhead, can use QuickSync |
| **Sonarr/Radarr/Lidarr** | Manage media files directly, better performance |
| **Prowlarr** | Lightweight, integrates with arr stack |
| **Bazarr** | Subtitle management, direct file access |
| **qBittorrent** | Downloads directly to local storage |
| **Jellyseerr** | Lightweight, integrates with Jellyfin |
| **Jellystat** | Can use TrueNAS PostgreSQL for database |

### Consider Later 📋

| Service | Notes |
|---------|-------|
| **Tautulli** | Jellyfin analytics (if you want detailed stats beyond Jellystat) |
| **Nginx Proxy Manager** | For external access with SSL |
| **Watchtower** | Auto-update Docker containers |
| **Portainer** | Docker GUI management |

### Keep Separate (Optional) 🔄

| Service | Reason |
|---------|--------|
| **VPN/Gluetun** | If already using on main desktop |
| **Monitoring** | If monitoring multiple systems, keep centralized |

---

## Next Steps

After completing setup:

1. ✅ **Test Jellyfin playback** - Try different file types, resolutions
2. ✅ **Configure transcoding** - Enable QuickSync if available
3. ✅ **Set up automated scrubs** - Monthly ZFS integrity checks
4. ✅ **Configure snapshots** - Automated backups of configs
5. ✅ **Test external access** - If needed, set up reverse proxy
6. ✅ **Document your setup** - Update this file with specifics
7. ✅ **Create external backup** - Weekly backups to USB drive or cloud

---

## Additional Resources

- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
- [TrueNAS API Reference (v25.10)](https://api.truenas.com/v25.10/)
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Servarr Wiki](https://wiki.servarr.com/) - For *arr apps
- [TRaSH Guides](https://trash-guides.info/) - Quality profiles for Sonarr/Radarr
- [Your Media Stack Docs](../media/README.md)

---

## Hardware-Specific Notes

### Beelink Mini S Pro

**Document your specific configuration here:**

- **CPU**: _[Intel model]_
- **RAM**: _[Amount]_
- **Storage**:
  - NVMe 1: _[Size/Model]_
  - NVMe 2: _[Size/Model]_
  - HDD 1: _[Size/Model]_
  - HDD 2: _[Size/Model]_
- **Network**: _[Gigabit/2.5G]_
- **GPU**: _[Intel QuickSync supported?]_

**Known Issues:**
- _[Document any issues specific to this hardware]_

**Workarounds:**
- _[Any BIOS settings or configuration needed]_

---

*This guide is based on TrueNAS Scale CE 25.10. Update as needed for newer versions.*
