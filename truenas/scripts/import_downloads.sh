#!/usr/bin/env bash
# =============================================================================
# import_downloads.sh — Walk the Sonarr/Radarr queue and auto-import matched files
# =============================================================================
# Every file that lands in qBittorrent/SABnzbd's completed dir got there
# because Sonarr or Radarr's download client integration grabbed it (an
# automatic search grab, or a manual Prowlarr "escape hatch" grab via
# POST /api/v3/release — either way it's Sonarr/Radarr's own grab call, so it
# registers a queue entry same as any other). That means the queue is USUALLY
# a reliable index of everything waiting to be imported — including stuck
# importBlocked items whose files already exist on disk. Default mode walks
# that queue (not the filesystem) and auto-imports files with clean matches
# (no rejections) via the real import pipeline, reporting unmatched files so
# you know what needs --plan/--apply or manual UI attention.
#
# CAVEAT (open question, ai/todo.md #112, 2026-08-29): grabs made via
# Prowlarr's own POST /api/v1/search (the escape-hatch pattern — as opposed
# to Sonarr/Radarr's POST /api/v3/release) have NOT been showing up in the
# Sonarr/Radarr queue at all in practice, torrent or NZB, despite this
# header's original claim that they register a queue entry "same as any
# other". Root cause not yet investigated. Until it is, treat every
# escape-hatch grab (via Prowlarr's /api/v1/search, not Sonarr/Radarr's own
# /api/v3/release) as needing --scan-folder, not the default queue walk.
#
# Folder-scanning (--scan-folder) was written as a narrow fallback for a file
# dropped into the download folder completely outside any *arr-initiated
# grab, but per the caveat above it is currently the ONLY reliable path for
# every Prowlarr-escape-hatch grab too — that's the common case now, not the
# rare one. It has no downloadId to correlate against, so it can only report
# "needs manual attention" for anything that doesn't cleanly auto-match — see
# the "Known escape-hatch import gotchas" section below for the specific
# per-file fixes usually needed. It is also known incomplete: Sonarr's
# `manualimport?folder=` does not reliably recurse into every download
# subfolder (confirmed live 2026-08-29 — returned 104 items for a full
# completed-dir scan and silently missed an entire subfolder that
# `manualimport?downloadId=` returned in full).
#
# Known escape-hatch import gotchas (all confirmed live 2026-08-29, folding
# in lessons from that session so the next run doesn't rediscover them):
#   - Folder path is `sabnzbd/completed` (plural) — `sabnzbd/complete` (singular,
#     an old doc typo) returns an empty scan with no error, not a failure.
#   - NEVER pass `&seriesId=<id>` to `manualimport?folder=` — it makes Sonarr
#     fuzzy-match against the ENTIRE existing library folder instead of just
#     the scanned download folder (confirmed: 36 real files became an 85-item
#     result mixing in already-owned episodes). Scan without the hint, then
#     assign seriesId explicitly per file in the payload you build.
#   - `indexerFlags` is REQUIRED in the ManualImport payload (this script now
#     includes it — see below). Omitting it does not error; the command
#     returns `status: "completed"` with an empty `message` and silently
#     imports zero files. The only trustworthy success signal is `message`
#     saying "Manually imported N files" with N > 0 — this script checks
#     that now, not just `status`.
#   - A release using absolute/continuous numbering across seasons (e.g.
#     Robotech's E61-E85 spanning what Sonarr tracks as Season 3) fails
#     Sonarr's own `S01E##`-style parse ("Invalid season or episode") even
#     though the number in the filename is real — map it yourself via each
#     target episode's `absoluteEpisodeNumber` (`GET /api/v3/episode?seriesId=`)
#     instead of trusting the scan's own episode match.
#   - Radarr and Sonarr do NOT share a language-id table — Sonarr's Japanese
#     is id 8, but Radarr's id 6 is Danish (Radarr's Japanese is also 8, but
#     don't assume any id carries across apps). Always fetch
#     `GET /api/v3/language` from the SAME app you're importing into and use
#     its own id, per [[../../ai/PATTERNS.md]]'s "build payload FROM the scan
#     result" rule — don't hand-carry an id you saw work in the other app.
#
# This is the canonical way to import stuck/manual downloads — run this
# BEFORE reaching for ad-hoc curl against the Sonarr/Radarr API. Every run
# is logged to logs/ so failures can be diagnosed after the fact instead of
# re-running the same curl commands to see what happened.
#
# Usage:
#   ./import_downloads.sh [--dry-run]
#   ./import_downloads.sh --scan-folder <dir> [--dry-run]
#   ./import_downloads.sh --plan
#   ./import_downloads.sh --apply <plan-file>
#
#   --dry-run            Show what would be imported without actually importing
#   --scan-folder <dir>  Fallback-only folder scan (see above) instead of the
#                        default queue walk. Only useful for a file that
#                        reached the download folder outside any *arr grab.
#   --plan              Generates a review file for every importBlocked queue
#                        item (not just ones the default scan can auto-fix) —
#                        pulls manualimport data per stuck downloadId, and
#                        writes a plan file to stuck_plans/<run_id>.json
#                        — files Sonarr/Radarr auto-matched are pre-filled,
#                        anything with a null series/movie is left with empty
#                        seriesId/episodeIds (or movieId) for a human to fill
#                        in by hand. Does not submit anything.
#   --apply <plan-file> Re-reads a --plan file and submits only the entries
#                        that are fully mapped. Refuses to submit any part of
#                        a download that still has an unmapped file — series/
#                        episode matching for odd-naming releases is NOT safe
#                        to auto-guess. (A first attempt at doing this by hand
#                        mapped a whole season from a regex that matched the
#                        parent folder name instead of the filename, silently
#                        assigning every episode to episode 1 — this refusal
#                        check exists because of that exact mistake.) Polls
#                        each submitted command and re-checks the queue
#                        afterward to report cleared vs. still-stuck.
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
MODE="queue"
PLAN_FILE=""
SCAN_FOLDER=""
case "${1:-}" in
  --plan) MODE="plan" ;;
  --apply)
    MODE="apply"
    PLAN_FILE="${2:?Usage: import_downloads.sh --apply <plan-file>}"
    ;;
  --scan-folder)
    MODE="folder"
    SCAN_FOLDER="${2:?Usage: import_downloads.sh --scan-folder <dir> [--dry-run]}"
    [[ "${3:-}" == "--dry-run" ]] && DRY_RUN=true
    ;;
  *)
    for arg in "$@"; do
      case "$arg" in
        --dry-run) DRY_RUN=true ;;
      esac
    done
    ;;
