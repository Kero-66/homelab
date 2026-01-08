#!/usr/bin/env bash
# Dry-run helper: show exact Sonarr API changes that would import TRaSH CFs
set -euo pipefail

CRED=media/.config/.credentials
SONARR_API=$(grep -E '^SONARR_API_KEY=' "$CRED" | cut -d= -f2-)
SONARR_URL=$(grep -E '^SONARR_URL=' "$CRED" | cut -d= -f2- || echo "http://localhost/sonarr")

echo "Dry-run: will NOT POST anything. Reviewing local CF files and building example curl commands."
echo "Sonarr URL: $SONARR_URL"
echo

CF_DIR="scripts/trash_cf"
for f in "$CF_DIR"/*.json; do
  name=$(jq -r '.name' "$f")
  echo "Custom Format file: $f -> name: $name"
  echo "  Example import command:"
  echo "  curl -X POST -H \"X-Api-Key: <api>\" -H \"Content-Type: application/json\" $SONARR_URL/api/v3/customFormat -d @${f}"
  echo
done

echo "Proposed Quality Profile: 'Remux-1080p - Anime' (example payload written to scripts/proposed_anime_profile.json)"

cat > scripts/proposed_anime_profile.json <<'JSON'
{
  "name": "Remux-1080p - Anime",
  "upgradeAllowed": true,
  "upgradeUntilQuality": "Bluray-1080p",
  "upgradeUntilCustomFormatScore": 10000,
  "minCustomFormatScore": 1000,
  "items": [
    "Bluray-1080p Remux",
    "Bluray-1080p",
    "HD - 720p/1080p - Anime/Japanese",
    "HD-1080p",
    "HD-720p/480p - Anime/Japanese",
    "WEBDL-1080p",
    "WEBDL-720p",
    "WEBRip-1080p",
    "WEBRip-720p",
    "HDTV-720p/1080p"
  ]
}
JSON

echo "Wrote scripts/proposed_anime_profile.json"
echo
echo "Manual steps after import (recommended):"
echo "- POST each CF with: curl -X POST -H 'X-Api-Key: <key>' -H 'Content-Type: application/json' $SONARR_URL/api/v3/customFormat -d @<file>"
echo "- GET /api/v3/qualityProfile to find the newly created profile or existing profile id."
echo "- PATCH /api/v3/qualityProfile/{id} with the desired 'formatItems' mapping to CF IDs and ordering of qualities."
echo
echo "If you approve, run: RUN_SONARR_TRASH_APPLY=1 ./scripts/sonarr_trash_apply.sh  (will be provided after your approval)"
