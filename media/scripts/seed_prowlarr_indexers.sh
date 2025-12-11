#!/bin/bash
set -euo pipefail

# =============================================================================
# Prowlarr Indexer Configuration - Database Seeding
# =============================================================================
# SOLUTION PATTERN:
# Prowlarr stores indexers in SQLite database (prowlarr.db), not XML config
# 
# Database tables:
#   - Indexers: Main indexer records (Name, Implementation, ConfigContract, Settings)
#   - IndexerStatus: Health/status tracking
#   - ApplicationIndexerMapping: Links indexers to Sonarr/Radarr/Lidarr
#
# APPROACH:
# 1. Before container start: Seed prowlarr.db with indexer records
# 2. Use direct SQLite INSERT to add indexers with proper settings JSON
# 3. Only add missing indexers (check by Name uniqueness)
#
# DOCUMENTED INDEXER FORMATS:
# - Cardigann: Site scrapers (Nyaa, EZTV, etc.)
#   Implementation: "Cardigann"
#   ConfigContract: "CardigannSettings"  
#   Settings: JSON with definitionFile, extraFieldData, baseSettings
#
# - Torznab: Torrent feed aggregators (AnimeTosho, Jackett)
#   Implementation: "Torznab"
#   ConfigContract: "TorznabSettings"
#   Settings: JSON with baseUrl, apiPath, apiKey
#
# - Newznab: Usenet indexers (NZBGeek, Generic Newznab)
#   Implementation: "Newznab"
#   ConfigContract: "NewznabSettings"
#   Settings: JSON with baseUrl, apiPath, apiKey
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "════════════════════════════════════════════════════════════"
echo "  Prowlarr Indexer Setup (Database Seeding)"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if prowlarr.db exists
if [[ ! -f "prowlarr/prowlarr.db" ]]; then
    echo -e "${YELLOW}⚠${NC} prowlarr.db not found - container may not have started yet"
    echo "  Wait for Prowlarr container to start, then run: bash scripts/configure_indexers.sh"
    exit 0
fi

# Function to check if indexer exists
indexer_exists() {
    local name="$1"
    sqlite3 prowlarr/prowlarr.db "SELECT COUNT(*) FROM Indexers WHERE Name='$name';"
}

# Function to add indexer to database
add_indexer() {
    local name="$1"
    local implementation="$2"
    local config_contract="$3"
    local settings="$4"
    local priority="${5:-25}"
    
    if [[ $(indexer_exists "$name") -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} $name (already exists)"
        return 0
    fi
    
    # Insert into Indexers table
    sqlite3 prowlarr/prowlarr.db << EOF
INSERT INTO Indexers (Name, Implementation, ConfigContract, Settings, Enable, Priority, Added, Redirect, AppProfileId, Tags, DownloadClientId)
VALUES (
    '$name',
    '$implementation',
    '$config_contract',
    '$settings',
    1,
    $priority,
    datetime('now'),
    0,
    1,
    '[]',
    0
);
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $name added"
    else
        echo -e "${YELLOW}⚠${NC} $name failed to add"
        return 1
    fi
}

# Cardigann indexers (scrapers like Nyaa)
echo "Adding Cardigann indexers..."
add_indexer "Nyaa.si" "Cardigann" "CardigannSettings" \
    '{"definitionFile":"nyaasi","extraFieldData":{"prefer_magnet_links":true,"sonarr_compatibility":false,"strip_s01":false,"radarr_compatibility":false,"filter-id":0,"cat-id":0,"sort":0,"type":1},"baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":false}}'

add_indexer "Anidex" "Cardigann" "CardigannSettings" \
    '{"definitionFile":"anidex","extraFieldData":{},"baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":false}}'

add_indexer "The Pirate Bay" "Cardigann" "CardigannSettings" \
    '{"definitionFile":"thepiratebay","extraFieldData":{},"baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":true}}'

add_indexer "TorrentGalaxy" "Cardigann" "CardigannSettings" \
    '{"definitionFile":"torrentgalaxy","extraFieldData":{},"baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":false}}'

add_indexer "1337x" "Cardigann" "CardigannSettings" \
    '{"definitionFile":"1337x","extraFieldData":{},"baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":false}}'

add_indexer "RARBG" "Cardigann" "CardigannSettings" \
    '{"definitionFile":"rarbg","extraFieldData":{},"baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":true}}'

echo ""
echo "Adding Torznab indexers..."
add_indexer "AnimeTosho" "Torznab" "TorznabSettings" \
    '{"baseUrl":"https://feed.animetosho.org","apiPath":"/api","apiKey":"","baseSettings":{"limitsUnit":0},"torrentBaseSettings":{"preferMagnetUrl":false}}'

echo ""
echo "Adding Newznab indexers..."
add_indexer "Generic Newznab" "Newznab" "NewznabSettings" \
    '{"baseUrl":"https://nzbgeek.info","apiPath":"/api","apiKey":"","baseSettings":{"limitsUnit":0}}'

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Indexer seeding complete${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Indexers added and ready for use in Sonarr/Radarr/Lidarr"
echo ""
