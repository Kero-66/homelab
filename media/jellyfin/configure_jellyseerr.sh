#!/bin/bash
set -e

# Automate Jellyseerr initial setup and connection to Jellyfin + Sonarr/Radarr

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$SCRIPT_DIR/.."
cd "$MEDIA_DIR"

# Load credentials
if [ ! -f .config/.credentials ]; then
    echo "Error: .config/.credentials file not found"
    exit 1
fi

source .config/.credentials

echo "Configuring Jellyseerr..."

# Ensure Jellyfin is running (uses main compose.yaml with profiles)
echo "Checking if Jellyfin is running..."
if ! docker ps | grep -q jellyfin; then
    echo "Starting Jellyfin..."
    docker compose --profile jellyfin up -d jellyfin
    echo "Waiting for Jellyfin to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8096/health > /dev/null 2>&1; then
            echo "Jellyfin is ready!"
            break
        fi
        sleep 2
    done
fi

# Ensure Jellyseerr is running (uses main compose.yaml with profiles)
if ! docker ps | grep -q jellyseerr; then
    echo "Starting Jellyseerr..."
    docker compose --profile jellyfin up -d jellyseerr
    echo "Waiting for Jellyseerr to start..."
    sleep 5
fi

# Wait for Jellyseerr to be ready
echo "Waiting for Jellyseerr API..."
for i in {1..30}; do
    if curl -sf http://localhost:5055/api/v1/settings/public > /dev/null 2>&1; then
        echo "Jellyseerr is ready!"
        break
    fi
    sleep 2
done

# Check if already initialized
INITIALIZED=$(curl -s http://localhost:5055/api/v1/settings/public | python3 -c 'import sys,json; print(json.load(sys.stdin).get("initialized", False))' 2>/dev/null || echo "False")
if [ "$INITIALIZED" = "True" ]; then
    echo "Jellyseerr is already initialized"
    exit 0
fi

# Get Sonarr and Radarr API keys (trim whitespace)
echo "Getting Sonarr and Radarr API keys..."
SONARR_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' sonarr/config.xml | tr -d '[:space:]')
RADARR_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' radarr/config.xml | tr -d '[:space:]')

if [ -z "$SONARR_API_KEY" ] || [ -z "$RADARR_API_KEY" ]; then
    echo "Error: Could not get API keys from Sonarr/Radarr config files"
    echo "Make sure Sonarr and Radarr have started at least once"
    exit 1
fi

# Stop Jellyseerr to modify configuration
docker stop jellyseerr

# Update settings.json with Sonarr/Radarr configuration
SETTINGS_FILE="jellyfin/jellyseerr/settings.json"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Error: $SETTINGS_FILE not found"
    echo "Jellyseerr needs to start at least once to create this file"
    exit 1
fi

echo "Configuring Sonarr and Radarr in settings.json..."
sudo python3 << PYEOF
import json
with open('$SETTINGS_FILE', 'r') as f:
    config = json.load(f)

config['radarr'] = [{
    "id": 1,
    "name": "Radarr",
    "hostname": "radarr",
    "port": 7878,
    "apiKey": "$RADARR_API_KEY",
    "useSsl": False,
    "baseUrl": "",
    "activeProfileId": 1,
    "activeProfileName": "Any",
    "activeDirectory": "/data/movies",
    "tags": [],
    "is4k": False,
    "minimumAvailability": "released",
    "isDefault": True,
    "externalUrl": "",
    "syncEnabled": True
}]

config['sonarr'] = [{
    "id": 1,
    "name": "Sonarr",
    "hostname": "sonarr",
    "port": 8989,
    "apiKey": "$SONARR_API_KEY",
    "useSsl": False,
    "baseUrl": "",
    "activeProfileId": 1,
    "activeProfileName": "Any",
    "activeDirectory": "/data/shows",
    "activeLanguageProfileId": 1,
    "tags": [],
    "activeAnimeProfileId": None,
    "activeAnimeDirectory": None,
    "activeAnimeLanguageProfileId": None,
    "animeTags": [],
    "is4k": False,
    "enableSeasonFolders": True,
    "isDefault": True,
    "externalUrl": "",
    "syncEnabled": True
}]

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(config, f, indent=2)
PYEOF

# Start Jellyseerr
docker start jellyseerr

echo ""
echo "✓ Jellyseerr fully configured!"
echo ""
echo "Access Jellyseerr at: http://localhost:5055"
echo "Complete one-time setup wizard:"
echo "  1. Choose Jellyfin server"
echo "  2. Sign in with: $USERNAME / $PASSWORD"
echo "  3. Email: admin@localhost"
echo ""
echo "Sonarr and Radarr will be auto-configured!"
