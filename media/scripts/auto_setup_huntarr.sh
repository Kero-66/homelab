#!/usr/bin/env bash
set -euo pipefail

# Auto-setup script for Huntarr (non-2FA)
# - Reads credentials from env `HUNTARR_ADMIN_USER`/`HUNTARR_ADMIN_PASS`
#   or from `media/.config/.credentials` if present.
# - Waits for the service to become reachable and POSTs to /setup.

CREDENTIALS_FILE="media/.config/.credentials"
HUNTARR_URL="${HUNTARR_URL:-http://127.0.0.1:9705}"
HUNTARR_ADMIN_USER="${HUNTARR_ADMIN_USER:-}"
HUNTARR_ADMIN_PASS="${HUNTARR_ADMIN_PASS:-}"
MAX_WAIT="${MAX_WAIT:-300}"
SLEEP_INTERVAL=3
# Behaviour flags
SKIP_2FA="${SKIP_2FA:-true}"
SKIP_RECOVERY="${SKIP_RECOVERY:-true}"
COOKIE_JAR="${COOKIE_JAR:-.config/huntarr.cookies}"

if [ -z "${HUNTARR_ADMIN_USER}" ] || [ -z "${HUNTARR_ADMIN_PASS}" ]; then
  if [ -f "${CREDENTIALS_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${CREDENTIALS_FILE}" || true
    HUNTARR_ADMIN_USER="${HUNTARR_ADMIN_USER:-${HUNTARR_USER:-}}"
    HUNTARR_ADMIN_PASS="${HUNTARR_ADMIN_PASS:-${HUNTARR_PASS:-}}"
  fi
fi

if [ -z "${HUNTARR_ADMIN_USER}" ] || [ -z "${HUNTARR_ADMIN_PASS}" ]; then
  echo "HUNTARR_ADMIN_USER and HUNTARR_ADMIN_PASS must be set (env or ${CREDENTIALS_FILE})"
  exit 1
fi

echo "Waiting for Huntarr at ${HUNTARR_URL} ..."
start_ts=$(date +%s)
while true; do
  if curl -s -I "${HUNTARR_URL}/" >/dev/null 2>&1; then
    echo "Huntarr reachable."
    break
  fi
  now_ts=$(date +%s)
  if [ $((now_ts - start_ts)) -ge "${MAX_WAIT}" ]; then
    echo "Timeout waiting for Huntarr (${MAX_WAIT} seconds)."
    exit 2
  fi
  sleep "${SLEEP_INTERVAL}"
done

echo "Attempting to create admin user '${HUNTARR_ADMIN_USER}' (non-2FA)..."

# HTTP helper that prefers API key header but falls back to cookie-based session
post_json(){
  # $1 = path, $2 = json body
  if [ -n "${HUNTARR_API_KEY:-}" ]; then
    curl -s -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" -X POST "${HUNTARR_URL}${1}" -H 'Content-Type: application/json' -H "X-Api-Key: ${HUNTARR_API_KEY}" -d "${2}"
  else
    curl -s -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" -X POST "${HUNTARR_URL}${1}" -H 'Content-Type: application/json' -d "${2}"
  fi
}

http_post_with_status(){
  # $1 = path, $2 = json body
  # returns body and sets global LAST_STATUS
  local out
  if [ -n "${HUNTARR_API_KEY:-}" ]; then
    out=$(curl -s -w "\n%{http_code}" -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" -X POST "${HUNTARR_URL}${1}" -H 'Content-Type: application/json' -H "X-Api-Key: ${HUNTARR_API_KEY}" -d "${2}" ) || true
  else
    out=$(curl -s -w "\n%{http_code}" -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" -X POST "${HUNTARR_URL}${1}" -H 'Content-Type: application/json' -d "${2}" ) || true
  fi
  LAST_STATUS=$(printf '%s' "${out}" | tail -n1)
  printf '%s' "${out%$LAST_STATUS}"  # body
}

# Generic GET that uses API key header if available
api_get(){
  # $1 = path
  if [ -n "${HUNTARR_API_KEY:-}" ]; then
    curl -s -H "X-Api-Key: ${HUNTARR_API_KEY}" "${HUNTARR_URL}${1}"
  else
    curl -s -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" "${HUNTARR_URL}${1}"
  fi
}

# Try programmatic login (AJAX-style) to populate cookie jar when API key not present
try_auth(){
  if [ -n "${HUNTARR_API_KEY:-}" ]; then
    return 0
  fi
  if [ -n "${HUNTARR_ADMIN_USER}" ] && [ -n "${HUNTARR_ADMIN_PASS}" ]; then
    echo "Attempting programmatic login to obtain session cookie..."
    login_body=$(printf '{"username":"%s","password":"%s"}' "${HUNTARR_ADMIN_USER}" "${HUNTARR_ADMIN_PASS}")
    login_out=$(curl -s -w "\n%{http_code}" -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" -X POST "${HUNTARR_URL}/auth/login" -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'X-Requested-With: XMLHttpRequest' -d "${login_body}" ) || true
    login_status=$(printf '%s' "${login_out}" | tail -n1)
    login_body_resp=$(printf '%s' "${login_out%$login_status}")
    if [ "${login_status}" = "200" ] || printf '%s' "${login_body_resp}" | grep -q '"success":true'; then
      echo "Login successful, session cookie saved to ${COOKIE_JAR}"
      return 0
    else
      echo "Programmatic login failed (status ${login_status}). Response: ${login_body_resp}"
      return 1
    fi
  fi
  return 1
}

# Verify instances via authenticated endpoints
verify_instances(){
  echo "Verifying instances via Huntarr API..."
  unauthorized_found=0
  for path in "/api/sonarr" "/api/radarr" "/api/prowlarr"; do
    out=$(api_get "${path}") || true
    if printf '%s' "${out}" | grep -q 'Unauthorized\|"error"'; then
      echo "  ${path} returned Unauthorized or error. Attempting auth..."
      if try_auth; then
        out=$(api_get "${path}") || true
      fi
      unauthorized_found=1
    fi
    echo "  ${path} => $(echo "${out}" | tr '\n' ' ' | sed -n '1,1p')"
  done

  # If we couldn't authenticate, fall back to DB persistence (requires docker & sqlite3)
  if [ "${unauthorized_found}" -ne 0 ]; then
    echo "Some endpoints returned Unauthorized. Will attempt DB fallback to persist instances."
    db_persist_instances || true
  fi
}


db_persist_instances(){
  # Only attempt if sqlite3 and docker compose file exist
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "sqlite3 not available; cannot perform DB fallback.";
    return 1
  fi
  COMPOSE_FILE="media/compose.yaml"
  DB_PATH="media/huntarr/huntarr.db"
  if [ ! -f "${DB_PATH}" ]; then
    echo "DB file ${DB_PATH} not found; cannot persist instances.";
    return 1
  fi
  echo "Stopping Huntarr container to update DB..."
  docker compose -f "${COMPOSE_FILE}" stop huntarr || true
  echo "Applying instance updates directly to ${DB_PATH}"
  sqlite3 "${DB_PATH}" <<SQL
BEGIN TRANSACTION;
UPDATE app_configs SET config_data = '{"instances":[{"name":"Default","api_url":"http://${SONARR_HOST}:${SONARR_PORT}","api_key":"${SONARR_KEY}","enabled":true,"hunt_missing_items":1,"hunt_upgrade_items":0,"hunt_missing_mode":"seasons_packs","upgrade_mode":"seasons_packs","state_management_mode":"custom","state_management_hours":168}],"sleep_duration":900,"monitored_only":true,"skip_future_episodes":true,"tag_processed_items":true,"custom_tags":{"missing":"huntarr-missing","upgrade":"huntarr-upgrade","shows_missing":"huntarr-shows-missing"},"hourly_cap":20}' WHERE app_type='sonarr';
UPDATE app_configs SET config_data = '{"enabled": true, "missing": false, "upgrade": false, "skip_future_releases": false, "process_no_release_dates": false, "max_missing_movies": 2, "max_upgrade_movies": 2, "minimum_cutoff_percentage": 95, "season_pack_priority": false, "upgrade_profile_filter": "", "monitored_only": true, "dry_run": false, "instances": [{"name": "Default", "address": "http://${RADARR_HOST}:${RADARR_PORT}", "api_key": "${RADARR_KEY}", "api_timeout": 120, "state_management_mode": "custom", "state_management_hours": 168}], "hunt_missing_movies": 1, "hunt_upgrade_movies": 0, "sleep_duration": 900, "tag_processed_items": true, "custom_tags": {"missing": "huntarr-missing", "upgrade": "huntarr-upgrade"}, "hourly_cap": 20}' WHERE app_type='radarr';
UPDATE app_configs SET config_data = '{"instances": [], "enabled": true, "name": "Prowlarr", "api_url": "http://${PROWL_HOST}:${PROWL_PORT}", "api_key": "${PROWL_KEY}"}' WHERE app_type='prowlarr';
COMMIT;
SQL
  echo "Starting Huntarr container..."
  docker compose -f "${COMPOSE_FILE}" up -d huntarr || true
  echo "Waiting a few seconds for Huntarr to come up..."
  sleep 6
  echo "DB fallback complete."
  return 0
}

# Create account (idempotent: treat "User already exists" as success)
body=$(printf '{"username":"%s","password":"%s","confirm_password":"%s"}' "${HUNTARR_ADMIN_USER}" "${HUNTARR_ADMIN_PASS}" "${HUNTARR_ADMIN_PASS}")
resp=$(http_post_with_status "/setup" "${body}") || true
if [ "${LAST_STATUS:-0}" = "200" ] || printf '%s' "${resp}" | grep -q '"success":true'; then
  echo "Admin user created or already existed."
else
  # check for user exists message in JSON
  if printf '%s' "${resp}" | grep -q 'User already exists'; then
    echo "User already exists; continuing."
  else
    echo "Setup user creation failed (status ${LAST_STATUS}). Response: ${resp}"
    exit 3
  fi
fi

# Optionally skip 2FA generation/verification — the UI allows skipping; preserve default to skip
if [ "${SKIP_2FA}" != "true" ]; then
  echo "Generating 2FA for ${HUNTARR_ADMIN_USER}..."
  twofa=$(post_json "/api/user/2fa/setup" "{}") || true
  echo "2FA response: ${twofa}"
  # verification would require user input; leave for manual step unless SKIP_2FA=false and calling verify is desired
fi

# Set basic general settings (idempotent)
echo "Saving general settings (auth_mode=standard)..."
gen_body='{"base_url":"","auth_mode":"standard","local_access_bypass":false,"proxy_auth_bypass":false}'
gen_resp=$(post_json "/api/settings/general" "${gen_body}") || true
echo "General settings response: ${gen_resp}"

# Helper: read value from media/.env with default
get_env_var(){
  # $1 = VAR name, $2 = default
  local val
  if [ -f media/.env ]; then
    val=$(grep -E "^${1}=" media/.env | tail -n1 | cut -d'=' -f2- || true)
  fi
  printf '%s' "${val:-$2}"
}

# Configure integrated services: Prowlarr, Sonarr, Radarr (idempotent)
echo "Configuring Prowlarr/Sonarr/Radarr in Huntarr..."
# Ensure API keys are available (sourced from credentials file earlier)
PROWL_KEY="${PROWLARR_API_KEY:-}"
SONARR_KEY="${SONARR_API_KEY:-}"
RADARR_KEY="${RADARR_API_KEY:-}"

PROWL_HOST=$(get_env_var IP_PROWLARR "172.39.0.8")
PROWL_PORT=$(get_env_var PROWLARR_PORT "9696")
SONARR_HOST=$(get_env_var IP_SONARR "172.39.0.3")
SONARR_PORT=$(get_env_var SONARR_PORT "8989")
RADARR_HOST=$(get_env_var IP_RADARR "172.39.0.4")
RADARR_PORT=$(get_env_var RADARR_PORT "7878")

if [ -n "${PROWL_KEY}" ]; then
  PROWL_URL="http://${PROWL_HOST}:${PROWL_PORT}"
  echo "  Setting Prowlarr -> ${PROWL_URL}"
  prowl_payload=$(printf '{"prowlarr":{"api_key":"%s","api_url":"%s","enabled":true,"name":"Prowlarr"}}' "${PROWL_KEY}" "${PROWL_URL}")
  prowl_resp=$(post_json "/api/settings/general" "${prowl_payload}") || true
  echo "  Prowlarr response: ${prowl_resp}"
fi

if [ -n "${SONARR_KEY}" ]; then
  SONARR_URL="http://${SONARR_HOST}:${SONARR_PORT}"
  echo "  Adding Sonarr instance -> ${SONARR_URL}"
  sonarr_payload=$(printf '{"sonarr":{"instances":[{"api_key":"%s","api_url":"%s","enabled":true,"name":"Sonarr"}]}}' "${SONARR_KEY}" "${SONARR_URL}")
  sonarr_resp=$(post_json "/api/settings/general" "${sonarr_payload}") || true
  echo "  Sonarr response: ${sonarr_resp}"
fi

if [ -n "${RADARR_KEY}" ]; then
  RADARR_URL="http://${RADARR_HOST}:${RADARR_PORT}"
  echo "  Adding Radarr instance -> ${RADARR_URL}"
  radarr_payload=$(printf '{"radarr":{"instances":[{"api_key":"%s","api_url":"%s","enabled":true,"name":"Radarr"}]}}' "${RADARR_KEY}" "${RADARR_URL}")
  radarr_resp=$(post_json "/api/settings/general" "${radarr_payload}") || true
  echo "  Radarr response: ${radarr_resp}"
fi

# Optionally generate recovery key (only if enabled)
if [ "${SKIP_RECOVERY}" != "true" ]; then
  echo "Generating recovery key..."
  rec_body=$(printf '{"password":"%s","setup_mode":true}' "${HUNTARR_ADMIN_PASS}")
  rec_resp=$(post_json "/auth/recovery-key/generate" "${rec_body}") || true
  echo "Recovery response: ${rec_resp}"
fi

# Save setup progress server-side so UI will not redirect to setup
echo "Saving server-side setup progress..."
progress='{"progress":{"current_step":6,"completed_steps":[1,2,3,4,5],"account_created":true,"two_factor_enabled":false,"plex_setup_done":false,"auth_mode_selected":true,"recovery_key_generated":false,"username":"'${HUNTARR_ADMIN_USER}'"}}'
prog_resp=$(post_json "/api/setup/progress" "${progress}") || true
echo "Progress save response: ${prog_resp}"

# Clear setup to finalize
echo "Clearing setup progress (finalize)..."
clear_resp=$(post_json "/api/setup/clear" "{}") || true
echo "Clear response: ${clear_resp}"

echo "Huntarr setup automation completed."

# After setup, verify instances
verify_instances

exit 0
