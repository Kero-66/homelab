#!/usr/bin/env bash
# =============================================================================
# import_downloads.sh — Scan download folders and auto-import matched files
# =============================================================================
# Scans qBittorrent and SABnzbd completed dirs against Radarr and Sonarr.
# Auto-imports files with clean matches (no rejections) via the real import
# pipeline, and reports unmatched files so you know what needs manual UI
# attention.
#
# This is the canonical way to import stuck/manual downloads — run this
# BEFORE reaching for ad-hoc curl against the Sonarr/Radarr API. Every run
# is logged to logs/ so failures can be diagnosed after the fact instead of
# re-running the same curl commands to see what happened.
#
# Usage:
#   ./import_downloads.sh [--dry-run]
#
#   --dry-run   Show what would be imported without actually importing
#
# Requirements: jq, curl, infisical CLI authenticated
#
# --- Why POST /api/v3/command (name: ManualImport), not POST /api/v3/manualimport ---
# POST /api/v3/manualimport is Sonarr/Radarr's ReprocessItems endpoint — it
# only re-evaluates quality/language/episode matching and echoes the result
# back. It does NOT copy/hardlink any file, and does NOT fire the internal
# DownloadCompletedEvent that Sonarr/Radarr use to mark a queue item resolved
# and (depending on download-client settings) remove/stop tracking it.
# Confirmed live 2026-08-29: a POST to /api/v3/manualimport for an
# already-imported Zoids Chaotic Century episode returned an unchanged echo
# and left its queue item stuck at importBlocked; the Sonarr UI's Interactive
# Import (which goes through the real import pipeline / DownloadedEpisodesImportService)
# cleared the same queue item immediately and logged DownloadCompletedEvent.
# POST /api/v3/command with name "ManualImport" drives that same real
# pipeline via the API — that's what this script (and the PATTERNS.md manual
# curl pattern) must use. See PATTERNS.md → "Manual Import — always pass
# downloadId through" for the downloadId field, which is a separate, also-real
# requirement for this to correlate back to the right queue item.
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
# Logging — every run is captured, not just echoed to a terminal that closes
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/import_downloads_${RUN_ID}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Logging to $LOG_FILE"

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------
INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
INFISICAL_DOMAIN="http://192.168.20.22:8081"
_isec() {
  infisical secrets get "$1" --env dev --path "$2" --plain \
    --projectId "$INFISICAL_PROJECT_ID" --domain "$INFISICAL_DOMAIN" 2>/dev/null
}

SONARR_API=$(_isec SONARR_API_KEY /media || true)
RADARR_API=$(_isec RADARR_API_KEY /media || true)

