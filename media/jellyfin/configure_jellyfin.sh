#!/bin/bash
set -e

# Automate Jellyfin initial setup
# This configures the server, creates admin user, and adds media libraries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load credentials
if [ ! -f ../.config/.credentials ]; then
    echo "Error: ../.config/.credentials file not found"
    exit 1
fi

source ../.config/.credentials

JELLYFIN_URL="http://localhost:8096"
echo "Waiting for Jellyfin to be ready..."

# Wait for Jellyfin to start
for i in {1..30}; do
    if curl -s "$JELLYFIN_URL/System/Info/Public" > /dev/null 2>&1; then
        echo "Jellyfin is up!"
        break
    fi
    sleep 2
done

# Check if wizard is already complete
WIZARD_COMPLETE=$(grep "IsStartupWizardCompleted>true<" config/system.xml && echo "yes" || echo "no")

if [ "$WIZARD_COMPLETE" == "yes" ]; then
    echo "Jellyfin wizard already completed."
    echo "Checking if libraries need to be added..."
    
    # Try to get existing libraries (no auth needed for public info in some cases)
    LIBS=$(curl -s "$JELLYFIN_URL/Library/VirtualFolders" 2>/dev/null || echo "[]")
    LIB_COUNT=$(echo "$LIBS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    
    if [ "$LIB_COUNT" -gt "0" ]; then
        echo "Libraries already configured ($LIB_COUNT found)."
        echo ""
        echo "Jellyfin is ready at: http://localhost:8096"
        exit 0
    fi
    
    echo "No libraries found. You'll need to add them manually or provide authentication."
    echo ""
    echo "To add libraries manually:"
    echo "1. Go to http://localhost:8096"
    echo "2. Sign in with your credentials"
    echo "3. Go to Dashboard → Libraries → Add Library"
    echo "4. Add: TV Shows (/data/shows), Movies (/data/movies), Music (/data/music)"
    exit 0
fi

echo "Starting automated Jellyfin setup..."

# Step 1: Set server name and language
echo "Configuring server settings..."
curl -s -X POST "$JELLYFIN_URL/Startup/Configuration" \
    -H "Content-Type: application/json" \
    -d '{
        "UICulture": "en-US",
        "MetadataCountryCode": "AU",
        "PreferredMetadataLanguage": "en"
    }' > /dev/null

# Step 2: Get the first user (this triggers user creation if none exists)
echo "Getting first user (triggers creation if needed)..."
FIRST_USER=$(curl -s -X GET "$JELLYFIN_URL/Startup/User")
echo "  Default user: $(echo "$FIRST_USER" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("Name", "unknown"))' 2>/dev/null || echo 'unknown')"

# Step 3: Update the user with our credentials
echo "Setting admin credentials..."
USER_RESPONSE=$(curl -s -X POST "$JELLYFIN_URL/Startup/User" \
    -H "Content-Type: application/json" \
    -d '{
        "Name": "'"$USERNAME"'",
        "Password": "'"$PASSWORD"'"
    }')

if echo "$USER_RESPONSE" | grep -q "error\|Error"; then
    echo "Error updating user: $USER_RESPONSE"
    exit 1
fi

echo "Admin user configured successfully"

# Step 3: Complete startup wizard
echo "Completing startup wizard..."
curl -s -X POST "$JELLYFIN_URL/Startup/Complete" > /dev/null

# Wait for wizard to complete and Jellyfin to restart services
echo "Waiting for Jellyfin to finalize setup..."
sleep 10

# Step 4: Authenticate to get access token
echo "Authenticating..."
AUTH_RESPONSE=$(curl -s -X POST "$JELLYFIN_URL/Users/AuthenticateByName" \
    -H "Content-Type: application/json" \
    -H "X-Emby-Authorization: MediaBrowser Client=\"Script\", Device=\"Setup\", DeviceId=\"script\", Version=\"1.0.0\"" \
    -d '{
        "Username": "'"$USERNAME"'",
        "Pw": "'"$PASSWORD"'"
    }')

ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessToken'])" 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Could not authenticate"
    exit 1
