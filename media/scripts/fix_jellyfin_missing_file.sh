#!/usr/bin/env bash
set -euo pipefail

# fix_jellyfin_missing_file.sh
# Helper to find a media file on the host, compare sizes, and optionally move/rename
# it into the Jellyfin library path expected by Jellyfin inside the container.

usage() {
  cat <<EOF
Usage: $0 --expected CONTAINER_PATH [--data-dir HOST_DATA_DIR] [--apply] [--restart]

--expected      Path as Jellyfin expects it (e.g. "/data/shows/Foundation (2021)/Season 3/foundation.s03e03.1080p...mkv")
--data-dir      Host DATA_DIR mount (default: /mnt/wd_media/homelab-data)
--apply         Actually move/rename the found candidate into the expected location
--restart       Restart the docker container named 'jellyfin' after moving
--help          Show this message

Examples:
  $0 --expected '/data/shows/Foundation (2021)/Season 3/foundation.s03e03.1080p.web.h264-successfulcrab[EZTVx.to].mkv[eztvx.to].mkv' --data-dir /mnt/wd_media/homelab-data
  $0 --expected '/data/shows/Foundation (2021)/Season 3/foundation.s03e03.mkv' --apply --restart
EOF
}

EXPECTED=""
DATA_DIR="/mnt/wd_media/homelab-data"
APPLY=false
RESTART=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected) EXPECTED="$2"; shift 2;;
    --data-dir) DATA_DIR="$2"; shift 2;;
    --apply) APPLY=true; shift;;
    --restart) RESTART=true; shift;;
    --help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "$EXPECTED" ]]; then
  echo "--expected is required"
  usage
  exit 2
fi

# Normalize paths
EXPECTED_CONTAINER_PATH="$EXPECTED"
# Remove leading /data/ which is what Jellyfin maps to $DATA_DIR on the host by default
RELATIVE_PATH="${EXPECTED_CONTAINER_PATH#/data/}"
HOST_EXPECTED_PATH="$DATA_DIR/$RELATIVE_PATH"

echo "Expected container path: $EXPECTED_CONTAINER_PATH"
echo "Translated host path: $HOST_EXPECTED_PATH"

if [[ -e "$HOST_EXPECTED_PATH" ]]; then
  echo "✅ Expected file exists on host: $HOST_EXPECTED_PATH"
  stat -c '%n %s %U:%G %y' "$HOST_EXPECTED_PATH"
  exit 0
fi

# File missing — search for likely candidates by basename and fuzzy matches
BASENAME=$(basename "$RELATIVE_PATH")
NAME_NO_EXT="${BASENAME%.*}"
# Build a find-safe name pattern: remove bracketed sections for search
SEARCH_NAME=$(echo "$NAME_NO_EXT" | sed -E 's/\[[^]]*\]//g' | sed -E 's/[^A-Za-z0-9._-]+/ /g' | awk '{$1=$1;print}' | sed 's/ /.*?/g')

echo "Searching host DATA_DIR ($DATA_DIR) for candidate files matching: $SEARCH_NAME"

# Limit search to common locations under DATA_DIR
CANDIDATES=$(find "$DATA_DIR" -type f -iregex ".*${SEARCH_NAME}.*\\.mkv$" -printf "%p|%s\n" 2>/dev/null || true)

if [[ -z "$CANDIDATES" ]]; then
  echo "No candidates found with fuzzy match. Trying looser search (basename fragments)..."
  # split words
  IFS='.' read -r -a parts <<< "$NAME_NO_EXT"
  terms=""
  for p in "${parts[@]}"; do
    t=$(echo "$p" | sed 's/[^A-Za-z0-9]//g')
    [[ -n "$t" ]] && terms="$terms -iname '*$t*'"
  done
  # shellcheck disable=SC2086
  CANDIDATES=$(eval find "$DATA_DIR" -type f -iname '*.mkv' $terms -printf "%p|%s\n" 2>/dev/null || true)
fi

if [[ -z "$CANDIDATES" ]]; then
  echo "No likely file candidates found. You may need to re-download or place the file into the library." 
  exit 1
fi

echo "Found candidates (path|size):"
printf "%s\n" "$CANDIDATES"

echo
readarray -t ARR <<<"$(printf "%s" "$CANDIDATES")"

# Choose best candidate: exact filename (ignoring extra .mkv) or largest size
BEST_INDEX=-1
BEST_SIZE=0
for i in "${!ARR[@]}"; do
  line="${ARR[$i]}"
  path="${line%%|*}"
  size="${line##*|}"
  bname=$(basename "$path")
  if [[ "$bname" == "$BASENAME" ]]; then
    BEST_INDEX=$i
    BEST_SIZE=$size
    break
  fi
  if (( size > BEST_SIZE )); then
    BEST_INDEX=$i
    BEST_SIZE=$size
  fi
done

CHOICE_PATH="${ARR[$BEST_INDEX]%%|*}"
CHOICE_SIZE="${ARR[$BEST_INDEX]##*|}"

echo "\nSuggested candidate: $CHOICE_PATH (size: $CHOICE_SIZE)"

if [[ "$APPLY" != true ]]; then
  echo "\nDry run: to move this file into place, re-run with --apply"
  echo "Suggested command to run (as root or user with write permissions to DATA_DIR):"
  echo "mkdir -p \"$(dirname "$HOST_EXPECTED_PATH")\""
  echo "mv -v -- \"$CHOICE_PATH\" \"$HOST_EXPECTED_PATH\""
  echo "chown -R 1000:1000 \"$(dirname "$HOST_EXPECTED_PATH")\""
  echo "# then restart jellyfin: docker restart jellyfin"
  exit 0
fi

# APPLY mode: move file
mkdir -p "$(dirname "$HOST_EXPECTED_PATH")"
# Use mv safely
mv -v -- "$CHOICE_PATH" "$HOST_EXPECTED_PATH"
# Ensure permissions match typical container PUID/PGID (1000:1000)
chown -R 1000:1000 "$(dirname "$HOST_EXPECTED_PATH")"

echo "Moved candidate into place: $HOST_EXPECTED_PATH"

if [[ "$RESTART" == true ]]; then
  if command -v docker >/dev/null 2>&1; then
    echo "Restarting jellyfin container..."
    docker restart jellyfin || echo "Failed to restart container — you may need to restart jellyfin manually."
  else
    echo "docker command not found; cannot restart jellyfin."
  fi
fi

exit 0
