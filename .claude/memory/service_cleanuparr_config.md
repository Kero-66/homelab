---
name: service_cleanuparr_config
description: Cleanuparr's real config lives in cleanuparr.db not config.yml; its REST API works with a fresh X-Api-Key (job trigger + event log endpoints)
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

**Correction (2026-08-29): the previous claim above about JWT-only auth was wrong.** Cleanuparr's
own REST API *does* accept a simple `X-Api-Key: <key>` header (or `?apikey=<key>` query param) —
confirmed live against `GET /api/Jobs` (200 OK once given the *current* key). The `CLEANUPARR_API_KEY`
secret in Infisical `/media` had gone stale (401 with the old value) — the real key must be copied
fresh from the Cleanuparr UI (Settings → General) whenever this stops working, same staleness
pattern as `config.yml`. **Prefer the API over SQLite reads now that this works** — SQLite is
read-only and fine for one-off config diffs, but don't use it to poll status or trigger anything.

**Job control via API** (`http://192.168.20.22:11011`, direct port, no Caddy prefix):
- `GET /api/Jobs` — list all jobs with schedule/next/previous run time (`previousRunTime` only
  reflects scheduled cron runs, not manual triggers — don't use it to confirm a manual trigger ran)
- `POST /api/Jobs/{jobType}/trigger` (e.g. `QueueCleaner`, `DownloadCleaner`) — run a job immediately
  instead of waiting for its cron (`0 0 0/3 ? * * *`, every 3h by default). Empty body. Returns
  `{"message": "Job '<name>' triggered successfully for one-time execution"}` on 200.
- `GET /api/Events?pageSize=<n>` — the real way to confirm what a job actually did. Each item has
  `eventType` (`DownloadCleaned`, `CategoryChanged`, etc.), `cleanReason`, `itemTitle`, `timestamp`.
  This is what actually proved a manual `DownloadCleaner` trigger worked (8 downloads cleaned with
  `MaxSeedTimeReached` at the exact trigger timestamp) — far more reliable than tailing container
  logs. A few other guessed endpoint paths (`/api/EventLog`, `/api/History`, `/api/Logs`) all
  silently return 200 with the Angular SPA's `index.html` (client-side routing fallback), not JSON —
  don't trust a 200 status alone as proof a route exists; check the response body looks like real
  JSON, not an HTML page starting with `<!doctype html>`.
- No login/session endpoint exists in the API controllers — web UI auth is separate (cookie-based)
  and irrelevant to REST calls.
