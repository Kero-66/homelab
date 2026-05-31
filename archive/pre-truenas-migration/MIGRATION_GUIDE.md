# Windows to Linux Migration Guide

## Quick Start - Backup Everything

### 1. Run the Backup Script

```bash
cd ~/repos/homelab
./backup_to_d_drive.sh
```

This will create a complete backup at `/mnt/d/homelab-backup/YYYYMMDD_HHMMSS/` including:
- ✅ All configurations
- ✅ All databases
- ✅ All scripts
- ✅ Docker state
- ✅ Credentials
- ✅ Documentation

### 2. Verify the Backup

```bash
# Check backup location
ls -lh /mnt/d/homelab-backup/

# View the latest backup
cd /mnt/d/homelab-backup/
ls -lht | head -5

# Check the compressed archive
ls -lh *.tar.gz
```

### 3. Optional: Copy to Additional Storage

```bash
# Copy to USB drive
cp /mnt/d/homelab-backup/homelab_backup_*.tar.gz /mnt/usb/

# Or upload to cloud
rclone copy /mnt/d/homelab-backup/homelab_backup_*.tar.gz remote:backups/
```

## What Gets Backed Up

| Category | Items | Location in Backup |
|----------|-------|-------------------|
| **Configurations** | All *arr apps, Jellyfin, download clients | `configs/` |
| **Databases** | SQLite DBs, PostgreSQL dumps | `configs/*/` |
| **Docker** | Compose files, container lists, networks | `docker/`, `repo/` |
| **Scripts** | All automation and helper scripts | `scripts/`, `repo/` |
| **Credentials** | `.env` files, `.credentials` | `configs/` |
| **Documentation** | READMEs, notes, changelogs | `docs/`, `repo/` |
| **System Info** | Docker info, running containers | `system-info/` |

## Migration Process

### Phase 1: Backup (Windows/WSL2)

1. **Stop services** (optional, but recommended for consistency):
   ```bash
   cd ~/repos/homelab/media
   docker compose down
   cd ~/repos/homelab/monitoring
   docker compose down
   cd ~/repos/homelab/proxy
   docker compose down
   ```

2. **Run backup**:
   ```bash
   cd ~/repos/homelab
   ./backup_to_d_drive.sh
   ```

3. **Verify backup completed**:
   - Check `/mnt/d/homelab-backup/` for the timestamped folder
   - Review `MIGRATION_NOTES.md` in the backup
   - Verify the `.tar.gz` archive was created

### Phase 2: Setup New Linux System

1. **Install Linux** (Ubuntu Server 22.04 LTS or Fedora Server recommended)

2. **Install Prerequisites**:
   ```bash
   # For Ubuntu/Debian
   sudo apt update
   sudo apt install -y docker.io docker-compose git rsync curl wget tree
   sudo usermod -aG docker $USER
   
   # For Fedora
   sudo dnf install -y docker docker-compose git rsync curl wget tree
   sudo systemctl enable --now docker
   sudo usermod -aG docker $USER
   
   # Log out and back in for group changes
   ```

3. **Mount Data Drive**:
   ```bash
   # Find your drive
   lsblk
   sudo blkid
   
   # Create mount point
   sudo mkdir -p /mnt/data
   
   # Mount temporarily to test
   sudo mount /dev/sdX1 /mnt/data
   
   # Add to /etc/fstab for automatic mounting
   # Get UUID: sudo blkid /dev/sdX1
   sudo nano /etc/fstab
   # Add: UUID=your-uuid-here /mnt/data ext4 defaults 0 2
   
   # Test fstab
   sudo umount /mnt/data
   sudo mount -a
   ```

### Phase 3: Restore

1. **Transfer backup to new system**:
   ```bash
   # Option A: Copy from USB/external drive
   cp /media/usb/homelab_backup_*.tar.gz ~/
   
   # Option B: Transfer over network
   scp user@windows-pc:/mnt/d/homelab-backup/homelab_backup_*.tar.gz ~/
   
   # Option C: Use the D drive if you can access it on Linux
   sudo mount /dev/sdX /mnt/old-d-drive
   cp /mnt/old-d-drive/homelab-backup/homelab_backup_*.tar.gz ~/
   ```

2. **Extract backup**:
   ```bash
   cd ~
   tar -xzf homelab_backup_*.tar.gz
   cd homelab_backup_*/
   ```

3. **Run restore script**:
   ```bash
   ./restore.sh ~/homelab
   ```

4. **Update configuration for Linux**:
   ```bash
   cd ~/homelab/media
   nano .env
   ```
   
   Change paths:
   ```bash
   # OLD (Windows/WSL2):
   DATA_DIR=/mnt/d/homelab-data
   
   # NEW (Native Linux):
   DATA_DIR=/mnt/data/homelab-data
   ```

