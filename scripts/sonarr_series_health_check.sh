#!/usr/bin/env bash
set -euo pipefail

# sonarr_series_health_check.sh
# Usage: sonarr_series_health_check.sh [--webhook <url>] ["Series Title 1" "Series Title 2" ...]
# Defaults to the two series you asked about when no titles are provided.

CRED_FILE="/mnt/library/repos/homelab/media/.config/.credentials"
SONARR_URL_DEFAULT="http://localhost/sonarr"

WEBHOOK=""
TITLES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook) WEBHOOK="$2"; shift 2;;
    --) shift; break;;
    -*) echo "Unknown option: $1" >&2; exit 1;;
    *) TITLES+=("$1"); shift;;
  esac
done

if [ -f "$CRED_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CRED_FILE" || true
fi

SONARR_API_KEY=${SONARR_API_KEY:-}
SONARR_URL=${SONARR_URL:-$SONARR_URL_DEFAULT}

if [ -z "$SONARR_API_KEY" ]; then
  echo "SONARR_API_KEY not set. Please export it or place it in $CRED_FILE" >&2
  exit 1
fi

API="$SONARR_URL/api/v3"

if [ ${#TITLES[@]} -eq 0 ]; then
  TITLES=("My Status as an Assassin Obviously Exceeds the Hero's" "Mobile Suit Gundam Wing")
fi

safe_curl(){
  curl -sS -H "X-Api-Key: $SONARR_API_KEY" "$@"
}

report="{\"series_report\":[] }"
tmpfile=$(mktemp)

for title in "${TITLES[@]}"; do
  echo "--- Checking: $title ---"
  series_json=$(safe_curl "$API/series" )

  # find by exact title (case-insensitive) or by contains
  series_b64=$(echo "$series_json" | jq -r --arg t "$title" '(.[] | select((.title|ascii_downcase) == ($t|ascii_downcase)) // empty) | @base64' | head -n1 || true)
  if [ -z "$series_b64" ]; then
    series_b64=$(echo "$series_json" | jq -r --arg t "$title" '(.[] | select((.title|ascii_downcase) | contains(($t|ascii_downcase))) ) | @base64' | head -n1 || true)
  fi

  if [ -z "$series_b64" ]; then
    echo "Series not found in Sonarr: $title"
    report=$(echo "$report" | jq --arg t "$title" '.series_report += [{title:$t,found:false}]')
    continue
  fi

  series=$(echo "$series_b64" | base64 -d)
  sid=$(echo "$series" | jq -r '.id')
  sTitle=$(echo "$series" | jq -r '.title')

  echo "Found series id=$sid title=\"$sTitle\""

  # episodes: count monitored episodes missing files
  eps=$(safe_curl "$API/episode?seriesId=$sid")
  missing_count=$(echo "$eps" | jq '[.[] | select(.monitored == true and (.hasFile|not))] | length' 2>/dev/null || echo 0)

  # recent history for this series
  h=$(safe_curl "$API/history?seriesId=$sid&limit=100")
  last_grabbed=$(echo "$h" | jq -r '[.[] | select(.eventType=="Grab" or .eventType=="Grabbed" or .eventType=="grabbed" or .eventType=="grab")][0].date' 2>/dev/null || echo "")
  last_download_failed=$(echo "$h" | jq -r '[.[] | select(.eventType=="downloadFailed" or .eventType=="DownloadFailed" or .eventType=="ImportFailed" or .eventType=="importFailed")][0].date' 2>/dev/null || echo "")

  # queue items
  q=$(safe_curl "$API/queue")
  queue_items=$(echo "$q" | jq --argjson sid $sid '[.[] | select(.series && (.series.id == $sid))] | length' 2>/dev/null || echo 0)

  echo "Missing monitored episodes: $missing_count"
  if [ -n "$last_grabbed" ] && [ "$last_grabbed" != "null" ]; then
    echo "Last grabbed: $last_grabbed"
  else
    echo "No recent grabs in history"
  fi
  if [ -n "$last_download_failed" ] && [ "$last_download_failed" != "null" ]; then
    echo "Recent download/import failure: $last_download_failed"
  fi
  echo "Queue items for series: $queue_items"

  # collect details for webhook/report
  report=$(echo "$report" | jq --arg t "$sTitle" --arg id "$sid" --arg missing "$missing_count" --arg lastgrab "$last_grabbed" --arg lastfail "$last_download_failed" --arg queue "$queue_items" '.series_report += [{title:$t,seriesId:$id,missing_monitored:(($missing|tonumber)),last_grabbed:$lastgrab,last_fail:$lastfail,queue_items:(($queue|tonumber))}]')

done

echo
echo "Summary JSON:" 
echo "$report" | jq .

if [ -n "$WEBHOOK" ]; then
  echo "Posting report to webhook: $WEBHOOK"
  curl -fsS -X POST -H "Content-Type: application/json" -d "$report" "$WEBHOOK" || echo "Webhook POST failed"
fi

rm -f "$tmpfile"

exit 0
