#!/usr/bin/env bash
set -e

# Homelab Restore Script (Fedora 43 + Podman, folder-level backup)
echo "Homelab Restore Script (Fedora 43 + Podman)"
echo "============================================="
echo ""
echo "This script will help restore your homelab configuration from a folder-level backup using Podman."
echo ""

# Prerequisite check
REQUIRED_CMDS=(podman podman-compose rsync)
MISSING=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done
if (( ${#MISSING[@]} > 0 )); then
    echo "[ERROR] Missing required tools: ${MISSING[*]}"
    echo "Install with: sudo dnf install ${MISSING[*]} -y"
    exit 1
fi

echo "All prerequisites found."
echo "  - podman: $(podman --version)"
  podman-compose --version || true
  rsync --version | head -1

echo ""
echo "Before running, ensure:"
echo "  1. Your data drive is mounted and writable"
echo "  2. You've reviewed MIGRATION_NOTES.md"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Ask for backup folder (current dir is assumed to be the backup root)
BACKUP_DIR="$(pwd)"
echo "Backup folder: $BACKUP_DIR"

# Ask for target restore directory
TARGET_DIR="${1:-$HOME/repos/homelab}"
echo "Target directory: $TARGET_DIR"
read -p "Is this correct? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run again with: ./restore.sh /your/target/path"
    exit 0
fi

mkdir -p "$TARGET_DIR"
echo "Copying repository..."
rsync -av "$BACKUP_DIR/repo/" "$TARGET_DIR/"

echo ""
echo "✓ Repository restored to: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Review and edit: $TARGET_DIR/media/.env"
echo "  2. Update paths for Linux (change /mnt/d/ to your mount point)"
echo "  3. Copy service configs from $BACKUP_DIR/configs/ directory"
echo "  4. Run: cd $TARGET_DIR/media && podman-compose up -d"
echo ""
echo "See MIGRATION_NOTES.md for detailed instructions."

# Podman Compose: Start services (optional prompt)
read -p "Start media stack with podman-compose now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$TARGET_DIR/media"
    podman-compose up -d
    echo "Media stack started with podman-compose."
fi
