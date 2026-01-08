#!/usr/bin/env bash
set -euo pipefail

# probe_and_update_radarr.sh
# Safely probe Radarr releaseprofile endpoints (including reverse proxy /radarr)
# and optionally merge ignored tokens into the profile named like "Anime".
# By default the script runs in dry-run mode. To apply changes set the
# environment variable APPLY=1 or pass --apply.

CREDS="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CREDS" ]; then
  echo "Credentials file not found: $CREDS" >&2
  exit 1
fi

RADARR_KEY=$(grep -Ei 'RADARR_API_KEY|RADARR' "$CREDS" | head -n1 | sed -E 's/^[^=]*=//; s/^"|"$//g' || true)
if [ -z "$RADARR_KEY" ]; then
  echo "No Radarr API key found in $CREDS" >&2
  exit 1
fi

APPLY=0
if [ "${APPLY_ENV:-}" = "1" ]; then APPLY=1; fi
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1; shift ;;
    --help) echo "Usage: $0 [--apply]"; exit 0 ;;
  esac
done

# Hard-coded tokens list to avoid complex inline quoting
TOKENS_JSON='["Dubbed","English","English Dub","English-Sub"]'

# Candidate Radarr bases to try (including common reverse-proxy path)
BASES=(
  "http://localhost/radarr/api"
  "http://localhost/radarr/api/v3"
  "http://localhost/radarr/api/v4"
  "http://localhost:7878/api"
  "http://localhost:7878/api/v3"
)

echo "Radarr API key: found"
FOUND_BASE=""
for BASE in "${BASES[@]}"; do
  echo "Testing $BASE/releaseprofile ..."
  RESP=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$BASE/releaseprofile" || true)
  if echo "$RESP" | jq -e . >/dev/null 2>&1; then
    FOUND_BASE="$BASE"
    echo "Valid JSON response from $BASE"
    break
  fi
done

if [ -z "$FOUND_BASE" ]; then
  echo "Could not reach any Radarr releaseprofile endpoint. Exiting." >&2
  exit 0
fi

PROFILES=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$FOUND_BASE/releaseprofile")
echo "Profiles fetched: $(echo "$PROFILES" | jq 'length')"

# Find a profile whose name contains 'anime' (case-insensitive)
ANIME_ID=$(echo "$PROFILES" | jq -r '[.[] | select((.name//"")|test("anime";"i"))] | .[0].id // empty')
if [ -z "$ANIME_ID" ]; then
  echo "No releaseprofile with name matching 'anime' found at $FOUND_BASE"
  echo "Available profiles (first 40):"
  echo "$PROFILES" | jq '.[0:40] | map({id:.id,name:.name})'
  exit 0
fi

echo "Found Radarr profile id=$ANIME_ID at $FOUND_BASE"
RAD_PROFILE=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$FOUND_BASE/releaseprofile/$ANIME_ID")
echo "Current profile excerpt:"
echo "$RAD_PROFILE" | jq '{id:.id, name:.name, ignored:(if has("ignored") then .ignored else .ignoreTokens end)}'

# Prepare merged profile JSON
MERGED=$(echo "$RAD_PROFILE" | jq --argjson new "$TOKENS_JSON" '
  if has("ignored") then
    (.ignored // []) as $old | .ignored = (($old + $new) | unique)
  else
    (.ignoreTokens // []) as $old | .ignoreTokens = (($old + $new) | unique)
  end
')

echo "Merged profile preview (id,name,ignored/ignoreTokens):"
echo "$MERGED" | jq '{id:.id, name:.name, ignored:(if has("ignored") then .ignored else .ignoreTokens end)}'

if [ "$APPLY" -ne 1 ]; then
  echo "Dry-run mode (no changes applied). To apply, run: $0 --apply or set APPLY_ENV=1 and run." 
  exit 0
fi

echo "Applying merged profile to Radarr at $FOUND_BASE/releaseprofile/$ANIME_ID"
echo "$MERGED" | curl -s -X PUT -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" -d @- "$FOUND_BASE/releaseprofile/$ANIME_ID" | jq '{id:.id,name:.name,ignored:.ignored // .ignoreTokens}'

echo "Done."