fi

echo "Authenticated successfully!"

# Step 5: Add media libraries
echo "Checking existing libraries..."

# Get existing libraries
LIBRARIES=$(curl -s "$JELLYFIN_URL/Library/VirtualFolders" -H "X-Emby-Token: $ACCESS_TOKEN")

if echo "$LIBRARIES" | python3 -c "import sys,json; libs=json.load(sys.stdin); print('yes' if any(l['Name']=='TV Shows' for l in libs) else 'no')" 2>/dev/null | grep -q "yes"; then
    echo "  • TV Shows library already exists"
else
    echo "Adding TV Shows library..."
    curl -s -X POST "$JELLYFIN_URL/Library/VirtualFolders?collectionType=tvshows&refreshLibrary=false&name=TV%20Shows" \
    -H "X-Emby-Token: $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "LibraryOptions": {
            "EnablePhotos": true,
            "EnableRealtimeMonitor": true,
            "EnableChapterImageExtraction": false,
            "ExtractChapterImagesDuringLibraryScan": false,
            "PathInfos": [
                {"Path": "/data/shows"}
            ]
        }
    }' > /dev/null
    echo "  ✓ TV Shows library added (/data/shows)"
fi

# Check Movies library
if echo "$LIBRARIES" | python3 -c "import sys,json; libs=json.load(sys.stdin); print('yes' if any(l['Name']=='Movies' for l in libs) else 'no')" 2>/dev/null | grep -q "yes"; then
    echo "  • Movies library already exists"
else
    echo "Adding Movies library..."
    curl -s -X POST "$JELLYFIN_URL/Library/VirtualFolders?collectionType=movies&refreshLibrary=false&name=Movies" \
    -H "X-Emby-Token: $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "LibraryOptions": {
            "EnablePhotos": true,
            "EnableRealtimeMonitor": true,
            "EnableChapterImageExtraction": false,
            "ExtractChapterImagesDuringLibraryScan": false,
            "PathInfos": [
                {"Path": "/data/movies"}
            ]
        }
    }' > /dev/null
    echo "  ✓ Movies library added (/data/movies)"
fi

# Check Music library
if echo "$LIBRARIES" | python3 -c "import sys,json; libs=json.load(sys.stdin); print('yes' if any(l['Name']=='Music' for l in libs) else 'no')" 2>/dev/null | grep -q "yes"; then
    echo "  • Music library already exists"
else
    echo "Adding Music library..."
    curl -s -X POST "$JELLYFIN_URL/Library/VirtualFolders?collectionType=music&refreshLibrary=false&name=Music" \
    -H "X-Emby-Token: $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "LibraryOptions": {
            "EnablePhotos": true,
            "EnableRealtimeMonitor": true,
            "EnableChapterImageExtraction": false,
            "ExtractChapterImagesDuringLibraryScan": false,
            "PathInfos": [
                {"Path": "/data/music"}
            ]
        }
    }' > /dev/null
    echo "  ✓ Music library added (/data/music)"
fi

echo ""
echo "✓ Jellyfin setup complete!"
echo ""
echo "Access Jellyfin at: http://localhost:8096"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo ""

# Configure companion services
echo "========================================="
echo "Configuring companion services..."
echo "========================================="
echo ""

# Configure Jellyseerr
if [ -f "configure_jellyseerr.sh" ]; then
    echo "--- Configuring Jellyseerr ---"
    bash configure_jellyseerr.sh
    echo ""
fi

# Configure Jellystat
if [ -f "configure_jellystat.sh" ]; then
    echo "--- Configuring Jellystat ---"
    bash configure_jellystat.sh
    echo ""
fi

echo "========================================="
echo "✓ All Jellyfin services configured!"
echo "========================================="
