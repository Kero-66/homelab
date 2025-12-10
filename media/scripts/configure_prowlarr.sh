#!/bin/bash
set -e

# =============================================================================
# Configure Prowlarr - Complete Setup
# =============================================================================
# This script performs complete Prowlarr configuration:
# 1. Adds FlareSolverr proxy for Cloudflare-protected indexers
# 2. Connects Prowlarr to Sonarr, Radarr, and Lidarr
#
# Run after: docker compose up -d
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

PROWLARR_PORT=${PROWLARR_PORT:-9696}
FLARESOLVERR_HOST="http://${IP_FLARESOLVERR:-172.39.0.9}:8191/"

echo "════════════════════════════════════════════════════════════"
echo "  Prowlarr Configuration"
echo "════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# Wait for Prowlarr
# -----------------------------------------------------------------------------
echo "Waiting for Prowlarr to be ready..."
for i in {1..30}; do
    if curl -s "http://localhost:$PROWLARR_PORT/ping" > /dev/null 2>&1; then
        echo "✓ Prowlarr is up!"
        break
    fi
    sleep 2
done

# Extract API key from config
API_KEY=$(grep -oP '<ApiKey>\K[^<]+' prowlarr/config.xml 2>/dev/null | tr -d '[:space:]' || echo "")

if [[ -z "$API_KEY" ]]; then
    echo "Error: Could not find Prowlarr API key"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 1: Configure FlareSolverr Proxy
# -----------------------------------------------------------------------------
echo ""
echo "Step 1: Configuring FlareSolverr proxy..."

EXISTING_PROXY=$(curl -s -H "X-Api-Key: $API_KEY" "http://localhost:$PROWLARR_PORT/api/v1/indexerproxy" | python3 -c "
import sys, json
try:
    proxies = json.load(sys.stdin)
    for proxy in proxies:
        if proxy.get('implementation') == 'FlareSolverr':
            print(proxy.get('id', ''))
            break
except:
    pass
" || echo "")

FLARESOLVERR_PAYLOAD='{
    "name": "FlareSolverr",
    "implementation": "FlareSolverr",
    "implementationName": "FlareSolverr",
    "configContract": "FlareSolverrSettings",
    "fields": [
        {"name": "host", "value": "'"$FLARESOLVERR_HOST"'"},
        {"name": "requestTimeout", "value": 60}
    ],
    "tags": []
}'

if [[ -n "$EXISTING_PROXY" ]]; then
    echo "  FlareSolverr proxy exists (ID: $EXISTING_PROXY), updating..."
    curl -s -X PUT \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        "http://localhost:$PROWLARR_PORT/api/v1/indexerproxy/$EXISTING_PROXY" \
        -d "$(echo "$FLARESOLVERR_PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); d['id']=$EXISTING_PROXY; print(json.dumps(d))")" > /dev/null
    echo "  ✓ FlareSolverr proxy updated"
else
    RESPONSE=$(curl -s -X POST \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        "http://localhost:$PROWLARR_PORT/api/v1/indexerproxy" \
        -d "$FLARESOLVERR_PAYLOAD")
    
    if echo "$RESPONSE" | grep -q '"id"'; then
        echo "  ✓ FlareSolverr proxy added"
    else
        echo "  ⚠ Could not add FlareSolverr proxy: $RESPONSE"
    fi
fi

# -----------------------------------------------------------------------------
# Step 2: Connect Arr Applications
# -----------------------------------------------------------------------------
echo ""
echo "Step 2: Connecting Arr applications..."

add_application() {
    local APP_NAME=$1
    local APP_PORT=$2
    local CONFIG_FILE=$3
    local APP_IP=$4
    local SYNC_CATEGORIES=$5
    
    # Extract API key from app config
    APP_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$CONFIG_FILE" 2>/dev/null | tr -d '[:space:]' || echo "")
    
    if [[ -z "$APP_API_KEY" ]]; then
        echo "  ⚠ $APP_NAME: Could not find API key, skipping"
        return 1
    fi
    
    # Check if app already exists
    EXISTING_APP=$(curl -s -H "X-Api-Key: $API_KEY" \
        "http://localhost:$PROWLARR_PORT/api/v1/applications" | \
        python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        if app.get('name', '').lower() == '${APP_NAME,,}':
            print(app.get('id', ''))
            break
except:
    pass
" || echo "")
    
    if [[ -n "$EXISTING_APP" ]]; then
        echo "  ✓ $APP_NAME already connected (ID: $EXISTING_APP)"
        return 0
    fi
    
    # Add application
    RESPONSE=$(curl -s -X POST \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        "http://localhost:$PROWLARR_PORT/api/v1/applications" \
        -d '{
            "name": "'"$APP_NAME"'",
            "syncLevel": "addOnly",
            "implementation": "'"$APP_NAME"'",
            "configContract": "'"$APP_NAME"'Settings",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://'"${IP_PROWLARR:-172.39.0.8}"':'"$PROWLARR_PORT"'"},
                {"name": "baseUrl", "value": "http://'"$APP_IP"':'"$APP_PORT"'"},
                {"name": "apiKey", "value": "'"$APP_API_KEY"'"},
                {"name": "syncCategories", "value": '"$SYNC_CATEGORIES"'}
            ],
            "tags": []
        }')
    
    if echo "$RESPONSE" | grep -q '"id"'; then
        echo "  ✓ $APP_NAME connected"
    else
        echo "  ⚠ $APP_NAME: Could not connect"
    fi
}

