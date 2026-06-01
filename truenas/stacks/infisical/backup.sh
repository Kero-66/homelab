#!/usr/bin/env bash
# Infisical backup — runs on TrueNAS, pushes dumps to workstation HDD
#
# Schedule via cron on TrueNAS (run as kero66):
#   0 3 * * * bash /mnt/Fast/docker/infisical/backup.sh >> /mnt/Fast/docker/infisical/backup.log 2>&1
#
# Restore:
#   docker exec -i infisical-db psql -U infisical infisical < /path/to/backup.sql

set -euo pipefail

LOCAL_BACKUP_DIR="/mnt/Fast/docker/infisical/backups"
REMOTE_HOST="192.168.20.66"
REMOTE_USER="kero66"
REMOTE_DIR="/mnt/library/backups/infisical"
RETAIN_DAYS=14
DATE=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$LOCAL_BACKUP_DIR/infisical_${DATE}.sql"

mkdir -p "$LOCAL_BACKUP_DIR"

# Dump postgres
sudo docker exec infisical-db pg_dump -U infisical infisical > "$DUMP_FILE"
echo "[$(date)] Dump complete: $DUMP_FILE ($(wc -c < "$DUMP_FILE") bytes)"

# Push to workstation if reachable
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_DIR" 2>/dev/null; then
    scp -q "$DUMP_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
    echo "[$(date)] Pushed to $REMOTE_HOST:$REMOTE_DIR"
else
    echo "[$(date)] WARNING: workstation unreachable, backup kept locally only"
fi

# Prune local backups older than RETAIN_DAYS
find "$LOCAL_BACKUP_DIR" -name 'infisical_*.sql' -mtime "+${RETAIN_DAYS}" -delete

echo "[$(date)] Backup done"
