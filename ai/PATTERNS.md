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
- **Media secrets (Bazarr, Jellyfin, Sonarr, Radarr)**: path `/media`
- **Infisical domain**: `http://192.168.20.22:8081` (self-hosted on TrueNAS)
- **Project ID**: `$INFISICAL_PROJECT_ID`
- **Requires `--projectId` and `--domain` flags** when no `.infisical.json` in working dir

### Authenticate (one-time per session — run manually in your terminal)
```bash
infisical login -i --domain http://192.168.20.22:8081 --email <your-infisical-email>
# -i = interactive terminal login (password prompt only, no browser)
# Session token stored locally; Claude can use infisical after this.
```

### Get a single secret (plain value)
```bash
# Project ID is hardcoded — always include --projectId and --domain
INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
infisical secrets get <SECRET_NAME> --env dev --path /TrueNAS \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 --plain 2>/dev/null
```

### Standard preamble for any script needing multiple secrets
```bash
INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
_isec() { infisical secrets get "$1" --env dev --path "$2" --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null; }

SONARR_KEY=$(_isec SONARR_API_KEY /media)
RADARR_KEY=$(_isec RADARR_API_KEY /media)
PROWLARR_KEY=$(_isec PROWLARR_API_KEY /media)
```

### Get Jellyfin API key
```bash
infisical secrets get JELLYFIN_API_KEY --env dev --path /media --plain
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
PROJECT_ID="$INFISICAL_PROJECT_ID"
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --domain http://192.168.20.22:8081 --projectId "$PROJECT_ID" --plain 2>/dev/null | ssh-add - 2>/dev/null

# Run SSH commands normally (agent provides the key automatically)
ssh kero66@192.168.20.22 "sudo docker ps"
ssh kero66@192.168.20.22 "sudo docker logs jellyfin --tail 50"

# Clean up agent when done
ssh-agent -k > /dev/null
```

### SCP with ssh-agent
```bash
PROJECT_ID="$INFISICAL_PROJECT_ID"
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --domain http://192.168.20.22:8081 --projectId "$PROJECT_ID" --plain 2>/dev/null | ssh-add - 2>/dev/null
scp local_file.txt kero66@192.168.20.22:/mnt/Fast/docker/service/
ssh-agent -k > /dev/null
```

### Fallback: temp file (if ssh-agent fails)
**If you must use a temp file, use mktemp -d for a random path and always clean up.**
**The key from Infisical has CRLF/escape-sequence line endings — must decode with python, NOT tr -d '\r'.**
```bash
PROJECT_ID="$INFISICAL_PROJECT_ID"
KEYDIR=$(mktemp -d) && chmod 700 "$KEYDIR"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --domain http://192.168.20.22:8081 --projectId "$PROJECT_ID" --plain 2>/dev/null \
  | python3 -c "import sys; d=sys.stdin.read(); d=d.replace('\\\\n','\n').replace('\\r','').replace('\\n','\n'); sys.stdout.write(d)" \
  > "$KEYDIR/id" && chmod 600 "$KEYDIR/id"
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

### Restart an app (single-service standalone app)
```bash
# For standalone apps (jellyfin, caddy, etc.) — stop/start via midclt
ssh kero66@192.168.20.22 "sudo midclt call -j app.stop APP_NAME && sudo midclt call -j app.start APP_NAME"
```

### ⚠️ midclt MUST use sudo — fails silently without it
```
# WRONG — runs as .UNAUTHENTICATED, returns job ID but does nothing:
ssh kero66@192.168.20.22 "midclt call app.start bazarr"

# CORRECT:
ssh kero66@192.168.20.22 "sudo midclt call -j app.start APP_NAME"
```
TrueNAS audit log will show `.UNAUTHENTICATED` Method Call errors if sudo is omitted.

### ⚠️ Multi-service apps (arr-stack, downloaders) — no per-service restart via midclt
midclt only operates at the app level. To restart a single container within arr-stack or downloaders,
stop/start the whole app — there is no per-service equivalent. Plan config changes to minimize full
stack restarts.

---

## Dockhand API (preferred over SSH for container lifecycle)

Dockhand manages containers NOT owned by midclt (e.g. comicarr). Use this instead of SSH+docker.

```bash
INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
_isec() { infisical secrets get "$1" --env dev --path "$2" --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null; }
DH="http://192.168.20.22:30328"

# Login (session cookie)
COOKIE_JAR=$(mktemp)
curl -s -c "$COOKIE_JAR" -X POST "$DH/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$(_isec DOCKHAND_USER /TrueNAS)\", \"password\": \"$(_isec DOCKHAND_USER_PASSWORD /TrueNAS)\", \"provider\": \"local\"}" > /dev/null

# Find container ID by name
CONTAINER_ID=$(curl -s -b "$COOKIE_JAR" "$DH/api/containers?env=1" | \
  python3 -c "import sys,json; data=json.load(sys.stdin); [print(c['id']) for c in data if c.get('name')=='comicarr']")

# Restart / start / stop
curl -s -b "$COOKIE_JAR" -X POST "$DH/api/containers/$CONTAINER_ID/restart?env=1"
# curl -s -b "$COOKIE_JAR" -X POST "$DH/api/containers/$CONTAINER_ID/start?env=1"
# curl -s -b "$COOKIE_JAR" -X POST "$DH/api/containers/$CONTAINER_ID/stop?env=1"

rm -f "$COOKIE_JAR"
```

Known container names: `comicarr`
Environment ID: `1` (TrueNAS)

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

### Get all episodes for a series (with season/episode numbers)
```bash
SERIES_ID="510503d8b628f2208659a267b3afa881"  # from /Items?searchTerm=...&IncludeItemTypes=Series
curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  "$JELLYFIN_BASE/Shows/$SERIES_ID/Episodes?fields=Name,ParentIndexNumber,IndexNumber" \
  | python3 -c "import json,sys; [print(f'S{i[\"ParentIndexNumber\"]:02d}E{i[\"IndexNumber\"]:02d}', i['Name'], i['Id']) for i in json.load(sys.stdin)['Items']]"
