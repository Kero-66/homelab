#!/bin/bash
# Configure Radarr and Sonarr to notify Jellyfin on download completion
# This triggers Jellyfin library refresh when new content is added

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load environment
if [[ -f .env ]]; then
    source .env
fi
CONFIG_DIR="${CONFIG_DIR:-.}"

echo "🔧 Configuring Jellyfin notifications..."

# Get Jellyfin API key
JELLYFIN_API=$(python3 -c "import json; print(json.load(open('${CONFIG_DIR}/jellyfin/jellyseerr/settings.json'))['jellyfin']['apiKey'])" 2>/dev/null || echo "")
if [[ -z "$JELLYFIN_API" ]]; then
    echo "❌ Could not get Jellyfin API key from Jellyseerr settings"
    exit 1
fi
echo "✅ Got Jellyfin API key"

# Function to add Jellyfin notification to an *arr app
add_jellyfin_notification() {
    local app_name=$1
    local port=$2
    local config_file=$3
    local events=$4  # JSON fragment for app-specific events
    
    # Get API key
    local api_key=$(grep -oP '<ApiKey>\K[^<]+' "$config_file" 2>/dev/null | tr -d '[:space:]')
    if [[ -z "$api_key" ]]; then
        echo "⚠️  Could not get $app_name API key"
        return 1
    fi

    # Get UrlBase
    local url_base=$(grep -oP '<UrlBase>\K[^<]+' "$config_file" 2>/dev/null | tr -d '[:space:]' || echo "")
    local api_url="http://localhost:$port${url_base}/api/v3/notification"
    
    # Check if Jellyfin notification already exists
    local existing_id=$(curl -s "$api_url" -H "X-Api-Key: $api_key" 2>/dev/null | \
        python3 -c "import sys,json; data=json.load(sys.stdin); print(next((n.get('id') for n in data if n.get('name')=='Jellyfin'), 'none'))" 2>/dev/null || echo "error")
    
    # Build the notification payload
    local payload='{
        "name": "Jellyfin",
        "implementation": "MediaBrowser",
        "configContract": "MediaBrowserSettings",
        "onGrab": false,
        "onHealthIssue": false,
        "onHealthRestored": false,
        "onApplicationUpdate": false,
        "onManualInteractionRequired": false,
        "tags": [],
        '"$events"',
        "fields": [
            {"name": "host", "value": "jellyfin"},
            {"name": "port", "value": 8096},
            {"name": "useSsl", "value": false},
            {"name": "urlBase", "value": ""},
            {"name": "apiKey", "value": "'"$JELLYFIN_API"'"},
            {"name": "notify", "value": false},
            {"name": "updateLibrary", "value": true},
            {"name": "mapFrom", "value": ""},
            {"name": "mapTo", "value": ""}
        ]
    }'

    if [[ "$existing_id" != "none" && "$existing_id" != "error" ]]; then
        echo "🔄 $app_name: Updating existing Jellyfin notification (ID: $existing_id)..."
        # Add ID to payload for update
        payload=$(echo "$payload" | python3 -c "import sys,json; d=json.load(sys.stdin); d['id'] = $existing_id; print(json.dumps(d))")
        
        local result=$(curl -s -X PUT "$api_url/$existing_id" \
            -H "X-Api-Key: $api_key" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>/dev/null)
        
        if echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'id' in d else 1)" 2>/dev/null; then
            echo "✅ $app_name: Updated Jellyfin notification"
            return 0
        else
            echo "❌ $app_name: Failed to update notification"
            echo "   Response: $result"
            return 1
        fi
    fi
    
    # Add the notification (if not exists)
    echo "➕ $app_name: Adding new Jellyfin notification..."
    local result=$(curl -s -X POST "$api_url" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)
    
    if echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'id' in d else 1)" 2>/dev/null; then
        local id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
        echo "✅ $app_name: Added Jellyfin notification (ID: $id)"
        return 0
    else
        echo "❌ $app_name: Failed to add notification"
        echo "   Response: $result"
        return 1
    fi
}

# Configure Radarr
echo ""
echo "📽️  Configuring Radarr..."
RADARR_EVENTS='"onDownload": true, "onUpgrade": true, "onRename": true, "onMovieAdded": false, "onMovieDelete": true, "onMovieFileDelete": true, "onMovieFileDeleteForUpgrade": true'
add_jellyfin_notification "Radarr" "7878" "${CONFIG_DIR}/radarr/config.xml" "$RADARR_EVENTS"

# Configure Sonarr
echo ""
echo "📺 Configuring Sonarr..."
SONARR_EVENTS='"onDownload": true, "onUpgrade": true, "onRename": true, "onSeriesAdd": false, "onSeriesDelete": true, "onEpisodeFileDelete": true, "onEpisodeFileDeleteForUpgrade": true'
add_jellyfin_notification "Sonarr" "8989" "${CONFIG_DIR}/sonarr/config.xml" "$SONARR_EVENTS"

# Verify configuration
echo ""
echo "📋 Verification:"
echo ""

for app_info in "Radarr:7878:radarr" "Sonarr:8989:sonarr"; do
    IFS=':' read -r app_name port config_name <<< "$app_info"
    config_file="${CONFIG_DIR}/${config_name}/config.xml"
    api_key=$(grep -oP '<ApiKey>\K[^<]+' "$config_file" 2>/dev/null | tr -d '[:space:]')
    url_base=$(grep -oP '<UrlBase>\K[^<]+' "$config_file" 2>/dev/null | tr -d '[:space:]' || echo "")
    if [[ -n "$api_key" ]]; then
        curl -s "http://localhost:$port${url_base}/api/v3/notification" -H "X-Api-Key: $api_key" | \
            python3 -c "
import sys, json
data = json.load(sys.stdin)
for n in data:
    if n.get('name') == 'Jellyfin':
        update_lib = next((f['value'] for f in n.get('fields', []) if f['name'] == 'updateLibrary'), False)
        print(f'  {\"$app_name\"}: updateLibrary={update_lib}')
" 2>/dev/null || echo "  $app_name: Could not verify"
    fi
done

echo ""
echo "✅ Done! Jellyfin will now automatically refresh when content is imported."
echo ""
echo "ℹ️  Note: Jellyfin notification uses 'MediaBrowser' implementation (not 'Emby')"
echo "   Connection goes through host.docker.internal since containers are on different networks"
