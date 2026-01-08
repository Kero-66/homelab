#!/usr/bin/env bash
set -euo pipefail

# apply_anime_release_profile.sh
# Creates an 'anime' tag, a Sonarr release profile that requires Japanese audio,
# and assigns the tag to series whose language profile is Japanese.
# Dry-run by default. To apply changes set APPLY=1 or pass --apply.

CREDS="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CREDS" ]; then
  echo "Credentials file not found: $CREDS" >&2
  exit 1
fi

SONARR_KEY=$(grep -Ei 'SONARR_API_KEY|SONARR' "$CREDS" | head -n1 | sed -E 's/^[^=]*=//; s/^"|"$//g')
if [ -z "$SONARR_KEY" ]; then
  echo "No Sonarr API key found in $CREDS" >&2
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

SONARR_BASE=${SONARR_BASE:-"http://localhost:8989/sonarr/api/v3"}

echo "Fetching language profiles..."
langs=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/languageprofile")
echo "$langs" | jq -c '.'

JAP_ID=$(echo "$langs" | jq -r '.[] | select(.name|test("Japanese";"i")) | .id // empty')
if [ -n "$JAP_ID" ]; then
  echo "Found Japanese language profile id=$JAP_ID"
  echo "Listing series with languageProfileId=$JAP_ID"
  series=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/series")
  anime_series_ids=$(echo "$series" | jq -r --argjson id "$JAP_ID" '.[] | select(.languageProfileId==$id) | .id')
else
  echo "No Japanese language profile found — falling back to detecting series by quality profile name containing 'anime'"
  qp=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/qualityprofile")
  echo "Quality profiles:"; echo "$qp" | jq -c '.[] | {id:.id,name:.name}'
  anime_qp_ids=$(echo "$qp" | jq -r '.[] | select(.name|test("anime";"i")) | .id')
  echo "Detected anime quality profile ids: $anime_qp_ids"
  series=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/series")
  anime_series_ids=""
  for qid in $anime_qp_ids; do
    more=$(echo "$series" | jq -r --argjson q "$qid" '.[] | select(.qualityProfileId==$q) | .id') || true
    anime_series_ids="$anime_series_ids $more"
  done
  anime_series_ids=$(echo "$anime_series_ids" | xargs -n1 | sort -u | xargs)
  echo "Series (IDs) detected as anime by quality profile:"
  echo "$anime_series_ids" || true
fi

echo "Checking/creating tag 'anime'"
tags=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/tag")
anime_tag_id=$(echo "$tags" | jq -r '.[] | select(.label|test("^anime$";"i")) | .id // empty')
if [ -z "$anime_tag_id" ]; then
  echo "No existing 'anime' tag found. Will create one." 
  if [ "$APPLY" -eq 1 ]; then
    created=$(curl -s -X POST -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" -d '{"label":"anime"}' "$SONARR_BASE/tag")
    anime_tag_id=$(echo "$created" | jq -r '.id')
    echo "Created tag 'anime' id=$anime_tag_id"
  else
    echo "Dry-run: would create tag 'anime'"
    anime_tag_id="<will-create>"
  fi
else
  echo "Found existing tag 'anime' id=$anime_tag_id"
fi

echo "Preparing release profile payload (Anime - Japanese Only)"
if [ "$anime_tag_id" = "<will-create>" ]; then
  TAGS_JSON='[]'
else
  TAGS_JSON="[$anime_tag_id]"
fi
payload=$(jq -n --arg name "Anime - Japanese Only" --argjson required '["Japanese"]' --argjson ignored '["English","English Dub","Dubbed","English-Sub"]' --argjson tags "$TAGS_JSON" '{"name":$name,"enabled":true,"required":$required,"ignored":$ignored,"indexerId":0,"tags":$tags}')

echo "Release profile payload preview:"
echo "$payload" | jq -c '.'

if [ "$APPLY" -eq 1 ]; then
  echo "Creating release profile in Sonarr"
  resp=$(echo "$payload" | curl -s -X POST -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" -d @- "$SONARR_BASE/releaseprofile")
  echo "Created release profile:"; echo "$resp" | jq -c '{id:.id,name:.name,required:.required,ignored:.ignored,tags:.tags}'
else
  echo "Dry-run: would POST the above payload to $SONARR_BASE/releaseprofile"
fi

echo "Tagging detected anime series with the 'anime' tag (if apply)"
for sid in $anime_series_ids; do
  echo "Series id=$sid"
  sobj=$(curl -s -H "X-Api-Key: $SONARR_KEY" "$SONARR_BASE/series/$sid")
  cur_tags=$(echo "$sobj" | jq -r '.tags // []')
  if echo "$cur_tags" | jq -e --arg at "$anime_tag_id" 'index($at) // empty' >/dev/null 2>&1; then
    echo "Series already has 'anime' tag"
    continue
  fi
  if [ "$APPLY" -eq 1 ]; then
    new_tags=$(echo "$cur_tags" | jq --arg at "$anime_tag_id" '. + [$at|tonumber] | unique')
    updated=$(echo "$sobj" | jq --argjson t "$new_tags" '.tags = $t')
    echo "Updating series $sid with new tags"; echo "$updated" | curl -s -X PUT -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" -d @- "$SONARR_BASE/series/$sid" | jq -c '{id:.id,title:.title,tags:.tags}'
  else
    echo "Dry-run: would add tag id=$anime_tag_id to series id=$sid"
  fi
done

echo "Done."
