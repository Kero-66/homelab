#!/usr/bin/env bash
set -euo pipefail

# prowlarr_search.sh
# Safe Prowlarr search helper. Disabled by default — set RUN_PROWLARR_SEARCH=1 to run.
# Usage: RUN_PROWLARR_SEARCH=1 /path/to/prowlarr_search.sh ["query 1" "query 2" ...]

if [ "${RUN_PROWLARR_SEARCH:-0}" != "1" ]; then
  echo "prowlarr_search.sh is disabled by default. Set RUN_PROWLARR_SEARCH=1 to run." >&2
  exit 0
fi

CRED_FILE="/mnt/library/repos/homelab/media/.config/.credentials"
if [ -f "$CRED_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CRED_FILE" || true
fi

PROWLARR_API_KEY=${PROWLARR_API_KEY:-}
BASE=${PROWLARR_BASE:-http://localhost/prowlarr/api/v1}

if [ -z "$PROWLARR_API_KEY" ]; then
  echo "PROWLARR_API_KEY not set. Please export it or place it in $CRED_FILE" >&2
  exit 1
fi

QUERIES=()
if [ $# -gt 0 ]; then
  QUERIES=("$@")
else
  QUERIES=("My Status as an Assassin Obviously Exceeds the Hero's" "Mobile Suit Gundam Wing")
fi

for q in "${QUERIES[@]}"; do
  safe_name=$(echo "$q" | tr ' /' '__' | tr -dc '[:alnum:]_-' | cut -c1-40)
  out="scripts/prow_search_${safe_name}.json"
  echo "Searching Prowlarr for: $q -> $out"
  curl -sS -G -H "X-Api-Key: $PROWLARR_API_KEY" --data-urlencode "query=$q" "$BASE/search" -m 30 -o "$out" || true
  if [ -s "$out" ]; then
    count=$(jq 'length' "$out" 2>/dev/null || echo 0)
    echo "  results: $count"
    echo "  sample:"; jq '.[0:6]' "$out" 2>/dev/null | sed -n '1,20p' || true
  else
    echo "  no results (empty response)"
  fi
done

echo "Saved results under scripts/ as prow_search_<name>.json"

exit 0
