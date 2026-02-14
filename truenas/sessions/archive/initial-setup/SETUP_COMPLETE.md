# TrueNAS Setup Complete ✅

**Date**: 2026-02-11  
**System**: truenas @ 192.168.20.22  
**Version**: TrueNAS Scale 25.10.1  
**Status**: **READY FOR MIGRATION**

---

## What Was Completed

### ✅ User Account Created
- **Username**: kero66
- **UID/GID**: 1000:1000 (matches media stack PUID/PGID)
- **Purpose**: Daily operations and container file ownership
- **Credentials**: Stored in Infisical at `/TrueNAS/kero66_password`

### ✅ Storage Pools Configured

#### Pool 1: "Data" (HDD Mirror)
- **Devices**: sda + sdb (2x 8TB WDC HDD)
- **Type**: 2-way mirror
- **Capacity**: 7.45 TB usable
- **Status**: ONLINE ✓
- **Purpose**: Media files, downloads, backups

#### Pool 2: "Fast" (NVMe Mirror)  
- **Devices**: nvme0n1 + nvme2n1 (2x Lexar 1TB NVMe)
- **Type**: 2-way mirror
- **Capacity**: 953 GB usable
- **Status**: ONLINE ✓
- **Purpose**: Docker configs, databases
- **Note**: nvme1n1 is the boot drive (TrueNAS OS)

### ✅ Datasets Created

**Data Pool:**
```
/mnt/Data/
├── media/
│   ├── movies/
│   ├── shows/
│   └── music/
├── downloads/
│   ├── complete/
│   └── incomplete/
└── backups/
```

**Fast Pool:**
```
/mnt/Fast/
├── docker/
│   ├── jellyfin/
│   ├── sonarr/
│   ├── radarr/
│   ├── prowlarr/
│   ├── bazarr/
│   ├── qbittorrent/
│   ├── jellyseerr/
│   └── fileflows/
└── databases/
    └── jellystat/
```

### ✅ NFS Shares Configured

| Share | Mount Target | Purpose |
|-------|--------------|---------|
| 192.168.20.22:/mnt/Data/media | /data/media | Media files |
| 192.168.20.22:/mnt/Data/downloads | /data/downloads | Download directory |
| 192.168.20.22:/mnt/Fast/docker | /docker-configs | Container configs |

**Access**: All shares mapped to kero66 (1000:1000)  
**Network**: 192.168.20.0/24 (local only)

### ✅ Services Enabled
- SMB/CIFS: Running ✓
- NFS: Running ✓
- SSH: Stopped (disabled for security)

---

## Hardware Configuration Summary

### Corrected Hardware Inventory

**Boot Drive (NOT AVAILABLE FOR POOLS):**
- nvme1n1 (YMTC PC41Q-1TB-B) - TrueNAS OS installation

**Data Pool (IN USE):**
- sda (WDC 8TB HDD)
- sdb (WDC 8TB HDD)

**Fast Pool (IN USE):**
- nvme0n1 (Lexar 1TB NVMe)
- nvme2n1 (Lexar 1TB NVMe)

---

## Next Steps: Container Migration

### Option 1: Run Docker on Separate Host (Recommended)

Mount NFS shares to your Docker host and update compose.yaml:

**1. Mount NFS shares on Docker host:**
```bash
# Install NFS client
sudo apt install nfs-common

# Create mount points
sudo mkdir -p /data/media /data/downloads /docker-configs

# Mount shares (add to /etc/fstab for persistence)
sudo mount 192.168.20.22:/mnt/Data/media /data/media
sudo mount 192.168.20.22:/mnt/Data/downloads /data/downloads
sudo mount 192.168.20.22:/mnt/Fast/docker /docker-configs
```

**2. Update media/.env:**
```bash
DATA_DIR=/data
CONFIG_DIR=/docker-configs
PUID=1000  # Already matches kero66
PGID=1000  # Already matches kero66
```

**3. Start containers:**
```bash
cd media
docker compose --profile all up -d
```

### Option 2: Run Docker on TrueNAS (Alternative)

Use TrueNAS Scale's built-in Docker/Kubernetes apps system. See official docs for details.

---

## Credentials Reference

All credentials stored in Infisical project `homelab` (dev environment):

```bash
# Get TrueNAS admin API key (for scripts/automation)
infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain

# Get TrueNAS admin password (break-glass only)
infisical secrets get truenas_admin --env dev --path /TrueNAS --plain

# Get kero66 password (daily operations)
infisical secrets get kero66_password --env dev --path /TrueNAS --plain

# Get username
infisical secrets get TRUENAS_USER --env dev --path /TrueNAS --plain
```

---

## System Access

**Web UI**: http://192.168.20.22  
**Admin User**: truenas_admin (UID 950) - emergency only  
**Regular User**: kero66 (UID 1000) - daily operations  
**API Base**: http://192.168.20.22/api/v2.0/

---

## Verification Commands

Run these on your Docker host to verify NFS connectivity:

```bash
# Test NFS availability
showmount -e 192.168.20.22

# Test mount (temporary)
sudo mount -t nfs 192.168.20.22:/mnt/Data/media /mnt/test

# Verify permissions
ls -la /mnt/test  # Should show kero66:kero66 ownership

# Unmount test
sudo umount /mnt/test
```

---

## Performance Expectations

### Data Pool (HDD Mirror)
- **Sequential read**: ~200-250 MB/s (per drive)
- **Sequential write**: ~200-250 MB/s (limited by slower drive)
- **Random IOPS**: Moderate (HDD limitation)
- **Use case**: Perfect for media streaming (needs ~50 MB/s max)

### Fast Pool (NVMe Mirror)
- **Sequential read**: ~3000-5000 MB/s (NVMe speeds)
- **Sequential write**: ~2000-4000 MB/s (mirror write penalty)
- **Random IOPS**: Excellent (NVMe)
- **Use case**: Perfect for databases, configs, transcode temp

---

## Troubleshooting

### NFS Mount Issues

**Problem**: Permission denied when accessing NFS share

**Solution**:
```bash
# Verify your Docker host user has UID 1000
id $(whoami)  # Should show uid=1000

# If different, either:
# 1. Change PUID/PGID in .env to match your user
# 2. Or create user with UID 1000 on Docker host
```

### Container Startup Issues

**Problem**: Containers can't write to mounted paths

**Check**:
```bash
# On Docker host
ls -la /data/media  # Should show kero66:kero66
touch /data/media/test.txt  # Should succeed

# If fails, check NFS mount options
mount | grep nfs
# Should NOT have "ro" (read-only)
```

---

## Documentation Files

- `HARDWARE_CONFIG.md` - Complete hardware inventory and pool details
- `README.md` - Main setup guide with detailed instructions
- `STATUS.md` - Pre-installation checklist (historical)
- `DISCOVERY_COMPLETE.md` - Initial discovery results (historical)
- `scripts/` - Automation scripts for user creation, system info
- `docs/INFISICAL_GUIDE.md` - Complete Infisical usage reference

---

## Next Session Checklist

If continuing in next session:

- [ ] Mount NFS shares on Docker host
- [ ] Test file operations with kero66 user
- [ ] Update media/.env with new paths
- [ ] Migrate existing container configs to TrueNAS
- [ ] Start containers and verify functionality
- [ ] Set up backup strategy for Fast pool configs

---

## Success Criteria ✅

- [x] User kero66 created with correct UID/GID
- [x] Fast pool created with 2x NVMe mirror
- [x] All datasets created on both pools
- [x] NFS shares configured and accessible
- [x] Services running (SMB, NFS)
- [x] Documentation updated with actual configuration

**Status**: System is production-ready for container migration!
