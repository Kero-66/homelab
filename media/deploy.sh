#!/bin/bash
set -e

# =============================================================================
# Media Stack - One-Command Deployment
# =============================================================================
# Fully automated deployment of the complete media stack.
#
# Usage:
#   ./deploy.sh                          # Interactive mode (prompts for config)
#   ./deploy.sh --non-interactive        # Use defaults/env vars only
#   ./deploy.sh --with-vpn               # Include VPN services
#   ./deploy.sh --with-jellyfin          # Include Jellyfin stack
#   ./deploy.sh --full                   # Everything (VPN + Jellyfin)
#   ./deploy.sh --destroy                # Remove everything and start fresh
#
# Environment variables (optional, will prompt if not set):
#   MEDIA_USERNAME    - Username for all services
#   MEDIA_PASSWORD    - Password for all services
#   MEDIA_DATA_DIR    - Data directory (default: /data)
#   MEDIA_CONFIG_DIR  - Config directory (default: . for dev, /opt/docker/media for prod)
#   MEDIA_TZ          - Timezone (default: UTC)
#   MEDIA_PUID        - User ID (default: 1000)
#   MEDIA_PGID        - Group ID (default: 1000)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Default values
DATA_DIR="${MEDIA_DATA_DIR:-/data}"
CONFIG_DIR="${MEDIA_CONFIG_DIR:-.}"
TZ="${MEDIA_TZ:-UTC}"
PUID="${MEDIA_PUID:-1000}"
PGID="${MEDIA_PGID:-1000}"
NON_INTERACTIVE=false
PROFILE_ARGS=""
DESTROY_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --with-vpn) PROFILE_ARGS="$PROFILE_ARGS --profile vpn"; shift ;;
        --with-jellyfin) PROFILE_ARGS="$PROFILE_ARGS --profile jellyfin"; shift ;;
        --full) PROFILE_ARGS="--profile all"; shift ;;
        --destroy) DESTROY_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --non-interactive    Don't prompt for input, use env vars/defaults"
            echo "  --with-vpn          Include VPN (Gluetun) services"
            echo "  --with-jellyfin     Include Jellyfin stack (Jellyfin, Jellyseerr, Jellystat)"
            echo "  --full              Include all optional services"
            echo "  --destroy           Remove all containers and volumes, start fresh"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "  Media Stack Deployment"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# Destroy mode
