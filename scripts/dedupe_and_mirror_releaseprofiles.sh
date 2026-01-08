#!/usr/bin/env bash
set -eo pipefail

# Dedupe Sonarr 'Anime' releaseprofile ignored tokens and mirror to Radarr
# Usage: run on the host where Sonarr and Radarr are reachable at localhost

CREDS="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CREDS" ]; then
  echo "Credentials file not found: $CREDS" >&2
  exit 1
fi

SONARR_KEY=$(grep -Ei 'SONARR' "$CREDS" | head -n1 | sed -E 's/^[^=]*=//; s/^"|"$//g' || true)
RADARR_KEY=$(grep -Ei 'RADARR' "$CREDS" | head -n1 | sed -E 's/^[^=]*=//; s/^"|"$//g' || true)
SONARR_KEY=${SONARR_KEY:-}
RADARR_KEY=${RADARR_KEY:-}

SONARR_BASE=${SONARR_BASE:-"http://localhost:8989/sonarr/api/v3"}

if [ -z "$SONARR_KEY" ]; then
  echo "No Sonarr API key found in $CREDS" >&2
  exit 1
fi

echo "Fetching Sonarr releaseprofile id=1 (Anime)"
orig=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/releaseprofile/1")
if [ -z "$orig" ] || [ "$orig" = "null" ]; then
  echo "Failed to fetch Sonarr releaseprofile/1" >&2
  exit 1
fi

echo "Before (id,name,required,ignored):"
echo "$orig" | jq '{id:.id,name:.name,required:.required,ignored:.ignored}'

# Dedupe ignored and required arrays and ensure "Japanese" is required
patched=$(echo "$orig" | jq '.ignored = ((.ignored//[]) | unique) | .required = ((.required//[]) | unique)')
patched=$(echo "$patched" | jq 'if (.required | index("Japanese")) then . else .required += ["Japanese"] end')

echo "Applying deduped releaseprofile to Sonarr"
resp=$(echo "$patched" | curl -s -X PUT -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" -d @- "$SONARR_BASE/releaseprofile/1")
echo "$resp" | jq '{id:.id,name:.name,required:.required,ignored:.ignored}'

# Extract ignored tokens as JSON array for mirroring
IGNORED_JSON=$(echo "$patched" | jq -c '.ignored')
echo "Ignored tokens to mirror: $IGNORED_JSON"

if [ -z "$RADARR_KEY" ]; then
  echo "No Radarr API key found in $CREDS; skipping Radarr mirror."
  exit 0
fi

# Try common Radarr API base URLs
RADARR_BASE=""
for base in "http://localhost:7878/api" "http://localhost:7878/api/v3" "http://localhost:7878/api/v4"; do
  out=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$base/releaseprofile" || true)
  if echo "$out" | jq -e . >/dev/null 2>&1; then
    RADARR_BASE=$base
    break
  fi
done

if [ -z "$RADARR_BASE" ]; then
  echo "Could not detect Radarr releaseprofile endpoint; skipping Radarr mirror." >&2
  exit 0
fi

echo "Using Radarr endpoint: $RADARR_BASE"
profiles=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR_BASE/releaseprofile")
anime_id=$(echo "$profiles" | jq -r '[.[] | select((.name//"")|test("anime";"i"))] | .[0].id // empty')

if [ -z "$anime_id" ]; then
  echo "No Radarr releaseprofile named like 'anime' found. Available profiles (first 20):"
  echo "$profiles" | jq '.[0:20] | map({id:.id,name:.name})'
  echo "Skipping automatic mirroring."
  exit 0
fi

echo "Found Radarr profile id=$anime_id; fetching"
rad_profile=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR_BASE/releaseprofile/$anime_id")
echo "Radarr before (id,name,ignored/ignoreTokens):"
echo "$rad_profile" | jq '{id:.id,name:.name,ignored:.ignored // .ignoreTokens}'

# Merge ignored tokens into Radarr profile (handle field name differences)
if echo "$rad_profile" | jq 'has("ignored")' >/dev/null 2>&1 && [ "$(echo "$rad_profile" | jq 'has("ignored")')" = "true" ]; then
  rad_merged=$(echo "$rad_profile" | jq --argjson new "$IGNORED_JSON" '(.ignored // []) as $old | .ignored = (($old + $new) | unique)')
elif echo "$rad_profile" | jq 'has("ignoreTokens")' >/dev/null 2>&1 && [ "$(echo "$rad_profile" | jq 'has("ignoreTokens")')" = "true" ]; then
  rad_merged=$(echo "$rad_profile" | jq --argjson new "$IGNORED_JSON" '(.ignoreTokens // []) as $old | .ignoreTokens = (($old + $new) | unique)')
else
  echo "Radarr releaseprofile schema does not expose known ignored fields; skipping automatic update." >&2
  exit 0
fi

echo "Applying merged profile to Radarr"
echo "$rad_merged" | curl -s -X PUT -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" -d @- "$RADARR_BASE/releaseprofile/$anime_id" | jq '{id:.id,name:.name,ignored:.ignored // .ignoreTokens}'

echo "Done."
