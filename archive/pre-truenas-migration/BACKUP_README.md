# 🚀 Windows to Linux Migration - Backup & Restore

Complete backup solution for migrating your homelab from Windows/WSL2 to native Linux.

## Quick Start (3 Simple Steps)

### 1️⃣ Verify Your System

```bash
cd ~/repos/homelab
./verify_before_migration.sh
```

This checks:
- ✅ D drive availability and space
- ✅ Docker installation and running services
- ✅ All configurations and databases
- ✅ Environment files and credentials

### 2️⃣ Backup Everything

```bash
./backup_to_d_drive.sh
```

This creates a complete backup in `/mnt/d/homelab-backup/` including:
- All configurations (*arr apps, Jellyfin, etc.)
- All databases (SQLite + PostgreSQL)
- All scripts and automation
- Docker state and compose files
- Credentials and environment files
- Full documentation

**Backup takes:** ~5-10 minutes depending on your config size  
**Space required:** ~5-10GB (compressed)

### 3️⃣ Follow Migration Guide

```bash
cat MIGRATION_GUIDE.md
```

Complete step-by-step instructions for setting up Linux and restoring everything.

---

## What Each Script Does

### `verify_before_migration.sh`
**Pre-flight check** - Verifies your system is ready for backup
- Checks storage availability
- Validates Docker and services
- Confirms all configs exist
- Reports any issues

**Usage:**
```bash
./verify_before_migration.sh
```

### `backup_to_d_drive.sh`
**Complete backup** - Creates timestamped backup of everything
- Backs up all services
- Exports databases
- Captures Docker state
- Creates compressed archive
- Generates restore script

**Usage:**
```bash
# Default location: /mnt/d/homelab-backup/
./backup_to_d_drive.sh

# Custom location:
./backup_to_d_drive.sh /path/to/backup
```

**What gets backed up:**
```
homelab-backup/
├── configs/              # All service configurations
│   ├── radarr/
│   ├── sonarr/
│   ├── jellyfin/
│   └── ...
├── docker/               # Docker state
│   ├── containers.txt
│   ├── volumes.txt
│   └── compose-configs/
├── scripts/              # All automation scripts
├── docs/                 # Documentation
├── repo/                 # Complete repository
├── system-info/          # System information
├── MIGRATION_NOTES.md    # Migration instructions
├── restore.sh            # Restore script
└── backup_summary.txt    # Backup summary
```

### `MIGRATION_GUIDE.md`
**Complete migration guide** - Step-by-step instructions
- Linux installation
- Restore process
- Configuration updates
- Troubleshooting
- Post-migration checklist

---

## Migration Workflow

```
┌─────────────────────┐
│  Windows + WSL2     │
│                     │
│  1. Verify System   │ ← ./verify_before_migration.sh
│  2. Stop Services   │ ← docker compose down (optional)
│  3. Backup All      │ ← ./backup_to_d_drive.sh
│  4. Copy to USB     │ ← Optional: external storage
└─────────────────────┘
          │
          ▼
┌─────────────────────┐
│   Install Linux     │
│                     │
│  - Ubuntu/Fedora    │
│  - Install Docker   │
│  - Mount drives     │
└─────────────────────┘
          │
          ▼
┌─────────────────────┐
│  Restore & Start    │
│                     │
│  1. Extract backup  │ ← tar -xzf backup.tar.gz
│  2. Run restore     │ ← ./restore.sh ~/homelab
│  3. Update paths    │ ← Edit .env files
│  4. Start services  │ ← docker compose up -d
└─────────────────────┘
```

---

## Backup Structure

After running the backup, you'll have:

