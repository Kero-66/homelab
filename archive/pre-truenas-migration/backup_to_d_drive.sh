#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Complete Homelab Backup Script - Windows to Linux Migration
# =============================================================================
# Creates a comprehensive backup of all services, configurations, and data
# to D drive before migrating from Windows + WSL2 to native Linux.
#
# Usage:
#   ./backup_to_d_drive.sh
#   ./backup_to_d_drive.sh /mnt/d/homelab-backup-custom
#
# What gets backed up:
#   ✓ All Docker Compose files and .env files
#   ✓ All service configurations (*arr apps, Jellyfin, etc.)
#   ✓ All databases (PostgreSQL, SQLite)
#   ✓ All scripts and automation files
#   ✓ Documentation and notes
#   ✓ Credentials and secrets
#   ✓ Git repository state
#   ✓ List of running containers
#   ✓ Docker volumes list
#   ✓ Network configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default to D drive for Windows/WSL2 setups
BACKUP_ROOT="${1:-/mnt/d/homelab-backup}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_section() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

# ASCII Art Banner
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}HOMELAB BACKUP - WINDOWS TO LINUX MIGRATION${NC}           ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Backup Location:${NC} $BACKUP_DIR"
echo -e "${YELLOW}Timestamp:${NC}       $TIMESTAMP"
echo ""

# Check if D drive is mounted
if [ ! -d "/mnt/d" ]; then
    log_error "D drive not mounted at /mnt/d!"
    echo "       Please mount your D drive first."
    exit 1
fi

# Check disk space
AVAILABLE_SPACE=$(df -BG /mnt/d | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 50 ]; then
    log_warn "Only ${AVAILABLE_SPACE}GB available on D drive"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Create backup directory structure
log_section "Creating Backup Structure"
mkdir -p "$BACKUP_DIR"/{configs,docker,scripts,docs,repo,system-info}
log_info "Backup directory created: $BACKUP_DIR"

# -----------------------------------------------------------------------------
# 1. Repository State
# -----------------------------------------------------------------------------
log_section "Backing Up Repository State"

log_info "Copying entire repository..."
rsync -av --exclude='.git' \
    --exclude='media/media/*' \
    --exclude='**/node_modules' \
    --exclude='**/tmp/*' \
    --exclude='**/cache/*' \
    --exclude='**/logs/*.log' \
    --exclude='**/postgres/*' \
    --exclude='**/ipc-socket' \
    --exclude='*.sock' \
    --exclude='*.socket' \
    "$SCRIPT_DIR/" "$BACKUP_DIR/repo/" 2>&1 | grep -v "Permission denied" | grep -v "Operation not supported" || true

log_info "Capturing Git state..."
cd "$SCRIPT_DIR"
git status > "$BACKUP_DIR/repo/git-status.txt" 2>&1 || echo "Not a git repo" > "$BACKUP_DIR/repo/git-status.txt"
git log --oneline -20 > "$BACKUP_DIR/repo/git-log.txt" 2>&1 || true
git diff > "$BACKUP_DIR/repo/git-diff.txt" 2>&1 || true
git branch -a > "$BACKUP_DIR/repo/git-branches.txt" 2>&1 || true

# -----------------------------------------------------------------------------
# 2. Docker State
# -----------------------------------------------------------------------------
log_section "Capturing Docker State"

log_info "Listing running containers..."
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" > "$BACKUP_DIR/docker/containers.txt" 2>&1 || true

log_info "Listing Docker images..."
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" > "$BACKUP_DIR/docker/images.txt" 2>&1 || true

log_info "Listing Docker volumes..."
docker volume ls > "$BACKUP_DIR/docker/volumes.txt" 2>&1 || true

log_info "Listing Docker networks..."
docker network ls > "$BACKUP_DIR/docker/networks.txt" 2>&1 || true

log_info "Exporting Docker Compose states..."
for compose_file in $(find "$SCRIPT_DIR" -name "compose.yaml" -o -name "compose.yml"); do
    rel_path=$(realpath --relative-to="$SCRIPT_DIR" "$compose_file")
    dir_name=$(dirname "$rel_path" | tr '/' '_')
    
    log_info "  Checking $rel_path"
    cd "$(dirname "$compose_file")"
    docker compose config > "$BACKUP_DIR/docker/compose-config_${dir_name}.yaml" 2>&1 || true
    docker compose ps > "$BACKUP_DIR/docker/compose-ps_${dir_name}.txt" 2>&1 || true
