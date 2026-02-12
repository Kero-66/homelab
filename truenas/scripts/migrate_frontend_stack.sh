#!/usr/bin/env bash
# truenas/scripts/migrate_frontend_stack.sh
#
# Migrate Homepage, Caddy, and AdGuard Home to TrueNAS
# Preserves all existing configurations and data
#
# Prerequisites:
#   - SSH access to TrueNAS configured (key-based auth)
#   - Infisical Agent running on TrueNAS
#
# Usage:
#   bash truenas/scripts/migrate_frontend_stack.sh

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

# --- Create backup ---
BACKUP_FILE="$HOME/frontend_stack_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
log_info "Creating backup of workstation configs..."
cd /mnt/library/repos/homelab
tar czf "$BACKUP_FILE" \
  networking/.config/caddy \
  networking/.config/adguard \
  apps/homepage/config \
  apps/homepage/.env \
  2>/dev/null || log_warn "Some configs may not exist"
log_ok "Backup created: $BACKUP_FILE"

# --- Create directories on TrueNAS ---
log_info "Creating service directories on TrueNAS..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "mkdir -p /mnt/Fast/docker/{caddy,adguard-home,homepage}"
log_ok "Directories created"

# --- Migrate Caddy ---
log_info "Migrating Caddy configuration..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "mkdir -p /mnt/Fast/docker/caddy/{data,config}"
scp -r networking/.config/caddy/Caddyfile "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/caddy/"
scp -r networking/.config/caddy/data/* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/caddy/data/" 2>/dev/null || log_warn "No Caddy data to migrate"
scp -r networking/.config/caddy/config/* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/caddy/config/" 2>/dev/null || log_warn "No Caddy config cache to migrate"
log_ok "Caddy configuration migrated"

# --- Migrate AdGuard Home ---
log_info "Migrating AdGuard Home configuration..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "mkdir -p /mnt/Fast/docker/adguard-home/{work,conf}"
scp -r networking/.config/adguard/work/* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/adguard-home/work/" 2>/dev/null || log_warn "No AdGuard work data to migrate"
scp -r networking/.config/adguard/conf/* "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/adguard-home/conf/" 2>/dev/null || log_warn "No AdGuard config to migrate"
log_ok "AdGuard Home configuration migrated"

# --- Migrate Homepage ---
log_info "Migrating Homepage configuration..."
scp -r apps/homepage/config "${TRUENAS_USER}@${TRUENAS_IP}:/mnt/Fast/docker/homepage/"
log_ok "Homepage configuration migrated"

# --- Fix ownership ---
log_info "Setting correct ownership (1000:1000)..."
ssh "${TRUENAS_USER}@${TRUENAS_IP}" "chown -R 1000:1000 /mnt/Fast/docker/{caddy,adguard-home,homepage}"
log_ok "Ownership set"

log_ok "=== Migration Complete ==="
log_info "Backup saved to: $BACKUP_FILE"
echo ""
log_info "Next steps:"
echo "  1. Upload Infisical template for Homepage (if using Infisical for secrets)"
echo "  2. Update Caddyfile on TrueNAS to use service names instead of localhost"
echo "  3. Deploy Custom Apps via TrueNAS Web UI using compose files in truenas/stacks/"
echo "  4. Configure AdGuard Home with local DNS entries"
echo "  5. Update router DNS to point to TrueNAS IP (192.168.20.22)"
