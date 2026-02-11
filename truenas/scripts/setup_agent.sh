#!/usr/bin/env bash
# truenas/scripts/setup_agent.sh
#
# Deploys Infisical Agent config and Jellyfin compose files to TrueNAS via API.
# Run this ONCE from your workstation to bootstrap the TrueNAS stacks.
#
# Prerequisites:
#   1. Infisical CLI installed and logged in
#   2. Machine Identity created in Infisical dashboard:
#      - Project Settings → Machine Identities → "truenas-agent"
#      - Auth: Universal Auth
#      - Scope: Read access to /media in dev environment
#   3. TrueNAS API key stored at /TrueNAS/truenas_admin_api in Infisical
#   4. jq installed
#
# Usage:
#   bash truenas/scripts/setup_agent.sh
#
# What this does:
#   1. Creates directories on TrueNAS via filesystem API
#   2. Uploads compose files, agent config, and templates
#   3. Writes Machine Identity credentials (600, root-only)
#   4. Sets correct ownership on container directories
#
# NO SSH REQUIRED — uses TrueNAS REST API only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (matches get_system_info.sh / create_user.sh style)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Check dependencies ---
if ! command -v infisical &>/dev/null; then
    log_error "infisical CLI not found. Install from: https://infisical.com/docs/cli/overview"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    log_error "jq not found. Install with: sudo dnf install jq"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    log_error "curl not found"
    exit 1
fi

# --- Configuration ---
TRUENAS_IP="${TRUENAS_IP:-192.168.20.22}"
TRUENAS_URL="https://$TRUENAS_IP"

# Self-hosted Infisical instance
INFISICAL_DOMAIN="${INFISICAL_API_URL:-http://localhost:8081}"
export INFISICAL_API_URL="$INFISICAL_DOMAIN"

# --- Get TrueNAS API key from Infisical ---
log_info "Retrieving TrueNAS API key from Infisical..."
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null || echo "")

if [ -z "$TRUENAS_API_KEY" ]; then
    log_error "Failed to retrieve TrueNAS API key from Infisical"
    log_error "Make sure you're logged in: infisical login"
    exit 1
fi

AUTH_HEADER=(-H "Authorization: Bearer $TRUENAS_API_KEY")
# Self-signed cert on TrueNAS — skip verification
CURL_OPTS=(-sk)
log_ok "API key retrieved"

# --- Test API connectivity ---
log_info "Testing connection to TrueNAS at $TRUENAS_IP..."
if ! curl "${CURL_OPTS[@]}" -f "${AUTH_HEADER[@]}" "$TRUENAS_URL/api/v2.0/system/info" >/dev/null; then
    log_error "Failed to connect to TrueNAS API at $TRUENAS_URL"
    exit 1
fi
log_ok "TrueNAS API accessible"

# --- Helper: create directory via API ---
tn_mkdir() {
    local dir_path="$1"
    local response http_code
    response=$(curl "${CURL_OPTS[@]}" "${AUTH_HEADER[@]}" \
        -X POST -H "Content-Type: application/json" \
        -w "\n%{http_code}" \
        -d "{\"path\": \"$dir_path\"}" \
        "$TRUENAS_URL/api/v2.0/filesystem/mkdir" 2>/dev/null)
    http_code=$(echo "$response" | tail -1)

    if [[ "$http_code" == "200" ]]; then
        log_ok "Created: $dir_path"
    elif [[ "$http_code" == "422" ]]; then
        log_warn "Directory already exists: $dir_path"
    else
        log_error "Failed to create: $dir_path (HTTP $http_code)"
        return 1
    fi
}

# --- Helper: upload file via API ---
tn_put_file() {
    local local_path="$1"
    local remote_path="$2"

    curl "${CURL_OPTS[@]}" -f "${AUTH_HEADER[@]}" \
        -X POST \
        -F "data={\"path\": \"$remote_path\"}" \
        -F "file=@$local_path" \
        "$TRUENAS_URL/api/v2.0/filesystem/put" >/dev/null || {
        log_error "Failed to upload: $local_path → $remote_path"
        return 1
    }
    log_ok "Uploaded: $remote_path"
}

