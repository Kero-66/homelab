#!/bin/bash
set -e

# =============================================================================
# Media Stack Backup Script
# =============================================================================
# Creates timestamped backups of all service configurations and databases.
#
# Usage:
#   ./backup.sh                    # Backup to ./backups/
#   ./backup.sh /path/to/backups   # Backup to custom location
#   ./backup.sh --restore latest   # Restore from latest backup
#
# What gets backed up:
#   - All *arr app configs (config.xml, databases)
#   - Download client configs (qBittorrent)
#   - Jellyfin configuration
#   - Jellyseerr settings
#   - Jellystat database (PostgreSQL dump)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="${1:-$SCRIPT_DIR/backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="media_backup_$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Restore Mode
# -----------------------------------------------------------------------------
if [[ "$1" == "--restore" ]]; then
    RESTORE_TARGET="$2"
    
    if [[ -z "$RESTORE_TARGET" ]]; then
        echo "Usage: $0 --restore <backup_name|latest>"
        echo ""
        echo "Available backups:"
        ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | xargs -n1 basename || echo "  No backups found"
        exit 1
    fi
    
    if [[ "$RESTORE_TARGET" == "latest" ]]; then
        RESTORE_FILE=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    else
        RESTORE_FILE="$BACKUP_DIR/$RESTORE_TARGET"
        [[ ! "$RESTORE_FILE" == *.tar.gz ]] && RESTORE_FILE="${RESTORE_FILE}.tar.gz"
    fi
    
    if [[ ! -f "$RESTORE_FILE" ]]; then
        log_error "Backup not found: $RESTORE_FILE"
        exit 1
    fi
    
    log_warn "This will overwrite current configurations!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    log_info "Stopping services..."
    docker compose down 2>/dev/null || true
    
    log_info "Restoring from: $(basename "$RESTORE_FILE")"
    tar -xzf "$RESTORE_FILE" -C "$SCRIPT_DIR"
    
    log_info "Restore complete! Start services with: docker compose up -d"
    exit 0
fi

# -----------------------------------------------------------------------------
# Backup Mode
# -----------------------------------------------------------------------------
echo "════════════════════════════════════════════════════════════"
echo "  Media Stack Backup"
echo "════════════════════════════════════════════════════════════"
echo ""

mkdir -p "$BACKUP_DIR"
TEMP_DIR=$(mktemp -d)
BACKUP_PATH="$TEMP_DIR/$BACKUP_NAME"
mkdir -p "$BACKUP_PATH"

log_info "Creating backup: $BACKUP_NAME"
echo ""

# Backup function
backup_service() {
    local SERVICE=$1
    local SOURCE=$2
    local INCLUDE_PATTERN="${3:-*}"
    
    if [[ -d "$SOURCE" ]]; then
        log_info "Backing up $SERVICE..."
        mkdir -p "$BACKUP_PATH/$SERVICE"
        
        # Copy config files (exclude large cache/log directories)
        rsync -a --exclude='logs/' --exclude='log/' --exclude='Logs/' \
              --exclude='cache/' --exclude='Cache/' \
              --exclude='MediaCover/' --exclude='Sentry/' \
              --exclude='*.log' --exclude='*.pid' \
              "$SOURCE/" "$BACKUP_PATH/$SERVICE/" 2>/dev/null || \
        cp -r "$SOURCE"/* "$BACKUP_PATH/$SERVICE/" 2>/dev/null || true
        
        echo "  ✓ $SERVICE"
    else
        log_warn "$SERVICE directory not found, skipping"
    fi
}

# Backup all services
backup_service "sonarr" "./sonarr"
backup_service "radarr" "./radarr"
backup_service "lidarr" "./lidarr"
backup_service "prowlarr" "./prowlarr"
backup_service "bazarr" "./bazarr"
backup_service "qbittorrent" "./qbittorrent"
backup_service "jellyfin-config" "./jellyfin/config"
backup_service "jellyseerr" "./jellyfin/jellyseerr"

# Backup Jellystat PostgreSQL database
if docker ps --format '{{.Names}}' | grep -q "jellystat-db"; then
    log_info "Backing up Jellystat database..."
    mkdir -p "$BACKUP_PATH/jellystat"
    docker exec jellystat-db pg_dump -U "${JELLYSTAT_DB_USER:-postgres}" > "$BACKUP_PATH/jellystat/database.sql" 2>/dev/null && \
        echo "  ✓ Jellystat database" || \
        log_warn "Could not backup Jellystat database"
fi

# Backup .env (without sensitive values)
if [[ -f ".env" ]]; then
    log_info "Backing up .env template..."
    # Mask sensitive values
    sed -E 's/(PASSWORD|KEY|SECRET)=.*/\1=REDACTED/' .env > "$BACKUP_PATH/.env.backup"
    echo "  ✓ .env (sensitive values masked)"
fi

# Backup credentials template
if [[ -f ".config/.credentials" ]]; then
    log_info "Backing up credentials structure..."
    echo "USERNAME=REDACTED" > "$BACKUP_PATH/credentials.template"
    echo "PASSWORD=REDACTED" >> "$BACKUP_PATH/credentials.template"
    echo "  ✓ credentials template"
fi

echo ""
log_info "Compressing backup..."

# Create compressed archive
ARCHIVE_PATH="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
tar -czf "$ARCHIVE_PATH" -C "$TEMP_DIR" "$BACKUP_NAME"

# Cleanup
rm -rf "$TEMP_DIR"

# Calculate size
BACKUP_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Backup Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Location: $ARCHIVE_PATH"
echo "Size: $BACKUP_SIZE"
echo ""
echo "To restore: $0 --restore $BACKUP_NAME"
echo ""

# Cleanup old backups (keep last 5)
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
if [[ $BACKUP_COUNT -gt 5 ]]; then
    log_info "Cleaning up old backups (keeping last 5)..."
    ls -t "$BACKUP_DIR"/*.tar.gz | tail -n +6 | xargs rm -f
fi
