#!/usr/bin/env bash
set -euo pipefail

# Guard: require explicit consent to run
if [ "${RUN_SONARR_EPISODE_SEARCH:-0}" != "1" ]; then
  cat <<EOF
This script is guarded. To run it set:

  RUN_SONARR_EPISODE_SEARCH=1 ./scripts/run_sonarr_episode_searches.sh

It will read Sonarr credentials from media/.config/.credentials,
query two representative episodes, run /episode/{id}/search and
save JSON results to the scripts/ directory.
EOF
  exit 0
fi

CREDENTIALS_FILE="media/.config/.credentials"
if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "Credentials file missing: $CREDENTIALS_FILE" >&2
  exit 1
fi

SONARR_API=$(grep -E '^SONARR_API_KEY=' "$CREDENTIALS_FILE" | cut -d= -f2- || true)
SONARR_URL=$(grep -E '^SONARR_URL=' "$CREDENTIALS_FILE" | cut -d= -f2- || true)
# Default to the reverse-proxied Sonarr path used in this workspace
SONARR_URL=${SONARR_URL:-http://localhost/sonarr}

if [ -z "$SONARR_API" ]; then
  echo "SONARR_API_KEY not found in $CREDENTIALS_FILE" >&2
  exit 1
fi

echo "Using Sonarr URL: $SONARR_URL"
echo "SONARR_API=redacted"

mkdir -p scripts

# Helper to fetch episodes for a series
fetch_episodes() {
  local seriesId="$1"
  curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/episode?seriesId=$seriesId"
}


# Representative episodes: series 12 S01E12, series 29 S01E01, and MF GHOST (series 21) S01E01
EPID12=$(fetch_episodes 12 | jq -r '.[] | select(.seasonNumber==1 and .episodeNumber==12) | .id' || true)
EPID29=$(fetch_episodes 29 | jq -r '.[] | select(.seasonNumber==1 and .episodeNumber==1) | .id' || true)
EPID_MFG=$(fetch_episodes 21 | jq -r '.[] | select(.seasonNumber==1 and .episodeNumber==1) | .id' || true)

echo "Selected episode IDs: series12 S01E12 -> ${EPID12:-<none>} ; series29 S01E01 -> ${EPID29:-<none>} ; MF GHOST S01E01 -> ${EPID_MFG:-<none>}"

run_search() {
  local epid="$1"
  local out="scripts/sonarr_search_episode_${epid}.json"
  echo "Running Sonarr search for episode id $epid -> $out"
  curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/episode/$epid/search" > "$out"
  echo "Saved $out (entries: $(jq 'length' "$out" || echo 0))"
}

if [ -n "$EPID12" ]; then
  run_search "$EPID12"
fi

if [ -n "$EPID29" ]; then
  run_search "$EPID29"
fi

if [ -n "$EPID_MFG" ]; then
  run_search "$EPID_MFG"
fi

echo "Done. Review JSON files in the scripts/ directory."