# Connect all Arr applications
# Categories: TV (5000+), Movies (2000+), Audio (3000+)
add_application "Sonarr" "8989" "sonarr/config.xml" "${IP_SONARR:-172.39.0.3}" '[5000,5010,5020,5030,5040,5045,5050,5060,5070,5080,5090]'
add_application "Radarr" "7878" "radarr/config.xml" "${IP_RADARR:-172.39.0.4}" '[2000,2010,2020,2030,2040,2045,2050,2060,2070,2080,2090]'
add_application "Lidarr" "8686" "lidarr/config.xml" "${IP_LIDARR:-172.39.0.5}" '[3000,3010,3020,3030,3040,3050,3060]'

# Helper to add application when API key is already known (e.g. from ini file)
add_application_with_key() {
    local APP_NAME=$1
    local APP_PORT=$2
    local APP_API_KEY=$3
    local APP_IP=$4
    local SYNC_CATEGORIES=$5

    if [[ -z "$APP_API_KEY" ]]; then
        echo "  ⚠ $APP_NAME: no API key provided, skipping"
        return 1
    fi

    EXISTING_APP=$(curl -s -H "X-Api-Key: $API_KEY" \
        "http://localhost:$PROWLARR_PORT/api/v1/applications" | \
        python3 -c "import sys,json
try:
    apps=json.load(sys.stdin)
    for app in apps:
        if app.get('name','').lower()==('${APP_NAME,,}'):
            print(app.get('id',''))
            break
except:
    pass
" || echo "")

    if [[ -n "$EXISTING_APP" ]]; then
        echo "  ✓ $APP_NAME already connected (ID: $EXISTING_APP)"
        return 0
    fi

    # Some applications have different 'implementation' names in Prowlarr
    IMPLEMENTATION_NAME="$APP_NAME"
    CONFIG_CONTRACT="${APP_NAME}Settings"
    # Map Mylar3 -> Mylar implementation used by Prowlarr
    if [[ "${APP_NAME,,}" == "mylar3" ]]; then
        IMPLEMENTATION_NAME="Mylar"
        CONFIG_CONTRACT="MylarSettings"
        # ensure we have a non-empty category for books/comics
        if [[ "$SYNC_CATEGORIES" == '[]' || -z "$SYNC_CATEGORIES" ]]; then
            SYNC_CATEGORIES='[7030]'
        fi
    fi

    RESPONSE=$(curl -s -X POST \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        "http://localhost:$PROWLARR_PORT/api/v1/applications" \
        -d '{
            "name": "'"$APP_NAME"'",
            "syncLevel": "addOnly",
            "implementation": "'"$IMPLEMENTATION_NAME"'",
            "configContract": "'"$CONFIG_CONTRACT"'",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://'"${IP_PROWLARR:-172.39.0.8}"':'"$PROWLARR_PORT"'"},
                {"name": "baseUrl", "value": "http://'"$APP_IP"':'"$APP_PORT"'"},
                {"name": "apiKey", "value": "'"$APP_API_KEY"'"},
                {"name": "syncCategories", "value": '"$SYNC_CATEGORIES"'}
            ],
            "tags": []
        }')

    if echo "$RESPONSE" | grep -q '"id"'; then
        echo "  ✓ $APP_NAME connected"
    else
        echo "  ⚠ $APP_NAME: Could not connect"
        echo "  Response: $RESPONSE"
    fi
}

# Add Mylar3 by reading API key from ini
MY3_API_KEY=$(grep -oP -m1 '^api_key\s*=\s*\K.*' mylar3/config.ini 2>/dev/null | tr -d '\r\n' || echo "")
add_application_with_key "Mylar3" "8090" "$MY3_API_KEY" "${IP_MY3:-172.39.0.19}" '[]'

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Prowlarr Configuration Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "FlareSolverr: $FLARESOLVERR_HOST"
echo "Connected apps: Sonarr, Radarr, Lidarr"
echo ""
echo "Indexers added to Prowlarr will automatically sync to all apps."
