# Media Stack Migration Guide

This guide explains how to migrate your media stack from one machine (e.g., desktop/WSL) to a dedicated media server.

## Quick Migration (< 30 minutes)

### On Your Current Machine

1. **Create a backup**
   ```bash
   cd /home/kero66/repos/homelab/media
   ./backup.sh
   ```
   This creates a timestamped backup in `./backups/`

2. **Copy the backup to your new server**
   ```bash
   # Option A: SCP
   scp backups/media_backup_*.tar.gz user@newserver:/tmp/
   
   # Option B: USB drive, network share, etc.
   ```

3. **Note your current configuration**
   - Copy your `.env` file
   - Copy your `.config/.credentials` file
   - Note any VPN credentials if using Gluetun

### On Your New Server

1. **Install prerequisites**
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install -y docker.io docker-compose-v2 git curl
   
   # Add user to docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Clone the repository**
   ```bash
   git clone https://github.com/kieranmcjannett-coder/homelab.git
   cd homelab/media
   ```

3. **Restore your backup**
   ```bash
   ./backup.sh --restore /tmp/media_backup_*.tar.gz
   ```

4. **Update configuration for new server**
   ```bash
   # Edit .env with new server's settings
   nano .env
   
   # Key items to update:
   # - TZ (if different timezone)
   # - PUID/PGID (run: id $USER)
   # - DATA_DIR (if different path)
   # - VPN settings (if applicable)
   ```

5. **Create data directory on new server**
   ```bash
   # If using local storage
   sudo mkdir -p /data
   sudo chown -R $(id -u):$(id -g) /data
   
   # Or mount your NAS/network share
   # See "Network Storage" section below
   ```

6. **Deploy**
   ```bash
   ./deploy.sh --full
   ```

---

## Fresh Installation (New Server, No Migration)

If starting fresh without migrating existing data:

```bash
# 1. Clone repository
git clone https://github.com/kieranmcjannett-coder/homelab.git
cd homelab/media

# 2. Run deployment (interactive)
./deploy.sh --full

# That's it! Follow the prompts.
```

---

## Network Storage Setup

### Option 1: NFS Mount (Recommended for Linux servers)

```bash
# Install NFS client
sudo apt install nfs-common

# Create mount point
sudo mkdir -p /data

# Add to /etc/fstab
echo "nas.local:/volume1/media /data nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Mount
sudo mount -a
```

### Option 2: CIFS/SMB Mount (Windows shares, Synology, etc.)

```bash
# Install CIFS utilities
sudo apt install cifs-utils

# Create credentials file (secure)
sudo nano /etc/samba/.credentials
# Add:
# username=your_nas_user
# password=your_nas_password

sudo chmod 600 /etc/samba/.credentials

# Add to /etc/fstab
echo "//nas.local/media /data cifs credentials=/etc/samba/.credentials,uid=1000,gid=1000,iocharset=utf8 0 0" | sudo tee -a /etc/fstab

# Mount
sudo mount -a
```

### Option 3: Local Storage with Symlinks

If your media is on a different drive:

```bash
# Mount drive (adjust device name)
sudo mount /dev/sdb1 /mnt/media-drive

# Create symlinks
sudo ln -s /mnt/media-drive /data
```

---

## Server-Specific Configurations

### Proxmox LXC Container

If running in Proxmox LXC:

1. Enable TUN device for VPN:
   ```bash
   # In Proxmox host, edit container config
   nano /etc/pve/lxc/<container_id>.conf
   
   # Add:
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net dev/net none bind,create=dir
   ```

2. Enable nesting for Docker:
   ```bash
   # In container config
   features: nesting=1
   ```

### Unraid

1. Use the Community Applications plugin to install Docker Compose Manager
2. Clone this repo to `/mnt/user/appdata/homelab`
3. Update `DATA_DIR` in `.env` to match your Unraid share paths

### TrueNAS Scale

1. Use the built-in Docker/Kubernetes support
2. Mount datasets as `/data` in the container
3. Ensure PUID/PGID match your TrueNAS user

---

## Post-Migration Checklist

After migration, verify everything works:

```bash
# Run verification script
./verify_setup.sh

# Check all services are healthy
docker compose ps

# Test playback in Jellyfin
# Test downloads in Sonarr/Radarr
# Verify VPN is working (if enabled)
curl -s https://ipinfo.io/ip
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Permission denied on /data | Run: `sudo chown -R $(id -u):$(id -g) /data` |
| Container can't reach another | Check they're on same Docker network |
| VPN not connecting | Verify WireGuard keys in `.env` |
| qBittorrent stuck | Check VPN health: `docker logs gluetun` |
| Services timing out | Increase healthcheck timeouts in compose.yaml |

---

## Updating After Migration

To pull updates from the repository:

```bash
cd /path/to/homelab/media

# Backup first
./backup.sh

# Pull updates
git pull origin main

# Restart services
docker compose down
docker compose --profile all up -d

# Re-run automation if needed
./deploy.sh --non-interactive
```

---

## Rollback

If something goes wrong:

```bash
# Stop everything
docker compose --profile all down

# Restore from backup
./backup.sh --restore latest

# Restart
docker compose --profile all up -d
```
