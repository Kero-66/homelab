#!/usr/bin/env bash
# Infisical Postgres backup script
# Backs up the database and ENCRYPTION_KEY to BACKUP_DIR
# Run via cron: 0 2 * * * /mnt/library/repos/homelab/security/infisical/backup.sh
#
# Restore:
#   docker compose -f /mnt/library/repos/homelab/security/infisical/compose.yaml \
#     exec -T infisical-db psql -U infisical infisical < /path/to/backup.sql

set -euo pipefail

COMPOSE_DIR="/mnt/library/repos/homelab/security/infisical"
BACKUP_DIR="/mnt/library/backups/infisical"
RETAIN_DAYS=14
DATE=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$BACKUP_DIR/infisical_${DATE}.sql"
KEY_FILE="$BACKUP_DIR/encryption_key_${DATE}.txt"

mkdir -p "$BACKUP_DIR"

# Dump Postgres
docker compose -f "$COMPOSE_DIR/compose.yaml" exec -T infisical-db \
  pg_dump -U infisical infisical > "$DUMP_FILE"

# Back up ENCRYPTION_KEY (without printing it)
grep '^ENCRYPTION_KEY=' "$COMPOSE_DIR/.env" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Remove dumps older than RETAIN_DAYS
find "$BACKUP_DIR" -name 'infisical_*.sql' -mtime +${RETAIN_DAYS} -delete
find "$BACKUP_DIR" -name 'encryption_key_*.txt' -mtime +${RETAIN_DAYS} -delete

echo "Backup complete: $DUMP_FILE"