5. **Restore service configurations**:
   ```bash
   # The backup includes a configs/ directory
   # Copy each service config back
   
   cd ~/homelab_backup_*/configs
   cp -r radarr ~/homelab/media/
   cp -r sonarr ~/homelab/media/
   cp -r lidarr ~/homelab/media/
   cp -r prowlarr ~/homelab/media/
   cp -r bazarr ~/homelab/media/
   cp -r jellyfin ~/homelab/media/jellyfin/config
   cp -r jellyseerr ~/homelab/media/jellyfin/
   cp -r qbittorrent ~/homelab/media/
   # ... etc
   ```

6. **Restore databases**:
   ```bash
   # Start PostgreSQL container first
   cd ~/homelab/media
   docker compose up -d jellystat-db
   sleep 10
   
   # Restore Jellystat database
   docker exec -i jellystat-db psql -U postgres < ~/homelab_backup_*/configs/jellystat/postgres_dump.sql
   ```

### Phase 4: Start Services

1. **Start media stack**:
   ```bash
   cd ~/homelab/media
   docker compose up -d
   ```

2. **Check logs**:
   ```bash
   docker compose logs -f
   # Ctrl+C to exit
   ```

3. **Verify services**:
   - Jellyfin: http://your-linux-ip:8096
   - Radarr: http://your-linux-ip:7878
   - Sonarr: http://your-linux-ip:8989
   - Prowlarr: http://your-linux-ip:9696
   - qBittorrent: http://your-linux-ip:8080

4. **Start other stacks**:
   ```bash
   cd ~/homelab/monitoring
   docker compose up -d
   
   cd ~/homelab/proxy
   docker compose up -d
   
   cd ~/homelab/surveillance
   docker compose up -d
   ```

## Post-Migration Checklist

- [ ] All services start successfully
- [ ] Can access all web interfaces
- [ ] Download clients can download (test with a small file)
- [ ] Indexers working in Prowlarr
- [ ] *arr apps can see and import media
- [ ] Jellyfin can play media files
- [ ] Monitoring dashboards show data
- [ ] Backups configured (cron jobs)
- [ ] Reverse proxy working (if using)
- [ ] VPN working (if using Gluetun)

## Troubleshooting

### Permissions Issues

```bash
# Fix ownership of homelab directory
sudo chown -R $USER:$USER ~/homelab

# Fix ownership of data directory
sudo chown -R $USER:$USER /mnt/data/homelab-data

# Make scripts executable
chmod +x ~/homelab/media/*.sh
chmod +x ~/homelab/media/jellyfin/*.sh
chmod +x ~/homelab/media/scripts/*.sh
```

### Container Won't Start

```bash
# Check logs
cd ~/homelab/media
docker compose logs [service-name]

# Restart specific service
docker compose restart [service-name]

# Recreate service
docker compose up -d --force-recreate [service-name]
```

### Path Issues

Common path changes needed:

| Service | Config File | Setting to Update |
|---------|-------------|-------------------|
| *arr apps | `config.xml` | Root folders paths |
| qBittorrent | `qBittorrent.conf` | Download paths |
| Jellyfin | Web UI | Library paths |

### Database Issues

```bash
# Reset Jellystat if needed
docker compose down jellystat jellystat-db
docker volume rm media_jellystat-db-data
docker compose up -d jellystat-db
# Wait 30 seconds
docker exec -i jellystat-db psql -U postgres < backup/postgres_dump.sql
docker compose up -d jellystat
```

## Performance Improvements on Linux

Native Linux will likely be faster than WSL2. Consider:

1. **Enable Docker BuildKit**:
   ```bash
   echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
   ```

2. **Optimize Docker**:
   ```bash
   sudo nano /etc/docker/daemon.json
   ```
   ```json
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     }
   }
   ```

3. **Set up automatic updates**:
   ```bash
   # Ubuntu/Debian
   sudo apt install unattended-upgrades
   
   # Fedora
   sudo dnf install dnf-automatic
   sudo systemctl enable --now dnf-automatic.timer
   ```

## Backup Strategy on Linux

Set up automated backups:

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /home/youruser/homelab/backup_to_d_drive.sh /mnt/backup

# Weekly full backup
0 3 * * 0 /home/youruser/homelab/backup_to_d_drive.sh /mnt/backup-weekly
```

## Resources

- **Docker Docs**: https://docs.docker.com/
- **Servarr Wiki**: https://wiki.servarr.com/
- **Jellyfin Docs**: https://jellyfin.org/docs/
- **TRaSH Guides**: https://trash-guides.info/

## Support

If issues arise:

1. Check service logs: `docker compose logs -f [service]`
2. Check system logs: `journalctl -u docker -f`
3. Review service-specific documentation in `~/homelab/[service]/README.md`
4. Check the original repo: https://github.com/TechHutTV/homelab

---

**Good luck with your migration! Welcome to native Linux! 🐧🎉**