```

### Create a playlist (watch order)
```bash
USER_ID=$(curl -s -H "X-Emby-Token: $JELLYFIN_API_KEY" "$JELLYFIN_BASE/Users" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['Id'])")

# IDS = ordered list of Jellyfin item IDs (episodes + movies interleaved)
IDS_JSON=$(python3 -c "import json; print(json.dumps(['id1','id2','id3']))")

curl -s -X POST -H "X-Emby-Token: $JELLYFIN_API_KEY" -H "Content-Type: application/json" \
  "$JELLYFIN_BASE/Playlists" \
  -d "{\"Name\": \"My Watch Order\", \"Ids\": $IDS_JSON, \"UserId\": \"$USER_ID\", \"MediaType\": \"Unknown\"}"
# Returns: {"Id": "<playlist_id>"}
```

---

## Jellystat API

### Setup
```bash
JELLYSTAT_API_KEY=$(infisical secrets get JELLYSTAT_API_KEY --env dev --path /media --plain \
  --projectId "5086c25c-310d-4cfb-9e2c-24d1fa92c152" --domain http://192.168.20.22:8081 2>/dev/null)
JELLYSTAT_BASE="http://jellystat.home"
# Auth header: x-api-token (NOT Authorization or X-Emby-Token)
```

### Search global playback history
```bash
# size/page/search params — GET request
curl -s -X GET -H "x-api-token: $JELLYSTAT_API_KEY" \
  "$JELLYSTAT_BASE/api/getHistory?size=200&page=1&search=overlord"
# Returns: {current_page, pages, size, results: [{NowPlayingItemName, SeriesName, UserId, PlaybackDuration, ActivityDateInserted, ...}]}
```

### Get history for a specific item (series/movie)
```bash
# POST with JSON body
curl -s -X POST -H "x-api-token: $JELLYSTAT_API_KEY" -H "Content-Type: application/json" \
  "$JELLYSTAT_BASE/api/getItemHistory" \
  -d '{"id": "<jellyfin_item_id>", "page": 1, "size": 200}'
```

### Get history for a specific user
```bash
curl -s -X POST -H "x-api-token: $JELLYSTAT_API_KEY" -H "Content-Type: application/json" \
  "$JELLYSTAT_BASE/api/getUserHistory" \
  -d '{"userid": "<jellyfin_user_id>", "page": 1, "size": 200}'
```

### Swagger spec (all endpoints)
```bash
# Full API spec embedded in swagger-ui-init.js — extract with python3
curl -s "$JELLYSTAT_BASE/swagger/swagger-ui-init.js" | python3 -c "
import sys, re, json
content = sys.stdin.read()
match = re.search(r'\"swaggerDoc\": (\{.*\}),\s*\"customOptions\"', content, re.DOTALL)
doc = json.loads(match.group(1))
for path in doc['paths'].keys(): print(path)
"
```

### Notes
- API key from Jellystat UI: Settings → API Key — stored in Infisical `/media` as `JELLYSTAT_API_KEY`
- `getHistory` is GET; `getItemHistory` and `getUserHistory` are POST
- History search is case-insensitive partial match on item name

## SABnzbd API

### Setup
```bash
SABKEY=$(infisical secrets get SABNZBD_API_KEY --env dev --path /media --plain 2>/dev/null)
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

### Force manual import for stuck importBlocked items
Sonarr sometimes blocks auto-import with "release was matched to series by ID" for releases with non-English filenames. This pattern analyzes and imports all clean (zero-rejection) files for a given `downloadId`.

```bash
# Step 1: check what's stuck
curl -s -H "X-Api-Key: $SONARR_KEY" "http://192.168.20.22:8989/sonarr/api/v3/queue?pageSize=50" | \
  jq '.records[] | select(.trackedDownloadState == "importBlocked") | {title, downloadId, seriesId, episodeId}'

# Step 2: analyze a stuck download (verify episode detection and check rejections)
curl -s -H "X-Api-Key: $SONARR_KEY" \
  "http://192.168.20.22:8989/sonarr/api/v3/manualimport?downloadId=<DOWNLOAD_ID>&filterExistingFiles=false" | \
  jq '.[] | {path, episodes: [.episodes[].episodeNumber], rejections}'

# Step 3: force import (pipe jq-built payload directly to curl — no temp files)
# Imports only files with zero rejections; skips downgrades/unexpected episodes automatically
# importMode MUST be "copy", not "move" — see "Manual Import importMode" note below for why.
curl -s -H "X-Api-Key: $SONARR_KEY" \
  "http://192.168.20.22:8989/sonarr/api/v3/manualimport?downloadId=<DOWNLOAD_ID>&filterExistingFiles=false" | \
  jq '[.[] | select(.rejections | length == 0)] | {name: "ManualImport", importMode: "copy", files: [.[] | {path, seriesId: .series.id, episodeIds: [.episodes[0].id], quality, languages, downloadId}]}' | \
  curl -s -X POST -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
    --data-binary @- "http://192.168.20.22:8989/sonarr/api/v3/command" | jq '{id, status}'

# Step 4: check result
curl -s -H "X-Api-Key: $SONARR_KEY" "http://192.168.20.22:8989/sonarr/api/v3/command/<COMMAND_ID>" | jq '{status, message}'

# Step 5: clear the now-orphaned queue entry — manual import does NOT do this automatically
# A forced ManualImport bypasses Sonarr's normal completion pipeline, so the queue entry
# (matched to the download by downloadId) is never marked as resolved. It sits forever
# with trackedDownloadState "importBlocked" / status message "Unable to parse download,
# automatic import is not possible" — even though the files were correctly imported.
# Cleanuparr's queue_cleaner does NOT catch this pattern (only catches things like "Not an
# upgrade for existing episode file(s)"), so it will not self-clear. Verify the import
# actually landed (episode/episodefile hasFile checks) before removing, then:
curl -s -H "X-Api-Key: $SONARR_KEY" "http://192.168.20.22:8989/sonarr/api/v3/queue?pageSize=200&includeUnknownSeriesItems=true" | \
  jq -r '.records[] | select(.downloadId=="<DOWNLOAD_ID>") | .id' | while read -r qid; do
    curl -s -X DELETE -H "X-Api-Key: $SONARR_KEY" \
      "http://192.168.20.22:8989/sonarr/api/v3/queue/$qid?removeFromClient=true&blocklist=false"
  done
```
**Never do this without confirming with the user first if the removal is more than a couple of items** — clearing the queue is easy to reverse-in-spirit (nothing is blocklisted, files aren't touched) but it's still an action on shared state, not a read.

**When this fails (permanent blocks):**
- `"Not an upgrade for existing episode file"` → existing file is better quality, don't import
- `"Episode was unexpected"` → season pack mislabeled; check which episodes actually need files
- DVD ISO downloads → Sonarr cannot import ISOs at all; needs manual extraction first

### Grab a specific release for an episode (upgrade/fix)
- **Use `http://sonarr.home` (Caddy vhost), not the IP:port** — that's the intended access pattern
- **POST calls MUST use the `/sonarr/` prefix directly** (`http://sonarr.home/sonarr/api/v3/release`) — hitting the bare `/api/v3/release` path returns a 307 redirect to the `/sonarr/`-prefixed path, and curl silently drops the POST body when following that redirect even with `-L`. GET requests don't have this problem (empty body, nothing to lose), only POST/PUT do.
```bash
# Find available releases for an episode
curl -s -H "X-Api-Key: $SONARR_KEY" "http://sonarr.home/sonarr/api/v3/release?episodeId=<EPISODE_ID>" | \
  jq 'sort_by(-.customFormatScore) | .[:10] | .[] | "\(.customFormatScore) | \(.quality.quality.name) | \(.size/1048576 | floor)MB | \(.title)"'

# Grab a specific release by guid+indexerId
curl -s -H "X-Api-Key: $SONARR_KEY" "http://sonarr.home/sonarr/api/v3/release?episodeId=<EPISODE_ID>" | \
  jq '.[] | select(.title | contains("keyword")) | {guid, indexerId, title}'

curl -s -X POST -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
  -d '{"guid": "<GUID>", "indexerId": <INDEXER_ID>}' \
  "http://sonarr.home/sonarr/api/v3/release"
```
- **Never `cat`/`jq`-print the `guid` or `.data.downloadUrl` fields from release/history responses** — they embed the live Prowlarr API key in cleartext. Extract into a shell variable and pipe straight into the next curl call instead.
- Release cache: Sonarr caches the release-to-episode decision server-side for 30 min, keyed by `IndexerId_Guid` (`ReleaseController.GetCacheKey`). A grab can 404 if that entry expired — re-fetch the release list immediately before grabbing rather than reusing an old search result.

### "Unable to parse release" — two different problems, two different fixes
Sonarr's episode-matching can fail for two structurally different reasons. Check the release title shape first to know which one applies:

**1. Release HAS episode markers, but they map to the wrong season** (e.g. `S01E48` when Sonarr's season 1 only goes to E25) — usually an old show where the release group numbers continuously but TVDB split it into artificial seasons. This is a **persistent** fix, done once per series:
- Check `https://thexem.info/map/single?id=<TVDB_ID>&origin=tvdb&destination=scene` first — if a community scene mapping already exists, Sonarr can use it automatically via `useSceneNumbering`. XEM registration for adding new shows may be closed; check before assuming you can contribute one.
- If no XEM mapping exists, set it manually per episode: `PUT /api/v3/episode/{id}` with `sceneSeasonNumber` and `sceneEpisodeNumber` added to the existing episode object (send the full episode resource, not a partial patch), then set `useSceneNumbering: true` on the series. Requires the absolute episode numbering to line up 1:1 with the release group's continuous numbering — verify this first (compare first/last episode of each season against the release group's numbering) rather than assuming.
- **Get explicit user confirmation before bulk-writing scene numbers** — this is inferred metadata, not sourced from a third party, and the auto-mode classifier will block unattended bulk writes to production series data anyway.

**2. Release has NO episode markers at all** (e.g. a "Complete Series" pack with no season/episode info in the title) — scene numbering can't help since there's no encoded number to translate. This needs a **one-time manual override at grab time**, not a persistent config change — the next similarly-unparseable release will need the same treatment again:
```bash
# Requires: seriesId, full list of episodeIds the pack covers, a quality id (GET /api/v3/qualitydefinition
# for the id matching the release's stated quality), and the series' originalLanguage id.
jq -n --slurpfile rel release.json --slurpfile eps episode_ids.json '
  ($rel[0][] | select(.title | test("KEYWORD"))) as $r |
  {guid: $r.guid, indexerId: $r.indexerId, protocol: $r.protocol,
   shouldOverride: true, seriesId: <SERIES_ID>, episodeIds: $eps[0],
   quality: {quality: {id: <QUALITY_ID>, name: "<QUALITY_NAME>"}, revision: {version: 1, real: 0, isRepack: false}},
   languages: [{id: <LANG_ID>, name: "<LANG_NAME>"}]}
' > grab_body.json
curl -s -X POST -H "X-Api-Key: $SONARR_KEY" -H "Content-Type: application/json" \
  --data-binary @grab_body.json "http://sonarr.home/sonarr/api/v3/release"
```
- Verify success via `GET /api/v3/history?seriesId=<ID>&pageSize=5` (look for fresh `grabbed` events) — the response body from the POST itself can come back with `null` fields even on a genuine `200` success, don't treat that as failure.
- After download completes, use Sonarr's Manual Import (`GET /api/v3/manualimport?downloadId=<ID>`) to map the pack's actual files to individual episodes.

---

## qBittorrent API

### Setup
```bash
QBIT_USER=$(infisical secrets get QBITTORRENT_USER --env dev --path /media --plain 2>/dev/null)
QBIT_PASS=$(infisical secrets get QBITTORRENT_PASS --env dev --path /media --plain 2>/dev/null)
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

### Manually trigger subsync on an existing subtitle (movie)

Endpoint: `PATCH /bazarr/api/subtitles` (NOT `/api/movies/subtitles` — that's for download)

```bash
INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
BAZARR_KEY=$(infisical secrets get BAZARR_API_KEY --env dev --path /media \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 --plain 2>/dev/null)

curl -s -w "\nHTTP %{http_code}" -X PATCH \
  -H "X-API-KEY: $BAZARR_KEY" \
  -G "http://192.168.20.22:6767/bazarr/api/subtitles" \
  --data-urlencode "path=/data/movies/Show (Year)/subtitle.en.hi.srt" \
  -d "action=sync&type=movie&id=<radarrId>&language=en&hi=True&forced=False&reference=a:1"
# reference=a:0 = first audio track, a:1 = second audio track, etc.
# Returns HTTP 204 on success; sync runs async (~4 min for 2hr 4K film)
```

For episodes, use `type=episode&id=<sonarrEpisodeId>`.

**Required params**: `action`, `type`, `id`, `language`, `path`
**Optional**: `hi`, `forced`, `reference` (audio stream to sync against — omit to use default)

Get `radarrId`: `curl ... "$BAZARR_BASE/movies" | jq '[.data[] | select(.title | test("keyword";"i")) | {id: .radarrId, title}]'`

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

### BD Subtitle Timing Offset Fix

When Bazarr downloads a subtitle timed for a WEB-DL release but the MKV is a Blu-ray encode,
the sub will be consistently early or late (typically a few seconds constant offset).

**Diagnosis**: Compare first dialogue timestamp in the external `.srt` against an embedded sub
that IS correctly timed (e.g. an Italian or Japanese ASS track from the same encode group):

```bash
# Check MKV tracks
sudo docker run --rm -v '/mnt/Data/media/shows:/shows' linuxserver/ffmpeg \
  -i "/shows/Series/Season 01/episode.mkv" 2>&1 | grep 'Stream'

# Extract embedded sub to stdout and check first timestamps
sudo docker run --rm -v '/mnt/Data/media/shows:/shows' linuxserver/ffmpeg \
  -i "/shows/Series/Season 01/episode.mkv" \
  -map 0:2 -f ass - 2>/dev/null | grep '^Dialogue:' | head -5

# Check first timestamps in the external SRT
head -20 "/mnt/Data/media/shows/Series/Season 01/episode.en.srt"
```

**Fix**: Shift the `.srt` timestamps by the measured offset (negative = make earlier):

```bash
python3 - <<'PYEOF'
import re, shutil

SRT = '/mnt/Data/media/shows/Series/Season 01/episode.en.srt'
SHIFT_MS = -3213  # negative = shift earlier; measure from comparing embedded vs external sub

def shift_ts(match):
    def to_ms(h, m, s, ms):
        return int(h)*3600000 + int(m)*60000 + int(s)*1000 + int(ms)
    def from_ms(v):
        v = max(0, v)
        h, v = divmod(v, 3600000)
        m, v = divmod(v, 60000)
        s, v = divmod(v, 1000)
        return f'{h:02d}:{m:02d}:{s:02d},{v:03d}'
    g = match.groups()
    return f'{from_ms(to_ms(*g[:4]) + SHIFT_MS)} --> {from_ms(to_ms(*g[4:]) + SHIFT_MS)}'

shutil.copy2(SRT, SRT + '.bak')
with open(SRT) as f:
    content = f.read()
pattern = r'(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})'
with open(SRT, 'w') as f:
    f.write(re.sub(pattern, shift_ts, content))
print('Done. Backup at', SRT + '.bak')
PYEOF
```

Run via SSH: `ssh kero66@192.168.20.22 "python3 - <<'PYEOF' ... PYEOF"`

**Note**: This is the right approach when the offset is constant throughout the episode (BD vs WEB timing).
If the offset drifts (different encode speed), use subsync instead — trigger via Bazarr UI or API.

---

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

## AdGuard Home DNS

- **Web UI**: `http://adguard.home` → Filters → DNS rewrites
- **Port**: 3080 (host) → 3000 (internal). API at `http://192.168.20.22:3080/control/`
- **Username**: `kero66` (NOT `admin`)
- **Password**: `ADGUARD_PASSWORD` in Infisical `/TrueNAS` — verify it's current before scripting
- ⚠️ **ADGUARD_PASSWORD may be stale** — if 401, update the secret or use the web UI

### Add a DNS rewrite via API
```bash
ADGUARD_PASS=$(infisical secrets get ADGUARD_PASSWORD --env dev --path /TrueNAS --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)

curl -s -o /dev/null -w "%{http_code}" -u "kero66:$ADGUARD_PASS" \
  -X POST "http://192.168.20.22:3080/control/rewrite/add" \
  -H "Content-Type: application/json" \
  -d '{"domain": "newservice.home", "answer": "192.168.20.22"}'

# Verify
curl -s -u "kero66:$ADGUARD_PASS" "http://192.168.20.22:3080/control/rewrite/list" | \
  jq '[.[] | select(.domain == "newservice.home")]'
```

### ⚠️ If 401 from Mac but works from TrueNAS
Run via SSH from TrueNAS as a fallback — the cause is unknown but may be IP-based filtering after failed attempts.

### Manual fallback (always works)
Go to `http://adguard.home` → Filters → DNS rewrites → Add rewrite → domain: `newservice.home`, answer: `192.168.20.22`

---

## Dockhand (Stack Deployment)

- **URL**: `http://192.168.20.22:30328/`
- **Auth**: Session cookie — POST to `/api/auth/login`, then use `-b "$COOKIEJAR"` for all requests
- **Username**: `DOCKHAND_USER` in Infisical `/TrueNAS`
- **Password**: `DOCKHAND_USER_PASSWORD` in Infisical `/TrueNAS`
- **Environment ID**: `1` (named "TrueNAS", connected via Docker socket)
- **`/mnt/Fast` is mounted** into Dockhand container — `env_file: /mnt/Fast/...` paths work correctly

### Update Dockhand catalog app config (e.g. add storage mounts)
```bash
# Use REST API with values wrapper — midclt app.update rejects all fields for catalog apps
TRUENAS_API=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)
curl -sk -X PUT -H "Authorization: Bearer $TRUENAS_API" -H "Content-Type: application/json" \
  -d '{"values": {"storage": {"data": {"type": "ix_volume", "ix_volume_config": {"acl_enable": false, "dataset_name": "data"}}, "additional_storage": [{"type": "host_path", "read_only": false, "mount_path": "/mnt/Fast", "host_path_config": {"acl_enable": false, "path": "/mnt/Fast"}}]}}}' \
  "https://192.168.20.22/api/v2.0/app/id/dockhand" | python3 -c "import sys,json; d=json.load(sys.stdin); print('job_id:', d.get('job_id'))"
# job returns immediately — check /api/v2.0/core/get_jobs?id=<job_id> for status
```

### Deploy a new stack
```bash
DOCKHAND_USER=$(infisical secrets get DOCKHAND_USER --env dev --path /TrueNAS --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)
DOCKHAND_PASS=$(infisical secrets get DOCKHAND_USER_PASSWORD --env dev --path /TrueNAS --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)

COOKIEJAR=$(mktemp)
# Pass credentials via env vars to avoid password appearing in process listings
DH_USER="$DOCKHAND_USER" DH_PASS="$DOCKHAND_PASS" python3 -c "
import json,os; print(json.dumps({'username':os.environ['DH_USER'],'password':os.environ['DH_PASS']}))" | \
  curl -s -c "$COOKIEJAR" -X POST "http://192.168.20.22:30328/api/auth/login" \
  -H "Content-Type: application/json" --data-binary @- > /dev/null

# Deploy — compose field name is "compose" (not "composeContent")
python3 -c "
import json
compose = open('truenas/stacks/<APP>/compose.yaml').read()
print(json.dumps({'name': '<APP>', 'environmentId': 1, 'compose': compose}))
" | curl -s -b "$COOKIEJAR" -X POST "http://192.168.20.22:30328/api/stacks" \
  -H "Content-Type: application/json" --data-binary @- | jq '{jobId}'

# Check job result
curl -s -b "$COOKIEJAR" "http://192.168.20.22:30328/api/jobs/<JOB_ID>" | jq '{status, error}'

rm -f "$COOKIEJAR"
```

### List stacks
```bash
curl -s -b "$COOKIEJAR" "http://192.168.20.22:30328/api/stacks?environmentId=1" | jq '[.[] | {id, name, status}]'
```

---

## Recyclarr (Quality Profile Sync)

- **Config**: `truenas/stacks/recyclarr/recyclarr.yml` in repo → SCP to `/mnt/Fast/docker/recyclarr/config/recyclarr.yml` on TrueNAS
- **Manages**: Sonarr + Radarr custom formats and quality profile scores

### Sync after editing recyclarr.yml
```bash
# 1. SCP updated config to TrueNAS (use SSH secure pattern)
scp -i "$TMPKEY" truenas/stacks/recyclarr/recyclarr.yml \
  kero66@192.168.20.22:/mnt/Fast/docker/recyclarr/config/recyclarr.yml

# 2. Sync Sonarr
ssh -i "$TMPKEY" kero66@192.168.20.22 "sudo docker exec recyclarr recyclarr sync sonarr 2>&1 | tail -5"

# 3. Sync Radarr
ssh -i "$TMPKEY" kero66@192.168.20.22 "sudo docker exec recyclarr recyclarr sync radarr 2>&1 | tail -5"
```

### Key recyclarr.yml sections
- `min_format_score` on quality profiles controls the grab threshold (0 = grab anything not explicitly blocked)
- Radarr Anime (1080p): `min_format_score: 0` — allows niche/fansub releases to be grabbed
- German blocking formats (score -10000): `German LQ`, `German LQ (release title)`, `German DL`
- Language blocking (score -10000): `Language: Not Original` (trash_id `ae575f95ab639ba5d15f663bf019e3e8`) — rejects any release whose audio isn't the series' original language, verified real/syncable via primary source, not "guide-only"

---

## Cleanuparr (Queue/Download Cleanup)

- **Live config lives in `cleanuparr.db` (SQLite), NOT `config.yml`** — the YAML file on disk is a stale bootstrap/sample and does not reflect settings changed via the web UI (confirmed: file said `dry_run: true`, live DB had it `0`/false)
- **Own API requires web-login/JWT auth** (not `X-Api-Key` like Sonarr/Radarr) — use SSH + sqlite3 for read-only inspection instead
```bash
sudo sqlite3 -header -column /mnt/Fast/docker/cleanuparr/cleanuparr.db 'SELECT * FROM <table>;'
```
- Key tables: `general_configs` (dry_run, log_level), `queue_cleaner_configs` (strike-based, `failed_import_patterns` JSON list matched against Sonarr/Radarr import failure messages — e.g. `"Not an upgrade for existing episode file(s)"`, `failed_import_max_strikes`), `download_cleaner_configs` (enable/cron only), `q_bit_seeding_rules`/`r_torrent_seeding_rules`/etc. (per-client seed time/ratio rules by category), `content_blocker_configs` (blocklist sync)
- Two independent cleanup paths — don't conflate: (1) queue_cleaner strikes stuck import-pending/failed items by message pattern match, (2) per-client seeding rules reap torrents by seed time/ratio regardless of Sonarr/Radarr import state

---

## Prowlarr Indexer Management

### List all indexers with stats
```bash
PROWLARR_KEY=$(infisical secrets get PROWLARR_API_KEY --env dev --path /media --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)

curl -s -H "X-Api-Key: $PROWLARR_KEY" "http://192.168.20.22:9696/prowlarr/api/v1/indexer" | \
  jq '[.[] | {id, name, priority}]'

curl -s -H "X-Api-Key: $PROWLARR_KEY" "http://192.168.20.22:9696/prowlarr/api/v1/indexerstats" | \
  jq '.indexers[] | {name: .indexerName, queries: .numberOfQueries, failed: .numberOfFailedQueries, avgMs: .averageResponseTime}'
```

### Delete an indexer
```bash
curl -s -X DELETE -H "X-Api-Key: $PROWLARR_KEY" \
  "http://192.168.20.22:9696/prowlarr/api/v1/indexer/<ID>"
```

### Cross-reference grab history (which indexer actually sourced grabs)
```bash
# Sonarr
curl -s -H "X-Api-Key: $SONARR_KEY" "http://192.168.20.22:8989/sonarr/api/v3/history?pageSize=500&eventType=1" | \
  jq '[.records[].data.indexer // "unknown"] | group_by(.) | map({indexer: .[0], grabs: length}) | sort_by(-.grabs)[]'

# Radarr
curl -s -H "X-Api-Key: $RADARR_KEY" "http://192.168.20.22:7878/radarr/api/v3/history?pageSize=500&eventType=1" | \
  jq '[.records[].data.indexer // "unknown"] | group_by(.) | map({indexer: .[0], grabs: length}) | sort_by(-.grabs)[]'
```

### Escape hatch: searching directly via Prowlarr when Sonarr/Radarr's own search finds nothing

Sonarr/Radarr query indexers with fairly narrow, structured terms (series+episode number, movie+year). Prowlarr's own `/search` endpoint accepts a free-text query and can surface releases those narrower queries miss — this is how a release found by hand on an indexer's own site can exist even when Sonarr/Radarr interactive search comes back empty (confirmed 2026-08-18, Trigun 1998 season pack on Treasure Maps/SceneNZB).

**Prowlarr indexer IDs are a different namespace from Sonarr/Radarr's synced indexer IDs — do not reuse one for the other.** Get Prowlarr's own id from `GET /api/v1/indexer` (matched by name), not from Sonarr/Radarr's `/api/v3/indexer` list, or the search call fails with a generic "all selected indexers being unavailable" error that looks like an indexer outage but is actually just the wrong ID.

```bash
PROWLARR_KEY=$(infisical secrets get PROWLARR_API_KEY --env dev --path /media --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)

# Get the indexer's own Prowlarr id (NOT Sonarr/Radarr's proxy id for the same indexer)
curl -sL "http://prowlarr.home/api/v1/indexer?apikey=$PROWLARR_KEY" | jq '.[] | select(.name | test("<indexer name>")) | {id, name}'

# Free-text search against one indexer
curl -sL -G "http://prowlarr.home/api/v1/search" \
  --data-urlencode "query=<broad search terms>" \
  --data-urlencode "indexerIds=<prowlarr id from above>" \
  --data-urlencode "type=search" \
  --data-urlencode "apikey=$PROWLARR_KEY" | jq '.[] | {title, guid, indexerId, seeders}'
```

**A guid found this way is not directly grabbable through Sonarr/Radarr's `/release` POST endpoint** — that endpoint requires the guid to already be in Sonarr/Radarr's own release cache (populated by *their* search), and returns `404 "Couldn't find requested release in cache, try searching again"` otherwise. Two ways to actually use the find:

1. **Try to get Sonarr/Radarr's own search to surface the same release** with broader query scope (e.g. season-level search instead of per-episode) — if it lands in their cache, the normal grab/manual-override flow works and you keep automatic episode/movie mapping. Preferred when it works.
2. **Manual download + Manual Import** — download the release directly (via Prowlarr's own download action, or the indexer site), let it land in the download client under the right category, then use Sonarr/Radarr's Manual Import UI/API to map files to episodes/movie by hand. This fully bypasses both trash-guides custom-format scoring *and* Sonarr/Radarr's automated release parsing — necessary for genuinely unparseable or narrowly-unsearchable content, but loses the automated mapping/validation both apps normally provide.

---

## Radarr API

### Setup
```bash
RADARR_KEY=$(infisical secrets get RADARR_API_KEY --env dev --path /media --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)
RADARR="http://192.168.20.22:7878/radarr"
```

### List monitored movies without files (missing)
```bash
curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR/api/v3/movie" | \
  jq '[.[] | select(.monitored == true and .hasFile == false) | {id, title, year, status, qualityProfileId}] | sort_by(.year)[]'
```

### Trigger search for specific movie IDs
```bash
curl -s -X POST -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" \
  -d '{"name": "MoviesSearch", "movieIds": [1, 2, 3]}' \
  "$RADARR/api/v3/command" | jq '{id, name, status}'
```

### Trigger search for all missing monitored movies
```bash
MISSING_IDS=$(curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR/api/v3/movie" | \
  jq '[.[] | select(.monitored == true and .hasFile == false and .status == "released") | .id]')
curl -s -X POST -H "X-Api-Key: $RADARR_KEY" -H "Content-Type: application/json" \
  -d "{\"name\": \"MoviesSearch\", \"movieIds\": $MISSING_IDS}" \
  "$RADARR/api/v3/command" | jq '{id, status}'
```

### Check quality profile format scores
```bash
curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR/api/v3/qualityprofile/<PROFILE_ID>" | \
  jq '.formatItems[] | select(.score != 0) | {format: .name, score}'
```

### Interactive release search for a specific movie
```bash
curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR/api/v3/release?movieId=<ID>" | \
  jq '[.[] | {title: .title[0:70], score: .customFormatScore, rejected, reason: .rejections[0]}]'
```

---

## Manual Import Script

**Run this before reaching for ad-hoc curl against Sonarr/Radarr's manual-import API.**
Hand-crafting the same curl commands turn after turn burns tokens for no reason once a working,
logged script exists — use the script first, and only drop to raw curl for something the script
doesn't cover (a one-off single-file case, or diagnosing why the script itself failed).

Script: `truenas/scripts/import_downloads.sh`
Scans qBittorrent and SABnzbd completed dirs, auto-imports clean matches into Sonarr/Radarr via
`POST /api/v3/command` (`name: "ManualImport"`) — every run's full output is also captured to
`truenas/scripts/logs/import_downloads_<timestamp>.log` (gitignored) so a failure can be diagnosed
from the log afterward instead of re-running curl commands to reconstruct what happened.

```bash
# Dry run — shows what would be imported without doing anything
./truenas/scripts/import_downloads.sh --dry-run

# Live run — copies matched files into media library (hardlinked, same dataset — see note below)
./truenas/scripts/import_downloads.sh
```

Requirements: `jq`, `curl`, `infisical` CLI authenticated.
Scan dirs: `/data/downloads/qbittorrent/completed`, `/data/downloads/sabnzbd/complete`
Auto-imports: files with series/movie match and zero rejections (importMode: copy)

### `POST /api/v3/manualimport` vs `POST /api/v3/command` (name: `ManualImport`) — not interchangeable
`POST /api/v3/manualimport` is Sonarr/Radarr's **ReprocessItems** endpoint — it only re-evaluates
quality/language/episode matching for the items you send it and echoes the result back. It does
**not** copy or hardlink any file, and does not fire the internal `DownloadCompletedEvent` that
marks a queue item resolved. Confirmed live 2026-08-29: POSTing an already-imported Zoids Chaotic
Century episode to it returned an unchanged echo and left the queue item stuck at `importBlocked`;
using the Sonarr UI's own Interactive Import (which drives the real import pipeline) cleared the
same queue item immediately and logged `DownloadCompletedEvent`. `POST /api/v3/command` with
`{"name": "ManualImport", "files": [...], "importMode": "copy"}` drives that same real pipeline via
the API and is a queued async Command — poll `GET /api/v3/command/<id>` until `status` leaves
`queued`/`started`. This is what `import_downloads.sh` uses; don't revert to `/api/v3/manualimport`
for anything other than a read-only `GET` to see what's importable.
Reports: files needing manual attention with rejection reason

### Manual Import `importMode` — always use `"copy"`, never `"move"`
Since the `Data/Servarr` unified-dataset migration (#92, confirmed live 2026-08-24), downloads and
the media library share one ZFS dataset, so Sonarr/Radarr's normal import genuinely hardlinks —
`importMode: "copy"` in the Manual Import API respects that (creates a hardlink when the media
manager's "Use Hardlinks" setting is on, same as automatic import), keeping the file in the
download folder too so the torrent stays seedable and Cleanuparr's seeding-rules can clean it up
on schedule. `importMode: "move"` physically relocates the file out of the download folder —
breaks the torrent (qBittorrent can no longer find its data, shows `checkingUP`/`missingFiles`
after the next recheck) even though the import itself succeeds. If a `move` import already broke
a torrent, it's fixable without re-downloading: match qBittorrent's original per-file name+size
(`GET /api/v2/torrents/files?hash=<hash>`) against the imported library file by exact byte size,
recreate a hardlink at the original download path (`os.link`), then `POST /api/v2/torrents/recheck`.

### Stuck queue items after Manual Import — what's confirmed vs. still open
9 batch/pack downloads (Zoids Chaotic Century, RWBY, Robotech, Koyomimonogatari, Maison Ikkoku,
Mospeada, Tekkaman Blade BD-BOX, .hack, G.U. Trilogy) were found stuck at
`trackedDownloadState: importBlocked` with a null series/movie id — permanent "Series/Movie title
mismatch" queue entries, invisible to the normal `GET /api/v3/queue` unless
`includeUnknownSeriesItems=true`/`includeUnknownMovieItems=true` is passed. This also permanently
blocks Cleanuparr's seeding-rule cleanup, which refuses to touch any download an arr still has
queued (`[DownloadCleaner] skip | download is used by an arr`), regardless of `max_seed_time`.

**Confirmed (2026-08-29):**
- These imports had all been done via `POST /api/v3/manualimport`, which is a metadata-only
  reprocess (see above) — it never fires the `DownloadCompletedEvent` that queue clearing depends
  on. A single-file test resubmit with `downloadId` added, still via `/api/v3/manualimport`,
  changed nothing.
- The Sonarr UI's own Interactive Import for Zoids Chaotic Century cleared its queue item
  immediately and logged `DownloadCompletedEvent` — confirming the real pipeline (i.e.
  `POST /api/v3/command` with `name: "ManualImport"`) is what's required, not the reprocess
  endpoint.
- `GET /api/v3/manualimport` already returns `downloadId` per file — always thread it into the
  import payload (`{path, seriesId, episodeIds, downloadId, ...}` for Sonarr;
  `{path, movieId, downloadId, ...}` for Radarr). This is schema-correct per Sonarr's own
  `ManualImportFile`/`ManualImportItem` models regardless, and costs nothing to include.

**Still open / not independently verified:** whether `POST /api/v3/command` (ManualImport) via the
API — as opposed to the UI's Interactive Import specifically — actually clears these particular 9
queue items, and whether `downloadId` is necessary or just correct-but-inert for that to happen.
`import_downloads.sh` now uses the command endpoint with `downloadId` included; the real test is
running it against one of the 9 stuck items and checking `GET /api/v3/queue` afterward — don't
assume it's fixed until that's actually been observed.

---

## Shipping Script Logs to Loki

Any script that logs to a local file (like `import_downloads.sh`) should also ship that log to
Loki (the Grafana Alloy stack, `truenas/stacks/grafana-alloy/`) so it's queryable in Grafana instead
of living only on whatever machine ran the script — this is the standard going forward for
repeatable scripts, not a one-off.

**Endpoint**: `http://loki.home/loki/api/v1/push` — added 2026-08-29 specifically so scripts can push
without SSH. Loki itself has no built-in auth (its own docs: "authorization is not part of the Loki
API... needs to be done separately") and binds to `127.0.0.1:3100` on the TrueNAS host, so Caddy
joins `grafana-alloy-network` and puts `basic_auth` in front — the one `*.home` vhost that isn't
bare LAN-trust, because it's a write endpoint. Credentials: `LOKI_PUSH_USER`/`LOKI_PUSH_PASSWORD` in
Infisical `/observability` (the Caddyfile's `basic_auth` hash is a static `htpasswd`-generated
literal until #111 in `ai/todo.md` wires it through Infisical Agent templating — regenerate and
redeploy the hash manually if the password ever rotates).

**Payload shape — keep labels low-cardinality, put detail in the line itself**:
```json
{"streams": [{
  "stream": {"job": "<script_name>", "host": "<hostname>", "run_status": "success|failure"},
  "values": [["<unix_nanoseconds_as_string>", "<log line>"], ...]
}]}
```
- `stream` labels become Loki's index — keep them to a small fixed set (job/host/status). Never put
  the run id, timestamp, or free-text content in a label; that's what blew up cardinality warnings
  in other Loki setups. Put `run_id=<value>` as a suffix on the log line text instead, so it's
  searchable via `|= "run_id=x"` without being an index dimension.
- Timestamps must be **non-decreasing** within a stream, sent as a **string**, not a number
  (`400` otherwise) — assign strictly increasing nanosecond values per line if pushing a whole log
  file's lines in one batch (e.g. `base_ns + line_index`).
- `jq -R -s 'split("\n") | map(select(length > 0)) | to_entries | map([...])'` is the reliable way to
  turn a multi-line log file into this shape from bash — see `import_downloads.sh`'s
  `ship_log_to_loki()` for the full working version. Strip ANSI color codes first
  (`sed -E 's/\x1b\[[0-9;]*m//g'`) so lines read cleanly in Grafana's log panel.

**Querying it back** (from anywhere on the LAN, no SSH): Grafana's datasource-proxy API works even
without opening Grafana's UI —
```bash
curl -s -u "admin:$GRAFANA_PASS" -G "http://grafana.home/api/datasources/proxy/uid/P8E80F9AEF21F6940/loki/api/v1/query_range" \
  --data-urlencode 'query={job="import_downloads"}' \
  --data-urlencode "start=$(( $(date +%s) - 3600 ))000000000" \
  --data-urlencode "end=$(date +%s)000000000" | jq '.data.result'
```
(`GRAFANA_ADMIN_PASSWORD` in Infisical `/observability`; Loki datasource UID `P8E80F9AEF21F6940`,
confirmed live — re-check via `GET /api/datasources` if this ever changes.)

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
| Backgrounding a sequential loop of `curl`/API calls (e.g. per-series Sonarr fetches) | Hangs indefinitely with near-zero CPU — confirmed 2026-08-15, root cause not identified, happens even with the secret pre-resolved outside the loop | Run the loop in the foreground, in batches small enough to fit the ~2min command timeout (e.g. 15-20 series per call) |
| Trust Sonarr's search results for a franchise show with a generic/reused name (e.g. "GUN×SWORD") without checking `.seriesTitle`/alias fields | Sonarr's TVDB alias table can silently map a show's search terms onto a *different* unrelated show's TVDB ID, returning dozens of wrong-show releases mixed in with real ones (confirmed: GUN×SWORD search returned mostly "Sword Art Online Alternative: Gun Gale Online" releases) | Check `mappedSeriesId` / the alias-match rejection message before grabbing; don't assume title-relevance in results means correct-show |
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
| `ADGUARD_PASSWORD` | dev | `/TrueNAS` | AdGuard Home admin password — username is `kero66`, may be stale |
| `DOCKHAND_USER` | dev | `/TrueNAS` | Dockhand username |
| `DOCKHAND_USER_PASSWORD` | dev | `/TrueNAS` | Dockhand password |
| `DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE` | dev | `/TrueNAS` | Dockhand GitHub deploy key |
| `QBITTORRENT_USER` | dev | `/media` | qBittorrent username |
| `QBITTORRENT_PASS` | dev | `/media` | qBittorrent password |
| `CLEANUPARR_API_KEY` | dev | `/media` | Cleanuparr API key |
| `JELLYFIN_API_KEY` | dev | `/media` | NOT /TrueNAS, NOT root / |
| `JELLYSEERR_API_KEY` | dev | `/media` | Base64-encoded |
| `SONARR_API_KEY` | dev | `/media` | NOT /TrueNAS |
| `RADARR_API_KEY` | dev | `/media` | |
| `PROWLARR_API_KEY` | dev | `/media` | |
| `SABNZBD_API_KEY` | dev | `/media` | Corrected 2026-08-24 — confirmed at /media, not /TrueNAS as previously documented here |
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
