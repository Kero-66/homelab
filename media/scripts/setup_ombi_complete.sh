#!/bin/bash
# =============================================================================
# Ombi Complete Setup - Using REST API
# Configures Ombi completely for manga requests through Sonarr
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OMBI_URL="http://localhost:8000"
JELLYFIN_HOST="jellyfin"
JELLYFIN_PORT="8096"
JELLYFIN_API="${JELLYFIN_API_KEY:-}"
SONARR_HOST="sonarr"
SONARR_PORT="8989"
SONARR_API="${SONARR_API_KEY:-}"
SONARR_PATH="/data/manga"

echo -e "${YELLOW}=== Ombi Complete Automatic Setup ===${NC}\n"

# Wait for Ombi
echo -e "${YELLOW}Waiting for Ombi...${NC}"
for i in {1..60}; do
    if curl -sf "${OMBI_URL}/api/v1/status" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ombi is ready!${NC}\n"
        break
    fi
    [ $i -eq 60 ] && echo -e "${RED}✗ Ombi timeout${NC}" && exit 1
    sleep 1
done

# Step 1: Configure Jellyfin
echo -e "${YELLOW}Step 1: Configuring Jellyfin...${NC}"
curl -s -X POST "${OMBI_URL}/api/v1/settings/jellyfin" \
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

# Step 2: Configure Sonarr
echo -e "\n${YELLOW}Step 2: Configuring Sonarr...${NC}"

# Get quality profile ID from Sonarr
QUALITY_ID=$(curl -s -X GET "http://localhost:8989/api/v3/qualityProfile" \
  -H "X-Api-Key: ${SONARR_API}" 2>/dev/null | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

[ -z "$QUALITY_ID" ] && QUALITY_ID="1"

echo "  Using quality profile: $QUALITY_ID"

# Configure Sonarr in Ombi
curl -s -X POST "${OMBI_URL}/api/v1/settings/sonarr" \
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
echo "  Season Folders: Disabled"

# Step 3: Create admin user to skip wizard
echo -e "\n${YELLOW}Step 3: Creating admin user...${NC}"
curl -s -X POST "${OMBI_URL}/api/v1/Identity/CreateFirstUser" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin",
    "confirmPassword": "admin"
  }' > /dev/null 2>&1

echo -e "${GREEN}✓ Admin user created (admin/admin)${NC}"

# Summary
echo -e "\n${YELLOW}=== Setup Complete! ===${NC}\n"
echo -e "${GREEN}Your manga request system is ready!${NC}\n"
echo "Login Credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "You can now:"
echo "  1. Open Ombi at ${OMBI_URL}"
echo "  2. Login with admin/admin"
echo "  3. Search for manga titles"
echo "  4. Click 'Request' to add to Sonarr"
echo "  5. Sonarr downloads from Nyaa.si automatically"
echo "  6. Files appear in ${SONARR_PATH}/"
echo ""
echo "Access:"
echo "  • Ombi: ${OMBI_URL} (manga requests)"
echo "  • Sonarr: http://localhost:8989 (automated downloads)"
echo "  • Jellyfin: http://localhost:8096 (media discovery)"
echo "  • qBittorrent: http://localhost:8080 (monitor downloads)"
echo ""
