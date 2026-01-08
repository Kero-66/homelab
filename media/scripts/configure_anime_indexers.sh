#!/bin/bash
set -e

# =============================================================================
# Configure Anime Indexers (Nyaa, DMHY, BakaBT, AniDex) - Prowlarr + Jackett
# =============================================================================
# This script provides setup instructions for anime-focused indexers:
# - Prowlarr built-in: Nyaa, AniDex, AnimeTosho, EZTV
# - Jackett: DMHY (Chinese anime), BakaBT (private), Anirena
#
# Run after: configure_indexers.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

PROWLARR_PORT=${PROWLARR_PORT:-9696}
JACKETT_PORT=${JACKETT_PORT:-9117}

echo "════════════════════════════════════════════════════════════"
echo "  Anime Indexer Configuration"
echo "════════════════════════════════════════════════════════════"
echo ""

# Extract API key
PROWLARR_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' prowlarr/config.xml 2>/dev/null | tr -d '[:space:]' || echo "")

if [[ -z "$PROWLARR_API_KEY" ]]; then
    echo "Error: Could not find Prowlarr API key"
    exit 1
fi

# =============================================================================
# Step 1: Show existing anime indexers in Prowlarr
# =============================================================================
echo "Step 1: Anime indexers already configured:"
echo ""

ANIME_INDEXERS=$(curl -s -H "X-Api-Key: $PROWLARR_API_KEY" \
    "http://localhost:$PROWLARR_PORT/api/v1/indexer" 2>/dev/null | \
    python3 -c "
import sys, json
anime_keywords = ['nyaa', 'anidex', 'animetosho', 'eztv', 'anime']
try:
    indexers = json.load(sys.stdin)
    for idx in indexers:
        name = idx.get('name', '').lower()
        if any(keyword in name for keyword in anime_keywords):
            print(idx.get('name', 'Unknown'))
except:
    pass
" || echo "")

if [[ -z "$ANIME_INDEXERS" ]]; then
    echo "  None found - add some from Step 2 below"
else
    while IFS= read -r indexer; do
        [[ -n "$indexer" ]] && echo "  ✓ $indexer"
    done <<< "$ANIME_INDEXERS"
fi

# =============================================================================
# Step 2: Recommend Prowlarr built-in anime indexers
# =============================================================================
echo ""
echo "Step 2: Add these built-in Prowlarr anime indexers:"
echo ""
echo "  To add:  http://localhost:$PROWLARR_PORT/indexers → '+' button"
echo ""
echo "     • Nyaa.si             - Primary anime torrent source (required)"
echo "     • Anidex              - Anime tracker and metadata"
echo "     • AnimeTosho          - High-quality anime releases"
echo "     • EZTV                - TV-focused (some anime available)"
echo ""

# =============================================================================
# Step 3: Jackett anime sources (Chinese, private)
# =============================================================================
echo "Step 3: Jackett anime scrapers (if you want additional sources):"
echo ""

if curl -s "http://localhost:$JACKETT_PORT/ping" > /dev/null 2>&1; then
    echo "  ✓ Jackett is running at http://localhost:$JACKETT_PORT"
    echo ""
    echo "  Optional scrapers to add in Jackett:"
    echo "     • DMHY (dmhy.org)       - Chinese donghua/anime source"
    echo "     • BakaBT (bakabt.me)    - Private tracker (requires invite)"
    echo "     • Nyaa (nyaa.si)        - Jackett scraper version"
    echo ""
    echo "  Steps:"
    echo "  1. Open http://localhost:$JACKETT_PORT"
    echo "  2. Search & add 'DMHY' or 'BakaBT' (or other anime trackers)"
    echo "  3. Configure with your credentials"
    echo "  4. Copy Torznab URL from the indexer"
    echo "  5. Add to Prowlarr as Torznab indexer"
else
    echo "  ⚠ Jackett is not running"
    echo "    Start with: docker compose up -d jackett"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Anime Setup Summary"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Must-have:"
echo "  ✓ Nyaa.si   (required for anime)"
echo ""
echo "Recommended:"
echo "  ✓ Anidex    (better metadata)"
echo "  ✓ AnimeTosho (high-quality releases)"
echo ""
echo "Optional (via Jackett):"
echo "  ○ DMHY      (Chinese donghua)"
echo "  ○ BakaBT    (older anime, private)"
echo ""
echo "After adding indexers:"
echo "  1. Configure Sonarr/Radarr for anime"
echo "  2. Create anime quality profiles"
echo "  3. Add search filters (e.g., 'BluRay', 'HEVC')"
echo ""

