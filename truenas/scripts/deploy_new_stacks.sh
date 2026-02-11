#!/usr/bin/env bash
# truenas/scripts/deploy_new_stacks.sh
#
# Deploy arr-stack, downloaders, and tailscale configs to TrueNAS
# Updates Infisical Agent with new templates
#
# Prerequisites:
#   - TrueNAS API key in Infisical
#   - SSH access configured (key-based auth)
#   - Infisical Agent already running on TrueNAS
#
# Usage:
#   bash truenas/scripts/deploy_new_stacks.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

TRUENAS_IP="192.168.20.22"
TRUENAS_USER="root"

# --- Verify SSH access ---
log_info "Testing SSH connection to TrueNAS..."
if ! ssh "${TRUENAS_USER}@${TRUENAS_IP}" "hostname" &>/dev/null; then
    log_error "Cannot SSH to TrueNAS. Ensure key-based auth is configured."
    exit 1
fi
log_ok "SSH connection verified"

# --- Create output directories on TrueNAS ---
log_info "Creating output directories for new stacks..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "mkdir -p /mnt/Fast/docker/{arr-stack,downloaders,tailscale}"
log_ok "Output directories created"

# --- Upload new templates ---
log_info "Uploading Infisical Agent templates..."
scp truenas/stacks/infisical-agent/arr-stack.tmpl "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/infisical-agent/config/"
scp truenas/stacks/infisical-agent/downloaders.tmpl "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/infisical-agent/config/"
scp truenas/stacks/infisical-agent/tailscale.tmpl "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/infisical-agent/config/"
log_ok "Templates uploaded"

# --- Upload updated agent config ---
log_info "Uploading updated agent config..."
scp truenas/stacks/infisical-agent/agent-config.yaml "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/infisical-agent/config/"
log_ok "Agent config uploaded"

# --- Create config directories on TrueNAS ---
log_info "Creating service config directories..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "mkdir -p /mnt/Fast/docker/{prowlarr,sonarr,radarr,bazarr,recyclarr/config,cleanuparr,qbittorrent,sabnzbd,tailscale}"
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "chown -R 1000:1000 /mnt/Fast/docker/{prowlarr,sonarr,radarr,bazarr,recyclarr,cleanuparr,qbittorrent,sabnzbd,tailscale}"
log_ok "Config directories created (ownership: 1000:1000)"

# --- Migrate existing configurations ---
log_info "=== Migrating Existing Service Configurations ==="
log_warn "This will copy ALL your existing configs to preserve settings"

# Create backup first
BACKUP_FILE="$HOME/arr_configs_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
log_info "Creating backup of workstation configs..."
cd /mnt/library/repos/homelab/media
tar czf "$BACKUP_FILE" \
  sonarr/ radarr/ prowlarr/ bazarr/ recyclarr/ cleanuparr/ \
  qbittorrent/ sabnzbd/ 2>/dev/null || log_warn "Some configs may not exist yet"
log_ok "Backup created: $BACKUP_FILE"

# Migrate Arr Stack configs
log_info "Migrating Arr stack configurations..."
for service in prowlarr sonarr radarr bazarr cleanuparr; do
    if [ -d "media/${service}" ]; then
        log_info "Copying ${service} config..."
        scp -r "media/${service}/"* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/${service}/" 2>/dev/null || \
            log_warn "${service} config copy failed or empty"
    else
        log_warn "${service} directory not found - will start fresh"
    fi
done

# Migrate Recyclarr config
if [ -d "media/recyclarr/config" ]; then
    log_info "Copying recyclarr config..."
    scp -r "media/recyclarr/config/"* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/recyclarr/config/" 2>/dev/null
fi

# Migrate Downloader configs
log_info "Migrating Downloader configurations..."
for service in qbittorrent sabnzbd; do
    if [ -d "media/${service}" ]; then
        log_info "Copying ${service} config..."
        scp -r "media/${service}/"* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/${service}/" 2>/dev/null || \
            log_warn "${service} config copy failed or empty"
    else
        log_warn "${service} directory not found - will start fresh"
    fi
done

# Fix all ownership after migration
log_info "Setting correct ownership on all configs..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "chown -R 1000:1000 /mnt/Fast/docker/{prowlarr,sonarr,radarr,bazarr,recyclarr,cleanuparr,qbittorrent,sabnzbd}"
log_ok "All configurations migrated and ownership fixed"

# --- Restart Infisical Agent to pick up new config ---
log_warn "Infisical Agent needs restart to load new templates"
log_info "After agent restarts, it will render .env files to:"
echo "  - /mnt/Fast/docker/arr-stack/.env"
echo "  - /mnt/Fast/docker/downloaders/.env"
echo "  - /mnt/Fast/docker/tailscale/.env"
echo ""
log_info "To restart agent:"
echo "  1. Open TrueNAS Web UI → Apps"
echo "  2. Find 'infisical-agent' app"
echo "  3. Click ⋮ → Restart"
echo ""
log_info "After agent restart, wait 1-2 minutes for .env files to generate, then:"
echo "  1. Verify .env files exist: ssh root@${TRUENAS_IP} 'ls -la /mnt/Fast/docker/{arr-stack,downloaders,tailscale}/.env'"
echo "  2. Verify configs migrated: ssh root@${TRUENAS_IP} 'ls -la /mnt/Fast/docker/sonarr/'"
echo "  3. Deploy apps via TrueNAS Web UI using compose files in truenas/stacks/"
echo ""
log_ok "Deployment preparation complete!"
log_ok "Backup saved to: $BACKUP_FILE"
