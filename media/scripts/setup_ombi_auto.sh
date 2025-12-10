#!/bin/bash
# =============================================================================
# Ombi Complete Setup Script
# Configures Ombi with credentials from .env for manga requests through Sonarr
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load credentials from .env
OMBI_HOST="http://localhost:8000"
OMBI_USER="${OMBI_ADMIN_USER:-kero66}"
OMBI_PASS="${OMBI_ADMIN_PASS:-temppwd}"

JELLYFIN_HOST="jellyfin"
JELLYFIN_PORT="8096"
JELLYFIN_API="${JELLYFIN_API_KEY:-}"

SONARR_HOST="sonarr"
SONARR_PORT="8989"
SONARR_API="${SONARR_API_KEY:-}"
SONARR_PATH="/data/manga"

echo -e "${YELLOW}=== Ombi Complete Setup ===${NC}\n"

# Wait for Ombi
echo -e "${YELLOW}Waiting for Ombi to be ready...${NC}"
for i in {1..60}; do
    if curl -sf "${OMBI_HOST}/api/v1/status" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ombi is ready!${NC}\n"
        break
    fi
    [ $i -eq 60 ] && echo -e "${RED}✗ Ombi timeout${NC}" && exit 1
    sleep 1
done

# Step 1: Create admin user
echo -e "${YELLOW}Step 1: Creating admin user...${NC}"
curl -s -X POST "${OMBI_HOST}/api/v1/Identity/CreateFirstUser" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"${OMBI_USER}\",
    \"password\": \"${OMBI_PASS}\",
    \"confirmPassword\": \"${OMBI_PASS}\"
  }" > /dev/null 2>&1

echo -e "${GREEN}✓ Admin user created${NC}"
echo "  Username: ${OMBI_USER}"
echo "  Password: ${OMBI_PASS}"

# Step 2: Configure Jellyfin
echo -e "\n${YELLOW}Step 2: Configuring Jellyfin...${NC}"
curl -s -X POST "${OMBI_HOST}/api/v1/settings/jellyfin" \
  -H "Content-Type: application/json" \
  -d "{
    \"enabled\": true,
    \"hostname\": \"${JELLYFIN_HOST}\",
    \"port\": ${JELLYFIN_PORT},
    \"useSsl\": false,
    \"apiKey\": \"${JELLYFIN_API}\",
    \"urlBase\": \"\"
  }" > /dev/null 2>&1

echo -e "${GREEN}✓ Jellyfin configured${NC}"

# Step 3: Configure Sonarr
echo -e "\n${YELLOW}Step 3: Configuring Sonarr for Manga...${NC}"

# Get quality profile from Sonarr
QUALITY_ID=$(curl -s -X GET "http://localhost:${SONARR_PORT}/api/v3/qualityProfile" \
  -H "X-Api-Key: ${SONARR_API}" 2>/dev/null | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

[ -z "$QUALITY_ID" ] && QUALITY_ID="1"

# Configure Sonarr in Ombi
curl -s -X POST "${OMBI_HOST}/api/v1/settings/sonarr" \
  -H "Content-Type: application/json" \
  -d "[{
    \"name\": \"Sonarr - Manga\",
    \"hostname\": \"${SONARR_HOST}\",
    \"port\": ${SONARR_PORT},
    \"useSsl\": false,
    \"apiKey\": \"${SONARR_API}\",
    \"urlBase\": \"\",
    \"qualityProfile\": \"${QUALITY_ID}\",
    \"qualityProfileAnime\": \"${QUALITY_ID}\",
    \"seasonFolders\": false,
    \"rootPath\": \"${SONARR_PATH}\",
    \"rootPathAnime\": \"${SONARR_PATH}\",
    \"enabled\": true,
    \"isDefault\": true
  }]" > /dev/null 2>&1

echo -e "${GREEN}✓ Sonarr configured${NC}"
echo "  Hostname: ${SONARR_HOST}"
echo "  Port: ${SONARR_PORT}"
echo "  Root Path: ${SONARR_PATH}"
echo "  Quality Profile: ${QUALITY_ID}"

# Step 4: Enable Anime/Manga in Ombi
echo -e "\n${YELLOW}Step 4: Enabling Anime/Manga Search...${NC}"

# Enable anime settings in Ombi
curl -s -X POST "${OMBI_HOST}/api/v1/settings/anime" \
  -H "Content-Type: application/json" \
  -d "{
    \"enabled\": true,
    \"allowUsers\": true,
    \"enableUser\": true
  }" > /dev/null 2>&1

echo -e "${GREEN}✓ Anime/Manga search enabled${NC}"

# Enable notification types for anime requests
curl -s -X POST "${OMBI_HOST}/api/v1/settings/notifications" \
  -H "Content-Type: application/json" \
  -d "{
    \"enabled\": true,
    \"enabledNotificationTypes\": [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
  }" > /dev/null 2>&1

echo -e "${GREEN}✓ Notifications configured${NC}"

# Summary
echo -e "\n${YELLOW}=== Setup Complete! ===${NC}\n"
echo -e "${GREEN}Your manga request system is fully configured!${NC}\n"

echo "Login to Ombi:"
echo "  URL: ${OMBI_HOST}"
echo "  Username: ${OMBI_USER}"
echo "  Password: ${OMBI_PASS}"
echo ""

echo "System Access:"
echo "  • Ombi: ${OMBI_HOST} (search & request manga)"
echo "  • Sonarr: http://localhost:${SONARR_PORT} (downloads)"
echo "  • Jellyfin: http://localhost:8096 (watch manga)"
echo "  • qBittorrent: http://localhost:8080 (monitor)"
echo ""

echo "Workflow:"
echo "  1. Login to Ombi with your credentials"
echo "  2. Search for manga (e.g., 'Bleach', 'Trigun')"
echo "  3. Click 'Request' to add to Sonarr"
echo "  4. Sonarr auto-downloads from Nyaa.si"
echo "  5. Files appear in ${SONARR_PATH}/"
echo ""
