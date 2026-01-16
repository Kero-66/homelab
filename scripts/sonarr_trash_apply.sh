#!/usr/bin/env bash
set -euo pipefail

# Apply TRaSH custom formats and anime quality profile to Sonarr (guarded)
# Dry-run by default. To execute changes set: RUN_SONARR_TRASH_APPLY=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

CRED=media/.config/.credentials
SONARR_API=$(grep -E '^SONARR_API_KEY=' "$CRED" | cut -d= -f2- || echo "$SONARR_API")
SONARR_URL=$(grep -E '^SONARR_URL=' "$CRED" | cut -d= -f2- || echo "http://localhost/sonarr")

DRY_RUN=true
if [[ "${RUN_SONARR_TRASH_APPLY:-0}" == "1" ]]; then
  DRY_RUN=false
fi

if [[ -z "$SONARR_API" ]]; then
  echo "ERROR: SONARR API key not found. Set SONARR_API in environment or in $CRED as SONARR_API_KEY." >&2
  exit 1
fi

echo "Sonarr URL: $SONARR_URL"
echo "Dry-run: $DRY_RUN"
echo

CF_DIR="scripts/trash_cf"
declare -A CF_IDS
declare -A CF_SCORES

echo "Step 1: Import or locate custom formats"
for f in "$CF_DIR"/*.json; do
  if [[ ! -f "$f" ]]; then
    continue
  fi
  name=$(jq -r '.name // empty' "$f")
  score=$(jq -r '.score // 0' "$f")
  CF_SCORES["$name"]=$score

  echo "- CF file: $f (name: $name, score: $score)"

  # Check existing CFs
  existing=$(curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/customFormat" | jq -c --arg name_lc "$(echo "$name" | tr '[:upper:]' '[:lower:]')" '.[] | select((.name|ascii_downcase) == $name_lc)' || true)
  if [[ -n "$existing" ]]; then
    id=$(echo "$existing" | jq -r 'if type=="object" then .id else empty end')
    CF_IDS["$name"]=$id
    echo "  -> exists (id: $id)"
    continue
  fi

  # Build a simple Sonarr customFormat payload from our example file
  # Use a ReleaseTitleSpecification regex based on name if available
  regex=""
  # crude: prefer language selectors in file
  sel=$(jq -r '.selector // empty' "$f")
  if [[ -n "$sel" ]]; then
    if echo "$sel" | grep -iq 'jpn\|japanese\|日本'; then
      regex='(?i)japanese|jpn|日本'
    elif echo "$sel" | grep -iq 'eng\|english\|dub'; then
      regex='(?i)english|dubbed|english dub|eng'
    fi
  fi
  if [[ -z "$regex" ]]; then
    # fallback to derive from name tokens
    lower_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    # replace non-alnum with '|' to form alternation
    san=$(echo "$lower_name" | sed -E 's/[^a-z0-9]+/|/g' | sed -E 's/^\||\|$//g')
    if [[ -n "$san" ]]; then
      regex="(?i)$san"
    fi
  fi

  payload=$(jq -n --arg name "$name" --arg regex "$regex" '{
    name: $name,
    specifications: [
      {
        name: "Title Regex",
        implementation: "ReleaseTitleSpecification",
        negate: false,
        required: false,
        fields: [ { order: 0, name: "value", label: "Regular Expression", value: $regex } ]
      }
    ],
    includeCustomFormatWhenRenaming: false
  }')

  echo "  -> would POST /api/v3/customFormat with payload:"
  echo "$payload" | jq '.'

  if [[ "$DRY_RUN" == "false" ]]; then
    resp=$(curl -s -X POST -H "X-Api-Key: $SONARR_API" -H "Content-Type: application/json" "$SONARR_URL/api/v3/customFormat" -d "$payload")
    id=$(echo "$resp" | jq -r 'if (type=="object") then .id elif (type=="array") then (.[0].id // empty) else empty end')
    if [[ -n "$id" ]]; then
      CF_IDS["$name"]=$id
      echo "  -> created id: $id"
    else
      echo "  -> create failed: $resp" >&2
    fi
  fi
done

echo
echo "Step 2: Create or update anime quality profile"
PROPOSED=scripts/proposed_anime_profile.json
if [[ ! -f "$PROPOSED" ]]; then
  echo "ERROR: $PROPOSED not found" >&2
  exit 1
fi
P_NAME=$(jq -r '.name' "$PROPOSED")
P_MIN=$(jq -r '.minCustomFormatScore // 0' "$PROPOSED")
P_CUTOFF=$(jq -r '.upgradeUntilCustomFormatScore // 0' "$PROPOSED")
P_UPGRADE=$(jq -r '.upgradeAllowed // false' "$PROPOSED")

echo "Proposed profile: $P_NAME (minFormatScore: $P_MIN, cutoff: $P_CUTOFF, upgradeAllowed: $P_UPGRADE)"

# Find existing profile by exact name
  prof=$(curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile" | jq -c --arg name "$P_NAME" '.[] | select(.name==$name)' || true)
if [[ -n "$prof" ]]; then
  prof_id=$(echo "$prof" | jq -r 'if type=="object" then .id else empty end')
  echo "Profile exists (id: $prof_id) -> will update"
else
  echo "Profile does not exist -> will create by cloning an HD template"
  # pick an HD template
  # pick an HD template using jq to avoid broken-pipe errors
  template=$(curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile" | jq -c 'map(select(.name | test("1080|1080p|HD";"i")))[0]')
  if [[ "$template" == "null" || -z "$template" ]]; then
    template=$(curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile" | jq -c '.[0]')
  fi
  if [[ -n "$template" ]]; then
    newprof=$(echo "$template" | jq --arg name "$P_NAME" 'del(.id) | .name=$name')
    echo "  -> new profile payload:"
    echo "$newprof" | jq '.'
    if [[ "$DRY_RUN" == "false" ]]; then
      created=$(curl -s -X POST -H "X-Api-Key: $SONARR_API" -H "Content-Type: application/json" "$SONARR_URL/api/v3/qualityProfile" -d "$newprof")
      prof_id=$(echo "$created" | jq -r '.id // empty')
      echo "  -> created profile id: $prof_id"
    fi
  else
    echo "ERROR: no template profile available" >&2
    exit 1
  fi
fi

if [[ -z "${prof_id:-}" ]]; then
  # If still empty (dry-run), try to derive an id for messages by looking for existing profile name
  prof_id=$(curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile" | jq -r ".[] | select(.name==\"$P_NAME\") | .id" || true)
fi

echo
echo "Step 3: Patch profile formatItems and thresholds (profile id: ${prof_id:-<not-created>})"

if [[ -z "${prof_id:-}" ]]; then
  echo "(dry-run) would PATCH profile after creation with formatItems mapping to CF ids and scores"
else
  # Fetch current profile
  current=$(curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile/$prof_id")
  # Ensure formatItems exists
  has_format=$(echo "$current" | jq 'has("formatItems")')
  if [[ "$has_format" != "true" ]]; then
    current=$(echo "$current" | jq '.formatItems = []')
  fi

  # Add/update CF mappings
  updated=$current
  for name in "${!CF_SCORES[@]}"; do
    cf_score=${CF_SCORES[$name]}
    cf_id=${CF_IDS[$name]:-}
    if [[ -z "$cf_id" ]]; then
      echo "  - warning: no cf id for $name (skipping mapping)"
      continue
    fi
    # If existing mapping exists, replace score; else append
    # use safe string args and convert to numbers inside jq
    exists=$(echo "$updated" | jq --arg id "$cf_id" '.formatItems | map(select(.format == ($id|tonumber))) | length')
    if [[ "$exists" -gt 0 ]]; then
      updated=$(echo "$updated" | jq --arg id "$cf_id" --arg sc "$cf_score" '(.formatItems |= (map(if .format == ($id|tonumber) then .score = ($sc|tonumber) else . end)))')
    else
      updated=$(echo "$updated" | jq --arg id "$cf_id" --arg sc "$cf_score" '.formatItems += [ { format: ($id|tonumber), score: ($sc|tonumber) } ]')
    fi
  done

  # Set minFormatScore and cutoffFormatScore from proposed (if provided)
  if [[ "$P_MIN" != "0" ]]; then
    updated=$(echo "$updated" | jq --arg m "$P_MIN" '.minFormatScore = ($m|tonumber)')
  fi
  if [[ "$P_CUTOFF" != "0" ]]; then
    updated=$(echo "$updated" | jq --arg c "$P_CUTOFF" '.cutoffFormatScore = ($c|tonumber)')
  fi
  # Set upgradeAllowed if requested
  if [[ "$P_UPGRADE" == "true" ]]; then
    updated=$(echo "$updated" | jq '.upgradeAllowed = true')
  fi

  echo "Profile PATCH payload preview:"
  echo "$updated" | jq '.'

  if [[ "$DRY_RUN" == "false" ]]; then
    curl -s -X PUT -H "X-Api-Key: $SONARR_API" -H "Content-Type: application/json" "$SONARR_URL/api/v3/qualityProfile/$prof_id" -d "$updated" > /dev/null
    echo "  -> profile updated"
  fi
fi

echo
echo "Step 4: Cleanup (Anime tagging logic removed)"
# This section previously applied profiles to series tagged as anime.
# It has been removed as we now use generic English profiles and global custom formats.

echo
echo "Step 5: Identify old anime profiles (names containing 'Anime')"
echo "Listing profiles to delete (will skip the current profile id: ${prof_id:-<unknown>})"
if [[ "$DRY_RUN" == "false" ]]; then
  # Stream and delete profiles that match 'anime' but are not the profile we just created/updated
  curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile" \
    | jq -c '.[] | select((.name|ascii_downcase) | test("anime"))' \
    | while read -r p; do
      pid=$(echo "$p" | jq -r '.id')
      pname=$(echo "$p" | jq -r '.name')
      if [[ "$pid" == "$prof_id" ]]; then
        echo "  - skipping current profile $pname ($pid)"
        continue
      fi
      echo "  - deleting old profile $pname ($pid)"
      curl -s -X DELETE -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile/$pid" > /dev/null
    done
else
  # Dry-run: just show the list
  curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/qualityProfile" | jq -c '.[] | select((.name|ascii_downcase) | test("anime"))' | jq -s '. | map({id:.id, name:.name})'
fi

echo
echo "Done. To execute these changes set RUN_SONARR_TRASH_APPLY=1 and re-run this script."
