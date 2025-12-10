#!/usr/bin/env bash
set -euo pipefail

# Wait for services to start and configure authentication via API
# This script adds Basic auth credentials to Arr apps that require it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load CONFIG_DIR from .env (defaults to current directory)
CONFIG_DIR="."
if [[ -f .env ]]; then
  CONFIG_DIR=$(grep -E "^CONFIG_DIR=" .env | cut -d'=' -f2 || echo ".")
  CONFIG_DIR="${CONFIG_DIR:-.}"
fi

# Load credentials
if [[ ! -f .config/.credentials ]]; then
  echo "Error: .config/.credentials file not found"
  exit 1
fi

source .config/.credentials

# Function to wait for service and configure auth
configure_arr_auth() {
  local SERVICE=$1
  local PORT=$2
  local CONFIG_FILE=$3
  
  echo "Waiting for $SERVICE to be ready..."
  for i in {1..30}; do
    if curl -s "http://localhost:$PORT/ping" > /dev/null 2>&1; then
      echo "  $SERVICE is up!"
      break
    fi
    sleep 2
  done
  
  # Extract API key from config
  API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$CONFIG_FILE" 2>/dev/null | tr -d '[:space:]' || echo "")
  
  if [[ -z "$API_KEY" ]]; then
    echo "  Warning: Could not find API key for $SERVICE"
    return 1
  fi
  
  echo "  Configuring Forms authentication for $SERVICE..."
  
  # Get current auth config
  AUTH_JSON=$(curl -s -H "X-Api-Key: $API_KEY" "http://localhost:$PORT/api/v3/config/host" 2>/dev/null || echo "")
  
  # Check if we got valid JSON
  if [[ -z "$AUTH_JSON" ]] || ! echo "$AUTH_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    echo "  Note: $SERVICE may already be configured or API not accessible"
    return 0
  fi
  
  # Update with Basic auth credentials
  UPDATED_JSON=$(echo "$AUTH_JSON" | python3 -c "
import sys, json
try:
    config = json.load(sys.stdin)
    config['authenticationMethod'] = 'forms'
    config['authenticationRequired'] = 'enabled'
    config['username'] = '${USERNAME}'
    config['password'] = '${PASSWORD}'
    print(json.dumps(config))
except Exception as e:
    print('{}')
" 2>/dev/null || echo "{}")
  
  # POST updated config
  RESULT=$(curl -s -X PUT -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
    -d "$UPDATED_JSON" "http://localhost:$PORT/api/v3/config/host" 2>&1 || echo "failed")
  
  if [[ "$RESULT" == "failed" || "$RESULT" == *"error"* ]]; then
    echo "  Note: $SERVICE may already be configured or doesn't support API auth setup"
  else
    echo "  ✓ Authentication configured for $SERVICE"
  fi
}

echo "Configuring authentication for Arr apps..."
echo ""

configure_arr_auth "Sonarr" "8989" "$CONFIG_DIR/sonarr/config.xml"
configure_arr_auth "Radarr" "7878" "$CONFIG_DIR/radarr/config.xml"
configure_arr_auth "Lidarr" "8686" "$CONFIG_DIR/lidarr/config.xml"
configure_arr_auth "Prowlarr" "9696" "$CONFIG_DIR/prowlarr/config.xml"

echo ""
echo "Authentication configuration complete!"
echo "You can now access the apps with username: $USERNAME and password: $PASSWORD"