esac

SONARR_URL="http://192.168.20.22:8989/sonarr"
RADARR_URL="http://192.168.20.22:7878/radarr"

# ---------------------------------------------------------------------------
# Logging — every run is captured, not just echoed to a terminal that closes
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
PLAN_DIR="$SCRIPT_DIR/stuck_plans"
mkdir -p "$LOG_DIR" "$PLAN_DIR"
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
# Fallback-only: folder-scan and import for one app (--scan-folder). See
# usage header for why this is not the default — kept only for a file that
# reached the download folder outside any *arr-initiated grab.
# ---------------------------------------------------------------------------
scan_folder_and_import() {
  local app="$1"       # sonarr or radarr
  local scan_dir="$2"

  local items
  if [[ "$app" == "sonarr" ]]; then
    items=$(sonarr_api "manualimport?folder=${scan_dir}&filterExistingFiles=false" 2>/dev/null)
  else
    items=$(radarr_api "manualimport?folder=${scan_dir}&filterExistingFiles=false" 2>/dev/null)
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
      # indexerFlags is REQUIRED — omitting it does not error, but the command
      # silently imports zero files (confirmed live 2026-08-29: response said
      # "status": "completed" with no exception, yet no episode/movie file
      # count changed). Pull it from the scan result like every other field
      # (`// 0` since a manual/out-of-band file has no indexer flags to carry).
      if [[ "$app" == "sonarr" ]]; then
        files=$(echo "$importable" | jq '[.[] | {
          path,
          seriesId: .series.id,
          episodeIds: [.episodes[].id],
          downloadId,
          quality,
          languages,
          releaseGroup,
          indexerFlags: (.indexerFlags // 0),
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
          indexerFlags: (.indexerFlags // 0),
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
      local status message imported_n
      status=$(echo "$final_status" | jq -r '.status // "unknown"')
      message=$(echo "$final_status" | jq -r '.message // ""')
      # status:"completed" is NOT proof the import happened — confirmed live
      # 2026-08-29: a payload missing indexerFlags returned status:"completed"
      # with no exception, but the message was empty and zero files actually
      # landed. The only reliable success signal is the message field saying
      # "Manually imported N files" with N > 0 — check that, not just status.
      imported_n=$(echo "$message" | grep -oE '^Manually imported [0-9]+' | grep -oE '[0-9]+' || echo "")
      if [[ "$status" == "completed" && -n "$imported_n" && "$imported_n" -gt 0 ]]; then
        log_ok "$app: ManualImport command $command_id imported $imported_n file(s) from $scan_dir"
      else
        log_skip "$app: ManualImport command $command_id did NOT confirm a real import (status='$status', message='$message') — verify hasFile on the target episode(s)/movie manually before trusting this ran"
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
# Default mode: walk the queue (not the filesystem) and import one download
# ---------------------------------------------------------------------------
import_one_download() {
  local app="$1" download_id="$2" title="$3"

  local items
  if [[ "$app" == "sonarr" ]]; then
    items=$(sonarr_api "manualimport?downloadId=${download_id}&filterExistingFiles=false" 2>/dev/null)
  else
    items=$(radarr_api "manualimport?downloadId=${download_id}&filterExistingFiles=false" 2>/dev/null)
  fi

  if ! echo "$items" | jq empty 2>/dev/null; then
    log_warn "$app: invalid manualimport response for downloadId=$download_id — skipping"
    return
  fi

  local importable needs_attention importable_count
  importable=$(echo "$items" | jq '[.[] | select((.series != null or .movie != null) and (.rejections | length == 0))]')
  needs_attention=$(echo "$items" | jq '[.[] | select((.series == null and .movie == null) or (.rejections | length > 0))]')
  importable_count=$(echo "$importable" | jq 'length')

  echo ""
  echo "  \"$title\" — downloadId=$download_id"

  if [[ "$importable_count" -gt 0 ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "    [DRY RUN] Would import $importable_count file(s):"
    else
      echo "    Importing $importable_count file(s):"
    fi
    echo "$importable" | jq -r '.[] | "      \(.series.title // .movie.title) — \(.path | split("/") | last)"'

    if [[ "$DRY_RUN" == false ]]; then
      local files command_payload result command_id final_status status
      if [[ "$app" == "sonarr" ]]; then
        files=$(echo "$importable" | jq '[.[] | {path, seriesId: .series.id, episodeIds: [.episodes[].id], downloadId, quality, languages, releaseGroup, importMode: "copy"}]')
      else
        files=$(echo "$importable" | jq '[.[] | {path, movieId: .movie.id, downloadId, quality, languages, releaseGroup, importMode: "copy"}]')
      fi
      command_payload=$(jq -n --argjson files "$files" '{name: "ManualImport", files: $files, importMode: "copy"}')

      if [[ "$app" == "sonarr" ]]; then
        result=$(sonarr_api "command" -X POST -H "Content-Type: application/json" -d "$command_payload" 2>/dev/null)
      else
        result=$(radarr_api "command" -X POST -H "Content-Type: application/json" -d "$command_payload" 2>/dev/null)
      fi

      if ! echo "$result" | jq empty 2>/dev/null; then
        log_warn "$app: invalid response from command POST for \"$title\" — files may not have been imported"
        return
      fi

      command_id=$(echo "$result" | jq -r '.id // empty')
      if [[ -z "$command_id" ]]; then
        log_skip "$app: command POST for \"$title\" did not return a command id — $(echo "$result" | jq -c '.')"
        return
      fi

      final_status=$(wait_for_command "$app" "$command_id")
      status=$(echo "$final_status" | jq -r '.status // "unknown"')
      if [[ "$status" == "completed" ]]; then
        log_ok "$app: ManualImport command $command_id completed for $importable_count file(s) — \"$title\""
      else
        log_skip "$app: ManualImport command $command_id ended with status '$status' — \"$title\" — $(echo "$final_status" | jq -c '{status, exception, trigger}')"
      fi
    fi
  fi

  local attention_count
  attention_count=$(echo "$needs_attention" | jq 'length')
  if [[ "$attention_count" -gt 0 ]]; then
    echo "    Needs manual attention ($attention_count file(s) — use --plan/--apply or the Sonarr/Radarr UI):"
    echo "$needs_attention" | jq -r '.[] | "      [\(.rejections[0].reason // "Unknown")] \(.path | split("/") | last)"'
  fi
}

scan_queue_and_import() {
  local app="$1"
  local unknown_param queue
  if [[ "$app" == "sonarr" ]]; then
    unknown_param="includeUnknownSeriesItems=true"
    queue=$(sonarr_api "queue?pageSize=200&${unknown_param}")
  else
    unknown_param="includeUnknownMovieItems=true"
    queue=$(radarr_api "queue?pageSize=200&${unknown_param}")
  fi

  # importPending: fully downloaded, waiting on the normal auto-import that
  # hasn't run yet. importBlocked: auto-import already failed/gave up (the
  # stuck-item case). Anything still downloading has no files to import yet.
  local pending pending_count
  pending=$(echo "$queue" | jq '[.records[] | select(.downloadId != null and (.trackedDownloadState=="importPending" or .trackedDownloadState=="importBlocked"))]')
  pending_count=$(echo "$pending" | jq 'length')
  [[ "$pending_count" -eq 0 ]] && return

  log_section "$app: $pending_count queue item(s) awaiting import"

  local i download_id title
  for i in $(seq 0 $((pending_count - 1))); do
    download_id=$(echo "$pending" | jq -r ".[$i].downloadId")
    title=$(echo "$pending" | jq -r ".[$i].title")
    import_one_download "$app" "$download_id" "$title"
  done
}

# ---------------------------------------------------------------------------
# --plan / --apply — queue-based fix for stuck importBlocked items whose
# files already exist. See usage header for why this is a separate two-step
# flow instead of an auto-fixer: series/episode matching for odd-naming
# releases is not safe to guess blindly.
# ---------------------------------------------------------------------------
run_plan() {
  local plan_path="$PLAN_DIR/${RUN_ID}.json"
  local downloads="[]"

  for app in sonarr radarr; do
    local unknown_param queue
    if [[ "$app" == "sonarr" ]]; then
      unknown_param="includeUnknownSeriesItems=true"
      queue=$(sonarr_api "queue?pageSize=200&${unknown_param}")
    else
      unknown_param="includeUnknownMovieItems=true"
      queue=$(radarr_api "queue?pageSize=200&${unknown_param}")
    fi

    local stuck stuck_count
    stuck=$(echo "$queue" | jq '[.records[] | select(.trackedDownloadState=="importBlocked")]')
    stuck_count=$(echo "$stuck" | jq 'length')
    [[ "$stuck_count" -eq 0 ]] && continue

    log_section "$app: $stuck_count importBlocked queue item(s)"

    local i
    for i in $(seq 0 $((stuck_count - 1))); do
      local record download_id title mi
      record=$(echo "$stuck" | jq ".[$i]")
      download_id=$(echo "$record" | jq -r '.downloadId')
      title=$(echo "$record" | jq -r '.title')

      if [[ "$app" == "sonarr" ]]; then
        mi=$(sonarr_api "manualimport?downloadId=${download_id}&filterExistingFiles=false")
      else
        mi=$(radarr_api "manualimport?downloadId=${download_id}&filterExistingFiles=false")
      fi

      # Trust Sonarr/Radarr's own automatic title match when it succeeded.
      # Anything it couldn't match (series/movie null, or a rejection) is
      # written with null seriesId/episodeIds/movieId for a human to fill in.
      local auto_matched needs_manual auto_count manual_count
      if [[ "$app" == "sonarr" ]]; then
        auto_matched=$(echo "$mi" | jq '[.[] | select(.series != null and (.rejections|length==0)) | {path, seriesId: .series.id, episodeIds: [.episodes[].id], downloadId, quality, languages, releaseGroup}]')
        needs_manual=$(echo "$mi" | jq '[.[] | select(.series == null or (.rejections|length>0)) | {path, seriesId: null, episodeIds: null, downloadId, quality, languages, releaseGroup, rejections}]')
      else
        auto_matched=$(echo "$mi" | jq '[.[] | select(.movie != null and (.rejections|length==0)) | {path, movieId: .movie.id, downloadId, quality, languages, releaseGroup}]')
        needs_manual=$(echo "$mi" | jq '[.[] | select(.movie == null or (.rejections|length>0)) | {path, movieId: null, downloadId, quality, languages, releaseGroup, rejections}]')
      fi
      auto_count=$(echo "$auto_matched" | jq 'length')
      manual_count=$(echo "$needs_manual" | jq 'length')

      echo "  \"$title\" — downloadId=$download_id"
      echo "    auto-matched: $auto_count file(s), needs manual mapping: $manual_count file(s)"

      downloads=$(jq -n --argjson downloads "$downloads" --arg app "$app" --arg title "$title" \
        --arg downloadId "$download_id" --argjson auto "$auto_matched" --argjson manual "$needs_manual" \
        '$downloads + [{app: $app, title: $title, downloadId: $downloadId, files: ($auto + $manual)}]')
    done
  done

  echo "$downloads" > "$plan_path"
  echo ""
  echo "Plan written to $plan_path"

  local manual_total
  manual_total=$(echo "$downloads" | jq '[.[].files[] | select(.seriesId == null and .movieId == null)] | length')
  if [[ "$manual_total" -gt 0 ]]; then
    echo ""
    echo "NEEDS MANUAL MAPPING ($manual_total file(s)) — edit $plan_path before --apply:"
    echo "$downloads" | jq -r '.[] | .title as $t | .files[] | select(.seriesId == null and .movieId == null) | "  [\($t)] \(.path | split("/") | last)"'
    echo ""
    echo "Fill in seriesId + episodeIds (Sonarr) or movieId (Radarr) for each entry above, then run:"
    echo "  $0 --apply $plan_path"
  else
    echo ""
    echo "Everything auto-matched — review $plan_path, then run:"
    echo "  $0 --apply $plan_path"
  fi
}

run_apply() {
  [[ -f "$PLAN_FILE" ]] || { echo "ERROR: plan file not found: $PLAN_FILE" >&2; exit 1; }
  local plan download_count
  plan=$(cat "$PLAN_FILE")
  download_count=$(echo "$plan" | jq 'length')

  local d
  for d in $(seq 0 $((download_count - 1))); do
    local entry app title download_id files mapped unmapped_count
    entry=$(echo "$plan" | jq ".[$d]")
    app=$(echo "$entry" | jq -r '.app')
    title=$(echo "$entry" | jq -r '.title')
    download_id=$(echo "$entry" | jq -r '.downloadId')
    files=$(echo "$entry" | jq '.files')

    # Submit only the files that are fully mapped — never guess the rest.
    # Per-file, not per-download: a batch release can be partly auto-matched
    # (e.g. RWBY's 118 numbered episodes) and partly not (its 5 unmonitored
    # specials) — the good 118 shouldn't wait on the 5 needing a human.
    if [[ "$app" == "sonarr" ]]; then
      mapped=$(echo "$files" | jq '[.[] | select(.seriesId != null and .episodeIds != null)]')
      unmapped_count=$(echo "$files" | jq '[.[] | select(.seriesId == null or .episodeIds == null)] | length')
    else
      mapped=$(echo "$files" | jq '[.[] | select(.movieId != null)]')
      unmapped_count=$(echo "$files" | jq '[.[] | select(.movieId == null)] | length')
    fi
    files="$mapped"

    if [[ "$unmapped_count" -gt 0 ]]; then
      log_warn "[$app] \"$title\" — $unmapped_count file(s) still unmapped, skipping those (edit the plan file to include them)"
    fi

    local file_count command_payload result command_id final_status status
    file_count=$(echo "$files" | jq 'length')
    if [[ "$file_count" -eq 0 ]]; then
      log_skip "[$app] \"$title\" — nothing mapped, skipping this download entirely"
      continue
    fi
    echo "[$app] \"$title\" — submitting $file_count mapped file(s), downloadId=$download_id"

    command_payload=$(echo "$files" | jq '{name: "ManualImport", files: [.[] | . + {importMode: "copy"}], importMode: "copy"}')
    if [[ "$app" == "sonarr" ]]; then
      result=$(sonarr_api "command" -X POST -H "Content-Type: application/json" -d "$command_payload")
    else
      result=$(radarr_api "command" -X POST -H "Content-Type: application/json" -d "$command_payload")
    fi

    command_id=$(echo "$result" | jq -r '.id // empty')
    if [[ -z "$command_id" ]]; then
      log_skip "[$app] \"$title\" — command POST did not return a command id: $(echo "$result" | jq -c '.')"
      continue
    fi

    final_status=$(wait_for_command "$app" "$command_id")
    status=$(echo "$final_status" | jq -r '.status // "unknown"')
    if [[ "$status" != "completed" ]]; then
      log_skip "[$app] \"$title\" — command $command_id ended with status '$status': $(echo "$final_status" | jq -c '{exception, trigger}')"
      continue
    fi

    local still_stuck
    if [[ "$app" == "sonarr" ]]; then
      still_stuck=$(sonarr_api "queue?pageSize=200&includeUnknownSeriesItems=true" | jq --arg dl "$download_id" '[.records[] | select(.downloadId == $dl and .trackedDownloadState=="importBlocked")] | length')
    else
      still_stuck=$(radarr_api "queue?pageSize=200&includeUnknownMovieItems=true" | jq --arg dl "$download_id" '[.records[] | select(.downloadId == $dl and .trackedDownloadState=="importBlocked")] | length')
    fi

    if [[ "$still_stuck" -eq 0 ]]; then
      log_ok "[$app] \"$title\" — queue item cleared"
    elif [[ "$unmapped_count" -gt 0 ]]; then
      log_warn "[$app] \"$title\" — command completed but queue item still importBlocked, expected since $unmapped_count file(s) remain unmapped"
    else
      log_warn "[$app] \"$title\" — command completed but queue item is still importBlocked, needs investigation"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "$MODE" in
  plan)
    run_plan
    ;;
  apply)
    run_apply
    ;;
  folder)
    [[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}--- DRY RUN MODE ---${NC}"
    log_section "Radarr ← $SCAN_FOLDER"
    scan_folder_and_import "radarr" "$SCAN_FOLDER"
    log_section "Sonarr ← $SCAN_FOLDER"
    scan_folder_and_import "sonarr" "$SCAN_FOLDER"
    ;;
  *)
    [[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}--- DRY RUN MODE ---${NC}"
    scan_queue_and_import "radarr"
    scan_queue_and_import "sonarr"
    ;;
esac

echo ""
echo "Done. Log saved to $LOG_FILE"
