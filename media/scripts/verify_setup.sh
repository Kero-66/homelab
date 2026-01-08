#!/bin/bash

# Verification script to check all services are properly configured

echo "════════════════════════════════════════════════════════════"
echo "  Media Stack Configuration Verification"
echo "════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load CONFIG_DIR from .env (defaults to current directory)
CONFIG_DIR="."
if [[ -f .env ]]; then
  CONFIG_DIR=$(grep -E "^CONFIG_DIR=" .env | cut -d'=' -f2 || echo ".")
  CONFIG_DIR="${CONFIG_DIR:-.}"
fi

check_service() {
    local name=$1
    local port=$2
    local check_url=$3
    
    if curl -sf "$check_url" > /dev/null 2>&1; then
        echo "✓ $name (http://localhost:$port)"
        return 0
    else
        echo "✗ $name - NOT RESPONDING"
        return 1
    fi
}

check_config_file() {
    local service=$1
    local file=$2
    local pattern=$3
    
    if [ -f "$file" ] && grep -q "$pattern" "$file" 2>/dev/null; then
        echo "  ✓ $service configuration found"
        return 0
    else
        echo "  ✗ $service configuration MISSING"
        return 1
    fi
}

# Check service accessibility
echo "Service Status:"
check_service "Sonarr" "8989" "http://localhost:8989/ping"
check_service "Radarr" "7878" "http://localhost:7878/ping"
check_service "Lidarr" "8686" "http://localhost:8686/ping"
check_service "Prowlarr" "9696" "http://localhost:9696/ping"
check_service "qBittorrent" "8080" "http://localhost:8080"
check_service "NZBGet" "6789" "http://localhost:6789"
check_service "Bazarr" "6767" "http://localhost:6767/ping"
check_service "Jellyfin" "8096" "http://localhost:8096/health"
check_service "Jellyseerr" "5055" "http://localhost:5055/api/v1/settings/public"
check_service "Jellystat" "3002" "http://localhost:3002"
check_service "FlareSolverr" "8191" "http://localhost:8191"

echo ""
echo "Configuration Files:"
check_config_file "Sonarr" "$CONFIG_DIR/sonarr/config.xml" "<ApiKey>"
check_config_file "Radarr" "$CONFIG_DIR/radarr/config.xml" "<ApiKey>"
check_config_file "Lidarr" "$CONFIG_DIR/lidarr/config.xml" "<ApiKey>"
check_config_file "Prowlarr" "$CONFIG_DIR/prowlarr/config.xml" "<ApiKey>"
check_config_file "Bazarr" "$CONFIG_DIR/bazarr/config/config.yaml" "use_sonarr: true"
check_config_file "Jellyfin" "$CONFIG_DIR/jellyfin/config/system.xml" "<ServerName>"
check_config_file "Jellyseerr" "$CONFIG_DIR/jellyfin/jellyseerr/settings.json" '"initialized": true'

echo ""
echo "API Integration Checks:"

# Check Prowlarr has apps connected
PROWLARR_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$CONFIG_DIR/prowlarr/config.xml" 2>/dev/null | tr -d '[:space:]')
if [ -n "$PROWLARR_KEY" ]; then
    APP_COUNT=$(curl -s "http://localhost:9696/api/v1/applications" -H "X-Api-Key: $PROWLARR_KEY" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "0")
    if [ "$APP_COUNT" -ge "3" ]; then
        echo "  ✓ Prowlarr connected to $APP_COUNT apps"
    else
        echo "  ✗ Prowlarr has only $APP_COUNT apps (expected 3+)"
    fi
else
    echo "  ✗ Cannot read Prowlarr API key"
fi

# Check Sonarr has download clients
SONARR_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$CONFIG_DIR/sonarr/config.xml" 2>/dev/null | tr -d '[:space:]')
if [ -n "$SONARR_KEY" ]; then
    DL_COUNT=$(curl -s "http://localhost:8989/api/v3/downloadclient" -H "X-Api-Key: $SONARR_KEY" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "0")
    if [ "$DL_COUNT" -ge "2" ]; then
        echo "  ✓ Sonarr has $DL_COUNT download clients"
    else
        echo "  ✗ Sonarr has only $DL_COUNT download clients (expected 2+)"
    fi
else
    echo "  ✗ Cannot read Sonarr API key"
fi

# Check Jellyseerr configuration
if [ -f "jellyfin/jellyseerr/settings.json" ]; then
    INITIALIZED=$(sudo cat jellyfin/jellyseerr/settings.json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("public", {}).get("initialized", False))' 2>/dev/null)
    RADARR_COUNT=$(sudo cat jellyfin/jellyseerr/settings.json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("radarr", [])))' 2>/dev/null || echo "0")
    SONARR_COUNT=$(sudo cat jellyfin/jellyseerr/settings.json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("sonarr", [])))' 2>/dev/null || echo "0")
    
    if [ "$INITIALIZED" = "True" ] && [ "$RADARR_COUNT" -ge "1" ] && [ "$SONARR_COUNT" -ge "1" ]; then
        echo "  ✓ Jellyseerr fully configured"
    else
        echo "  ⚠ Jellyseerr needs manual setup (visit http://localhost:5055)"
    fi
fi

echo ""
echo "Memory Limits:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | grep -E "NAME|jellyfin|jellyseerr|jellystat|sonarr|radarr|prowlarr|bazarr|qbittorrent|nzbget|lidarr|flaresolverr" | head -12

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Verification complete!"
echo ""
echo "If any checks failed, run: bash automate_all.sh"
echo "For detailed status, see: AUTOMATION_STATUS.md"
