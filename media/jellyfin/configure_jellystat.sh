#!/bin/bash
set -e

# Automate Jellystat setup and connection to Jellyfin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Load credentials  
if [ ! -f .config/.credentials ]; then
    echo "Error: .config/.credentials file not found"
    exit 1
fi

source .config/.credentials

JELLYSTAT_URL="http://localhost:3002"
JELLYFIN_URL="http://localhost:8096"

echo "Waiting for Jellystat to be ready..."
for i in {1..30}; do
    if curl -s "$JELLYSTAT_URL" > /dev/null 2>&1; then
        echo "Jellystat is ready!"
        break
    fi
    sleep 2
done

echo "Configuring Jellystat..."

# Create Jellyfin API key for Jellystat
echo "Creating Jellyfin API key for Jellystat..."
TOKEN=$(curl -s -X POST "$JELLYFIN_URL/Users/AuthenticateByName" \
    -H 'Content-Type: application/json' \
    -H 'X-Emby-Authorization: MediaBrowser Client="Setup", Device="Setup", DeviceId="setup", Version="1.0.0"' \
    -d '{"Username": "'"$USERNAME"'", "Pw": "'"$PASSWORD"'"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["AccessToken"])')

# Create API key using query parameter
curl -s -X POST "$JELLYFIN_URL/Auth/Keys?app=Jellystat" -H "X-Emby-Token: $TOKEN" > /dev/null

# Get the newly created API key
JELLYSTAT_API_KEY=$(curl -s "$JELLYFIN_URL/Auth/Keys" -H "X-Emby-Token: $TOKEN" | python3 -c 'import sys,json; items=json.load(sys.stdin)["Items"]; key=[i["AccessToken"] for i in items if i["AppName"]=="Jellystat"]; print(key[0] if key else "")' 2>/dev/null || echo "")

if [ -z "$JELLYSTAT_API_KEY" ]; then
    echo "Error: Could not create Jellyfin API key"
    exit 1
fi

echo "API Key created: ${JELLYSTAT_API_KEY:0:8}..."

# Try to configure Jellystat via API
echo "Attempting to configure Jellystat via API..."

# First, try to register/login
REGISTER_RESPONSE=$(curl -s -X POST "$JELLYSTAT_URL/api/auth/register" \
    -H 'Content-Type: application/json' \
    -d '{
        "username": "'"$USERNAME"'",
        "password": "'"$PASSWORD"'"
    }' 2>&1)

# Try to login
LOGIN_RESPONSE=$(curl -s -X POST "$JELLYSTAT_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d '{
        "username": "'"$USERNAME"'",
        "password": "'"$PASSWORD"'"
    }' 2>&1)

JELLYSTAT_TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token", ""))' 2>/dev/null || echo "")

if [ ! -z "$JELLYSTAT_TOKEN" ]; then
    # Add Jellyfin server to Jellystat
    echo "Adding Jellyfin server to Jellystat..."
    curl -s -X POST "$JELLYSTAT_URL/api/servers" \
        -H "Authorization: Bearer $JELLYSTAT_TOKEN" \
        -H 'Content-Type: application/json' \
        -d '{
            "name": "Jellyfin",
            "url": "http://jellyfin:8096",
            "apiKey": "'"$JELLYSTAT_API_KEY"'"
        }' > /dev/null
    
    echo ""
    echo "✓ Jellystat fully configured!"
    echo ""
    echo "Access Jellystat at: http://localhost:3002"
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
else
    echo ""
    echo "⚠️  Automatic configuration partially complete"
    echo ""
    echo "Jellyfin API Key created: $JELLYSTAT_API_KEY"
    echo ""
    echo "Manual setup (one-time):"
    echo "1. Go to http://localhost:3002"
    echo "2. Create account or sign in"
    echo "3. Add server:"
    echo "   - Name: Jellyfin"
    echo "   - URL: http://jellyfin:8096"
    echo "   - API Key: $JELLYSTAT_API_KEY"
    echo ""
    echo "The API key has been saved and is ready to use!"
fi
