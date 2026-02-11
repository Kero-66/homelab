#!/usr/bin/env bash
#
# Verify all configurations migrated successfully from workstation to TrueNAS
#

set -euo pipefail

TRUENAS_IP="192.168.20.22"
TRUENAS_USER="root"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_info() { echo -e "${NC}[i]${NC} $1"; }

echo "=== Configuration Migration Verification ==="
echo ""

# Check each service configuration
SERVICES=(
    "prowlarr:config.xml"
    "sonarr:config.xml"
    "radarr:config.xml"
    "bazarr:config/config.yaml"
    "recyclarr:config/recyclarr.yml"
    "qbittorrent:qBittorrent/qBittorrent.conf"
    "sabnzbd:sabnzbd.ini"
)

FAILED=0

for entry in "${SERVICES[@]}"; do
    IFS=':' read -r service key_file <<< "$entry"
    
    log_info "Checking ${service}..."
    
    # Check if config directory exists
    if ssh "${TRUENAS_USER}@${TRUENAS_IP}" "[ -d /mnt/Fast/docker/${service} ]" 2>/dev/null; then
        log_ok "  Directory exists: /mnt/Fast/docker/${service}"
        
        # Check for key file
        if ssh "${TRUENAS_USER}@${TRUENAS_IP}" "[ -f /mnt/Fast/docker/${service}/${key_file} ]" 2>/dev/null; then
            log_ok "  Key file found: ${key_file}"
            
            # Check ownership
            OWNER=$(ssh "${TRUENAS_USER}@${TRUENAS_IP}" "stat -c '%u:%g' /mnt/Fast/docker/${service}" 2>/dev/null)
            if [ "$OWNER" == "1000:1000" ]; then
                log_ok "  Ownership correct: ${OWNER}"
            else
                log_warn "  Ownership incorrect: ${OWNER} (expected 1000:1000)"
                FAILED=$((FAILED + 1))
            fi
            
            # Get file count
            FILE_COUNT=$(ssh "${TRUENAS_USER}@${TRUENAS_IP}" "find /mnt/Fast/docker/${service} -type f | wc -l" 2>/dev/null)
            log_ok "  Files migrated: ${FILE_COUNT}"
        else
            log_warn "  Key file missing: ${key_file} (may be fresh install)"
        fi
    else
        log_error "  Directory missing: /mnt/Fast/docker/${service}"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

# Check .env files
log_info "Checking .env files..."
ENV_FILES=(
    "arr-stack/.env"
    "downloaders/.env"
    "tailscale/.env"
)

for env_file in "${ENV_FILES[@]}"; do
    if ssh "${TRUENAS_USER}@${TRUENAS_IP}" "[ -f /mnt/Fast/docker/${env_file} ]" 2>/dev/null; then
        SIZE=$(ssh "${TRUENAS_USER}@${TRUENAS_IP}" "stat -c %s /mnt/Fast/docker/${env_file}" 2>/dev/null)
        if [ "$SIZE" -gt 10 ]; then
            log_ok "  ${env_file} exists (${SIZE} bytes)"
        else
            log_warn "  ${env_file} exists but may be empty (${SIZE} bytes)"
            FAILED=$((FAILED + 1))
        fi
    else
        log_error "  ${env_file} missing - Infisical Agent may need restart"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# Check media paths
log_info "Checking media paths..."
MEDIA_PATHS=(
    "/mnt/Data/media/movies"
    "/mnt/Data/media/shows"
    "/mnt/Data/downloads"
)

for path in "${MEDIA_PATHS[@]}"; do
    if ssh "${TRUENAS_USER}@${TRUENAS_IP}" "[ -d ${path} ]" 2>/dev/null; then
        FILE_COUNT=$(ssh "${TRUENAS_USER}@${TRUENAS_IP}" "find ${path} -type f 2>/dev/null | wc -l")
        SIZE=$(ssh "${TRUENAS_USER}@${TRUENAS_IP}" "du -sh ${path} 2>/dev/null | cut -f1")
        log_ok "  ${path}: ${FILE_COUNT} files (${SIZE})"
    else
        log_warn "  ${path}: Not found (may be empty or transfer in progress)"
    fi
done
echo ""

# Summary
echo "=== Verification Summary ==="
if [ $FAILED -eq 0 ]; then
    log_ok "All critical configurations verified successfully!"
    log_info "You can proceed with deploying the stacks via TrueNAS Web UI"
    exit 0
else
    log_error "Found ${FAILED} issues that need attention"
    log_info "Review the output above and fix any missing configs or ownership"
    exit 1
fi