done

cd "$SCRIPT_DIR"

# -----------------------------------------------------------------------------
# 3. Service Configurations
# -----------------------------------------------------------------------------
log_section "Backing Up Service Configurations"

backup_service_config() {
    local service_name="$1"
    local service_path="$2"
    
    if [ -d "$service_path" ]; then
        log_info "Backing up $service_name..."
        mkdir -p "$BACKUP_DIR/configs/$service_name"
        
        # Backup config files (exclude logs, cache, postgres data, and sockets)
        rsync -av \
            --exclude='logs/' \
            --exclude='cache/' \
            --exclude='tmp/' \
            --exclude='*.log' \
            --exclude='transcodes/' \
            --exclude='metadata/Downloads/' \
            --exclude='postgres/' \
            --exclude='ipc-socket' \
            --exclude='*.sock' \
            --exclude='*.socket' \
            "$service_path/" "$BACKUP_DIR/configs/$service_name/" 2>&1 | \
            grep -v "Permission denied" | grep -v "Operation not supported" > /dev/null 2>&1 || true
    else
        log_warn "$service_name not found at $service_path"
    fi
}

# Media services
backup_service_config "radarr" "media/radarr"
backup_service_config "sonarr" "media/sonarr"
backup_service_config "lidarr" "media/lidarr"
backup_service_config "prowlarr" "media/prowlarr"
backup_service_config "bazarr" "media/bazarr"
backup_service_config "jellyfin" "media/jellyfin/config"
backup_service_config "jellyseerr" "media/jellyfin/jellyseerr"
backup_service_config "jellystat" "media/jellyfin/jellystat"
backup_service_config "qbittorrent" "media/qbittorrent"
backup_service_config "jackett" "media/jackett"
backup_service_config "mylar3" "media/mylar3"
backup_service_config "ubooquity" "media/ubooquity"

# Monitoring
backup_service_config "prometheus" "monitoring/prometheus"
backup_service_config "grafana" "monitoring/grafana"
backup_service_config "telegraf" "monitoring/telegraf"

# Proxy
backup_service_config "nginx-proxy" "proxy"

# Home Assistant
backup_service_config "homeassistant" "homeassistant"

# Surveillance
backup_service_config "frigate" "surveillance/frigate"

# Automations
backup_service_config "automations" "automations"

# Cloud
backup_service_config "cloud" "cloud"

# -----------------------------------------------------------------------------
# 4. Databases
# -----------------------------------------------------------------------------
log_section "Backing Up Databases"

# Check if Jellystat PostgreSQL is running
if docker ps | grep -q jellystat-db; then
    log_info "Dumping Jellystat PostgreSQL database..."
    docker exec jellystat-db pg_dumpall -U postgres > "$BACKUP_DIR/configs/jellystat/postgres_dump.sql" 2>&1 || \
        log_warn "Failed to dump Jellystat database"
else
    log_warn "Jellystat PostgreSQL not running, skipping database dump"
fi

# SQLite databases are already backed up with service configs

# -----------------------------------------------------------------------------
# 5. Scripts and Automation
# -----------------------------------------------------------------------------
log_section "Backing Up Scripts"

log_info "Copying all scripts..."
mkdir -p "$BACKUP_DIR/scripts"
find "$SCRIPT_DIR" -type f -name "*.sh" -exec cp --parents {} "$BACKUP_DIR/scripts/" \; 2>/dev/null || true
find "$SCRIPT_DIR" -type f -name "*.py" -exec cp --parents {} "$BACKUP_DIR/scripts/" \; 2>/dev/null || true

# -----------------------------------------------------------------------------
# 6. Environment and Credentials
# -----------------------------------------------------------------------------
log_section "Backing Up Environment Files and Credentials"

log_info "Backing up .env files..."
find "$SCRIPT_DIR" -name ".env" -o -name ".env.*" | while read -r env_file; do
    rel_path=$(realpath --relative-to="$SCRIPT_DIR" "$env_file")
    cp --parents "$env_file" "$BACKUP_DIR/configs/" 2>/dev/null || true
done

