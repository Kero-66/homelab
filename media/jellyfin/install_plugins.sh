#!/bin/bash
# install_plugins.sh - Automated Jellyfin plugin installation via API
# Run after Jellyfin container is up and running

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env
ENV_FILE="${SCRIPT_DIR}/../.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
# JELLYFIN_API_KEY must be set in .env or environment
if [ -z "$JELLYFIN_API_KEY" ]; then
    echo "ERROR: JELLYFIN_API_KEY not set. Add it to media/.env"
    exit 1
fi

# Plugins to install (names must match exactly from /Packages API)
PLUGINS=(
    "File Transformation"
    "Jellyfin Enhanced"
    "Media Bar"
    "Home Screen Sections"
    "Custom Tabs"
    "JavaScript Injector"
    "Jellyfin Tweaks"
    "Plugin Pages"
    "NextPVR"
)

echo "=== Jellyfin Plugin Installer (API) ==="
echo "URL: $JELLYFIN_URL"
echo ""

# Wait for Jellyfin to be ready
wait_for_jellyfin() {
    local max_attempts=30
    local attempt=1
    echo "Waiting for Jellyfin to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$JELLYFIN_URL/System/Info" -H "X-Emby-Token: $JELLYFIN_API_KEY" | grep -q "Version"; then
            echo "Jellyfin is ready"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        ((attempt++))
    done
    echo "ERROR: Jellyfin did not become ready"
    return 1
}

# Get installed plugins
get_installed_plugins() {
    curl -s "$JELLYFIN_URL/Plugins" -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq -r '.[].Name'
}

# Install a plugin by name
install_plugin() {
    local name="$1"
    local encoded_name=$(echo "$name" | sed 's/ /%20/g')
    
    echo "Installing: $name"
    
    # Check if already installed
    if get_installed_plugins | grep -q "^${name}$"; then
        echo "  ✓ Already installed"
        return 0
    fi
    
    # Check if available in configured repos
    local available=$(curl -s "$JELLYFIN_URL/Packages" -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq -r ".[] | select(.name == \"$name\") | .name")
    if [ -z "$available" ]; then
        echo "  ✗ Not found in any configured repository"
        return 1
    fi
    
    # Install via API
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "$JELLYFIN_URL/Packages/Installed/$encoded_name" \
        -H "X-Emby-Token: $JELLYFIN_API_KEY")
    
    if [ "$http_code" = "204" ]; then
        echo "  ✓ Queued for installation"
        return 0
    else
        echo "  ✗ Failed (HTTP $http_code)"
        return 1
    fi
}

# Main
wait_for_jellyfin

echo ""
echo "Currently installed plugins:"
get_installed_plugins | while read -r plugin; do
    echo "  - $plugin"
done
echo ""

# Install each plugin
INSTALLED=0
for plugin in "${PLUGINS[@]}"; do
    if install_plugin "$plugin"; then
        ((INSTALLED++)) || true
    fi
done

echo ""
echo "=== Installation Complete ==="
echo "Plugins processed: ${#PLUGINS[@]}"

if [ "$INSTALLED" -gt 0 ]; then
    echo ""
    echo "Restarting Jellyfin to load new plugins..."
    curl -s -X POST "$JELLYFIN_URL/System/Restart" -H "X-Emby-Token: $JELLYFIN_API_KEY"
    echo "Jellyfin is restarting. Wait ~15 seconds for it to come back up."
fi
