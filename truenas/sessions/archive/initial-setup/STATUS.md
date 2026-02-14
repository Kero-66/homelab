# TrueNAS Setup - Current Status

## What's Been Done

### ✅ Documentation Created

1. **`truenas/README.md`** - Complete setup guide with:
   - Hardware configuration guidance
   - ZFS pool setup (mirrors recommended)
   - Dataset structure for fast (NVMe) and bulk (HDD) storage
   - Network shares (SMB/NFS) setup
   - Container migration strategy from current setup to TrueNAS
   - Best practices and troubleshooting

2. **`truenas/TRUENAS_SETUP_DETAILED.md`** - Detailed reference guide

3. **`docs/INFISICAL_GUIDE.md`** - Complete guide for using Infisical secrets:
   - How to retrieve TrueNAS credentials
   - API authentication methods
   - Command reference for all Infisical operations
   - Example scripts for automation

### ✅ Automation Scripts

1. **`truenas/scripts/setup_storage.sh`** - Automated storage setup:
   - Discovers available disks
   - Creates mirrored pools (fast/bulk)
   - Creates dataset hierarchy
   - Run on TrueNAS via SSH

2. **`truenas/scripts/get_system_info.sh`** - API testing script:
   - Retrieves credentials from Infisical
   - Tests TrueNAS API connection
   - Displays system info, pools, disks, services

### ✅ Configuration Templates

1. **`truenas/.env.sample`** - Environment configuration template

### ✅ Infisical Integration

- TrueNAS credentials stored in Infisical at path `/TrueNAS`
- Secret name: `truenas_admin`
- Successfully tested credential retrieval
- Scripts use Infisical for secure credential access

---

## Your TrueNAS Configuration

**Hardware**: Beelink Mini S Pro
**IP Address**: 192.168.20.22
**Status**: Not yet accessible (needs setup/power on)

---

## Next Steps

### 1. Install TrueNAS Scale

1. **Download ISO**:
   - Visit: https://www.truenas.com/truenas-scale/
   - Download latest stable release

2. **Create Bootable USB**:
   - Windows: Use Rufus
   - Linux: `dd if=truenas.iso of=/dev/sdX bs=4M`
   - Mac: Use balenaEtcher

3. **Install on Beelink**:
   - Boot from USB
   - Follow installer prompts
   - Set root password: Use the one stored in Infisical (`truenas_admin`)
   - Configure network: Static IP `192.168.20.22`

### 2. Initial Configuration

Once TrueNAS is installed and accessible:

```bash
# Test API connection (from your main machine)
cd ~/repos/homelab/truenas
bash scripts/get_system_info.sh 192.168.20.22

# Should show:
# - System info
# - Available disks
# - Network config
```

### 3. Configure Storage

```bash
# Copy setup script to TrueNAS
scp scripts/setup_storage.sh root@192.168.20.22:/tmp/

# SSH into TrueNAS
ssh root@192.168.20.22

# Run disk discovery
bash /tmp/setup_storage.sh --discover

# Review output, then create pools and datasets
bash /tmp/setup_storage.sh --all
```

**Expected pools:**
- `fast` - Mirror of 2x NVMe drives (apps/containers/databases)
- `bulk` - Mirror of 2x HDD drives (media/downloads/backups)

### 4. Set Up Shares

Follow the Network Shares section in `truenas/README.md`:
- Create `mediauser` account (UID 1000, GID 1000)
- Create SMB shares for: media, downloads, docker
- Configure NFS exports (recommended for Linux Docker host)

### 5. Migrate Jellyfin Stack

Follow the Container Migration section in `truenas/README.md`:
- Backup current configs
- Transfer to TrueNAS
- Update `.env` with TrueNAS paths
- Start containers on TrueNAS

---

## Jellyfin Stack Migration Plan

### Services to Run on TrueNAS

