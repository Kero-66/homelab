#!/bin/bash
set -e

# Configure download clients (qBittorrent) in all Arr apps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load CONFIG_DIR from .env (defaults to current directory)
CONFIG_DIR="."
if [[ -f .env ]]; then
  CONFIG_DIR=$(grep -E "^CONFIG_DIR=" .env | cut -d'=' -f2 || echo ".")
  CONFIG_DIR="${CONFIG_DIR:-.}"
fi

# Load environment variables from .env
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

# Load credentials
if [ ! -f .config/.credentials ]; then
    echo "Error: .config/.credentials file not found"
    exit 1
fi

source .config/.credentials

# Function to add qBittorrent to an Arr app
add_qbittorrent() {
    local APP_NAME=$1
    local APP_PORT=$2
    local API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$3" 2>/dev/null | tr -d '[:space:]' || echo "")
    
    if [[ -z "$API_KEY" ]]; then
        echo "  Error: Could not find API key for $APP_NAME"
        return 1
    fi
    
    echo "Adding qBittorrent to $APP_NAME..."
    
    # Check if already exists
    EXISTING=$(curl -s -H "X-Api-Key: $API_KEY" "http://localhost:$APP_PORT/api/v3/downloadclient" | \
        python3 -c "import sys,json; clients=json.load(sys.stdin); print([c['id'] for c in clients if c.get('implementation')=='QBittorrent'][0] if any(c.get('implementation')=='QBittorrent' for c in clients) else '')" || echo "")
    
    if [[ -n "$EXISTING" ]]; then
        echo "  ✓ qBittorrent already configured in $APP_NAME"
        return 0
    fi
    
    # Add qBittorrent
    RESPONSE=$(curl -s -X POST \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        "http://localhost:$APP_PORT/api/v3/downloadclient" \
        -d '{
            "enable": true,
            "protocol": "torrent",
            "priority": 1,
            "name": "qBittorrent",
            "fields": [
                {"name": "host", "value": "'"$IP_QBITTORRENT"'"},
                {"name": "port", "value": 8080},
                {"name": "useSsl", "value": false},
                {"name": "urlBase", "value": ""},
                {"name": "username", "value": "'"$USERNAME"'"},
                {"name": "password", "value": "'"$PASSWORD"'"},
                {"name": "category", "value": "'"${APP_NAME,,}"'"},
                {"name": "postImportCategory", "value": ""},
                {"name": "recentTvPriority", "value": 0},
                {"name": "olderTvPriority", "value": 0},
                {"name": "initialState", "value": 0},
                {"name": "sequentialOrder", "value": false},
                {"name": "firstAndLast", "value": false}
            ],
            "implementationName": "qBittorrent",
            "implementation": "QBittorrent",
            "configContract": "QBittorrentSettings",
            "tags": []
        }')
    
    if echo "$RESPONSE" | grep -q '"id"'; then
        echo "  ✓ qBittorrent added to $APP_NAME"
    else
        echo "  Warning: Could not add qBittorrent to $APP_NAME"
        echo "  Response: $RESPONSE"
    fi
}

echo "Configuring download clients in Arr apps..."
echo ""

# Configure Sonarr
echo "=== Sonarr ==="
add_qbittorrent "Sonarr" "8989" "$CONFIG_DIR/sonarr/config.xml"

echo ""
echo "=== Radarr ==="
add_qbittorrent "Radarr" "7878" "$CONFIG_DIR/radarr/config.xml"

echo ""
echo "=== Lidarr ==="
add_qbittorrent "Lidarr" "8686" "$CONFIG_DIR/lidarr/config.xml"

echo ""
echo "✓ Download clients configured!"
echo ""
echo "All Arr apps can now download via qBittorrent (torrents)."
