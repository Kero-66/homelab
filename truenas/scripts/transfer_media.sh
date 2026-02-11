#!/usr/bin/env bash
# truenas/scripts/transfer_media.sh
#
# Transfer media from WD external drive to TrueNAS via SMB mount.
# Uses rsync for resumability and progress tracking.
#
# Prerequisites:
#   - TrueNAS SMB share mounted at /mnt/truenas_media
#   - Source media at /mnt/wd_media/homelab-data
#
# Usage:
#   bash truenas/scripts/transfer_media.sh           # full transfer
#   bash truenas/scripts/transfer_media.sh --dry-run  # preview only
#
# Log: ~/truenas_media_transfer.log

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

SRC="/mnt/wd_media/homelab-data"
DST="/mnt/truenas_media"
LOG="$HOME/truenas_media_transfer.log"
DRY_RUN=""

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    log_warn "DRY RUN — no files will be transferred"
fi

# --- Validate mounts ---
if ! mountpoint -q "$DST" 2>/dev/null; then
    log_error "$DST is not mounted. Mount the TrueNAS SMB share first:"
    echo "  See: truenas/stacks/README.md for mount instructions"
    exit 1
fi

if [[ ! -d "$SRC/movies" ]]; then
    log_error "Source not found: $SRC/movies"
    exit 1
fi

# --- Transfer function ---
sync_dir() {
    local name="$1"
    local src_path="$SRC/$name/"
    local dst_path="$DST/$name/"

    if [[ ! -d "$src_path" ]]; then
        log_warn "Skipping $name (not found at $src_path)"
        return 0
    fi

    local count
    count=$(find "$src_path" -type f 2>/dev/null | wc -l)
    local size
    size=$(du -sh "$src_path" 2>/dev/null | cut -f1)

    log_info "Syncing $name: $count files, $size"

    rsync -avh --progress --partial \
        --no-perms --no-owner --no-group \
        $DRY_RUN \
        "$src_path" "$dst_path" 2>&1 | tee -a "$LOG"

    log_ok "$name sync complete"
}

# --- Start transfer ---
echo ""
log_info "=== Media Transfer: WD Drive → TrueNAS ==="
log_info "Source: $SRC"
log_info "Dest:   $DST"
log_info "Log:    $LOG"
echo ""

echo "--- Transfer started: $(date) ---" >> "$LOG"

sync_dir "movies"
sync_dir "shows"
sync_dir "music"

echo ""
echo "--- Transfer completed: $(date) ---" >> "$LOG"
log_ok "All transfers complete. Log: $LOG"