| Service | Why |
|---------|-----|
| **Jellyfin** | Direct storage access, QuickSync transcoding |
| **Sonarr/Radarr/Lidarr** | Manage files locally, no network overhead |
| **Prowlarr** | Lightweight indexer manager |
| **Bazarr** | Subtitle management with direct file access |
| **qBittorrent** | Downloads directly to NAS storage |
| **Jellyseerr** | Request management, lightweight |
| **Jellystat** | Statistics dashboard |

### Migration Checklist

- [ ] TrueNAS installed and accessible at 192.168.20.22
- [ ] Storage pools created (fast + bulk)
- [ ] Datasets configured (media, downloads, docker)
- [ ] Network shares set up (SMB/NFS)
- [ ] User created (mediauser, UID 1000)
- [ ] Backup current Jellyfin configs
- [ ] Transfer backups to TrueNAS
- [ ] Clone homelab repo to TrueNAS
- [ ] Configure `.env` with TrueNAS paths
- [ ] Start containers with `docker compose`
- [ ] Verify services accessible
- [ ] Update bookmarks/DNS

---

## Pre-Installation Checklist

Before installing TrueNAS, document your hardware:

### Beelink Mini S Pro Configuration

**Fill in these details:**

- [ ] **CPU**: ___________________ (check for Intel QuickSync support)
- [ ] **RAM**: ___________________ (minimum 8GB for ZFS)
- [ ] **Storage**:
  - [ ] NVMe Slot 1: ___________________ (Size/Model)
  - [ ] NVMe Slot 2: ___________________ (Size/Model)
  - [ ] SATA Bay 1: ___________________ (Size/Model)
  - [ ] SATA Bay 2: ___________________ (Size/Model)
  - [ ] Additional: ___________________
- [ ] **Network**: Gigabit Ethernet / 2.5GbE / Other: ___________
- [ ] **Boot Drive**: ___________________ (separate from data drives?)

**IMPORTANT**: Do NOT use data drives as boot drive. Use:
- Separate small USB drive (16GB+), OR
- Separate small SSD (120GB+), OR
- One of the NVMe drives (will partition for boot + data)

### Network Configuration

- [ ] **IP Address**: 192.168.20.22 (confirmed)
- [ ] **Subnet**: 192.168.20.0/24 (assumed)
- [ ] **Gateway**: ___________________ (usually 192.168.20.1)
- [ ] **DNS Servers**: ___________________ (e.g., 1.1.1.1, 8.8.8.8)

---

## Questions to Answer

Before proceeding, answer these:

1. **How many drives** does your Beelink have installed?
   - NVMe drives: ______
   - SATA drives: ______

2. **What capacities** are the drives?
   - NVMe: ______
   - SATA: ______

3. **What's currently on them?**
   - [ ] Empty/new drives
   - [ ] Has existing data (needs backup)
   - [ ] Currently running different OS

4. **Redundancy preference?**
   - [ ] Mirror (2 drives) - 50% capacity, can lose 1 drive
   - [ ] RAIDZ1 (3+ drives) - (n-1) capacity, can lose 1 drive
   - [ ] RAIDZ2 (4+ drives) - (n-2) capacity, can lose 2 drives
   - [ ] No redundancy (stripe) - 100% capacity, NOT RECOMMENDED

5. **Where is your current media stored?**
   - Current path: ___________________
   - Total size: ___________________
   - Will it fit on new NAS? [ ] Yes [ ] No

---

## Reference Links

- [TrueNAS Scale Download](https://www.truenas.com/truenas-scale/)
- [TrueNAS Documentation](https://www.truenas.com/docs/scale/)
- [TrueNAS API Docs](http://192.168.20.22/api/docs) (once installed)
- [Infisical Guide](../docs/INFISICAL_GUIDE.md)
- [Media Stack README](../media/README.md)

---

## Support

If you encounter issues:

1. Check TrueNAS logs: System Settings → Advanced → Audit
2. Check API connectivity: `bash scripts/get_system_info.sh 192.168.20.22`
3. Review documentation in `truenas/README.md`
4. TrueNAS Community: https://forums.truenas.com/

---

*Last updated: 2026-02-11*
*TrueNAS IP: 192.168.20.22*
*Status: Ready for installation*
