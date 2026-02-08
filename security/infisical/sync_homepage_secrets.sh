#!/usr/bin/env bash
# security/infisical/sync_homepage_secrets.sh
# Purpose: Mirror stack secrets into /homepage so Homepage can access all keys via a single Infisical path.

set -euo pipefail

ENVIRONMENT="${INFISICAL_ENV:-dev}"
PROJECT_ID="${INFISICAL_PROJECT_ID:-}"

if ! command -v infisical >/dev/null 2>&1; then
  echo "infisical CLI not found" >&2
  exit 1
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "INFISICAL_PROJECT_ID is required" >&2
  exit 1
fi

copy_secret() {
  local key=$1
  local from_path=$2

  if ! value=$(infisical secrets get "$key" --env "$ENVIRONMENT" --projectId "$PROJECT_ID" --path "$from_path" --plain 2>/dev/null); then
    echo "Skipping $key (not found in $from_path)"
    return 0
  fi

  if [[ -z "$value" ]]; then
    echo "Skipping $key (empty value in $from_path)"
    return 0
  fi

  infisical secrets set "$key=$value" --env "$ENVIRONMENT" --projectId "$PROJECT_ID" --path "/homepage" >/dev/null
  echo "Synced $key -> /homepage"
}

# Media secrets
for key in \
  SONARR_API_KEY RADARR_API_KEY LIDARR_API_KEY PROWLARR_API_KEY BAZARR_API_KEY SABNZBD_API_KEY \
  QBITTORRENT_USER QBITTORRENT_PASS CLEANUPARR_API_KEY; do
  copy_secret "$key" "/media"
done

# Jellyfin/Jellyseerr/Jellystat secrets (now stored under /media)
for key in \
  JELLYFIN_API_KEY JELLYSEERR_API_KEY JELLYSTAT_API_KEY JELLYSTAT_DB_USER JELLYSTAT_DB_PASS JELLYSTAT_JWT_SECRET; do
  copy_secret "$key" "/media"
done

# Monitoring secrets
for key in BESZEL_USER BESZEL_PASS; do
  copy_secret "$key" "/monitoring"
done

echo "Homepage secret sync complete."
