#!/bin/bash
set -e

# Configure Bazarr to connect with Sonarr and Radarr for automatic subtitle downloads

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load CONFIG_DIR from .env (defaults to current directory)
CONFIG_DIR="."
if [[ -f .env ]]; then
  CONFIG_DIR=$(grep -E "^CONFIG_DIR=" .env | cut -d'=' -f2 || echo ".")
  CONFIG_DIR="${CONFIG_DIR:-.}"
fi

# Load credentials
if [ ! -f .config/.credentials ]; then
    echo "Error: .config/.credentials file not found"
    exit 1
fi

source .config/.credentials

echo "Waiting for Bazarr to be ready..."
for i in {1..30}; do
    if curl -s "http://localhost:6767" > /dev/null 2>&1; then
        echo "Bazarr is ready!"
        break
    fi
    sleep 2
done

# Get Bazarr API key
BAZARR_API_KEY=$BAZARR_API_KEY

if [ -z "$BAZARR_API_KEY" ]; then
    BAZARR_API_KEY=$(grep "apikey:" "$CONFIG_DIR/bazarr/config/config.yaml" | head -1 | cut -d' ' -f4)
fi

if [ -z "$BAZARR_API_KEY" ]; then
    echo "Error: Could not find Bazarr API key"
    exit 1
fi

echo "Bazarr API Key: ${BAZARR_API_KEY:0:8}..."

# Use API keys from .credentials
SONARR_API_KEY=$SONARR_API_KEY
RADARR_API_KEY=$RADARR_API_KEY

# Configure Bazarr config file directly
echo "Updating Bazarr configuration..."

# Backup original config
cp "$CONFIG_DIR/bazarr/config/config.yaml" "$CONFIG_DIR/bazarr/config/config.yaml.bak"

# Update config using sed
sed -i "s|use_radarr: false|use_radarr: true|g" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "s|use_sonarr: false|use_sonarr: true|g" "$CONFIG_DIR/bazarr/config/config.yaml"

# Update Sonarr settings
sed -i "/^sonarr:/,/^[a-z]/ s|apikey: ''|apikey: '$SONARR_API_KEY'|" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "/^sonarr:/,/^[a-z]/ s|ip: .*|ip: 'sonarr'|" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "/^sonarr:/,/^[a-z]/ s|port: .*|port: 8989|" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "/^sonarr:/,/^[a-z]/ s|base_url: .*|base_url: '/sonarr'|" "$CONFIG_DIR/bazarr/config/config.yaml"

# Update Radarr settings
sed -i "/^radarr:/,/^[a-z]/ s|apikey: ''|apikey: '$RADARR_API_KEY'|" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "/^radarr:/,/^[a-z]/ s|ip: .*|ip: 'radarr'|" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "/^radarr:/,/^[a-z]/ s|port: .*|port: 7878|" "$CONFIG_DIR/bazarr/config/config.yaml"
sed -i "/^radarr:/,/^[a-z]/ s|base_url: .*|base_url: '/radarr'|" "$CONFIG_DIR/bazarr/config/config.yaml"

echo "✓ Bazarr configuration updated"

# Restart Bazarr to apply changes
echo "Restarting Bazarr..."
docker compose restart bazarr

echo "Waiting for Bazarr to restart..."
sleep 10

echo ""
echo "✓ Bazarr configured successfully!"
echo ""
echo "Access Bazarr at: http://localhost:6767"
echo "API Key: $BAZARR_API_KEY"
echo ""
echo "Next steps:"
echo "1. Go to Settings → Languages and add your preferred subtitle languages"
echo "2. Go to Settings → Providers and add subtitle providers (OpenSubtitles, etc.)"
echo "3. Bazarr will automatically download subtitles for new content from Sonarr/Radarr"