```
/mnt/d/homelab-backup/
└── 20231214_143022/                    # Timestamped directory
    ├── configs/                        # All service configs
    │   ├── radarr/
    │   │   ├── config.xml
    │   │   ├── radarr.db
    │   │   └── Backups/
    │   ├── sonarr/
    │   ├── jellyfin/
    │   └── ...
    ├── docker/
    │   ├── containers.txt              # Running containers list
    │   ├── volumes.txt                 # Docker volumes
    │   └── compose-config_*.yaml       # Validated compose files
    ├── scripts/
    │   └── [all .sh and .py files]
    ├── repo/                           # Complete repository
    │   ├── media/
    │   ├── monitoring/
    │   └── ...
    ├── system-info/
    │   ├── system.txt                  # System information
    │   └── docker-info.txt             # Docker info
    ├── MIGRATION_NOTES.md              # 📖 Migration instructions
    ├── restore.sh                      # 🔧 Restore script
    └── backup_summary.txt              # 📊 Backup summary
    
# Plus compressed archive:
homelab_backup_20231214_143022.tar.gz   # Everything compressed
```

---

## Common Questions

### Q: How long does the backup take?
**A:** 5-10 minutes for configs/databases. Does not backup media files (movies/shows) - only metadata.

### Q: What about my media files?
**A:** Media files (movies, shows, music) are not backed up by this script - they're too large. You should:
- Keep them on a separate drive
- Note the paths in your .env file
- Mount them on your new Linux system

### Q: Can I test the restore without breaking anything?
**A:** Yes! Extract the backup on your new Linux system and test before decommissioning Windows.

### Q: What if I find issues after migrating?
**A:** Keep your Windows system for a week or two after migration to ensure everything works.

### Q: Do I need to stop services before backup?
**A:** Not required, but recommended for consistency. Run:
```bash
cd ~/repos/homelab/media && docker compose down
cd ~/repos/homelab/monitoring && docker compose down
cd ~/repos/homelab/proxy && docker compose down
```

### Q: How much space do I need on D drive?
**A:** ~10-20GB recommended (5-10GB for backup, plus room for the compressed archive).

### Q: Can I backup to a different location?
**A:** Yes! Pass a custom path:
```bash
./backup_to_d_drive.sh /mnt/usb/backups
./backup_to_d_drive.sh ~/backups
```

### Q: What Linux distro should I use?
**A:** Recommended:
- **Ubuntu Server 22.04 LTS** - Most popular, great support
- **Fedora Server** - Cutting edge, modern packages
- **Debian 12** - Very stable

---

## Troubleshooting

### "D drive not mounted"
```bash
# Check if mounted
ls /mnt/d

# Mount manually if needed
sudo mount /dev/sdX /mnt/d
```

### "Docker not found"
```bash
# Check Docker status
docker --version
systemctl status docker

# Start Docker if needed
sudo systemctl start docker
```

### "Permission denied"
```bash
# Make scripts executable
chmod +x *.sh

# Fix ownership
sudo chown -R $USER:$USER ~/repos/homelab
```

---

## After Migration

Once restored on Linux:

1. **Verify all services start**
   ```bash
   cd ~/homelab/media
   docker compose ps
   ```

2. **Check logs for errors**
   ```bash
   docker compose logs -f
   ```

3. **Test each service**
   - Access web interfaces
   - Test downloads
   - Verify media playback

4. **Set up backups**
   ```bash
   # Add to crontab
   crontab -e
   # Add: 0 2 * * * ~/homelab/backup_to_d_drive.sh /mnt/backup
   ```

5. **Keep Windows available for 1-2 weeks**
   - Don't delete anything yet
   - Ensure everything works on Linux first

---

## Support

- **Migration Guide**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- **Original Repo**: https://github.com/TechHutTV/homelab
- **Docker Docs**: https://docs.docker.com/
- **Servarr Wiki**: https://wiki.servarr.com/

---

## Quick Command Reference

```bash
# Pre-migration
./verify_before_migration.sh           # Check system
./backup_to_d_drive.sh                # Backup everything
cat MIGRATION_GUIDE.md                # Read migration guide

# Post-migration (on Linux)
tar -xzf homelab_backup_*.tar.gz      # Extract backup
cd homelab_backup_*/
./restore.sh ~/homelab                # Restore to ~/homelab
cd ~/homelab/media
nano .env                             # Update paths
docker compose up -d                  # Start services
```

---

**Ready to migrate? Start with:** `./verify_before_migration.sh` 🚀
