#!/usr/bin/env bash
set -euo pipefail

# Idempotent Ubooquity configuration helper
# Configures Ubooquity API key and basic settings using JSON manipulation
# Requires jq and the .credentials file

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${MEDIA_DIR}/ubooquity"

# Load credentials if available
if [[ -f "${MEDIA_DIR}/.config/.credentials" ]]; then
    echo "Loading credentials from .config/.credentials"
    source "${MEDIA_DIR}/.config/.credentials" || true
fi

# Detect which preferences file to use (v2 is newer format)
PREFS_FILE="${CONFIG_DIR}/preferences-2.json"
if [[ ! -f "$PREFS_FILE" ]]; then
    PREFS_FILE="${CONFIG_DIR}/preferences.json"
fi

if [[ ! -f "$PREFS_FILE" ]]; then
    echo "Error: Ubooquity preferences file not found at $CONFIG_DIR"
    echo "Start Ubooquity at least once to generate the configuration file."
    exit 1
fi

echo "Configuring Ubooquity using $PREFS_FILE"

# Ensure API key exists in credentials
if [[ -z "${UBOOQUITY_API_KEY:-}" ]]; then
    # Try to extract from existing config
    if command -v jq >/dev/null 2>&1; then
        EXISTING_KEY=$(jq -r '.secretApiKey // empty' "$PREFS_FILE" 2>/dev/null || true)
        if [[ -n "$EXISTING_KEY" ]]; then
            echo "Importing existing Ubooquity API key to .credentials"
            echo "UBOOQUITY_API_KEY=$EXISTING_KEY" >> "${MEDIA_DIR}/.config/.credentials"
            UBOOQUITY_API_KEY="$EXISTING_KEY"
        fi
    fi
    
    # If still not set, generate a new one
    if [[ -z "${UBOOQUITY_API_KEY:-}" ]]; then
        echo "Generating new Ubooquity API key"
        UBOOQUITY_API_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(22).lower().replace('_','').replace('-','')[:30])")
        echo "UBOOQUITY_API_KEY=$UBOOQUITY_API_KEY" >> "${MEDIA_DIR}/.config/.credentials"
    fi
fi

# Update the preferences file with the API key using jq
if command -v jq >/dev/null 2>&1; then
    echo "Updating Ubooquity configuration with API key..."
    
    # Create a backup
    cp "$PREFS_FILE" "${PREFS_FILE}.bak"
    
    # Update the API key in the JSON file
    jq --arg apikey "$UBOOQUITY_API_KEY" \
        '.secretApiKey = $apikey' \
        "$PREFS_FILE" > "${PREFS_FILE}.tmp" && mv "${PREFS_FILE}.tmp" "$PREFS_FILE"
    
    echo "✓ API key configured: $UBOOQUITY_API_KEY"
    
    # Optionally configure other settings if needed
    # Example: set reverse proxy prefix, ports, etc.
    
else
    echo "Warning: jq not found. Please install jq to automatically configure Ubooquity."
    echo "Manual configuration required:"
    echo "  1. Set secretApiKey to: $UBOOQUITY_API_KEY"
    exit 1
fi

# Restart Ubooquity container to apply changes
if command -v docker >/dev/null 2>&1; then
    echo "Restarting ubooquity container..."
    docker compose -f "${MEDIA_DIR}/compose.yaml" restart ubooquity || true
    echo "✓ Ubooquity restarted"
fi

echo ""
echo "Ubooquity configuration complete!"
echo "API Key: $UBOOQUITY_API_KEY"
echo ""
echo "You can test the API with:"
echo "  curl \"http://localhost:2202/ubooquity/admin-api/comics?apikey=$UBOOQUITY_API_KEY\""
