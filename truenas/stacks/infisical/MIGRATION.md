# Infisical Migration: Workstation → TrueNAS

**From**: 192.168.20.66:8081  
**To**: 192.168.20.22:8081  
**Run all commands from the workstation.**

---

## Prerequisites

SSH access to TrueNAS must be working from the workstation:
```bash
ssh kero66@192.168.20.22 "echo ok"
```

---

## Step 1 — Backup workstation Infisical

```bash
# Dump the database
docker exec infisical-db pg_dump -U infisical infisical > ~/infisical_migration.sql

# Copy the .env (contains ENCRYPTION_KEY — critical)
cp /path/to/homelab/security/infisical/.env ~/infisical_migration.env

# Verify dump is non-empty
wc -l ~/infisical_migration.sql
```

---

## Step 2 — Create directories on TrueNAS

```bash
ssh kero66@192.168.20.22 "
  sudo mkdir -p /mnt/Fast/docker/infisical
  sudo mkdir -p /mnt/Fast/databases/infisical/postgres
  sudo mkdir -p /mnt/Fast/databases/infisical/redis
  sudo chown -R 1000:1000 /mnt/Fast/docker/infisical
  sudo chown -R 1000:1000 /mnt/Fast/databases/infisical
"
```

---

## Step 3 — Copy .env to TrueNAS

```bash
# The .env file from the workstation contains all required vars:
# ENCRYPTION_KEY, POSTGRES_USER, POSTGRES_PASSWORD, JWT_* keys, SMTP config, etc.
scp ~/infisical_migration.env kero66@192.168.20.22:/mnt/Fast/docker/infisical/.env
```

---

## Step 4 — Deploy Infisical on TrueNAS (DB only first)

```bash
# Pull the repo on your workstation is already up to date (truenas/stacks/infisical/compose.yaml)
# SCP compose file to TrueNAS staging location
scp truenas/stacks/infisical/compose.yaml kero66@192.168.20.22:/tmp/infisical-compose.yaml

ssh kero66@192.168.20.22 "
  # Start DB and Redis only (not infisical app yet)
  sudo docker compose -f /tmp/infisical-compose.yaml up -d infisical-db infisical-redis

  # Wait for DB healthy
  sleep 15
  sudo docker exec infisical-db pg_isready -U infisical
"
```

---

## Step 5 — Restore database

```bash
# Copy dump to TrueNAS
scp ~/infisical_migration.sql kero66@192.168.20.22:/tmp/infisical_migration.sql

ssh kero66@192.168.20.22 "
  # Restore
  sudo docker exec -i infisical-db psql -U infisical infisical < /tmp/infisical_migration.sql

  # Verify row counts
  sudo docker exec infisical-db psql -U infisical infisical -c '\dt' | head -20

  # Clean up
  rm /tmp/infisical_migration.sql
"
```

---

## Step 6 — Start Infisical app

```bash
ssh kero66@192.168.20.22 "
  sudo docker compose -f /tmp/infisical-compose.yaml up -d infisical
  sleep 30
  sudo docker logs infisical --tail 20
"

# Verify API responds
curl -sf http://192.168.20.22:8081/api/status | python3 -m json.tool
```

---

## Step 7 — Verify secrets are accessible

```bash
# From workstation — test infisical CLI against new instance
infisical secrets get JELLYFIN_API_KEY --env dev --path /TrueNAS \
  --projectId "5086c25c-310d-4cfb-9e2c-24d1fa92c152" \
  --domain http://192.168.20.22:8081 --plain 2>/dev/null
# Should return the same value as the old instance
```

---

## Step 8 — Deploy as TrueNAS native app

Deploy via midclt so TrueNAS manages the lifecycle (stop/start with the system):

```bash
ssh kero66@192.168.20.22 "sudo midclt call -j app.create '{
  \"app_name\": \"infisical\",
  \"custom_compose_config_string\": \"$(cat /tmp/infisical-compose.yaml | python3 -c 'import sys; import json; print(json.dumps(sys.stdin.read()))')\"
}'"
```

Or deploy via Dockhand UI pointing at `truenas/stacks/infisical/compose.yaml`.

---

## Step 9 — Update infisical-agent (already correct)

The agent-config.yaml uses `http://192.168.20.22:8081` after the address update in this session. Restart infisical-agent to pick up the new address:

```bash
ssh kero66@192.168.20.22 "sudo midclt call -j app.stop '\"infisical-agent\"' && sudo midclt call -j app.start '\"infisical-agent\"'"
```

---

## Step 10 — Stop workstation Infisical

Once everything is verified working:

```bash
# On workstation
cd /path/to/homelab/security/infisical
docker compose stop

# Optional: disable autostart
docker compose down
```

---

## Rollback

If anything fails before Step 10, the workstation instance is untouched. Just point clients back at `http://192.168.20.66:8081`.

---

## Post-migration: update PATTERNS.md

All local commands currently use `--domain http://192.168.20.66:8081`. Update to `192.168.20.22` after migration is verified:

```bash
sed -i 's|http://192.168.20.66:8081|http://192.168.20.22:8081|g' ai/PATTERNS.md
# Also update the description line:
sed -i 's|self-hosted on workstation|self-hosted on TrueNAS|' ai/PATTERNS.md
```

Then commit:
```bash
git add ai/PATTERNS.md
git commit -m "chore(infisical): update domain to TrueNAS after migration"
```

---

## Post-migration: backup to PC

Set up a cron on TrueNAS to dump DB and push to workstation HDD. See `backup.sh` in this directory.

```bash
# On TrueNAS — add to kero66 crontab
crontab -e
# Add: 0 3 * * * bash /mnt/Fast/docker/infisical/backup.sh >> /mnt/Fast/docker/infisical/backup.log 2>&1
```
