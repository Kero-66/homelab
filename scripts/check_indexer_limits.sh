#!/usr/bin/env bash
# scripts/check_indexer_limits.sh
# Quick reference to check NZB indexer usage against configured limits

set -euo pipefail

# Get Prowlarr API key from Infisical
PROWLARR_API_KEY=$(infisical secrets get PROWLARR_API_KEY --env dev --path /media --projectId 5086c25c-310d-4cfb-9e2c-24d1fa92c152 --plain 2>/dev/null)

if [ -z "$PROWLARR_API_KEY" ]; then
  echo "Error: Could not fetch PROWLARR_API_KEY from Infisical" >&2
  exit 1
fi

echo "==================================================================="
echo "NZB Indexer Usage Report - $(date '+%Y-%m-%d %H:%M:%S')"
echo "==================================================================="
echo ""

# Simple approach: just show the data in table format
printf "%-20s %10s %10s %10s %10s\n" "Indexer" "Queries" "Q-Limit" "Grabs" "G-Limit"
printf "%-20s %10s %10s %10s %10s\n" "--------------------" "----------" "----------" "----------" "----------"

curl -s http://localhost/prowlarr/api/v1/indexer -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -r '.[] | select(.protocol == "usenet") | "\(.id)|\(.name)"' | \
while IFS='|' read -r id name; do
  # Get limits from indexer config
  limits=$(curl -s "http://localhost/prowlarr/api/v1/indexer/$id" -H "X-Api-Key: $PROWLARR_API_KEY" | \
    jq -r '[.fields[] | select(.name == "baseSettings.queryLimit" or .name == "baseSettings.grabLimit") | .value // 0] | join("|")')
  queryLimit=$(echo "$limits" | cut -d'|' -f1)
  grabLimit=$(echo "$limits" | cut -d'|' -f2)
  
  # Get stats
  stats=$(curl -s http://localhost/prowlarr/api/v1/indexerstats -H "X-Api-Key: $PROWLARR_API_KEY" | \
    jq -r --arg name "$name" '.indexers[] | select(.indexerName == $name) | "\(.numberOfQueries)|\(.numberOfGrabs)"')
  
  if [ -n "$stats" ]; then
    queries=$(echo "$stats" | cut -d'|' -f1)
    grabs=$(echo "$stats" | cut -d'|' -f2)
  else
    queries=0
    grabs=0
  fi
  
  printf "%-20s %10s %10s %10s %10s\n" "$name" "$queries" "$queryLimit" "$grabs" "$grabLimit"
done

echo ""
echo "==================================================================="
echo "⚠️  Note: Prowlarr stats are cumulative (all-time), not daily."
echo "    Check indexer account pages for accurate 24-hour usage."
echo "==================================================================="
