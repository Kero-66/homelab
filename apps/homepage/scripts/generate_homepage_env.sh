#!/usr/bin/env bash
set -euo pipefail
# Generate a .env file for the homepage compose substitution from Infisical
OUT_DIR="$(dirname "$0")/.."
DEST_ENV="$OUT_DIR/.env"

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI not found" >&2
  exit 1
fi

echo "# Generated homepage env from Infisical (/homepage)" > "$DEST_ENV"
infisical export --env dev --path /homepage --format dotenv >> "$DEST_ENV"
echo "WROTE $DEST_ENV"
