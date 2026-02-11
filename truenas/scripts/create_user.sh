#!/usr/bin/env bash
# truenas/scripts/create_user.sh
#
# Creates a regular user account on TrueNAS for daily operations
# Generates a secure password and stores it in Infisical
#
# Usage:
#   bash create_user.sh [username] [uid]
#
# Example:
#   bash create_user.sh kero66 1000

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
    log_error "infisical CLI not found"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    log_error "jq not found"
    exit 1
fi

# Configuration
USERNAME="${1:-kero66}"
USER_UID="${2:-1000}"
USER_GID="${2:-1000}"
TRUENAS_IP="${TRUENAS_IP:-192.168.20.22}"

log_info "=== TrueNAS User Creation ==="
echo ""
log_info "Username: $USERNAME"
log_info "UID: $USER_UID"
log_info "GID: $USER_GID"
log_info "TrueNAS: $TRUENAS_IP"
echo ""

# Generate secure password (32 characters, alphanumeric + symbols)
log_info "Generating secure password..."
PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
log_ok "Password generated (32 characters)"

# Get TrueNAS API credentials
log_info "Retrieving TrueNAS API credentials from Infisical..."
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null || echo "")

if [ -z "$TRUENAS_API_KEY" ]; then
    log_error "Failed to retrieve TrueNAS API key from Infisical"
    exit 1
fi

log_ok "API key retrieved"
AUTH_HEADER=(-H "Authorization: Bearer $TRUENAS_API_KEY")

# Check if user already exists
log_info "Checking if user $USERNAME already exists..."
existing_user=$(curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/user?username=$USERNAME" | jq -r '.[0].username // empty')

if [ -n "$existing_user" ]; then
    log_warn "User $USERNAME already exists"
    read -p "Update password for existing user? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Skipping user creation"
        exit 0
    fi
    USER_EXISTS=true
else
    log_ok "User does not exist - will create new user"
    USER_EXISTS=false
fi

# Create or update user
echo ""
if [ "$USER_EXISTS" = false ]; then
    log_info "Creating user $USERNAME..."
    
    # Create user via API
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        "${AUTH_HEADER[@]}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$USERNAME\",
            \"full_name\": \"Kero User\",
            \"group_create\": true,
            "home": "/var/empty",
            "home_create": false,
            \"password\": \"$PASSWORD\",
            \"uid\": $USER_UID,
            \"shell\": \"/usr/bin/bash\",
            \"sudo_commands\": [],
            \"sudo_commands_nopasswd\": [],
            \"locked\": false,
            \"smb\": true
        }" \
        "http://$TRUENAS_IP/api/v2.0/user")
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    if [ "$http_code" = "200" ]; then
        log_ok "User $USERNAME created successfully"
        created_uid=$(echo "$body" | jq -r '.uid')
        log_info "Created with UID: $created_uid"
    else
        log_error "Failed to create user (HTTP $http_code)"
        echo "$body" | jq . 2>/dev/null || echo "$body"
        exit 1
    fi
else
    log_info "Updating password for existing user $USERNAME..."
    
    # Get user ID
    user_id=$(curl -s "${AUTH_HEADER[@]}" \
        "http://$TRUENAS_IP/api/v2.0/user?username=$USERNAME" | jq -r '.[0].id')
    
    # Update password
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        "${AUTH_HEADER[@]}" \
        -X PUT \
        -H "Content-Type: application/json" \
        -d "{
            \"password\": \"$PASSWORD\"
        }" \
        "http://$TRUENAS_IP/api/v2.0/user/id/$user_id")
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    
    if [ "$http_code" = "200" ]; then
        log_ok "Password updated successfully"
    else
        log_error "Failed to update password (HTTP $http_code)"
        exit 1
    fi
fi

# Store password in Infisical
echo ""
log_info "Storing credentials in Infisical..."

# Store password
if infisical secrets set "${USERNAME}_password=$PASSWORD" --env dev --path /TrueNAS >/dev/null 2>&1; then
    log_ok "Password stored as: /TrueNAS/${USERNAME}_password"
else
    log_error "Failed to store password in Infisical"
    echo ""
    log_warn "IMPORTANT: Save this password manually!"
    echo "Password: $PASSWORD"
    echo ""
    read -p "Press Enter after you've saved it..."
fi

# Store username for reference
if infisical secrets set "TRUENAS_USER=$USERNAME" --env dev --path /TrueNAS >/dev/null 2>&1; then
    log_ok "Username stored as: /TrueNAS/TRUENAS_USER"
fi

# Set SMB password (required for SMB access)
log_info "Setting SMB password..."
smb_response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    "${AUTH_HEADER[@]}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"username\": \"$USERNAME\",
        \"password\": \"$PASSWORD\"
    }" \
    "http://$TRUENAS_IP/api/v2.0/smb/set_passwd")

smb_http_code=$(echo "$smb_response" | grep "HTTP_CODE:" | cut -d: -f2)
if [ "$smb_http_code" = "200" ]; then
    log_ok "SMB password set successfully"
else
    log_warn "Failed to set SMB password (user can still access via SSH/API)"
fi

# Verify user creation
echo ""
log_info "Verifying user creation..."
user_info=$(curl -s "${AUTH_HEADER[@]}" \
    "http://$TRUENAS_IP/api/v2.0/user?username=$USERNAME" | jq -r '.[0]')

if [ "$user_info" = "null" ] || [ -z "$user_info" ]; then
    log_error "User verification failed"
    exit 1
fi

echo "$user_info" | jq '{
    username,
    uid,
    group: .group.bsdgrp_group,
    home,
    shell,
    locked,
    smb
}'

log_ok "User verified successfully"

# Summary
echo ""
echo "=== User Creation Complete ==="
echo ""
echo "Username: $USERNAME"
echo "UID: $(echo "$user_info" | jq -r '.uid')"
echo "GID: $(echo "$user_info" | jq -r '.group.bsdgrp_gid')"
echo "Home: $(echo "$user_info" | jq -r '.home')"
echo "Shell: $(echo "$user_info" | jq -r '.shell')"
echo ""
echo "Credentials stored in Infisical:"
echo "  Path: /TrueNAS"
echo "  Username key: TRUENAS_USER"
echo "  Password key: ${USERNAME}_password"
echo ""
echo "To retrieve credentials:"
echo "  infisical secrets get TRUENAS_USER --env dev --path /TrueNAS --plain"
echo "  infisical secrets get ${USERNAME}_password --env dev --path /TrueNAS --plain"
echo ""
echo "You can now:"
echo "  1. SSH into TrueNAS: ssh $USERNAME@$TRUENAS_IP"
echo "  2. Access SMB shares with these credentials"
echo "  3. Use this account for daily operations"
echo ""
echo "Keep truenas_admin for break-glass emergencies only!"
echo ""
