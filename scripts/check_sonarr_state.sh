#!/usr/bin/env bash
set -eo pipefail

# check_sonarr_state.sh
# Prints Sonarr system status, recent history (100), current queue (50), and recent commands.

CREDS="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CREDS" ]; then
  echo "Credentials file not found: $CREDS" >&2
  exit 1
fi

SONARR_KEY=$(grep -Ei "SONARR_API_KEY|SONARR" "$CREDS" | head -n1 | sed -E 's/^[^=]*=//; s/^"|"$//g')
if [ -z "$SONARR_KEY" ]; then
  echo "No Sonarr API key found in $CREDS" >&2
  exit 1
fi

BASE=${SONARR_BASE:-"http://localhost/sonarr/api/v3"}

echo "== Sonarr system status =="
curl -s -H "X-Api-Key: $SONARR_KEY" "$BASE/system/status" | jq '{appName:.appName,version:.version,isDebug:.isDebug,isAdmin:.isAdmin}' || true

echo
echo "== Last 100 history entries (most recent first) =="
curl -s -H "X-Api-Key: $SONARR_KEY" "$BASE/history?sortDirection=desc&limit=100" | jq '.[] | {id:.id,eventType:.eventType,title:.title,seriesId:.seriesId,episodeIds:[.episodeIds],date:.date,source:.source,summary:.summary}' || true

echo
echo "== Current download/import queue (first 50) =="
curl -s -H "X-Api-Key: $SONARR_KEY" "$BASE/queue" | jq '{size:(length),items:.[0:50] | map({id:.id,title:.title,episodeIds:[.episodeIds],status:.status,estimatedQuality:(.episode // {} | .quality // {} | .quality // null)})}' || true

echo
echo "== Recent commands =="
curl -s -H "X-Api-Key: $SONARR_KEY" "$BASE/command" | jq '.[] | {name:.name,protocol:.protocol,queued:.queued,started:.started,completed:.completed}' || true

echo
echo "Tip: to tail Sonarr logs on the host (docker):"
echo "  docker compose -f <compose-file> logs -f sonarr --tail 200"
echo "Or check journalctl if Sonarr is a systemd service."
