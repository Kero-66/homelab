---
name: service_cleanuparr_config
description: Cleanuparr's real config lives in cleanuparr.db (SQLite), not config.yml — config.yml is stale/bootstrap-only
metadata:
  type: project
---

Cleanuparr's live, authoritative configuration is stored in `/mnt/Fast/docker/cleanuparr/cleanuparr.db` (SQLite), not in `/mnt/Fast/docker/cleanuparr/config.yml`. The YAML file is a stale bootstrap/sample — it does not reflect settings changed via the Cleanuparr web UI afterward.

**Confirmed discrepancy (2026-08-06)**: `config.yml` showed `general.dry_run: true`, but the live DB (`general_configs.dry_run = 0`) had it disabled — matching what the logs actually showed (real file deletions). Read from the DB, not the file, when diagnosing Cleanuparr behavior.

**How to inspect**: read-only query via SSH + sqlite3 (kero66 has access, no docker exec needed):
```bash
sudo sqlite3 -header -column /mnt/Fast/docker/cleanuparr/cleanuparr.db 'SELECT * FROM <table>;'
```
Key tables: `general_configs` (dry_run, log_level), `queue_cleaner_configs` (strike-based cleanup of stalled/failed-import downloads — includes a `failed_import_patterns` JSON list matched against Sonarr/Radarr import failure messages, e.g. `"Not an upgrade for existing episode file(s)"`), `download_cleaner_configs` (enable/cron only, actual rules live in per-client seeding-rule tables), `q_bit_seeding_rules` / `r_torrent_seeding_rules` / etc. (per-download-client seed time/ratio rules, keyed by category), `content_blocker_configs` (blocklist sync settings).

**Two independent cleanup mechanisms — don't conflate them**:
1. `queue_cleaner_configs` — strikes-based (`failed_import_max_strikes`), targets stuck Sonarr/Radarr queue items matching `failed_import_patterns` (stalled, failed imports, "not an upgrade", missing files, etc.) on a cron (was `0 0 0/3 ? * * *`, every 3h).
2. Per-client seeding rules (e.g. `q_bit_seeding_rules`) — reaps torrents by category based on `min_seed_time`/`max_seed_time`/`max_ratio`, regardless of Sonarr/Radarr import state.

Cleanuparr's own API requires web-login/JWT auth (`users.db`, `jwt-key.bin` present), not a simple `X-Api-Key` header like Sonarr/Radarr/Bazarr — the `api_key` field in `config.yml` is for calling *out* to other services, not for authenticating *into* Cleanuparr's own API. Use the SQLite route for read-only inspection instead of fighting its auth.