# ---------------------------------------------------------------------------
# Ship this run's log to Loki (Grafana Alloy stack) so it's queryable in
# Grafana instead of only living on whatever machine ran the script. Runs on
# EXIT (success or failure) so a crashed run still gets shipped. Labels are
# kept low-cardinality and stable (job/host/run_status only) — the run_id and
# free-text content live in the log line itself, not as labels, per Loki's
# own guidance against high-cardinality labels blowing up the index.
# Credentials: LOKI_PUSH_USER/LOKI_PUSH_PASSWORD in Infisical /observability.
# See ai/PATTERNS.md → "Shipping script logs to Loki" for the reusable pattern.
# ---------------------------------------------------------------------------
ship_log_to_loki() {
  local exit_code=$?
  [[ -f "$LOG_FILE" ]] || return 0
  local status="success"
  [[ "$exit_code" -ne 0 ]] && status="failure"

  local loki_user loki_pass
  loki_user=$(_isec LOKI_PUSH_USER /observability || true)
  loki_pass=$(_isec LOKI_PUSH_PASSWORD /observability || true)
  if [[ -z "$loki_user" || -z "$loki_pass" ]]; then
    echo "  (skipping Loki push — LOKI_PUSH_USER/PASSWORD not available)" >&2
    return 0
  fi

  # Strip ANSI color codes (from log_ok/log_warn/log_skip) so lines read
  # cleanly in Grafana's log panel, then build one push stream, one value
  # per line, with strictly increasing nanosecond timestamps (Loki requires
  # non-decreasing order within a stream).
  local payload
  payload=$(sed -E 's/\x1b\[[0-9;]*m//g' "$LOG_FILE" | jq -R -s --arg host "$(hostname -s)" --arg run_id "$RUN_ID" --arg status "$status" '
    (split("\n") | map(select(length > 0))) as $lines |
    (now * 1000000000 | floor) as $base_ns |
    {
      streams: [{
        stream: {job: "import_downloads", host: $host, run_status: $status},
        values: ($lines | to_entries | map([
          ($base_ns + .key | tostring),
          (.value + " run_id=" + $run_id)
        ]))
      }]
    }' 2>/dev/null)

  if [[ -z "$payload" ]]; then
    echo "  (skipping Loki push — failed to build payload)" >&2
    return 0
  fi

  # Credentials passed via curl's -K stdin config (not -u on the command
  # line) so they never appear in `ps aux`/`/proc/<pid>/cmdline` for other
  # local users to read — see feedback in this repo's Dockhand notes about
  # avoiding passwords in process argv.
  curl -s -K - -o /dev/null -w "  Shipped log to Loki: %{http_code}\n" \
    -X POST "http://loki.home/loki/api/v1/push" \
    -H "Content-Type: application/json" \
    -d "$payload" <<EOF || echo "  (Loki push failed — non-fatal)" >&2
user = "${loki_user}:${loki_pass}"
EOF
}
trap ship_log_to_loki EXIT

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

# Poll a queued command until it leaves "queued"/"started", printing its final status
wait_for_command() {
  local app="$1" command_id="$2"
  local status_json status
  for _ in $(seq 1 30); do
    if [[ "$app" == "sonarr" ]]; then
      status_json=$(sonarr_api "command/${command_id}" 2>/dev/null)
    else
      status_json=$(radarr_api "command/${command_id}" 2>/dev/null)
    fi
    status=$(echo "$status_json" | jq -r '.status // "unknown"')
    if [[ "$status" != "queued" && "$status" != "started" ]]; then
      echo "$status_json"
      return
    fi
    sleep 2
  done
  echo "$status_json"
}

# ---------------------------------------------------------------------------
# Scan and import for one app
# ---------------------------------------------------------------------------
scan_and_import() {
  local app="$1"       # sonarr or radarr
  local scan_dir="$2"

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
      # Build the import payload — POST to /api/v3/command (name: ManualImport).
      # NOT /api/v3/manualimport — see header comment for why that endpoint
      # doesn't actually import anything.
      local files command_payload result command_id final_status
      if [[ "$app" == "sonarr" ]]; then
        files=$(echo "$importable" | jq '[.[] | {
          path,
          seriesId: .series.id,
          episodeIds: [.episodes[].id],
          downloadId,
          quality,
          languages,
          releaseGroup,
          importMode: "copy"
        }]')
      else
        files=$(echo "$importable" | jq '[.[] | {
          path,
          movieId: .movie.id,
          downloadId,
          quality,
          languages,
          releaseGroup,
          importMode: "copy"
        }]')
      fi

      command_payload=$(jq -n --argjson files "$files" '{name: "ManualImport", files: $files, importMode: "copy"}')

      if [[ "$app" == "sonarr" ]]; then
        result=$(sonarr_api "command" -X POST -H "Content-Type: application/json" -d "$command_payload" 2>/dev/null)
      else
        result=$(radarr_api "command" -X POST -H "Content-Type: application/json" -d "$command_payload" 2>/dev/null)
      fi

      if ! echo "$result" | jq empty 2>/dev/null; then
        log_warn "$app: invalid response from command POST — files may not have been imported"
        return
      fi

      command_id=$(echo "$result" | jq -r '.id // empty')
      if [[ -z "$command_id" ]]; then
        log_skip "$app: command POST did not return a command id — $(echo "$result" | jq -c '.')"
        return
      fi

      final_status=$(wait_for_command "$app" "$command_id")
      local status
      status=$(echo "$final_status" | jq -r '.status // "unknown"')
      if [[ "$status" == "completed" ]]; then
        log_ok "$app: ManualImport command $command_id completed for $importable_count file(s) from $scan_dir"
      else
        log_skip "$app: ManualImport command $command_id ended with status '$status' — $(echo "$final_status" | jq -c '{status, exception, trigger}')"
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
echo "Done. Log saved to $LOG_FILE"
