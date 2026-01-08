#!/usr/bin/env bash
# seed_jackett_indexers.sh
# Purpose: Seed Jackett-based Torznab indexers into Prowlarr database
# These indexers require Jackett to be running and accessible via Docker network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
PROWLARR_DB="$MEDIA_DIR/prowlarr/prowlarr.db"

# Jackett connection details
JACKETT_HOST="http://jackett:9117"
JACKETT_API_KEY="46vxyqzanpz4g18ouvdpezp230wvcp4t"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🎬 Seeding Jackett-based indexers into Prowlarr..."
echo "Database: $PROWLARR_DB"
echo "Jackett: $JACKETT_HOST"
echo ""

# Helper function to add Torznab indexer
add_torznab_indexer() {
  local name="$1"
  local jackett_tracker_id="$2"
  local priority="${3:-25}"
  
  # Torznab Settings JSON
  local settings="{\"baseUrl\":\"$JACKETT_HOST/torznab/$jackett_tracker_id\",\"apiPath\":\"/api/v2.0/indexers/{indexerId}/results/torznab\",\"apiKey\":\"$JACKETT_API_KEY\",\"categories\":[],\"minimumSeeders\":0}"
  
  # Check if indexer already exists
  local exists=$(sqlite3 "$PROWLARR_DB" "SELECT COUNT(*) FROM Indexers WHERE Name = '$name';" 2>/dev/null || echo 0)
  
  if [ "$exists" -gt 0 ]; then
    echo "⏭️  $name (already exists)"
    return 0
  fi
  
  # Insert indexer
  sqlite3 "$PROWLARR_DB" << EOF
INSERT INTO Indexers (Name, Implementation, ConfigContract, Settings, Enable, Priority, Added, Redirect, AppProfileId, Tags, DownloadClientId)
VALUES ('$name', 'Torznab', 'TorznabSettings', '$settings', 1, $priority, datetime('now'), 0, 1, '[]', 0);
EOF
  
  if [ $? -eq 0 ]; then
    echo "✓ $name (added)"
  else
    echo -e "${RED}✗ $name (failed)${NC}"
    return 1
  fi
}

# Anime-focused indexers via Jackett
# Only add indexers that don't have native Prowlarr support
add_torznab_indexer "DMHY" "dmhy" 24
# Note: Nyaa.si has native Cardigann support in Prowlarr - faster and no Jackett overhead
# Note: 52BT has aggressive Cloudflare protection that crashes FlareSolverr

echo ""
echo "✅ Jackett-based indexers seeded successfully!"
echo ""
echo "Note: Prowlarr will sync these indexers to Sonarr/Radarr on next sync cycle."
