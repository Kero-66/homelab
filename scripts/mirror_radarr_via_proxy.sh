#!/usr/bin/env bash
set -euo pipefail

# Mirror ignored tokens to Radarr via reverse-proxy (/radarr)
CREDS="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CREDS" ]; then
  echo "Credentials file not found: $CREDS" >&2
  exit 1
fi

RADARR_KEY=$(grep -Ei "RADARR_API_KEY|RADARR" "$CREDS" | head -n1 | sed -E "s/^[^=]*=//; s/^\"|\"$//g")
BASE="http://localhost/radarr/api/v3"

echo "Using RADARR key: ${RADARR_KEY:+found}, base: $BASE"
profiles=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$BASE/releaseprofile")
echo "Profiles fetched: count=$(echo "$profiles" | jq 'length')"
anime_id=$(echo "$profiles" | jq -r '[.[] | select((.name//"")|test("anime";"i"))] | .[0].id // empty')
if [ -z "$anime_id" ]; then
  echo "No anime profile found; listing top profiles:"
  echo "$profiles" | jq '.[0:20] | map({id:.id,name:.name})'
  exit 0
fi

echo "Found Radarr profile id=$anime_id"
rad_profile=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$BASE/releaseprofile/$anime_id")
echo "Radarr before:"
echo "$rad_profile" | jq '{id:.id,name:.name,ignored:.ignored // .ignoreTokens}'

TOKENS='["Dubbed","English","English Dub","English-Sub"]'
echo "Merging tokens: $TOKENS"
rad_merged=$(echo "$rad_profile" | jq --argjson new "$TOKENS" 'if has("ignored") then (.ignored // []) as $old | .ignored = (($old + $new) | unique) else (.ignoreTokens // []) as $old | .ignoreTokens = (($old + $new) | unique) end')

echo "Applying update..."
echo "$rad_merged" | curl -s -X PUT -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" -d @- "$BASE/releaseprofile/$anime_id" | jq '{id:.id,name:.name,ignored:.ignored // .ignoreTokens}'

echo "Done."