# --- Helper: write string content to file via API ---
tn_put_string() {
    local content="$1"
    local remote_path="$2"
    local tmpfile
    tmpfile=$(mktemp)
    echo -n "$content" > "$tmpfile"

    curl "${CURL_OPTS[@]}" -f "${AUTH_HEADER[@]}" \
        -X POST \
        -F "data={\"path\": \"$remote_path\"}" \
        -F "file=@$tmpfile" \
        "$TRUENAS_URL/api/v2.0/filesystem/put" >/dev/null || {
        rm -f "$tmpfile"
        log_error "Failed to write: $remote_path"
        return 1
    }
    rm -f "$tmpfile"
    log_ok "Written: $remote_path"
}

# --- Helper: set permissions via API ---
tn_setperm() {
    local path="$1"
    local mode="$2"

    curl "${CURL_OPTS[@]}" -f "${AUTH_HEADER[@]}" \
        -X POST -H "Content-Type: application/json" \
        -d "{\"path\": \"$path\", \"mode\": \"$mode\"}" \
        "$TRUENAS_URL/api/v2.0/filesystem/setperm" >/dev/null || {
        log_error "Failed to set permissions on: $path"
        return 1
    }
}

# --- Helper: set ownership via API ---
tn_chown() {
    local path="$1"
    local uid="$2"
    local gid="$3"
    local recursive="${4:-false}"

    curl "${CURL_OPTS[@]}" -f "${AUTH_HEADER[@]}" \
        -X POST -H "Content-Type: application/json" \
        -d "{\"path\": \"$path\", \"uid\": $uid, \"gid\": $gid, \"options\": {\"recursive\": $recursive}}" \
        "$TRUENAS_URL/api/v2.0/filesystem/chown" >/dev/null || {
        log_error "Failed to chown: $path"
        return 1
    }
}

# --- Get Machine Identity credentials from Infisical ---
echo ""
log_info "=== Machine Identity Setup ==="
log_info "Retrieving credentials from Infisical /TrueNAS path..."

CLIENT_ID=$(infisical secrets get INFISICAL_CLIENT_ID --env dev --path /TrueNAS --plain 2>/dev/null || echo "")
CLIENT_SECRET=$(infisical secrets get INFISICAL_CLIENT_SECRET --env dev --path /TrueNAS --plain 2>/dev/null || echo "")

if [[ -z "$CLIENT_ID" ]]; then
    log_error "INFISICAL_CLIENT_ID not found in Infisical /TrueNAS path"
    log_error "Store it with: infisical secrets set INFISICAL_CLIENT_ID=<value> --env dev --path /TrueNAS"
    exit 1
fi

if [[ -z "$CLIENT_SECRET" ]]; then
    log_error "INFISICAL_CLIENT_SECRET not found in Infisical /TrueNAS path"
    log_error "Store it with: infisical secrets set INFISICAL_CLIENT_SECRET=<value> --env dev --path /TrueNAS"
    exit 1
fi
log_ok "Credentials retrieved from Infisical"

# --- Verify credentials work ---
log_info "Verifying Machine Identity credentials..."
if ! curl -sf -X POST "http://192.168.20.66:8081/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\": \"$CLIENT_ID\", \"clientSecret\": \"$CLIENT_SECRET\"}" >/dev/null 2>&1; then
    log_error "Machine Identity authentication failed. Check your Client ID and Secret."
    exit 1
fi
log_ok "Machine Identity credentials verified"

# --- Create directories ---
echo ""
log_info "=== Creating Directories ==="

