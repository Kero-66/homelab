#!/bin/bash
set -e

# Complete automation script for fresh media stack deployment
# Run this after: docker compose up -d

echo "════════════════════════════════════════════════════════════"
echo "  Media Stack Complete Automation"
echo "════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"

# Check if .credentials exists
if [ ! -f "$MEDIA_DIR/.config/.credentials" ]; then
    echo "ERROR: .config/.credentials not found!"
    echo "Please create it with:"
    echo "  USERNAME=your_username"
    echo "  PASSWORD=your_password"
    exit 1
fi

# Wait for all services to be ready
echo "Step 1: Waiting for services to start..."
sleep 10

# Configure Arr stack (authentication + root folders)
echo ""
echo "Step 2: Configuring Arr apps (Sonarr, Radarr, Lidarr)..."
bash "$SCRIPT_DIR/wait_and_configure_auth.sh"

# Configure download clients
echo ""
echo "Step 3: Configuring download clients (qBittorrent, NZBGet)..."
bash "$SCRIPT_DIR/configure_download_clients.sh"

# Configure Prowlarr with indexers and app connections
echo ""
echo "Step 4: Configuring Prowlarr (indexers + app sync)..."
bash "$SCRIPT_DIR/configure_prowlarr.sh"

# Configure Sonarr for anime
echo ""
echo "Step 5: Configuring Sonarr for Anime (Japanese audio preference)..."
bash "$SCRIPT_DIR/configure_sonarr_anime.sh"

# Configure Radarr for anime
echo ""
echo "Step 6: Configuring Radarr for Anime (Japanese audio preference)..."
bash "$SCRIPT_DIR/configure_radarr_anime.sh"

# Configure Bazarr subtitle integration
echo ""
echo "Step 7: Configuring Bazarr (Sonarr/Radarr integration)..."
bash "$SCRIPT_DIR/configure_bazarr.sh"

# Configure Jellyfin ecosystem
echo ""
echo "Step 8: Configuring Jellyfin..."
bash "$MEDIA_DIR/jellyfin/configure_jellyfin.sh"

# Configure Jellyseerr anime integration
echo ""
echo "Step 9: Configuring Jellyseerr for Anime..."
bash "$SCRIPT_DIR/configure_jellyseerr_anime.sh"

# Configure TVHeadend for live TV
echo ""
echo "Step 10: Configuring TVHeadend (Live TV)..."
bash "$SCRIPT_DIR/configure_tvheadend.sh"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Automation Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Automation Status: ~98% complete"
echo ""
echo "Services Ready:"
echo "  ✓ Sonarr:        http://localhost:8989"
echo "  ✓ Radarr:        http://localhost:7878"
echo "  ✓ Lidarr:        http://localhost:8686"
echo "  ✓ Prowlarr:      http://localhost:9696"
echo "  ✓ qBittorrent:   http://localhost:8080"
echo "  ✓ NZBGet:        http://localhost:6789"
echo "  ✓ Bazarr:        http://localhost:6767"
echo "  ✓ Jellyfin:      http://localhost:8096"
echo "  ✓ Jellyseerr:    http://localhost:5055"
echo "  ✓ Jellystat:     http://localhost:3000"
echo "  ✓ TVHeadend:     http://localhost:9981"
echo ""
echo "Manual Steps Required (~5 minutes):"
echo ""
echo "1. Jellyseerr Setup (2 min):"
echo "   - Visit http://localhost:5055"
echo "   - Choose Jellyfin server"
echo "   - Sign in with your credentials"
echo "   - Email: admin@localhost"
echo "   - Sonarr/Radarr already configured!"
echo ""
echo "2. Jellystat Setup (2 min):"
echo "   - Visit http://localhost:3000"
echo "   - Create account"
echo "   - Add Jellyfin server with API key from:"
echo "     jellyfin/jellyseerr/settings.json (search for 'apiKey')"
echo ""
echo "3. TVHeadend Live TV Setup (1-2 min):"
echo "   - Visit http://localhost:9981"
echo "   - Login with admin / admin"
echo "   - Go to Configuration > DVB Inputs > Networks"
echo "   - Select 'IPTV Playlist' network"
echo "   - Click 'Scan for services' to import channels"
echo "   - Optional: Add EPG source from https://github.com/iptv-org/epg"
echo ""
echo "4. Bazarr Providers (optional, 2-3 min):"
echo "   - Visit http://localhost:6767"
echo "   - Settings → Providers"
echo "   - Add OpenSubtitles, Subscene, etc."
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Check docs/AUTOMATION_STATUS.md for detailed setup info!"