# -----------------------------------------------------------------------------
if [ "$DESTROY_MODE" = true ]; then
    log_warn "DESTROY MODE - This will remove all containers, volumes, and configs!"
    log_warn "This will DELETE watched history, plugins, and all user data!"
    if [ "$NON_INTERACTIVE" = false ]; then
        read -p "Are you sure? Type 'yes' to confirm: " -r
        if [[ ! $REPLY == "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    log_step "Stopping and removing containers..."
    docker compose --profile all down -v 2>/dev/null || true
    
    log_step "Removing configuration directories..."
    rm -rf sonarr radarr lidarr prowlarr bazarr nzbget qbittorrent gluetun 2>/dev/null || true
    rm -rf jellyfin/config jellyfin/jellyseerr jellyfin/jellystat 2>/dev/null || true
    
    log_info "Destruction complete. Run deploy.sh again to redeploy."
    exit 0
fi

# -----------------------------------------------------------------------------
# Backup Jellyfin user data before any changes (watched status, plugins)
# -----------------------------------------------------------------------------
backup_jellyfin_userdata() {
    if [ -d "jellyfin/config/data/data" ]; then
        log_info "Backing up Jellyfin user data (watched status, plugins)..."
        BACKUP_DIR="jellyfin/.userdata-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        # Backup database (contains watched status, users, settings)
        cp jellyfin/config/data/data/jellyfin.db "$BACKUP_DIR/" 2>/dev/null || true
        # Backup plugins
        cp -r jellyfin/config/data/plugins "$BACKUP_DIR/" 2>/dev/null || true
        echo "$BACKUP_DIR" > jellyfin/.last-backup
        log_info "✓ User data backed up to $BACKUP_DIR"
    fi
}

restore_jellyfin_userdata() {
    if [ -f "jellyfin/.last-backup" ]; then
        BACKUP_DIR=$(cat jellyfin/.last-backup)
        if [ -d "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/jellyfin.db" ]; then
            log_info "Restoring Jellyfin user data from backup..."
            # Wait for Jellyfin to create initial structure
            sleep 5
            docker stop jellyfin 2>/dev/null || true
            cp "$BACKUP_DIR/jellyfin.db" jellyfin/config/data/data/jellyfin.db 2>/dev/null || true
            cp -r "$BACKUP_DIR/plugins/"* jellyfin/config/data/plugins/ 2>/dev/null || true
            docker start jellyfin 2>/dev/null || true
            log_info "✓ User data restored (watched status, plugins)"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Step 1: Check prerequisites
# -----------------------------------------------------------------------------
log_step "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    log_info "See: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose (v2) is not installed."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running. Please start Docker."
    exit 1
fi

log_info "✓ Docker and Docker Compose ready"

# -----------------------------------------------------------------------------
# Step 2: Configure credentials
# -----------------------------------------------------------------------------
log_step "Configuring credentials..."

mkdir -p .config

if [ -f .config/.credentials ]; then
    log_info "Using existing .config/.credentials"
    source .config/.credentials
else
    if [ "$NON_INTERACTIVE" = true ]; then
        USERNAME="${MEDIA_USERNAME:-admin}"
        PASSWORD="${MEDIA_PASSWORD:-changeme}"
    else
        echo ""
        read -p "Enter username for all services [admin]: " USERNAME
        USERNAME="${USERNAME:-admin}"
        
        read -s -p "Enter password for all services: " PASSWORD
        echo ""
        if [ -z "$PASSWORD" ]; then
            log_error "Password cannot be empty"
            exit 1
        fi
    fi
    
    cat > .config/.credentials << EOF
USERNAME=$USERNAME
PASSWORD=$PASSWORD
EOF
    chmod 600 .config/.credentials
    log_info "✓ Credentials saved to .config/.credentials"
fi

# Ensure variables are set
source .config/.credentials

# -----------------------------------------------------------------------------
# Step 3: Configure environment
# -----------------------------------------------------------------------------
log_step "Configuring environment..."

if [ ! -f .env ]; then
    if [ "$NON_INTERACTIVE" = false ]; then
        # Detect timezone
        DETECTED_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
        read -p "Enter timezone [$DETECTED_TZ]: " TZ
        TZ="${TZ:-$DETECTED_TZ}"
        
        # Data directory
        read -p "Enter data directory [$DATA_DIR]: " INPUT_DATA_DIR
        DATA_DIR="${INPUT_DATA_DIR:-$DATA_DIR}"
        
        # Config directory (for production deployments)
        echo ""
        log_info "Config directory options:"
        echo "  . (current directory) - Simple, everything in one place (default)"
        echo "  /opt/docker/media     - Production, configs separate from code"
        read -p "Enter config directory [.]: " CONFIG_DIR
        CONFIG_DIR="${CONFIG_DIR:-.}"
        
        # User ID
        DETECTED_PUID=$(id -u)
        read -p "Enter user ID (PUID) [$DETECTED_PUID]: " PUID
        PUID="${PUID:-$DETECTED_PUID}"
        
        # Group ID
        DETECTED_PGID=$(id -g)
        read -p "Enter group ID (PGID) [$DETECTED_PGID]: " PGID
        PGID="${PGID:-$DETECTED_PGID}"
    fi
    
    # Generate .env from template
    if [ -f .env.example ]; then
        cp .env.example .env
        # Update values
        sed -i "s|^TZ=.*|TZ=$TZ|" .env
        sed -i "s|^PUID=.*|PUID=$PUID|" .env
        sed -i "s|^PGID=.*|PGID=$PGID|" .env
        sed -i "s|^DATA_DIR=.*|DATA_DIR=$DATA_DIR|" .env
        sed -i "s|^CONFIG_DIR=.*|CONFIG_DIR=$CONFIG_DIR|" .env
    else
        cat > .env << EOF
TZ=$TZ
PUID=$PUID
PGID=$PGID
DATA_DIR=$DATA_DIR
CONFIG_DIR=$CONFIG_DIR
EOF
    fi
    log_info "✓ Environment configured in .env"
else
    log_info "Using existing .env file"
    # Load DATA_DIR from existing .env
    DATA_DIR=$(grep -E "^DATA_DIR=" .env | cut -d'=' -f2 || echo "/data")
    CONFIG_DIR=$(grep -E "^CONFIG_DIR=" .env | cut -d'=' -f2 || echo ".")
fi

# -----------------------------------------------------------------------------
# Step 4: Create data directory structure
# -----------------------------------------------------------------------------
log_step "Creating data directory structure..."

if [ -d "$DATA_DIR" ]; then
    log_info "Data directory exists: $DATA_DIR"
else
    log_warn "Data directory does not exist: $DATA_DIR"
    
    if [ "$NON_INTERACTIVE" = false ]; then
        read -p "Create it now? (requires sudo) [Y/n]: " CREATE_DIR
        CREATE_DIR="${CREATE_DIR:-Y}"
    else
        CREATE_DIR="Y"
    fi
    
    if [[ $CREATE_DIR =~ ^[Yy] ]]; then
        sudo mkdir -p "$DATA_DIR"
        sudo chown -R "$PUID:$PGID" "$DATA_DIR"
        log_info "✓ Created $DATA_DIR"
    else
        log_error "Cannot continue without data directory"
        exit 1
    fi
fi

# Create subdirectories
log_info "Creating subdirectories..."
mkdir -p "$DATA_DIR/downloads/qbittorrent"/{completed,incomplete,torrents} 2>/dev/null || \
    sudo mkdir -p "$DATA_DIR/downloads/qbittorrent"/{completed,incomplete,torrents}
mkdir -p "$DATA_DIR/downloads/nzbget"/{completed,intermediate,nzb,queue,tmp} 2>/dev/null || \
    sudo mkdir -p "$DATA_DIR/downloads/nzbget"/{completed,intermediate,nzb,queue,tmp}
mkdir -p "$DATA_DIR"/{movies,shows,music,books,youtube} 2>/dev/null || \
    sudo mkdir -p "$DATA_DIR"/{movies,shows,music,books,youtube}

# Set permissions
sudo chown -R "$PUID:$PGID" "$DATA_DIR" 2>/dev/null || true

log_info "✓ Data directory structure ready"

# Create config directory if not current directory
if [ "$CONFIG_DIR" != "." ]; then
    log_info "Creating config directory: $CONFIG_DIR"
    if [ ! -d "$CONFIG_DIR" ]; then
        sudo mkdir -p "$CONFIG_DIR"
        sudo chown -R "$PUID:$PGID" "$CONFIG_DIR"
    fi
    # Create subdirectories for each service
    for svc in sonarr radarr lidarr prowlarr bazarr nzbget qbittorrent gluetun jellyfin/config jellyfin/jellyseerr jellyfin/jellystat; do
        mkdir -p "$CONFIG_DIR/$svc" 2>/dev/null || sudo mkdir -p "$CONFIG_DIR/$svc"
    done
    sudo chown -R "$PUID:$PGID" "$CONFIG_DIR" 2>/dev/null || true
    log_info "✓ Config directory structure ready"
fi

# -----------------------------------------------------------------------------
# Step 5: Generate seed configurations
# -----------------------------------------------------------------------------
log_step "Generating seed configurations..."

if [ -f scripts/setup_seed_configs.sh ]; then
    bash scripts/setup_seed_configs.sh
    log_info "✓ Seed configs generated"
fi

# Copy seed configs to service directories
if [ -f scripts/init_configs.sh ]; then
    bash scripts/init_configs.sh
    log_info "✓ Configs initialized"
fi

# -----------------------------------------------------------------------------
# Step 6: Start Docker containers
# -----------------------------------------------------------------------------
log_step "Starting Docker containers..."

# Backup Jellyfin user data before any changes
if [[ "$PROFILE_ARGS" == *"jellyfin"* ]] || [[ "$PROFILE_ARGS" == *"all"* ]]; then
    backup_jellyfin_userdata
fi

# Pull latest images
log_info "Pulling latest images..."
docker compose $PROFILE_ARGS pull --quiet

# Start services
log_info "Starting services..."
docker compose $PROFILE_ARGS up -d

# Wait for services to be healthy
log_info "Waiting for services to be healthy..."

wait_for_service() {
    local name=$1
    local url=$2
    local max_wait=${3:-60}
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 1
}

# Wait for core services
echo -n "  Waiting for Sonarr..."
wait_for_service "Sonarr" "http://localhost:8989/ping" && echo " ✓" || echo " ⚠"

echo -n "  Waiting for Radarr..."
wait_for_service "Radarr" "http://localhost:7878/ping" && echo " ✓" || echo " ⚠"

echo -n "  Waiting for Prowlarr..."
wait_for_service "Prowlarr" "http://localhost:9696/ping" && echo " ✓" || echo " ⚠"

echo -n "  Waiting for qBittorrent..."
wait_for_service "qBittorrent" "http://localhost:8080" && echo " ✓" || echo " ⚠"

# -----------------------------------------------------------------------------
# Step 7: Run automation scripts
# -----------------------------------------------------------------------------
log_step "Running automation scripts..."

# Configure authentication and root folders
if [ -f scripts/wait_and_configure_auth.sh ]; then
    log_info "Configuring Arr apps..."
    bash scripts/wait_and_configure_auth.sh
fi

# Configure download clients
if [ -f scripts/configure_download_clients.sh ]; then
    log_info "Configuring download clients..."
    bash scripts/configure_download_clients.sh
fi

# Configure Prowlarr
if [ -f scripts/configure_prowlarr.sh ]; then
    log_info "Configuring Prowlarr..."
    bash scripts/configure_prowlarr.sh
fi

# Configure Sonarr anime
if [ -f scripts/configure_sonarr_anime.sh ]; then
    log_info "Configuring Sonarr anime..."
    bash scripts/configure_sonarr_anime.sh
fi

# Configure Radarr anime
if [ -f scripts/configure_radarr_anime.sh ]; then
    log_info "Configuring Radarr anime..."
    bash scripts/configure_radarr_anime.sh
fi

# Configure Bazarr
if [ -f scripts/configure_bazarr.sh ]; then
    log_info "Configuring Bazarr..."
    bash scripts/configure_bazarr.sh
fi

# Configure Jellyfin (if profile enabled)
if [[ "$PROFILE_ARGS" == *"jellyfin"* ]] || [[ "$PROFILE_ARGS" == *"all"* ]]; then
    if [ -f jellyfin/configure_jellyfin.sh ]; then
        log_info "Configuring Jellyfin..."
        bash jellyfin/configure_jellyfin.sh
    fi
    # Restore user data (watched status, plugins) if we have a backup
    restore_jellyfin_userdata
fi

# Configure Jellyseerr anime integration
if [ -f scripts/configure_jellyseerr_anime.sh ]; then
    log_info "Configuring Jellyseerr anime..."
    bash scripts/configure_jellyseerr_anime.sh
fi

# -----------------------------------------------------------------------------
# Step 8: Verify deployment
# -----------------------------------------------------------------------------
log_step "Verifying deployment..."

if [ -f scripts/verify_setup.sh ]; then
    bash scripts/verify_setup.sh
fi

# -----------------------------------------------------------------------------
# Complete!
# -----------------------------------------------------------------------------
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "  ✓ Deployment Complete!"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
echo "Services available at:"
echo "  • Sonarr:        http://localhost:8989"
echo "  • Radarr:        http://localhost:7878"
echo "  • Lidarr:        http://localhost:8686"
echo "  • Prowlarr:      http://localhost:9696"
echo "  • qBittorrent:   http://localhost:8080"
echo "  • NZBGet:        http://localhost:6789"
echo "  • Bazarr:        http://localhost:6767"

if [[ "$PROFILE_ARGS" == *"jellyfin"* ]] || [[ "$PROFILE_ARGS" == *"all"* ]]; then
    echo "  • Jellyfin:      http://localhost:8096"
    echo "  • Jellyseerr:    http://localhost:5055"
    echo "  • Jellystat:     http://localhost:3000"
fi

echo ""
echo "Credentials:"
echo "  Username: $USERNAME"
echo "  Password: (as configured)"
echo ""

# Check for manual steps
if [[ "$PROFILE_ARGS" == *"jellyfin"* ]] || [[ "$PROFILE_ARGS" == *"all"* ]]; then
    echo "Remaining manual steps (~5 minutes):"
    echo "  1. Jellyseerr: Visit http://localhost:5055 to complete setup wizard"
    echo "  2. Jellystat: Visit http://localhost:3000 to create account"
    echo ""
fi

echo "For full status, see: AUTOMATION_STATUS.md"
echo "To backup configs: ./backup.sh"
echo "To destroy and redeploy: ./deploy.sh --destroy && ./deploy.sh"
echo ""