tn_mkdir "/mnt/Fast/docker/infisical-agent"
tn_mkdir "/mnt/Fast/docker/infisical-agent/config"
tn_mkdir "/mnt/Fast/docker/jellyfin/config"
tn_mkdir "/mnt/Fast/docker/jellyfin/jellystat-backup"
tn_mkdir "/mnt/Fast/docker/jellyseerr/config"
tn_mkdir "/mnt/Fast/databases/jellystat/postgres"

# --- Upload config files ---
echo ""
log_info "=== Uploading Configuration ==="

AGENT_DIR="$REPO_ROOT/truenas/stacks/infisical-agent"
JELLYFIN_DIR="$REPO_ROOT/truenas/stacks/jellyfin"

# Agent config and template
tn_put_file "$AGENT_DIR/agent-config.yaml" "/mnt/Fast/docker/infisical-agent/config/agent-config.yaml"
tn_put_file "$AGENT_DIR/jellyfin.tmpl" "/mnt/Fast/docker/infisical-agent/config/jellyfin.tmpl"

# Compose files
tn_put_file "$AGENT_DIR/compose.yaml" "/mnt/Fast/docker/infisical-agent/compose.yaml"
tn_put_file "$JELLYFIN_DIR/compose.yaml" "/mnt/Fast/docker/jellyfin/compose.yaml"

# --- Write credentials (sensitive) ---
echo ""
log_info "=== Writing Credentials ==="

tn_put_string "$CLIENT_ID" "/mnt/Fast/docker/infisical-agent/config/client-id"
tn_put_string "$CLIENT_SECRET" "/mnt/Fast/docker/infisical-agent/config/client-secret"

# Lock down credential files
tn_setperm "/mnt/Fast/docker/infisical-agent/config/client-id" "600"
tn_setperm "/mnt/Fast/docker/infisical-agent/config/client-secret" "600"
log_ok "Credentials written with mode 600"

# --- Set ownership ---
echo ""
log_info "=== Setting Ownership ==="

# Container dirs owned by kero66 (1000:1000)
tn_chown "/mnt/Fast/docker/jellyfin" 1000 1000 true
tn_chown "/mnt/Fast/docker/jellyseerr" 1000 1000 true
tn_chown "/mnt/Fast/databases/jellystat" 1000 1000 true
log_ok "Container directories owned by 1000:1000"

# Agent config stays root-owned (credential protection)
log_info "Agent config stays root:root (default)"

# --- Clean up test file if it exists ---
# (from API testing — harmless if missing)

# --- Summary ---
echo ""
echo "============================================="
echo -e "${GREEN}  Setup Complete!${NC}"
echo "============================================="
echo ""
echo "Files deployed to TrueNAS ($TRUENAS_IP):"
echo "  /mnt/Fast/docker/infisical-agent/"
echo "    ├── compose.yaml"
echo "    └── config/"
echo "        ├── agent-config.yaml"
echo "        ├── jellyfin.tmpl"
echo "        ├── client-id       (600, root-only)"
echo "        └── client-secret   (600, root-only)"
echo ""
echo "  /mnt/Fast/docker/jellyfin/"
echo "    └── compose.yaml"
echo ""
echo "Next steps (in TrueNAS Web UI):"
echo ""
echo "  1. Apps → Discover → Custom App"
echo "     Name: infisical-agent"
echo "     YAML:"
echo "       include:"
echo "         - /mnt/Fast/docker/infisical-agent/compose.yaml"
echo "       services: {}"
echo ""
echo "  2. Wait ~30s, check agent logs for successful secret fetch"
echo ""
echo "  3. Apps → Discover → Custom App"
echo "     Name: jellyfin"
echo "     YAML:"
echo "       include:"
echo "         - /mnt/Fast/docker/jellyfin/compose.yaml"
echo "       services: {}"
echo ""
echo "  4. Verify:"
echo "     Jellyfin:   http://$TRUENAS_IP:8096"
echo "     Jellyseerr: http://$TRUENAS_IP:5055"
echo "     Jellystat:  http://$TRUENAS_IP:3002"
echo ""
