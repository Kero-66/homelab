#!/usr/bin/env bash
set -euo pipefail

# Relax the 'Anime - Japanese Only' release profile (id=2) by clearing required tokens
# and then run a Sonarr episode search for a test episode (series 12 S01E02 / episode id 411).
# This script is standalone to avoid complex one-liners that crash shells.

CRED_FILE="/mnt/library/repos/homelab/media/.config/.credentials"
if [ -f "$CRED_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CRED_FILE" || true
fi

SONARR_API_KEY=${SONARR_API_KEY:-}
SONARR_URL=${SONARR_URL:-http://localhost/sonarr}

if [ -z "$SONARR_API_KEY" ]; then
  echo "SONARR_API_KEY not set. Please export it or place it in $CRED_FILE" >&2
  exit 1
fi

API="$SONARR_URL/api/v3"

echo "Fetching release profile id=2 from Sonarr..."
curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$API/releaseProfile/2" -o /tmp/rp2.json

if [ ! -s /tmp/rp2.json ]; then
  echo "Failed to fetch release profile id=2" >&2
  exit 1
fi

echo "Patching release profile: clearing required tokens and preserving ignored tokens..."
jq '.required = []' /tmp/rp2.json > /tmp/rp2_patch.json

echo "Uploading patched release profile..."
curl -sS -X PUT -H "X-Api-Key: $SONARR_API_KEY" -H "Content-Type: application/json" -d @/tmp/rp2_patch.json "$API/releaseProfile/2" | jq .

echo "Running a Sonarr episode search for episode id 411 (series 12 S01E02)..."
curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$API/episode/411/search" -o /tmp/ep411_search.json

if [ -s /tmp/ep411_search.json ]; then
  echo "Search results count: "$(jq 'length' /tmp/ep411_search.json)
  echo "Sample (first 6):"
  jq '.[0:6]' /tmp/ep411_search.json
else
  echo "No search results returned for episode 411."
fi

rm -f /tmp/rp2.json /tmp/rp2_patch.json /tmp/ep411_search.json

echo "Done."

exit 0