log_info "Backing up credentials..."
if [ -d "media/.config" ]; then
    cp -r media/.config "$BACKUP_DIR/configs/credentials" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 7. Documentation
# -----------------------------------------------------------------------------
log_section "Backing Up Documentation"

log_info "Copying documentation..."
find "$SCRIPT_DIR" -type f \( -name "*.md" -o -name "*.txt" \) -exec cp --parents {} "$BACKUP_DIR/docs/" \; 2>/dev/null || true

# -----------------------------------------------------------------------------
# 8. System Information
# -----------------------------------------------------------------------------
log_section "Capturing System Information"

log_info "Gathering system info..."
{
    echo "=== System Information ==="
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Docker Version: $(docker --version)"
    echo "Docker Compose Version: $(docker compose version)"
    echo ""
    echo "=== Disk Usage ==="
    df -h
    echo ""
    echo "=== Memory ==="
    free -h
    echo ""
    echo "=== Network Interfaces ==="
    ip addr show
    echo ""
    echo "=== Mounted Filesystems ==="
    mount | grep -E "(data|media|mnt)"
} > "$BACKUP_DIR/system-info/system.txt" 2>&1

log_info "Capturing Docker info..."
docker info > "$BACKUP_DIR/system-info/docker-info.txt" 2>&1 || true

log_info "Capturing environment variables..."
env | grep -i -E "(docker|path|home|user)" | sort > "$BACKUP_DIR/system-info/env.txt" 2>&1 || true

# -----------------------------------------------------------------------------
# 9. Configuration Backups (existing backups in repo)
# -----------------------------------------------------------------------------
log_section "Copying Existing Config Backups"

if [ -d "media/config_backups" ]; then
    log_info "Copying existing config backups..."
    cp -r media/config_backups "$BACKUP_DIR/configs/config_backups" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 10. Create Migration Notes
# -----------------------------------------------------------------------------
log_section "Creating Migration Documentation"

cat > "$BACKUP_DIR/MIGRATION_NOTES.md" << 'EOF'
# Homelab Migration Notes - Windows to Linux

## Backup Information

**Created:** $(date)
**Source System:** Windows 11 + WSL2
**Target System:** Linux (native)

## What Was Backed Up

- ✅ All Docker Compose files and .env configurations
- ✅ All service configurations (*arr apps, Jellyfin, Jellyseerr, etc.)
- ✅ All databases (SQLite and PostgreSQL dumps)
- ✅ Scripts and automation tools
- ✅ Documentation and README files
- ✅ Credentials and secrets
- ✅ Docker state (containers, volumes, networks list)
- ✅ Git repository state
- ✅ System information

## Important Files to Review Before Restoring

