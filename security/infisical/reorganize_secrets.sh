#!/usr/bin/env bash
# security/infisical/reorganize_secrets.sh
# Purpose: Move secrets into stack-specific folders in Infisical

set -euo pipefail

PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
ENV="dev"

# Helper to move a secret
move_secret() {
    local key=$1
    local from_path=$2
    local to_path=$3
    
    echo "Moving $key from $from_path to $to_path..."
    
    # Get value
    local value
    value=$(infisical secrets get "$key" --env "$ENV" --projectId "$PROJECT_ID" --path "$from_path" --plain)
    
    # Set in new path
    infisical secrets set "$key=$value" --env "$ENV" --projectId "$PROJECT_ID" --path "$to_path"
    
    # Delete from old path if different
    if [ "$from_path" != "$to_path" ]; then
        infisical secrets delete "$key" --env "$ENV" --projectId "$PROJECT_ID" --path "$from_path"
    fi
}

# 1. Create folders
echo "Creating folders..."
infisical secrets folders create --name media --env "$ENV" --projectId "$PROJECT_ID" --path "/" || true
infisical secrets folders create --name monitoring --env "$ENV" --projectId "$PROJECT_ID" --path "/" || true

# 2. Categorize Media Secrets
MEDIA_SECRETS=(
    "SONARR_API_KEY" "RADARR_API_KEY" "LIDARR_API_KEY" "PROWLARR_API_KEY" 
    "BAZARR_API_KEY" "SABNZBD_API_KEY" 
    "QBIT_WEBUI_PORT" "QBIT_TORRENT_PORT_TCP" "QBIT_TORRENT_PORT_UDP" # Wait, these are in .env? No, they were in secrets too.
    "QBITTORRENT_USER" "QBITTORRENT_PASS" "CLEANUPARR_API_KEY" "UBOOQUITY_API_KEY" 
    "DRUNKENSLUG_API_KEY" "EASYNEWS_USER" "EASYNEWS_PASS" "SCENENZB_API_KEY"
)

for secret in "${MEDIA_SECRETS[@]}"; do
    move_secret "$secret" "/" "/media" || echo "Skipping $secret (not found)"
done

 # 3. Categorize Monitoring Secrets
MONITORING_SECRETS=(
    "BESZEL_USER" "BESZEL_PASS"
    "BESZEL_AGENT_KEY"
)

for secret in "${MONITORING_SECRETS[@]}"; do
    move_secret "$secret" "/" "/monitoring" || echo "Skipping $secret (not found)"
done

# 5. Delete unused Wireguard secrets
echo "Deleting Wireguard secrets..."
infisical secrets delete WIREGUARD_PUBLIC_KEY --env "$ENV" --projectId "$PROJECT_ID" --path "/" || true
infisical secrets delete WIREGUARD_PRIVATE_KEY --env "$ENV" --projectId "$PROJECT_ID" --path "/" || true
infisical secrets delete WIREGUARD_PRESHARED_KEY --env "$ENV" --projectId "$PROJECT_ID" --path "/" || true
infisical secrets delete WIREGUARD_ADDRESSES --env "$ENV" --projectId "$PROJECT_ID" --path "/" || true

echo "Reorganization complete."
