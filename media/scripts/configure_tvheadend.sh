#!/usr/bin/env bash
set -euo pipefail

# Configure TVHeadend - Add IPTV sources and trigger automatic scanning via API
# This script fully automates TVHeadend setup with IPTV playlist importing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load .env variables
if [[ -f .env ]]; then
  CONFIG_DIR=$(grep -E "^CONFIG_DIR=" .env | cut -d'=' -f2 || echo ".")
  CONFIG_DIR="${CONFIG_DIR:-.}"
  TVHEADEND_PORT=$(grep -E "^TVHEADEND_PORT=" .env | cut -d'=' -f2 || echo "9981")
fi

TVHEADEND_URL="http://localhost:${TVHEADEND_PORT:-9981}"
TVHEADEND_CONFIG="${CONFIG_DIR}/tvheadend"
PLAYLIST_URL="https://iptv-org.github.io/iptv/index.m3u"
IPTV_NETWORK_UUID="fb78ffd1494c9cbb8b4526737694fd97"

echo "════════════════════════════════════════════════════════════"
echo "  TVHeadend Configuration"
echo "════════════════════════════════════════════════════════════"
echo ""

# Function to wait for TVHeadend to be ready
wait_for_tvheadend() {
  echo "Waiting for TVHeadend to be ready..."
  for i in {1..60}; do
    if curl -sf "$TVHEADEND_URL" > /dev/null 2>&1; then
      echo "✓ TVHeadend is ready!"
      return 0
    fi
    sleep 2
  done
  echo "✗ TVHeadend failed to start"
  return 1
}

# Function to configure IPTV playlist
configure_iptv_playlist() {
  echo "Configuring IPTV playlist..."
  
  # Find and configure the main IPTV network
  local NETWORK_DIR="$TVHEADEND_CONFIG/input/iptv/networks/$IPTV_NETWORK_UUID"
  local CONFIG_FILE="$NETWORK_DIR/config"
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "⚠ IPTV network not found. Waiting for TVHeadend to create it..."
    sleep 5
  fi
  
  # Update the network configuration with playlist URL
  if [[ -f "$CONFIG_FILE" ]]; then
    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    
    # Update configuration with playlist_auto enabled
    cat > "$CONFIG_FILE" << 'EOF'
{
        "channel_number": 0,
        "refetch_period": 3600,
        "ssl_peer_verify": false,
        "tsid_zero": false,
        "remove_args": "ticket",
        "ignore_path": 0,
        "use_libav": false,
        "scan_create": true,
        "service_sid": 0,
        "priority": 1,
        "spriority": 1,
        "max_streams": 0,
        "max_bandwidth": 0,
        "max_timeout": 0,
        "remove_scrambled": false,
        "enabled": true,
        "networkname": "IPTV Playlist",
        "nid": 0,
        "autodiscovery": 0,
        "bouquet": false,
        "skipinitscan": false,
        "idlescan": false,
        "sid_chnum": false,
        "ignore_chnum": false,
        "satip_source": 0,
        "localtime": 0,
        "wizard": true,
        "playlist_url": "https://iptv-org.github.io/iptv/index.m3u",
        "playlist_auto": 1,
        "playlist_keep_outdated": 0
}
EOF
    echo "✓ IPTV playlist configured"
    echo "  Playlist URL: $PLAYLIST_URL"
  fi
}

# Function to restart TVHeadend to load config
restart_tvheadend() {
  echo ""
  echo "Restarting TVHeadend to load configuration..."
  docker compose -f "$MEDIA_DIR/compose.yaml" restart tvheadend > /dev/null 2>&1
  sleep 10
  
  # Re-verify it's up
  if ! curl -sf "$TVHEADEND_URL" > /dev/null 2>&1; then
    echo "⚠ Warning: TVHeadend may not be fully ready"
    sleep 5
  fi
}

# Function to trigger channel scan via API
trigger_scan_via_api() {
  echo ""
  echo "Triggering channel scan via TVHeadend API..."
  
  # Build JSON payload with network UUID
  local JSON_PAYLOAD=$(cat <<EOF
{
  "uuid": "$IPTV_NETWORK_UUID"
}
EOF
)
  
  # Call the scan API endpoint
  local RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "$TVHEADEND_URL/api/mpegts/network/scan" 2>&1)
  
  if echo "$RESPONSE" | grep -q "error\|Error\|failed\|Failed"; then
    echo "⚠ API response: $RESPONSE"
    echo "  Note: Scan may still be processing in background"
    return 1
  else
    echo "✓ Scan triggered successfully"
    return 0
  fi
}

# Function to wait for initial channels to appear
wait_for_channels() {
  echo ""
  echo "Waiting for channels to be imported..."
  
  local MAX_WAIT=300  # 5 minutes
  local ELAPSED=0
  local CHECK_INTERVAL=10
  
  while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    # Check if muxes directory exists and has content
    local MUXES_DIR="$TVHEADEND_CONFIG/input/iptv/muxes"
    if [[ -d "$MUXES_DIR" ]]; then
      local MUX_COUNT=$(find "$MUXES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
      if [[ $MUX_COUNT -gt 0 ]]; then
        echo "✓ Channels imported! Found $MUX_COUNT+ channel entries"
        return 0
      fi
    fi
    
    echo "  Waiting for imports... ($ELAPSED/$MAX_WAIT seconds)"
    sleep $CHECK_INTERVAL
    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
  done
  
  echo "⚠ Import timeout - channels may still be downloading"
  echo "  This is normal for large playlists (5000+ channels)"
  echo "  Check TVHeadend logs or web UI for progress"
  return 0
}

# Main execution
main() {
  # Wait for TVHeadend container to start
  if ! wait_for_tvheadend; then
    echo "Error: TVHeadend failed to start"
    exit 1
  fi
  
  echo ""
  echo "Step 1: Configuring IPTV playlist..."
  configure_iptv_playlist
  
  echo ""
  echo "Step 2: Restarting TVHeadend..."
  restart_tvheadend
  
  echo ""
  echo "Step 3: Triggering automatic channel scan..."
  trigger_scan_via_api
  
  echo ""
  echo "Step 4: Monitoring channel import..."
  wait_for_channels
  
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  ✓ TVHeadend Setup Complete!"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  echo "Access TVHeadend Web UI: $TVHEADEND_URL"
  echo ""
  echo "Channels imported from:"
  echo "  ${PLAYLIST_URL}"
  echo ""
  echo "Import Status:"
  echo "  • Channel scanning initiated automatically"
  echo "  • Large playlists (5000+ channels) may take 5-15 minutes"
  echo "  • Check Configuration > DVB Inputs > Networks for progress"
  echo ""
  echo "Optional: Configure Electronic Program Guide (EPG)"
  echo "  Visit: https://github.com/iptv-org/epg"
  echo "  In TVHeadend: Configuration > DVB Inputs > EPG Grabber Modules"
  echo ""
}

main "$@"