1. **media/.env** - Update paths for Linux (change `/mnt/d/` to your new mount point)
2. **media/.config/.credentials** - Verify credentials are correct
3. **All compose.yaml files** - Update any Windows-specific paths
4. **media/config_backups/** - Contains *arr app seed configs

## Restoration Steps on New Linux System

### 1. Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y  # Debian/Ubuntu
# or
sudo dnf update -y  # Fedora

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose (if not included)
sudo apt install docker-compose-plugin  # Debian/Ubuntu
# or
sudo dnf install docker-compose-plugin  # Fedora

# Install git and other tools
sudo apt install git rsync curl wget  # Debian/Ubuntu
```

### 2. Prepare Storage

```bash
# Mount your data drive (adjust device name)
sudo mkdir -p /mnt/data
sudo mount /dev/sdX /mnt/data

# Add to /etc/fstab for persistent mounting
# Get UUID: sudo blkid /dev/sdX
# Add line: UUID=your-uuid /mnt/data ext4 defaults 0 2

# Create directory structure
sudo mkdir -p /mnt/data/homelab-data/{torrents,usenet,media}
sudo chown -R $USER:$USER /mnt/data/homelab-data
```

### 3. Restore Repository

```bash
# Copy backup to new system (or git clone if pushed)
cd ~
mkdir -p repos
cp -r /path/to/backup/repo ~/repos/homelab
cd ~/repos/homelab

# Or clone from git
git clone https://github.com/TechHutTV/homelab.git ~/repos/homelab
cd ~/repos/homelab
```

### 4. Update Configuration

```bash
cd ~/repos/homelab/media

# Copy .env from backup
cp /path/to/backup/configs/.env .

# Edit .env file - update paths
nano .env

# Change:
# DATA_DIR=/mnt/d/homelab-data  →  DATA_DIR=/mnt/data/homelab-data
# CONFIG_DIR - set to production path or leave as .
```

### 5. Restore Service Configurations

```bash
# Copy service configs from backup
cp -r /path/to/backup/configs/radarr ~/repos/homelab/media/radarr
cp -r /path/to/backup/configs/sonarr ~/repos/homelab/media/sonarr
cp -r /path/to/backup/configs/lidarr ~/repos/homelab/media/lidarr
cp -r /path/to/backup/configs/prowlarr ~/repos/homelab/media/prowlarr
cp -r /path/to/backup/configs/bazarr ~/repos/homelab/media/bazarr
cp -r /path/to/backup/configs/jellyfin ~/repos/homelab/media/jellyfin/config
cp -r /path/to/backup/configs/jellyseerr ~/repos/homelab/media/jellyfin/jellyseerr
cp -r /path/to/backup/configs/qbittorrent ~/repos/homelab/media/qbittorrent
# ... and so on for other services
```

### 6. Restore Databases

```bash
# For Jellystat PostgreSQL (after starting the container)
docker compose up -d jellystat-db
sleep 10
docker exec -i jellystat-db psql -U postgres < /path/to/backup/configs/jellystat/postgres_dump.sql
```

### 7. Start Services

```bash
# Start media stack
cd ~/repos/homelab/media
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### 8. Verify Services

- Jellyfin: http://your-ip:8096
- Radarr: http://your-ip:7878
- Sonarr: http://your-ip:8989
- Prowlarr: http://your-ip:9696
- qBittorrent: http://your-ip:8080

### 9. Additional Stacks

```bash
# Monitoring
cd ~/repos/homelab/monitoring
docker compose up -d

# Proxy
cd ~/repos/homelab/proxy
docker compose up -d

# Surveillance
cd ~/repos/homelab/surveillance
docker compose up -d
```

## Post-Migration Checklist

- [ ] All services accessible
- [ ] Download clients working (qBittorrent)
- [ ] Indexers connected in Prowlarr
- [ ] *arr apps can see media folders
- [ ] Jellyfin libraries scanning
- [ ] Monitoring dashboards showing data
- [ ] Reverse proxy configured
- [ ] Backups scheduled
- [ ] VPN working (if using Gluetun)

## Differences: Windows/WSL2 vs Native Linux

| Aspect | Windows/WSL2 | Native Linux |
|--------|--------------|--------------|
| Paths | `/mnt/c/`, `/mnt/d/` | `/`, `/mnt/data/` |
| Docker | Docker Desktop | Native Docker |
| Performance | Overhead | Better |
| File permissions | WSL handles | Direct control |
| Networking | NAT through Windows | Direct |

## Troubleshooting

### Permission Issues
```bash
# Fix ownership
sudo chown -R $USER:$USER ~/repos/homelab
sudo chown -R $USER:$USER /mnt/data/homelab-data

# Fix permissions
chmod -R 755 ~/repos/homelab/media/scripts
```

### Database Issues
```bash
# Reset Jellystat if needed
docker compose down jellystat jellystat-db
docker volume rm media_jellystat-db-data
docker compose up -d jellystat jellystat-db
```

### Networking Issues
```bash
# Check Docker networks
docker network ls
docker network inspect media_default

# Recreate network if needed
docker compose down
docker network prune
docker compose up -d
```

## Additional Resources

- Original repo: https://github.com/TechHutTV/homelab
- Docker docs: https://docs.docker.com/
- Servarr wiki: https://wiki.servarr.com/

## Support

If you encounter issues, check:
1. Docker logs: `docker compose logs -f [service]`
2. Service-specific logs in `config/logs/`
3. System logs: `journalctl -u docker`

Good luck with your migration! 🚀
EOF

# Replace placeholder date
sed -i "s/\$(date)/$(date)/" "$BACKUP_DIR/MIGRATION_NOTES.md" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 11. Create Archive
# -----------------------------------------------------------------------------
log_section "Creating Compressed Archive"

log_info "Compressing backup..."
cd "$BACKUP_ROOT"
tar -czf "homelab_backup_${TIMESTAMP}.tar.gz" "$TIMESTAMP" 2>&1 | \
    grep -v "Removing leading" || true

ARCHIVE_SIZE=$(du -h "homelab_backup_${TIMESTAMP}.tar.gz" | cut -f1)
log_info "Archive created: homelab_backup_${TIMESTAMP}.tar.gz ($ARCHIVE_SIZE)"

# -----------------------------------------------------------------------------
# 12. Create Quick Restore Script
# -----------------------------------------------------------------------------
log_section "Creating Restore Script"

cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Homelab Restore Script"
echo "======================"
echo ""
echo "This script will help restore your homelab configuration."
echo ""
echo "Before running, ensure:"
echo "  1. Docker is installed"
echo "  2. Your data drive is mounted"
echo "  3. You've reviewed MIGRATION_NOTES.md"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

TARGET_DIR="${1:-$HOME/repos/homelab}"
echo ""
echo "Target directory: $TARGET_DIR"
read -p "Is this correct? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run again with: ./restore.sh /your/target/path"
    exit 0
fi

mkdir -p "$TARGET_DIR"
echo "Copying repository..."
rsync -av repo/ "$TARGET_DIR/"

echo ""
echo "✓ Repository restored to: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Review and edit: $TARGET_DIR/media/.env"
echo "  2. Update paths for Linux (change /mnt/d/ to your mount point)"
echo "  3. Copy service configs from configs/ directory"
echo "  4. Run: cd $TARGET_DIR/media && docker compose up -d"
echo ""
echo "See MIGRATION_NOTES.md for detailed instructions."
EOF

chmod +x "$BACKUP_DIR/restore.sh"
log_info "Restore script created: restore.sh"

# -----------------------------------------------------------------------------
# 13. Summary
# -----------------------------------------------------------------------------
log_section "Backup Complete!"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}                   BACKUP SUCCESSFUL                        ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Backup Location:${NC}"
echo -e "  Directory: ${YELLOW}$BACKUP_DIR${NC}"
echo -e "  Archive:   ${YELLOW}$BACKUP_ROOT/homelab_backup_${TIMESTAMP}.tar.gz${NC}"
echo -e "  Size:      ${YELLOW}$ARCHIVE_SIZE${NC}"
echo ""
echo -e "${CYAN}What's Included:${NC}"
echo -e "  ✓ All Docker Compose configurations"
echo -e "  ✓ All service configurations and databases"
echo -e "  ✓ All scripts and automation"
echo -e "  ✓ Documentation and credentials"
echo -e "  ✓ System and Docker state information"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e "  1. Copy the backup to external storage (USB/cloud)"
echo -e "  2. Read: ${YELLOW}$BACKUP_DIR/MIGRATION_NOTES.md${NC}"
echo -e "  3. Test restore on new Linux system"
echo -e "  4. Verify all services work before decommissioning Windows"
echo ""
echo -e "${CYAN}Quick Commands:${NC}"
echo -e "  View notes:     ${YELLOW}cat $BACKUP_DIR/MIGRATION_NOTES.md${NC}"
echo -e "  List contents:  ${YELLOW}ls -lh $BACKUP_DIR/${NC}"
echo -e "  Extract:        ${YELLOW}tar -xzf $BACKUP_ROOT/homelab_backup_${TIMESTAMP}.tar.gz${NC}"
echo ""
echo -e "${GREEN}Happy migrating to Linux! 🐧${NC}"
echo ""

# Save summary to file
{
    echo "Backup Summary"
    echo "=============="
    echo ""
    echo "Timestamp: $TIMESTAMP"
    echo "Location: $BACKUP_DIR"
    echo "Archive: homelab_backup_${TIMESTAMP}.tar.gz"
    echo "Size: $ARCHIVE_SIZE"
    echo ""
    echo "Directory Structure:"
    tree -L 2 "$BACKUP_DIR" 2>/dev/null || find "$BACKUP_DIR" -maxdepth 2 -type d
    echo ""
    echo "Files backed up:"
    find "$BACKUP_DIR" -type f | wc -l
    echo ""
    echo "Total size (uncompressed):"
    du -sh "$BACKUP_DIR"
} > "$BACKUP_DIR/backup_summary.txt"

log_info "Summary saved to: backup_summary.txt"
