#!/usr/bin/env bash
# truenas/scripts/test_auth.sh
#
# Tests different authentication methods for TrueNAS API
# Supports both API keys (preferred) and username/password
#
# Usage:
#   bash test_auth.sh [TRUENAS_IP]

set -euo pipefail

TRUENAS_IP="${1:-192.168.20.22}"

echo "=== TrueNAS API Authentication Tester ==="
echo ""
echo "TrueNAS IP: $TRUENAS_IP"
echo ""

# Check if TrueNAS is reachable
echo "1. Testing network connectivity..."
if ping -c 1 -W 2 "$TRUENAS_IP" >/dev/null 2>&1; then
    echo "   ✓ TrueNAS is reachable"
else
    echo "   ✗ TrueNAS is not reachable"
    exit 1
fi

# Check if web interface is accessible
echo ""
echo "2. Testing web interface..."
if curl -sf -o /dev/null --connect-timeout 5 "http://$TRUENAS_IP" 2>/dev/null; then
    echo "   ✓ Web interface is accessible"
    echo "   URL: http://$TRUENAS_IP/ui/"
else
    echo "   ✗ Web interface is not accessible"
    exit 1
fi

# Check API endpoint
echo ""
echo "3. Testing API endpoint..."
if curl -sf -o /dev/null "http://$TRUENAS_IP/api/v2.0/" 2>/dev/null; then
    echo "   ✓ API endpoint is accessible"
    echo "   API URL: http://$TRUENAS_IP/api/v2.0/"
else
    echo "   ✗ API endpoint is not accessible"
    exit 1
fi

# Try to get credentials from Infisical
echo ""
echo "4. Retrieving credentials from Infisical..."

TRUENAS_API_KEY=""
TRUENAS_PASSWORD=""

if ! command -v infisical >/dev/null 2>&1; then
    echo "   ✗ Infisical CLI not found"
else
    # Try API key first (preferred)
    if TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null); then
        echo "   ✓ API key retrieved from Infisical"
        echo "   API key length: ${#TRUENAS_API_KEY} characters"
    else
        echo "   ⓘ No API key found in Infisical (truenas_admin_api)"
    fi
    
    # Also try password as fallback
    if TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain 2>/dev/null); then
        echo "   ✓ Password retrieved from Infisical (fallback)"
        echo "   Password length: ${#TRUENAS_PASSWORD} characters"
    else
        echo "   ⓘ No password found in Infisical (truenas_admin)"
    fi
fi

# If no credentials from Infisical, prompt for password
if [ -z "$TRUENAS_API_KEY" ] && [ -z "$TRUENAS_PASSWORD" ]; then
    echo ""
    read -sp "Enter TrueNAS admin password: " TRUENAS_PASSWORD
    echo ""
fi

# Test authentication
echo ""
echo "5. Testing authentication..."
echo ""

test_auth_api_key() {
    local api_key="$1"
    local response
    
    response=$(curl -s \
        -H "Authorization: Bearer $api_key" \
        -w "\nHTTP_CODE:%{http_code}" \
        "http://$TRUENAS_IP/api/v2.0/system/info" 2>&1)
    
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    if [ "$http_code" = "200" ]; then
        echo "   ✓ SUCCESS with API key authentication"
        echo ""
        echo "   System Info:"
        echo "$body" | jq -r '
          "   - Hostname: \(.hostname)",
          "   - Version: \(.version)",
          "   - Uptime: \((.uptime_seconds // 0) / 3600 | floor) hours",
          "   - Timezone: \(.timezone)"
        ' 2>/dev/null || echo "$body"
        return 0
    elif [ "$http_code" = "401" ]; then
        echo "   ✗ FAILED with API key (401 Unauthorized - invalid key)"
        return 1
    else
        echo "   ? UNKNOWN with API key (HTTP $http_code)"
        echo "     Response: $body"
        return 1
    fi
}

test_auth_basic() {
    local username="$1"
    local password="$2"
    local response
    
    response=$(curl -s -u "$username:$password" \
        -w "\nHTTP_CODE:%{http_code}" \
        "http://$TRUENAS_IP/api/v2.0/system/info" 2>&1)
    
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    if [ "$http_code" = "200" ]; then
        echo "   ✓ SUCCESS with username: $username"
        echo ""
        echo "   System Info:"
        echo "$body" | jq -r '
          "   - Hostname: \(.hostname)",
          "   - Version: \(.version)",
          "   - Uptime: \((.uptime_seconds // 0) / 3600 | floor) hours",
          "   - Timezone: \(.timezone)"
        ' 2>/dev/null || echo "$body"
        return 0
    elif [ "$http_code" = "401" ]; then
        echo "   ✗ FAILED with username: $username (401 Unauthorized - bad credentials)"
        return 1
    else
        echo "   ? UNKNOWN with username: $username (HTTP $http_code)"
        echo "     Response: $body"
        return 1
    fi
}

# Try API key first (preferred method)
if [ -n "$TRUENAS_API_KEY" ]; then
    if test_auth_api_key "$TRUENAS_API_KEY"; then
        echo ""
        echo "=== Authentication Successful (API Key) ==="
        echo ""
        echo "Your scripts can use:"
        echo "  TRUENAS_API_KEY=\$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain)"
        echo "  curl -H \"Authorization: Bearer \$TRUENAS_API_KEY\" http://$TRUENAS_IP/api/v2.0/..."
        echo ""
        echo "✓ API key authentication is the recommended method for automation"
        exit 0
    fi
    echo ""
fi

# Fallback to Basic Auth
if [ -n "$TRUENAS_PASSWORD" ]; then
    # Try root first (most common)
    if test_auth_basic "root" "$TRUENAS_PASSWORD"; then
        echo ""
        echo "=== Authentication Successful (Basic Auth) ==="
        echo "Username: root"
        echo ""
        echo "Your scripts can use:"
        echo "  TRUENAS_PASSWORD=\$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)"
        echo "  curl -u \"root:\$TRUENAS_PASSWORD\" http://$TRUENAS_IP/api/v2.0/..."
        echo ""
        echo "ⓘ Consider using API key authentication instead for better security"
        exit 0
    fi
    
    echo ""
    
    # Try admin
    if test_auth_basic "admin" "$TRUENAS_PASSWORD"; then
        echo ""
        echo "=== Authentication Successful (Basic Auth) ==="
        echo "Username: admin"
        echo ""
        echo "Your scripts can use:"
        echo "  TRUENAS_PASSWORD=\$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)"
        echo "  curl -u \"admin:\$TRUENAS_PASSWORD\" http://$TRUENAS_IP/api/v2.0/..."
        echo ""
        echo "ⓘ Consider using API key authentication instead for better security"
        exit 0
    fi
fi

echo ""
echo "=== Authentication Failed ==="
echo ""
echo "All authentication methods failed."
echo ""
echo "Possible issues:"
echo "  1. API key is invalid or expired"
echo "  2. Password is incorrect"
echo "  3. User doesn't exist in TrueNAS"
echo ""
echo "To update credentials in Infisical:"
echo "  infisical secrets set truenas_admin_api=NEW_API_KEY --env dev --path /TrueNAS"
echo "  infisical secrets set truenas_admin=NEW_PASSWORD --env dev --path /TrueNAS"
echo ""
echo "To test manually:"
echo "  # With API key:"
echo "  curl -H \"Authorization: Bearer YOUR_API_KEY\" http://$TRUENAS_IP/api/v2.0/system/info"
echo ""
echo "  # With password:"
echo "  curl -u \"root:YOUR_PASSWORD\" http://$TRUENAS_IP/api/v2.0/system/info"
echo ""

exit 1
