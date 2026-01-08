#!/usr/bin/env bash
set -euo pipefail

# sonarr_inspect.sh
# This script is intentionally safe: it will NOT run unless you set
# the environment variable RUN_SONARR_INSPECT=1. This prevents accidental
# terminal crashes when exploring Sonarr in interactive sessions.
#
# To run manually (and deliberately):
# RUN_SONARR_INSPECT=1 /path/to/sonarr_inspect.sh

if [ "${RUN_SONARR_INSPECT:-0}" != "1" ]; then
  echo "sonarr_inspect.sh is disabled by default. Set RUN_SONARR_INSPECT=1 to run." >&2
  exit 0
fi

CRED_FILE="/mnt/library/repos/homelab/media/.config/.credentials"
if [ -f "$CRED_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CRED_FILE" || true
fi

SONARR_API_KEY=${SONARR_API_KEY:-}
SONARR_URL=${SONARR_URL:-http://localhost/sonarr}

if [ -z "$SONARR_API_KEY" ]; then
  echo "SONARR_API_KEY not set. Export it or put it in $CRED_FILE" >&2
  exit 1
fi

API="$SONARR_URL/api/v3"

echo "== Series (example) =="
curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$API/series" | jq '.[0] | {id:.id,title:.title,qualityProfileId:.qualityProfileId,tags:.tags,seasons:(.seasons|length)}'

echo "== Tags =="
curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$API/tag" | jq '.'

echo "== Release Profiles =="
curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$API/releaseProfile" | jq -c '.[] | {id:.id,name:.name,required:.required,ignored:.ignored,tags:.tags}'

echo "== Custom Formats =="
curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$API/customformat" | jq -c '.[] | {id:.id,name:.name,filters:.filters}'

echo "== Note =="
echo "If you need targeted checks for particular series, use the sonarr_series_health_check.sh script in this repo and run it manually." 

exit 0
