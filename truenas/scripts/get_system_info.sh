#!/usr/bin/env bash
# truenas/scripts/get_system_info.sh
#
# Retrieves TrueNAS system information using the API
# Uses Infisical to securely retrieve credentials
#
# Usage:
#   bash get_system_info.sh [TRUENAS_IP]
#
# Example:
#   bash get_system_info.sh 10.0.0.50

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check dependencies
if ! command -v infisical &>/dev/null; then
    log_error "infisical CLI not found. Install from: https://infisical.com/docs/cli/overview"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    log_error "jq not found. Install with: sudo apt install jq"
    exit 1
fi

# Configuration
TRUENAS_IP="${1:-}"

# Prompt for IP if not provided
if [ -z "$TRUENAS_IP" ]; then
    read -p "Enter TrueNAS IP address: " TRUENAS_IP
fi

log_info "Retrieving TrueNAS credentials from Infisical..."

# Try API key first (preferred)
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null || echo "")

# Fallback to password
TRUENAS_PASSWORD=""
TRUENAS_USER="root"
if [ -z "$TRUENAS_API_KEY" ]; then
    if ! TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain 2>/dev/null); then
        log_error "Failed to retrieve credentials from Infisical"
        log_error "Make sure you've stored either:"
        log_error "  infisical secrets set truenas_admin_api=YOUR_API_KEY --env dev --path /TrueNAS"
        log_error "  OR"
        log_error "  infisical secrets set truenas_admin=YOUR_PASSWORD --env dev --path /TrueNAS"
        exit 1
    fi
fi

if [ -n "$TRUENAS_API_KEY" ]; then
    log_ok "API key retrieved successfully (preferred method)"
    AUTH_HEADER=(-H "Authorization: Bearer $TRUENAS_API_KEY")
else
    log_ok "Password retrieved successfully"
    AUTH_HEADER=(-u "$TRUENAS_USER:$TRUENAS_PASSWORD")
fi

# Test API connectivity
log_info "Testing connection to TrueNAS at $TRUENAS_IP..."

if ! curl -sf "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/system/info" >/dev/null; then
    log_error "Failed to connect to TrueNAS API at http://$TRUENAS_IP"
    log_error "Check:"
    log_error "  1. TrueNAS IP is correct: $TRUENAS_IP"
    log_error "  2. TrueNAS is powered on and accessible"
    log_error "  3. API is enabled in TrueNAS settings"
    log_error "  4. Credentials in Infisical are correct"
    exit 1
fi

log_ok "Successfully connected to TrueNAS API"
echo ""

# Get system information
log_info "=== System Information ==="
curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/system/info" | jq '{
    version,
    hostname,
    uptime_seconds,
    datetime,
    timezone
}'

echo ""
log_info "=== Storage Pools ==="
pools_output=$(curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/pool")

if [ "$pools_output" = "[]" ]; then
    log_warn "No storage pools configured yet"
else
    echo "$pools_output" | jq '.[] | {
        name,
        status,
        healthy,
        path,
        topology: .topology.data[0].type,
        disks: [.topology.data[0].children[]?.disk]
    }'
fi

echo ""
log_info "=== Disks ==="
curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/disk" | jq '.[] | {
    name,
    model,
    serial,
    size: (.size / 1073741824 | floor | tostring + " GB"),
    type,
    pool: (.pool // "available")
}'

echo ""
log_info "=== Network Interfaces ==="
curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/interface" | jq '.[] | {
    name,
    state: .state.link_state,
    aliases: [.aliases[]? | select(.type == "INET") | .address]
}'

echo ""
log_info "=== Services ==="
curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/service" | jq '.[] | select(.service | IN("cifs", "nfs", "ssh", "docker")) | {
    service,
    state,
    enable: .enable
}'

echo ""
log_ok "System information retrieved successfully"
log_info "For more API endpoints, visit: http://$TRUENAS_IP/api/docs"
