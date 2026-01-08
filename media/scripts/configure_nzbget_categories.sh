#!/bin/bash
set -e

# Configure NZBGet categories for Arr apps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load credentials
if [ ! -f .config/.credentials ]; then
    echo "Error: .config/.credentials file not found"
    exit 1
fi

source .config/.credentials

NZBGET_HOST="172.39.0.7"
NZBGET_PORT="6789"

echo "Configuring NZBGet categories..."

# Function to add category
add_category() {
    local CATEGORY=$1
    
    echo "Adding category: $CATEGORY"
    
    # Add category via NZBGet API
    curl -s -u "$USERNAME:$PASSWORD" \
        "http://$NZBGET_HOST:$NZBGET_PORT/jsonrpc" \
        -H "Content-Type: application/json" \
        -d '{
            "method": "config",
            "params": ["Category1.Name", "'"$CATEGORY"'"]
        }' > /dev/null
}

# Add categories for each Arr app
add_category "sonarr"
add_category "radarr"
add_category "lidarr"

echo ""
echo "✓ NZBGet categories configured!"
echo ""
echo "Note: These categories are for usenet downloads. You still need a usenet provider"
echo "subscription to actually download NZB files."
