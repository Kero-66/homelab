#!/usr/bin/env bash
set -euo pipefail
# Generate a .env file for the homepage compose substitution from media/.config/.credentials
OUT_DIR="$(dirname "$0")/.."
CREDS_FILE="$(realpath "$OUT_DIR/../../media/.config/.credentials")"
DEST_ENV="$OUT_DIR/.env"

if [ ! -f "$CREDS_FILE" ]; then
  echo "credentials file not found: $CREDS_FILE" >&2
  exit 1
fi

echo "# Generated homepage env from media/.config/.credentials" > "$DEST_ENV"
grep -E '^[A-Z0-9_]+=.*' "$CREDS_FILE" >> "$DEST_ENV"
echo "WROTE $DEST_ENV"
