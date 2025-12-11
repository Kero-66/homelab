#!/usr/bin/env bash
set -euo pipefail

# Helper: list Jackett Torznab feed URLs and optionally add them to Prowlarr
#
# Environment variables used:
# - JACKETT_URL (default: http://localhost:9117)
# - JACKETT_API (Jackett API key) - optional for endpoints, but recommended
# - PROWLARR_URL (optional) e.g. http://localhost:9696
# - PROWLARR_API (optional) API key for Prowlarr to auto-add indexers
#
# Usage:
#  cd media && JACKETT_URL=http://localhost:9117 JACKETT_API=abcd ./scripts/jackett_torznab_list.sh
#  To attempt adding to Prowlarr as well:
#  cd media && JACKETT_URL=http://localhost:9117 JACKETT_API=abcd PROWLARR_URL=http://localhost:9696 PROWLARR_API=<key> ./scripts/jackett_torznab_list.sh

JACKETT_URL=${JACKETT_URL:-http://localhost:9117}
JACKETT_API=${JACKETT_API:-}
PROWLARR_URL=${PROWLARR_URL:-}
PROWLARR_API=${PROWLARR_API:-}

curl_opts=(--silent --fail)

echo "Querying Jackett at ${JACKETT_URL} ..."

# Try to get indexer list (Jackett v2 API)
idx_json=$(curl "${curl_opts[@]}" "${JACKETT_URL}/api/v2.0/indexers" 2>/dev/null || true)
if [ -z "$idx_json" ]; then
  echo "Failed to get indexer list from ${JACKETT_URL}/api/v2.0/indexers"
  echo "You may need to provide JACKETT_API or check Jackett is running. Trying fallback /api/v2.0/indexers/all ..."
  idx_json=$(curl "${curl_opts[@]}" "${JACKETT_URL}/api/v2.0/indexers/all" 2>/dev/null || true)
fi

if [ -z "$idx_json" ]; then
  echo "Could not retrieve indexer list from Jackett. Exiting."
  exit 1
fi

echo "$idx_json" | jq -r '.[] | "[1m" + (.name // .title // "unknown") + "[0m\n" + ("Torznab: " + ("'${JACKETT_URL}'" + "/jackett/api/v2.0/indexers/" + (.id|tostring) + "/results/torznab/api?apikey=" + (env.JACKETT_API // "")))' | sed 's/^/  /'

echo
echo "Notes:"
echo "- The Torznab URL above uses Jackett's indexer id. Some Jackett installs also expose a friendly indexer name in URLs; use the URL Jackett shows in its UI if available."
echo "- To add an indexer into Prowlarr, copy the Torznab URL and add it in Prowlarr UI (Indexers → + → Torznab)."

if [ -n "$PROWLARR_URL" ] && [ -n "$PROWLARR_API" ]; then
  echo
  echo "Attempting to add all Jackett Torznab indexers to Prowlarr at ${PROWLARR_URL} ..."

  # Iterate indexers and call Prowlarr API to add a Torznab indexer entry.
  echo "$idx_json" | jq -c '.[]' | while read -r idx; do
    id=$(echo "$idx" | jq -r '.id')
    name=$(echo "$idx" | jq -r '.name // .title // "jackett-'$id'"')
    torznab_url="${JACKETT_URL}/jackett/api/v2.0/indexers/${id}/results/torznab/api?apikey=${JACKETT_API}"

    echo "Adding indexer to Prowlarr: ${name} -> ${torznab_url}"

    payload=$(jq -n --arg name "Jackett: ${name}" --arg url "$torznab_url" '{"enableRss":true, "name":$name, "implementation":"Torznab", "protocol":"Torznab", "settings":{"url":$url}}')

    resp=$(curl --silent --show-error --fail -X POST -H "X-Api-Key: ${PROWLARR_API}" -H "Content-Type: application/json" --data "$payload" "${PROWLARR_URL}/api/v1/indexer" 2>&1 || true)
    if [ $? -ne 0 ]; then
      echo "  Failed to add ${name}: ${resp}"
    else
      echo "  Added ${name}."
    fi
  done
fi

echo "Done."
