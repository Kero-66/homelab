#!/bin/bash
# Configure Jellyfin plugins and repositories
# Adds recommended plugin repositories and provides installation guidance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load environment
if [[ -f .env ]]; then
    source .env
fi
CONFIG_DIR="${CONFIG_DIR:-.}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Jellyfin Plugin Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Get Jellyfin API key
JELLYFIN_API=$(python3 -c "import json; print(json.load(open('${CONFIG_DIR}/jellyfin/jellyseerr/settings.json'))['jellyfin']['apiKey'])" 2>/dev/null || echo "")
if [[ -z "$JELLYFIN_API" ]]; then
    echo -e "${RED}❌ Could not get Jellyfin API key${NC}"
    exit 1
fi

# Get Jellyfin version
JELLYFIN_VERSION=$(curl -s "http://localhost:8096/System/Info" -H "X-Emby-Token: $JELLYFIN_API" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Version', 'Unknown'))" 2>/dev/null || echo "Unknown")
echo -e "Jellyfin Version: ${GREEN}$JELLYFIN_VERSION${NC}"
echo ""

# Recommended plugin repositories for your setup
declare -A REPOS=(
    # Essential for Jellyfin Enhanced and Intro Skipper
    ["File Transformation"]="https://www.iamparadox.dev/jellyfin/plugins/manifest.json"
    
    # Jellyfin Enhanced (already added, but ensure correct URL for 10.11)
    ["Jellyfin Enhanced"]="https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/10.11/manifest.json"
    
    # Intro Skipper - auto-skip intros/credits
    ["Intro Skipper"]="https://intro-skipper.org/manifest.json"
    
    # Anime metadata - great for your anime setup
    ["Ani-Sync"]="https://raw.githubusercontent.com/vosmiic/jellyfin-ani-sync/master/manifest.json"
    
    # Skin manager for themes
    ["danieladov Plugins"]="https://raw.githubusercontent.com/danieladov/JellyfinPluginManifest/master/manifest.json"
    
    # Theme songs for movies/shows
    ["LizardByte Plugins"]="https://app.lizardbyte.dev/jellyfin-plugin-repo/manifest.json"

    # Trakt-powered personalized recommendations, per-user virtual libraries, Jellyseerr integration
    ["JellyNext"]="https://raw.githubusercontent.com/luall0/jellyfin-luall0-plugins/refs/heads/main/manifest.json"
)

# Get current repositories
CURRENT_REPOS=$(curl -s "http://localhost:8096/Repositories" -H "X-Emby-Token: $JELLYFIN_API" 2>/dev/null || echo "[]")

echo -e "${YELLOW}📦 Checking Plugin Repositories...${NC}"
echo ""

# Function to check if repo exists
repo_exists() {
    local url=$1
    echo "$CURRENT_REPOS" | python3 -c "
import sys, json
repos = json.load(sys.stdin)
url = '$url'
for r in repos:
    if r.get('Url', '').lower() == url.lower():
        print('exists')
        exit(0)
print('missing')
" 2>/dev/null
}

# Check and add repositories
REPOS_TO_ADD=()
for name in "${!REPOS[@]}"; do
    url="${REPOS[$name]}"
    status=$(repo_exists "$url")
    if [[ "$status" == "exists" ]]; then
        echo -e "  ${GREEN}✅${NC} $name"
    else
        echo -e "  ${YELLOW}➕${NC} $name (will add)"
        REPOS_TO_ADD+=("$name|$url")
    fi
done

echo ""

if [[ ${#REPOS_TO_ADD[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Adding missing repositories...${NC}"
    
    # Build new repos array
    NEW_REPOS=$(echo "$CURRENT_REPOS" | python3 -c "
import sys, json
repos = json.load(sys.stdin)
additions = '''$(printf '%s\n' "${REPOS_TO_ADD[@]}")'''.strip().split('\n')
for addition in additions:
    if '|' in addition:
        name, url = addition.split('|', 1)
        repos.append({'Name': name, 'Url': url, 'Enabled': True})
print(json.dumps(repos))
")
    
    # Update repositories
    RESULT=$(curl -s -X POST "http://localhost:8096/Repositories" \
        -H "X-Emby-Token: $JELLYFIN_API" \
        -H "Content-Type: application/json" \
        -d "$NEW_REPOS" 2>/dev/null)
    
    echo -e "${GREEN}✅ Repositories updated${NC}"
else
    echo -e "${GREEN}✅ All recommended repositories already configured${NC}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Currently Installed Plugins${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

curl -s "http://localhost:8096/Plugins" -H "X-Emby-Token: $JELLYFIN_API" | python3 -c "
import sys, json
plugins = json.load(sys.stdin)
if plugins:
    for p in sorted(plugins, key=lambda x: x.get('Name', '')):
        status = '✅' if p.get('Status') == 'Active' else '⚠️ '
        print(f'  {status} {p.get(\"Name\", \"Unknown\")}: v{p.get(\"Version\", \"?\")}')
else:
    print('  No plugins installed')
"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Recommended Plugins to Install${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Install these via Dashboard > Plugins > Catalog:${NC}"
echo ""
echo -e "  ${GREEN}🔧 File Transformation${NC} (Required for Jellyfin Enhanced & Intro Skipper)"
echo -e "     Allows plugins to modify the web UI without permission issues"
echo ""
echo -e "  ${GREEN}✨ Jellyfin Enhanced${NC} (Highly Recommended)"
echo -e "     - Jellyseerr integration in search"
echo -e "     - Quality tags (4K/HDR/Atmos) on posters"
echo -e "     - Language flags on posters"
echo -e "     - .arr links for admins"
echo -e "     - Custom pause screen"
echo -e "     - Keyboard shortcuts"
echo -e "     - Auto Picture-in-Picture"
echo ""
echo -e "  ${GREEN}⏭️  Intro Skipper${NC} (Highly Recommended for TV Shows)"
echo -e "     - Auto-detects and skips intros/credits"
echo -e "     - Works with Jellyfin Enhanced auto-skip feature"
echo ""
echo -e "  ${GREEN}📺 Open Subtitles${NC} (Official - Already in catalog)"
echo -e "     - Auto-download subtitles from OpenSubtitles.org"
echo ""
echo -e "  ${GREEN}📊 Playback Reporting${NC} (Official - Already in catalog)"
echo -e "     - Track watch history and statistics"
echo ""
echo -e "  ${GREEN}🎬 TMDb Box Sets${NC} (Official - Already in catalog)"
echo -e "     - Auto-create movie collections from TMDb"
echo ""
echo -e "  ${GREEN}🎵 Themerr${NC} (From LizardByte repo)"
echo -e "     - Add theme songs to movies and TV shows"
echo ""
echo -e "  ${GREEN}🎯 JellyNext${NC} (From JellyNext repo)"
echo -e "     - Trakt-powered personalized recommendations (per-user watch history), routes requests through Jellyseerr"
echo ""

# For anime users
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Anime-Specific Plugins${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}🎌 AniDB${NC} (Official - Already in catalog)"
echo -e "     - Anime metadata from AniDB"
echo ""
echo -e "  ${GREEN}🎌 AniList${NC} (Official - Already in catalog)"
echo -e "     - Anime metadata from AniList"
echo ""
echo -e "  ${GREEN}🔄 Ani-Sync${NC} (From Ani-Sync repo)"
echo -e "     - Sync anime watch progress to MAL/AniList/Kitsu"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚠️  After installing plugins, restart Jellyfin:${NC}"
echo -e "   docker restart jellyfin"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Jellyseerr configuration note for Jellyfin Enhanced
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Jellyfin Enhanced + Jellyseerr Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "After installing Jellyfin Enhanced, configure Jellyseerr integration:"
echo ""
echo -e "  1. Go to ${YELLOW}Dashboard > Plugins > Jellyfin Enhanced${NC}"
echo -e "  2. Click ${YELLOW}Jellyseerr Settings${NC} tab"
echo -e "  3. Enable ${YELLOW}'Show Jellyseerr Results in Search'${NC}"
echo -e "  4. Enter Jellyseerr URL: ${GREEN}http://localhost:5055${NC}"
echo -e "     (or internal Docker: ${GREEN}http://jellyseerr:5055${NC})"
echo -e "  5. Get API key from Jellyseerr: Settings > General > API Key"
echo -e "  6. Click ${YELLOW}Test${NC} to verify connection"
echo -e "  7. Click ${YELLOW}Save${NC}"
echo ""
echo -e "Also ensure in Jellyseerr:"
echo -e "  - Settings > Users > Enable 'Jellyfin Sign-In'"
echo -e "  - Import your Jellyfin users into Jellyseerr"
echo ""
