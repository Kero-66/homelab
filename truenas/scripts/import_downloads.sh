#!/usr/bin/env bash
# =============================================================================
# import_downloads.sh — Scan download folders and auto-import matched files
# =============================================================================
# Scans qBittorrent and SABnzbd completed dirs against Radarr and Sonarr.
# Auto-imports files with clean matches (no rejections).
# Reports unmatched files so you know what needs manual UI attention.
#
# Usage:
#   ./import_downloads.sh [--dry-run]
#
#   --dry-run   Show what would be imported without actually importing
#
# Requirements: jq, curl, infisical CLI authenticated
# =============================================================================

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

SONARR_URL="http://192.168.20.22:8989"
RADARR_URL="http://192.168.20.22:7878"

SCAN_DIRS=(
  "/data/downloads/qbittorrent/completed"
  "/data/downloads/sabnzbd/complete"
)

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------
SONARR_API=$(infisical secrets get SONARR_API_KEY --env dev --path /media --plain 2>/dev/null)
RADARR_API=$(infisical secrets get RADARR_API_KEY --env dev --path /media --plain 2>/dev/null)

if [[ -z "$SONARR_API" || -z "$RADARR_API" ]]; then
  echo "ERROR: Could not retrieve API keys from Infisical" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }
log_ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()    { echo -e "  ${YELLOW}!${NC} $1"; }
log_skip()    { echo -e "  ${RED}✗${NC} $1"; }

sonarr_api() { curl -sL "$SONARR_URL/api/v3/$1" -H "X-Api-Key: $SONARR_API" "${@:2}"; }
radarr_api() { curl -sL "$RADARR_URL/api/v3/$1" -H "X-Api-Key: $RADARR_API" "${@:2}"; }

# ---------------------------------------------------------------------------
# Scan and import for one app
# ---------------------------------------------------------------------------
scan_and_import() {
  local app="$1"       # sonarr or radarr
  local scan_dir="$2"
  local matched=0
  local imported=0
  local unmatched=0

  local items
  if [[ "$app" == "sonarr" ]]; then
    items=$(sonarr_api "manualimport?folder=${scan_dir}&filterExistingFiles=true" 2>/dev/null)
  else
    items=$(radarr_api "manualimport?folder=${scan_dir}&filterExistingFiles=true" 2>/dev/null)
  fi

  # Check we got valid JSON
  if ! echo "$items" | jq empty 2>/dev/null; then
    log_warn "$app: invalid response for $scan_dir — skipping"
    return
  fi

  local count
  count=$(echo "$items" | jq 'length')
  [[ "$count" -eq 0 ]] && return

  # Split into importable (matched + no rejections) vs needs-attention
  local importable
  importable=$(echo "$items" | jq '
    [.[] | select(
      (.series != null or .movie != null) and
      (.rejections | length == 0)
    )]
  ')

  local needs_attention
  needs_attention=$(echo "$items" | jq '
    [.[] | select(
      (.series == null and .movie == null) or
      (.rejections | length > 0)
    )]
  ')

  local importable_count
  importable_count=$(echo "$importable" | jq 'length')

  if [[ "$importable_count" -gt 0 ]]; then
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
      echo "  [DRY RUN] Would import $importable_count file(s):"
    else
      echo "  Importing $importable_count file(s):"
    fi

    # Print what will be imported
    echo "$importable" | jq -r '.[] | "    \(.series.title // .movie.title) — \(.path | split("/") | last)"'

    if [[ "$DRY_RUN" == false ]]; then
      # Build the import payload — POST to manualimport
      local payload result
      if [[ "$app" == "sonarr" ]]; then
        payload=$(echo "$importable" | jq '[.[] | {
          path,
          seriesId: .series.id,
          episodeIds: [.episodes[].id],
          quality,
          languages,
          releaseGroup,
          importMode: "move"
        }]')
        result=$(sonarr_api "manualimport" \
          -X POST \
          -H "Content-Type: application/json" \
          -d "$payload" 2>/dev/null)
      else
        payload=$(echo "$importable" | jq '[.[] | {
          path,
          movieId: .movie.id,
          quality,
          languages,
          releaseGroup,
          importMode: "move"
        }]')
        result=$(radarr_api "manualimport" \
          -X POST \
          -H "Content-Type: application/json" \
          -d "$payload" 2>/dev/null)
      fi

      # Validate response — API returns array of imported items on success
      if ! echo "$result" | jq empty 2>/dev/null; then
        log_warn "$app: invalid response from manualimport POST — files may not have been imported"
        return
      fi
      local error_msg
      error_msg=$(echo "$result" | jq -r 'if type == "object" then .message // "" else "" end')
      if [[ -n "$error_msg" ]]; then
        log_skip "$app: import failed — $error_msg"
        return
      fi
      imported=$(echo "$result" | jq 'if type == "array" then length else 0 end')
      if [[ "$imported" -eq 0 ]]; then
        log_warn "$app: POST succeeded but no items confirmed imported from $scan_dir"
      else
        log_ok "$app: imported $imported file(s) from $scan_dir"
      fi
    fi
  fi

  # Report anything that needs manual attention
  local attention_count
  attention_count=$(echo "$needs_attention" | jq 'length')
  if [[ "$attention_count" -gt 0 ]]; then
    echo ""
    echo "  Needs manual attention ($attention_count file(s)):"
    echo "$needs_attention" | jq -r '.[] | "    [\(.rejections[0].reason // "Unknown")] \(.path | split("/") | last)"'
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}--- DRY RUN MODE ---${NC}"

for dir in "${SCAN_DIRS[@]}"; do
  log_section "Radarr ← $dir"
  scan_and_import "radarr" "$dir"

  log_section "Sonarr ← $dir"
  scan_and_import "sonarr" "$dir"
done

echo ""
echo "Done."
