# Verified Patterns & Commands

Copy-paste ready reference of commands that have been confirmed to work.
**No guessing. No trial-and-error. Only verified patterns.**

Last updated: 2026-03-29

---

## Table of Contents
1. [Infisical CLI](#infisical-cli)
2. [TrueNAS SSH](#truenas-ssh)
3. [TrueNAS REST API](#truenas-rest-api)
4. [TrueNAS App Management](#truenas-app-management)
5. [Docker on TrueNAS](#docker-on-truenas)
6. [Jellyfin API](#jellyfin-api)
7. [SABnzbd API](#sabnzbd-api)
8. [Sonarr API](#sonarr-api)
9. [qBittorrent API](#qbittorrent-api)
10. [Healthcheck Tool Availability](#healthcheck-tool-availability)
11. [Security Patterns](#security-patterns)
12. [File Staging (Working Files)](#file-staging-working-files)
13. [Bazarr (Subtitle Management)](#bazarr-subtitle-management)
14. [AnimeTosho (Subtitle Source for Anime)](#animetosho-subtitle-source-for-anime)
15. [Anti-Patterns (Never Do These)](#anti-patterns-never-do-these)

---

## Infisical CLI

### Environment and Paths
- **All secrets are in `dev` environment** (not `prod`, not default)
- **Infrastructure secrets**: path `/TrueNAS`
- **Jellyfin API key**: path `/` (root, not `/TrueNAS`)
- **Run from**: `/mnt/library/repos/homelab` (project root with `.infisical.json`)

### Get a single secret (plain value)
```bash
infisical secrets get <SECRET_NAME> --env dev --path /TrueNAS --plain
```

### Get Jellyfin API key (root path)
```bash
infisical secrets get JELLYFIN_API_KEY --env dev --path / --plain
```

### List all secrets in a path
```bash
infisical secrets --env dev --path /TrueNAS
```

### Export to .env format
```bash
infisical secrets export --env dev --path /TrueNAS --format=dotenv
```

### Use a secret inline (pipe to command)
```bash
TOKEN=$(infisical secrets get TRUENAS_API_TOKEN --env dev --path /TrueNAS --plain)
```

---

## TrueNAS SSH

### Preferred: ssh-agent (key lives in memory only, never on disk)
```bash
# Load key from Infisical into agent (memory only - no temp files)
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null

# Run SSH commands normally (agent provides the key automatically)
ssh kero66@192.168.20.22 "sudo docker ps"
ssh kero66@192.168.20.22 "sudo docker logs jellyfin --tail 50"

# Clean up agent when done
ssh-agent -k > /dev/null
```

### SCP with ssh-agent
```bash
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null
scp local_file.txt kero66@192.168.20.22:/mnt/Fast/docker/service/
ssh-agent -k > /dev/null
```

### Fallback: temp file (if ssh-agent fails)
**If you must use a temp file, use mktemp -d for a random path and always clean up.**
```bash
KEYDIR=$(mktemp -d) && chmod 700 "$KEYDIR"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null > "$KEYDIR/id" && chmod 600 "$KEYDIR/id"
ssh -i "$KEYDIR/id" kero66@192.168.20.22 "your-command"
rm -rf "$KEYDIR"
```

### Recover a TrueNAS user's SSH public key from private key
```bash
# If you need to restore a public key that was overwritten
ssh-keygen -y -f "$KEYDIR/id_ed25519"
# Output is the public key — use this to restore via API
```

---

## TrueNAS REST API

### Setup
```bash
# Always HTTPS — HTTP returns 308 redirect that DROPS the Authorization header
BASE="https://192.168.20.22"
TOKEN=$(infisical secrets get TRUENAS_API_TOKEN --env dev --path /TrueNAS --plain)
```

### Check response type before piping to jq
```bash
# Always check Content-Type first, or check the response manually
curl -sk -H "Authorization: Bearer $TOKEN" "$BASE/api/v2.0/system/info" | head -c 200
```

### System info
```bash
curl -sk -H "Authorization: Bearer $TOKEN" "$BASE/api/v2.0/system/info" | jq '.hostname, .version'
```

### List all Custom Apps
```bash
curl -sk -H "Authorization: Bearer $TOKEN" "$BASE/api/v2.0/app" | jq '[.[] | {name: .name, state: .state}]'
```

### Get app state and health
```bash
APP=jellyfin
curl -sk -H "Authorization: Bearer $TOKEN" "$BASE/api/v2.0/app/id/$APP" | jq '{state: .state, status: .status}'
```

### Get user by username
```bash
curl -sk -H "Authorization: Bearer $TOKEN" "$BASE/api/v2.0/user?username=kero66" | jq '.[0] | {id: .id, username: .username}'
```

### Update a user's SSH public key
```bash
USER_ID=72  # get from user query above
PUBKEY="ssh-ed25519 AAAA..."
curl -sk -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"sshpubkey\": \"$PUBKEY\"}" \
  "$BASE/api/v2.0/user/id/$USER_ID"
# NOTE: /id/ is required in the path — PUT /api/v2.0/user/72 returns 404
```

### Check async job status
```bash
JOB_ID=123
curl -sk -H "Authorization: Bearer $TOKEN" "$BASE/api/v2.0/core/get_jobs?id=$JOB_ID" | jq '.[0] | {state: .state, result: .result, error: .error}'
```

---

## TrueNAS App Management

### Get current compose config for an app
```bash
APP=jellyfin
TOKEN=$(infisical secrets get TRUENAS_API_TOKEN --env dev --path /TrueNAS --plain)
BASE="https://192.168.20.22"

curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "\"$APP\"" \
  "$BASE/api/v2.0/app/config" | jq '.custom_compose_config'
```

### Update app compose config (full workflow)
```python
#!/usr/bin/env python3
"""Update a TrueNAS Custom App's compose config via API."""
import subprocess, json, requests, urllib3
urllib3.disable_warnings()

BASE = "https://192.168.20.22"

def get_token():
    return subprocess.check_output(
        ["infisical", "secrets", "get", "TRUENAS_API_TOKEN",
         "--env", "dev", "--path", "/TrueNAS", "--plain"],
        text=True
    ).strip()

def get_app_config(session, app_name):
    r = session.post(f"{BASE}/api/v2.0/app/config", json=app_name)
    r.raise_for_status()
    return r.json()

def update_app(session, app_name, compose_config):
    r = session.put(
        f"{BASE}/api/v2.0/app/id/{app_name}",
        json={"custom_compose_config": compose_config}
    )
    r.raise_for_status()
    return r.json()  # returns {"job_id": <int>}

def wait_for_job(session, job_id, timeout=120):
    import time
    for _ in range(timeout):
        r = session.get(f"{BASE}/api/v2.0/core/get_jobs?id={job_id}")
        job = r.json()[0]
        if job["state"] in ("SUCCESS", "FAILED", "ABORTED"):
            return job
        time.sleep(1)
    raise TimeoutError(f"Job {job_id} did not complete in {timeout}s")

token = get_token()
session = requests.Session()
session.headers["Authorization"] = f"Bearer {token}"
session.verify = False

# Get current config
config = get_app_config(session, "jellyfin")
compose = config["custom_compose_config"]

# Modify compose dict here...
# compose["services"]["jellyfin"]["environment"].append("NEW_VAR=value")

# Push update
result = update_app(session, "jellyfin", compose)
job = wait_for_job(session, result["job_id"])
print(job["state"], job.get("error"))
```

### Create a new Custom App (midclt - NOT the REST API)
```bash
# REST API cannot create Custom Apps — use midclt via SSH
# Write payload locally, pipe to TrueNAS, call midclt from there
python3 -c "
import json
compose = open('/mnt/library/repos/homelab/truenas/stacks/APP_NAME/compose.yaml').read()
payload = json.dumps({
    'custom_app': True,
    'app_name': 'APP_NAME',
    'train': 'stable',
    'custom_compose_config_string': compose
})
print(payload)
" | ssh kero66@192.168.20.22 "cat > /tmp/app_payload.json && sudo midclt call -j app.create \"\$(cat /tmp/app_payload.json)\" 2>&1; rm /tmp/app_payload.json"
# Use ssh-agent to provide the key (see TrueNAS SSH section above)
```

### Update an existing app compose (midclt - safe pattern)
```bash
# SAFE: stop first to avoid port conflicts, then update, then start
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null

APP_NAME=commafeed
# 1. Stop first
ssh kero66@192.168.20.22 "sudo midclt call -j app.stop $APP_NAME 2>&1 | tail -2"
# 2. Push new compose
python3 -c "
import json
compose = open('truenas/stacks/$APP_NAME/compose.yaml').read()
print(json.dumps({'custom_compose_config_string': compose}))
" | ssh kero66@192.168.20.22 "cat > /tmp/u.json && sudo midclt call -j app.update $APP_NAME \"\$(cat /tmp/u.json)\" 2>&1 | tail -2; rm -f /tmp/u.json"
# 3. Start
ssh kero66@192.168.20.22 "sudo midclt call -j app.start $APP_NAME 2>&1 | tail -2"

ssh-agent -k > /dev/null
```

### ⚠️ NEVER use REST API PUT /app/id/{name} to update compose
```
# BROKEN: REST API PUT triggers container recreation WHILE the old one is running,
# causing port conflicts and leaving the app in a broken Created state.
# Use midclt stop → update → start instead (see above).
```

### Delete and re-create an app (nuclear option)
```bash
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null

APP_NAME=caddy
ssh kero66@192.168.20.22 "sudo midclt call -j app.delete $APP_NAME 2>&1 | tail -2"
python3 -c "
import json
compose = open('truenas/stacks/$APP_NAME/compose.yaml').read()
print(json.dumps({'custom_app': True, 'app_name': '$APP_NAME', 'train': 'stable', 'custom_compose_config_string': compose}))
" | ssh kero66@192.168.20.22 "cat > /tmp/a.json && sudo midclt call -j app.create \"\$(cat /tmp/a.json)\" 2>&1 | tail -3; rm -f /tmp/a.json"

ssh-agent -k > /dev/null
```

### Restart an app
```bash
APP=jellyfin
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE/api/v2.0/app/id/$APP/restart"
```

---

## Docker on TrueNAS

### kero66 cannot use docker directly — must sudo
```bash
# WRONG (permission denied):
ssh kero66@truenas "docker ps"

# CORRECT:
ssh kero66@truenas "sudo docker ps"
```

### Check container status
```bash
ssh -i "$KEYDIR/id" kero66@192.168.20.22 "sudo docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### View container logs
```bash
ssh -i "$KEYDIR/id" kero66@192.168.20.22 "sudo docker logs jellyfin --tail 50"
```

### Follow logs in real time
```bash
ssh -i "$KEYDIR/id" kero66@192.168.20.22 "sudo docker logs -f jellyfin"
```

### Exec into a container
```bash
ssh -i "$KEYDIR/id" kero66@192.168.20.22 "sudo docker exec jellyfin vainfo"
```

### Run vainfo inside Jellyfin container (Intel VAAPI check)
```bash
ssh -i "$KEYDIR/id" kero66@192.168.20.22 \
  "sudo docker exec -e LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri \
   -e LIBVA_DRIVER_NAME=iHD \
   jellyfin /usr/lib/jellyfin-ffmpeg/vainfo"
```

### TrueNAS Docker network naming
- TrueNAS creates networks named `ix-<APP_NAME>_default`
- Example: jellyfin stack → `ix-jellyfin_default`
- To join from another stack: add `ix-jellyfin_default` as external network in compose

---

## Jellyfin API

### Setup
```bash
JELLYFIN_BASE="http://jellyfin.home"
JELLYFIN_API_KEY=$(infisical secrets get JELLYFIN_API_KEY --env dev --path /media --plain)
# NOTE: JELLYFIN_API_KEY is at path "/media" not "/TrueNAS"
```

### Get encoding configuration
```bash
curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  "$JELLYFIN_BASE/System/Configuration/encoding" | jq '{HardwareAccelerationType, VaapiDevice}'
```

### Set VAAPI hardware transcoding (Intel N150)
```bash
# Get current config first
CONFIG=$(curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  "$JELLYFIN_BASE/System/Configuration/encoding")

# Then POST the modified config (HTTP 204 = success)
curl -s -X POST \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(echo $CONFIG | jq '
    .HardwareAccelerationType = "vaapi" |
    .VaapiDevice = "/dev/dri/renderD128" |
    .EnableHardwareEncoding = true |
    .EnableTonemapping = true |
    .HardwareDecodingCodecs = ["h264","hevc","vp8","vp9","av1"]
  ')" \
  "$JELLYFIN_BASE/System/Configuration/encoding"
# Returns HTTP 204 on success (no body)
```

### Get system info
```bash
curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  "$JELLYFIN_BASE/System/Info" | jq '{ServerName, Version, OperatingSystem}'
```

---

## SABnzbd API

### Setup
```bash
SABKEY=$(infisical secrets get SABNZBD_API_KEY --env dev --path /TrueNAS --plain 2>/dev/null)
SAB_BASE="http://sabnzbd.home"
```

### Get queue status
```bash
curl -s "$SAB_BASE/api?mode=queue&output=json&apikey=$SABKEY" | jq '{status: .queue.status, paused: .queue.paused, slots: .queue.noofslots}'
```

### Get queue items with status
```bash
curl -s "$SAB_BASE/api?mode=queue&output=json&apikey=$SABKEY" | jq '.queue.slots[] | {filename: .filename, status: .status, nzo_id: .nzo_id, labels: .labels}'
```

### Resume all paused items (does NOT resume individual paused items — use per-item below)
```bash
curl -s "$SAB_BASE/api?mode=resume&output=json&apikey=$SABKEY" | jq '.status'
```

### Resume individual paused items by nzo_id
```bash
# Get IDs of paused items first
IDS=$(curl -s "$SAB_BASE/api?mode=queue&output=json&apikey=$SABKEY" | jq -r '.queue.slots[] | select(.status == "Paused") | .nzo_id')
for id in $IDS; do
  curl -s "$SAB_BASE/api?mode=queue&name=resume&value=$id&output=json&apikey=$SABKEY" | jq -r '.status'
done
```

### Get/set config values
```bash
# Get misc config section
curl -s "$SAB_BASE/api?mode=get_config&section=misc&output=json&apikey=$SABKEY" | jq '.config.misc | {host_whitelist, pause_on_pwrar}'

# Set a value (example: set encrypted download action to abort/fail instead of pause)
# pause_on_pwrar: 0=ignore, 1=pause, 2=abort (abort notifies Sonarr as failure → triggers re-search)
curl -s "$SAB_BASE/api?mode=set_config&section=misc&keyword=pause_on_pwrar&value=2&output=json&apikey=$SABKEY" | jq '.config.misc.pause_on_pwrar'
```

### Add hostname to whitelist (needed for reverse proxy .home domains)
```bash
# Get current whitelist, add new entry
# First get current whitelist, then append new entry
CURRENT=$(curl -s "$SAB_BASE/api?mode=get_config&section=misc&output=json&apikey=$SABKEY" | jq -r '.config.misc.host_whitelist | join(",")')
curl -s "$SAB_BASE/api?mode=set_config&section=misc&keyword=host_whitelist&value=${CURRENT},sabnzbd.home&output=json&apikey=$SABKEY" | jq '.config.misc.host_whitelist'
# NOTE: Must include 'sabnzbd.home' WITHOUT port — browsers send Host header without port on :80
```

### Get history with search
```bash
curl -s "$SAB_BASE/api?mode=history&output=json&apikey=$SABKEY&search=keyword" | jq '.history.slots[] | {name, status, fail_message}'
```

---

## Sonarr API

### Setup
```bash
SONARR_KEY=$(infisical secrets get SONARR_API_KEY --env dev --path /media --plain 2>/dev/null)
# NOTE: SONARR_API_KEY is at /media NOT /TrueNAS
# NOTE: Sonarr redirects — use -L to follow, or it returns 307 with no body
SONARR_BASE="http://sonarr.home"
```

### Get queue (follow redirects with -L)
```bash
curl -sL "$SONARR_BASE/api/v3/queue?pageSize=100&apikey=$SONARR_KEY" | jq '.totalRecords, (.records[] | {title, status, protocol, trackedDownloadStatus, errorMessage})'
```

### Get queue for specific protocol
```bash
curl -sL "$SONARR_BASE/api/v3/queue?pageSize=100&apikey=$SONARR_KEY" | jq '.records[] | select(.protocol == "usenet") | {title, status, trackedDownloadStatus, errorMessage}'
```

### Find a series by name
```bash
curl -sL "$SONARR_BASE/api/v3/series?apikey=$SONARR_KEY" | jq '.[] | select(.title | ascii_downcase | test("keyword")) | {id, title, path}'
```

### Get episode files for a series (use series id from above)
```bash
SERIES_ID=55
curl -sL "$SONARR_BASE/api/v3/episodefile?seriesId=$SERIES_ID&apikey=$SONARR_KEY" | jq '[.[] | {path, quality: .quality.quality.name, size, videoCodec: .mediaInfo.videoCodec, videoResolution: .mediaInfo.videoResolution}] | sort_by(.path)'
```

### Get history for a series
```bash
curl -sL "$SONARR_BASE/api/v3/history?seriesId=$SERIES_ID&pageSize=20&apikey=$SONARR_KEY" | jq '.records[] | {date, eventType, sourceTitle}'
```

### Check download client config (failed download handling)
```bash
curl -sL "$SONARR_BASE/api/v3/config/downloadclient?apikey=$SONARR_KEY" | jq '{enableCompletedDownloadHandling, autoRedownloadFailed}'
```

---

## qBittorrent API

### Setup
```bash
QBIT_USER=$(infisical secrets get QBITTORRENT_USER --env dev --path /TrueNAS --plain 2>/dev/null)
QBIT_PASS=$(infisical secrets get QBITTORRENT_PASS --env dev --path /TrueNAS --plain 2>/dev/null)
QBIT_BASE="http://qbittorrent.home"
# Use .home hostname via Caddy — avoids IP ban issues from direct port access
```

### Login and query
```bash
curl -s -c /tmp/qb_cook -X POST "$QBIT_BASE/api/v2/auth/login" -d "username=$QBIT_USER&password=$QBIT_PASS"
curl -s -b /tmp/qb_cook "$QBIT_BASE/api/v2/torrents/info" | jq '.[] | {name, category, state, ratio, seeding_time}'
rm -f /tmp/qb_cook
```

### Filter torrents by name pattern
```bash
curl -s -b /tmp/qb_cook "$QBIT_BASE/api/v2/torrents/info" | jq '.[] | select(.name | ascii_downcase | test("keyword")) | {name, category, state, ratio, seeding_time}'
```

---



Use this before writing a healthcheck to avoid "command not found" failures.

| Container Image | `curl` | `wget` | `pg_isready` | Notes |
|---|---|---|---|---|
| `lscr.io/linuxserver/jellyfin` | ✅ yes | ✅ yes | ❌ no | Use curl |
| `cyfershepard/jellystat` | ❌ **NO** | ✅ yes | ❌ no | **Must use wget** |
| `postgres:15-alpine` | ❌ no | ❌ no | ✅ yes | Use pg_isready |
| `fallenbagel/jellyseerr` | ❌ no | ✅ yes | ❌ no | Use wget |
| `lscr.io/linuxserver/sonarr` | ✅ yes | ✅ yes | ❌ no | Use curl |
| `lscr.io/linuxserver/radarr` | ✅ yes | ✅ yes | ❌ no | Use curl |
| `lscr.io/linuxserver/prowlarr` | ✅ yes | ✅ yes | ❌ no | Use curl |

### wget healthcheck pattern (when curl absent)
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/ || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```
**Note:** Use `127.0.0.1` not `localhost` — avoids IPv6 `::1` connection refused on first try.

### curl healthcheck pattern
```yaml
healthcheck:
  test: curl -sf http://localhost:8096/health || exit 1
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### postgres healthcheck pattern
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
```

---

## Intel N150 VAAPI (Hardware Transcoding)

### Required compose.yaml settings
```yaml
services:
  jellyfin:
    environment:
      # iHD driver is bundled in jellyfin-ffmpeg, NOT on system PATH
      - LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri
      - LIBVA_DRIVER_NAME=iHD
    group_add:
      - "107"  # render GID — for /dev/dri/renderD128
      - "44"   # video GID  — for /dev/dri/card0
    devices:
      - /dev/dri:/dev/dri
```

### Verify VAAPI is working inside container
```bash
sudo docker exec \
  -e LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri \
  -e LIBVA_DRIVER_NAME=iHD \
  jellyfin /usr/lib/jellyfin-ffmpeg/vainfo
# Expect: "Intel iHD driver ... VAEntrypointVLD, VAEntrypointEncSlice..."
```

### Intel N150 GPU IDs (for reference)
- Vendor: `0x8086` (Intel)
- Device: `0x46d4` (Alder Lake-N / UHD Graphics)
- VA driver: `iHD` (Intel Media Driver)

---

## Security Patterns

### DO: Secure temp key handling
```bash
KEYDIR=$(mktemp -d)          # random dir, e.g. /tmp/tmp.xK9mQr
chmod 700 "$KEYDIR"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain > "$KEYDIR/id"
chmod 600 "$KEYDIR/id"
# ... use the key ...
rm -rf "$KEYDIR"             # cleanup immediately after use
```

### NEVER: Predictable temp file paths
```bash
# BAD — predictable name, other processes can read it
echo "$KEY" > /tmp/truenas_key
ssh -i /tmp/truenas_key user@host
# Key left on disk after session

# BAD — /tmp/id_rsa is a standard name attackers check
cp key /tmp/id_rsa
```

---

## File Staging (Working Files)

**NEVER use `/tmp` for working files** — only for SSH keys (mktemp -d, cleanup immediately).
Stage working files in the repo, SCP to TrueNAS from there.

```bash
# CORRECT: stage in repo, SCP to TrueNAS, clean up from repo when done
WORKDIR="/mnt/library/repos/homelab/scratch"  # gitignored directory
mkdir -p "$WORKDIR"
# ... download/create files in $WORKDIR ...
scp "$WORKDIR/file.ext" kero66@192.168.20.22:/mnt/Fast/docker/service/
rm -rf "$WORKDIR"
```

---

## Bazarr (Subtitle Management)

### API setup
```bash
BAZARR_API_KEY=$(infisical secrets get BAZARR_API_KEY --env dev --path /media --plain 2>/dev/null)
BAZARR_BASE="http://192.168.20.22:6767/bazarr/api"
```

### Get all settings
```bash
curl -s -H "X-API-KEY: $BAZARR_API_KEY" "$BAZARR_BASE/system/settings" | jq '.'
```

### Update settings (POST with full object required — partial updates don't work)
```bash
curl -s -H "X-API-KEY: $BAZARR_API_KEY" "$BAZARR_BASE/system/settings" > /tmp/s.json
# edit /tmp/s.json, then:
curl -s -X POST -H "X-API-KEY: $BAZARR_API_KEY" -H "Content-Type: application/json" \
  -d @/tmp/s.json "$BAZARR_BASE/system/settings"
rm /tmp/s.json
# Then SCP the updated config into repo: scp truenas:/mnt/Fast/docker/bazarr/config/config.yaml media/.config/bazarr/config.yaml
```

### Find a series/episode
```bash
# Series (returns sonarrSeriesId as 'id')
curl -s -H "X-API-KEY: $BAZARR_API_KEY" "$BAZARR_BASE/series" | jq '[.data[] | select(.title | test("keyword";"i")) | {id: .sonarrSeriesId, title}]'

# Episodes for a series (use sonarrSeriesId from above)
curl -s -H "X-API-KEY: $BAZARR_API_KEY" "$BAZARR_BASE/episodes?seriesid[]=$SERIES_ID" | jq '[.data[] | select(.episode == 8) | {id: .sonarrEpisodeId, title, path, subtitles}]'
```

### Key config values (confirmed correct)
- `use_embedded_subs: false` — do NOT trust embedded subs (releases often ship wrong ones)
- `use_subsync: true` — auto-sync downloaded subs to audio
- `use_subsync_threshold: true`, `subsync_threshold: 90`
- `use_subsync_movie_threshold: true`, `subsync_movie_threshold: 70`
- Config on TrueNAS: `/mnt/Fast/docker/bazarr/config/config.yaml` (gitignored — sync to repo manually)
- Repo reference: `media/.config/bazarr/config.yaml`

---

## AnimeTosho (Subtitle Source for Anime)

AnimeTosho indexes Nyaa releases and hosts subtitle attachments separately — no account needed.

### Search for a release
```bash
# JSON feed search (returns array of releases)
curl -s "https://feed.animetosho.org/json?q=show+name+E08" | python3 -c "
import json,sys
for i in json.load(sys.stdin):
    print(i['title'], '→', i.get('link',''))
"
```

### Get subtitle attachment links from a release page
```bash
curl -s "https://animetosho.org/view/<slug>" | python3 -c "
import sys, re
for l in re.findall(r'href=\"(https://[^\"]*\.ass\.xz[^\"]*?)\"', sys.stdin.read()):
    print(l)
"
```

### Download and extract a subtitle attachment
```bash
# Download to repo scratch dir, NOT /tmp
curl -sL "<animetosho_attach_url>.ass.xz" -o scratch/subtitle.ass.xz
xz -d scratch/subtitle.ass.xz
# Verify it has the right content before using:
grep '^Dialogue:' scratch/subtitle.ass | head -5
```

### Remux subtitle into MKV (replace a bad embedded track)
```bash
# Example: replace track 0:2 (English) with correct external sub
# -map 0:0 (video) -map 0:1 (audio) -map 1:0 (new sub) -map 0:3..N (keep other subs+attachments)
sudo docker run --rm \
  -v '/mnt/Data/media/shows:/shows' \
  -v '/mnt/library/repos/homelab/scratch:/scratch' \
  linuxserver/ffmpeg \
  -i "/shows/Show Name/Season 01/episode.mkv" \
  -i /scratch/subtitle.ass \
  -map 0:0 -map 0:1 -map 1:0 -map 0:3 -map 0:4 ... \
  -c copy \
  -metadata:s:s:0 language=eng \
  "/shows/Show Name/Season 01/episode.fixed.mkv"
# Then rename: mv episode.mkv episode.bak.mkv && mv episode.fixed.mkv episode.mkv
# Verify then delete bak
```

---

## Anti-Patterns (Never Do These)

| Anti-Pattern | Why It Fails | Correct Pattern |
|---|---|---|
| `http://192.168.20.22/api/...` | 308 redirect drops `Authorization` header | Use `https://` always |
| `PUT /api/v2.0/user/72` | Returns 404 | Use `PUT /api/v2.0/user/id/72` |
| Pipe API response directly to `jq` without checking | Endpoint may return HTML (Angular SPA) not JSON | Check `Content-Type` or `head -c 200` first |
| `ssh user@host "cmd1 && cmd2 | jq"` | SSH piped commands fail on TrueNAS | Run commands as separate SSH calls |
| Store key in `/tmp/predictable_name` | Readable by other processes, not cleaned up | Use `mktemp -d`, `chmod 600`, cleanup with `rm -rf` |
| **Use `/tmp` for working files** | Not version-controlled, easy to forget cleanup | Stage in repo `scratch/` dir, SCP to TrueNAS |
| Use `curl` in jellystat healthcheck | `curl` not installed in that image | Use `wget --spider` |
| `infisical secrets get X --env prod` | No prod environment exists | Use `--env dev` |
| `infisical secrets get JELLYFIN_API_KEY --path /TrueNAS` | Key is at root path | Use `--path /` |
| `docker ps` as kero66 on TrueNAS | Permission denied | `sudo docker ps` |
| `python3 -m json.tool` | Not as reliable, doesn't handle all edge cases | Use `jq` |
| Bazarr partial settings POST | API requires full settings object | GET settings, modify, POST full object back |
| Trust embedded subs in MKV releases | Encoders sometimes ship wrong subs (e.g. wrong show) | Use `use_embedded_subs: false` in Bazarr; verify with ffmpeg |
| Use `192.168.20.22:PORT` for service API calls | Bypasses Caddy, causes IP bans (qBittorrent), misses host verification | Use `http://service.home` — routes through Caddy as intended |
| `curl http://sonarr.home/api/...` (Sonarr without -L) | Returns 307 redirect with empty body | Always use `curl -sL` for Sonarr |
| Pipe SSH output through local `base64` for auth headers | Variable expansion breaks across SSH boundary | Use `curl -u 'user:pass'` instead |
| SABnzbd `mode=queue&name=resume` (resume all) | Does NOT resume individually paused items | Use `mode=queue&name=resume&value=<nzo_id>` per item |
| `pause_on_pwrar=1` (SABnzbd default) | Pauses encrypted downloads — Sonarr sees "paused" not "failed", never re-searches | Set to `2` (abort) so Sonarr gets failure notification |
| Assume Cleanuparr API is unauthenticated | Returns `{"error":"Setup required"}` for all unauthed requests — looks like misconfiguration | Cleanuparr requires login; "setup required" on API = auth failure, not missing config |

---

## Infisical Folder Structure

Root folders (run `infisical secrets folders get --env dev --path /` to list):
- `/TrueNAS` - TrueNAS infrastructure secrets (SSH keys, API tokens)
- `/media` - All media stack secrets (Jellyfin, Sonarr, Radarr, etc.)
- `/homepage` - Homepage dashboard secrets
- `/monitoring` - Monitoring stack secrets
- `/networking` - Networking secrets
- `/proxy` - Reverse proxy secrets
- `/automations` - Automation secrets

## Infisical Secret Locations Reference

| Secret Name | Environment | Path | Notes |
|---|---|---|---|
| `TRUENAS_API_TOKEN` | dev | `/TrueNAS` | Bearer token for TrueNAS REST API |
| `kero66_ssh_key` | dev | `/TrueNAS` | ED25519 private key for kero66@192.168.20.22 |
| `truenas_admin_api` | dev | `/TrueNAS` | TrueNAS admin API key |
| `ADGUARD_PASSWORD` | dev | `/TrueNAS` | AdGuard Home admin password |
| `QBITTORRENT_USER` | dev | `/TrueNAS` | qBittorrent username |
| `QBITTORRENT_PASS` | dev | `/TrueNAS` | qBittorrent password |
| `CLEANUPARR_API_KEY` | dev | `/media` | Cleanuparr API key |
| `JELLYFIN_API_KEY` | dev | `/media` | NOT /TrueNAS, NOT root / |
| `JELLYSEERR_API_KEY` | dev | `/media` | Base64-encoded |
| `SONARR_API_KEY` | dev | `/media` | NOT /TrueNAS |
| `RADARR_API_KEY` | dev | `/media` | |
| `PROWLARR_API_KEY` | dev | `/media` | |
| `SABNZBD_API_KEY` | dev | `/TrueNAS` | NOT /media |
| `BAZARR_API_KEY` | dev | `/media` | |
| `JELLYSTAT_DB_PASS` | dev | `/media` | |
| `JELLYSTAT_JWT_SECRET` | dev | `/media` | |

---

## TrueNAS API Endpoint Reference

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v2.0/system/info` | System hostname, version |
| GET | `/api/v2.0/app` | List all Custom Apps |
| GET | `/api/v2.0/app/id/{name}` | Get app state/status |
| POST | `/api/v2.0/app/config` | Get app compose config (body: `"app_name"`) |
| PUT | `/api/v2.0/app/id/{name}` | Update app (body: `{"custom_compose_config": {...}}`) |
| POST | `/api/v2.0/app/id/{name}/restart` | Restart app |
| GET | `/api/v2.0/user?username={name}` | Look up user |
| PUT | `/api/v2.0/user/id/{id}` | Update user (note: `/id/` required) |
| GET | `/api/v2.0/core/get_jobs?id={id}` | Check async job status |

All endpoints require: `-H "Authorization: Bearer $TOKEN"` and `https://` base URL.
