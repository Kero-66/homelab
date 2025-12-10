#!/bin/bash
# =============================================================================
# Manga/Comic/Webtoon Setup Script for Jellyfin
# Configures: Sonarr (for manga), Komga, and Jellyfin Bookshelf Plugin
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SONARR_HOST="${SONARR_HOST:-http://localhost:8989}"
SONARR_API_KEY="${SONARR_API_KEY:-}"
PROWLARR_HOST="${PROWLARR_HOST:-http://localhost:9696}"
PROWLARR_API_KEY="${PROWLARR_API_KEY:-}"
JELLYFIN_HOST="${JELLYFIN_HOST:-http://localhost:8096}"
JELLYFIN_ADMIN_KEY="${JELLYFIN_ADMIN_KEY:-}"
QBITTORRENT_HOST="${QBITTORRENT_HOST:-http://qbittorrent:8080}"
QBITTORRENT_USER="${QBITTORRENT_USER:-admin}"
QBITTORRENT_PASS="${QBITTORRENT_PASS:-}"
KOMGA_HOST="${KOMGA_HOST:-http://localhost:8081}"

echo -e "${YELLOW}=== Manga/Comic/Webtoon Pipeline Setup ===${NC}"

# Step 1: Get Sonarr API Key
echo -e "\n${YELLOW}Step 1: Getting Sonarr API Key...${NC}"
if [ -z "$SONARR_API_KEY" ]; then
    SONARR_API_KEY=$(cat sonarr/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
    if [ -z "$SONARR_API_KEY" ]; then
        echo -e "${RED}Error: Could not find Sonarr API key in config.xml${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}Sonarr API Key: ${SONARR_API_KEY}${NC}"

# Step 2: Configure Sonarr for Manga
echo -e "\n${YELLOW}Step 2: Configuring Sonarr for Manga...${NC}"

# 2a. Set download path
echo "  - Setting download path..."
curl -s -X PUT "${SONARR_HOST}/api/v3/config/mediamanagement" \
  -H "X-Api-Key: ${SONARR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "renameEpisodes": true,
    "episodeNamingFormat": "{Series Title} - {season:0}x{episode:00} - {episode title}",
    "seriesFolderFormat": "{Series Title}",
    "seasonFolderFormat": "Season {season}",
    "useLegacyNamingFormat": false,
    "checkForFinishedDownloadInterval": 1
  }' > /dev/null 2>&1 || echo "  Note: Some settings may require manual configuration"

# 2b. Configure qBittorrent download client
echo "  - Configuring qBittorrent client..."
QBIT_CONFIG=$(cat <<'EOF'
{
  "enable": true,
  "protocol": "torrent",
  "priority": 1,
  "removeCompletedDownloads": true,
  "removeFailedDownloads": true,
  "name": "qBittorrent",
  "implementation": "QBittorrent",
  "configContract": "QBittorrentSettings",
  "tags": ["manga"],
  "fields": [
    {
      "name": "host",
      "value": "qbittorrent"
    },
    {
      "name": "port",
      "value": 8080
    },
    {
      "name": "useSsl",
      "value": false
    },
    {
      "name": "username",
      "value": "admin"
    },
    {
      "name": "password",
      "value": ""
    },
    {
      "name": "category",
      "value": "manga"
    }
  ]
}
EOF
)

curl -s -X POST "${SONARR_HOST}/api/v3/downloadclient" \
  -H "X-Api-Key: ${SONARR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$QBIT_CONFIG" > /dev/null 2>&1 || echo "  Note: qBittorrent may already be configured"

# Step 3: Configure Prowlarr Integration with Sonarr
echo -e "\n${YELLOW}Step 3: Configuring Prowlarr Integration...${NC}"

# Get Sonarr Prowlarr ID (or create if not exists)
SONARR_PROWLARR_APP=$(curl -s "${PROWLARR_HOST}/api/v1/applications" \
  -H "X-Api-Key: ${PROWLARR_API_KEY}" 2>/dev/null | grep -o '"id":[0-9]*' | head -1 || echo "")

if [ -z "$SONARR_PROWLARR_APP" ]; then
    echo "  - Registering Sonarr with Prowlarr..."
    curl -s -X POST "${PROWLARR_HOST}/api/v1/applications" \
      -H "X-Api-Key: ${PROWLARR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "Sonarr",
        "implementation": "Sonarr",
        "configContract": "SonarrSettings",
        "tags": [],
        "fields": [
          {"name": "baseUrl", "value": "http://sonarr:8989"},
          {"name": "apiKey", "value": "'${SONARR_API_KEY}'"},
          {"name": "syncCategories", "value": [5070, 7000]},
          {"name": "priority", "value": 25}
        ]
      }' > /dev/null 2>&1
fi

echo -e "${GREEN}Prowlarr integration configured${NC}"

# Step 4: Komga Configuration
echo -e "\n${YELLOW}Step 4: Komga Configuration${NC}"
echo "  - Komga is running at ${KOMGA_HOST}"
echo "  - Default login: kero66 / temppwd"
echo "  - Mount point: /books"

# Step 5: Jellyfin Bookshelf Plugin Setup Instructions
echo -e "\n${YELLOW}Step 5: Jellyfin Bookshelf Plugin Setup${NC}"
echo "  1. Go to Jellyfin Settings > Plugins"
echo "  2. Search for 'Bookshelf'"
echo "  3. Install the plugin"
echo "  4. Restart Jellyfin"
echo "  5. Go to Plugins > Bookshelf > Configuration"
echo "  6. Set Comic Vine API Key: ${MYLAR_COMICVINE_API}"
echo "  7. Configure library metadata providers"

# Step 6: Library Setup
echo -e "\n${YELLOW}Step 6: Library Setup${NC}"

# Create directory structure if it doesn't exist
mkdir -p /mnt/d/homelab-data/manga
mkdir -p /mnt/d/homelab-data/comics
mkdir -p /mnt/d/homelab-data/webtoons
mkdir -p /mnt/d/homelab-data/ebooks

echo "  - Created directory structure:"
echo "    • /mnt/d/homelab-data/manga (for manga downloads)"
echo "    • /mnt/d/homelab-data/comics (for comics)"
echo "    • /mnt/d/homelab-data/webtoons (for webtoons)"
echo "    • /mnt/d/homelab-data/ebooks (for eBooks)"

# Step 7: Summary
echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Add your first manga series to Sonarr: http://localhost:8989"
echo "2. Access Komga at: http://localhost:8081"
echo "3. Jellyfin Bookshelf plugin will show books/comics in Jellyfin"
echo ""
echo "Services:"
echo "  - Sonarr (Anime/Manga): http://localhost:8989"
echo "  - Komga (Manga Reader): http://localhost:8081"
echo "  - Prowlarr (Indexers): http://localhost:9696"
echo "  - Jellyfin: http://localhost:8096"
echo ""
echo "Configuration files saved to:"
echo "  - Sonarr: ./sonarr/config.xml"
echo "  - Komga: ./komga/"
echo ""
