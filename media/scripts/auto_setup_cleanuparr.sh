#!/usr/bin/env bash
set -euo pipefail

# Auto-setup helper for CleanupArr
# - Reads CLEANUPARR_API_KEY from env or media/.config/.credentials
# - Waits for the service to become reachable and probes common API endpoints
# - Does not create rules by default; can accept RULE_JSON env to POST to /api/rules

CREDENTIALS_FILE="media/.config/.credentials"
CLEANUPARR_URL="${CLEANUPARR_URL:-http://127.0.0.1:11011}"
CLEANUPARR_API_KEY="${CLEANUPARR_API_KEY:-}"
MAX_WAIT="${MAX_WAIT:-300}"
SLEEP_INTERVAL=3

if [ -z "${CLEANUPARR_API_KEY}" ]; then
  if [ -f "${CREDENTIALS_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${CREDENTIALS_FILE}" || true
    CLEANUPARR_API_KEY="${CLEANUPARR_API_KEY:-}" 
  fi
fi

if [ -z "${CLEANUPARR_API_KEY}" ]; then
  echo "CLEANUPARR_API_KEY must be set (env or ${CREDENTIALS_FILE})"
  exit 1
fi

echo "Waiting for CleanupArr at ${CLEANUPARR_URL} ..."
start_ts=$(date +%s)
while true; do
  if curl -s -I "${CLEANUPARR_URL}/" >/dev/null 2>&1; then
    echo "CleanupArr reachable."
    break
  fi
  now_ts=$(date +%s)
  if [ $((now_ts - start_ts)) -ge "${MAX_WAIT}" ]; then
    echo "Timeout waiting for CleanupArr (${MAX_WAIT} seconds)."
    exit 2
  fi
  sleep "${SLEEP_INTERVAL}"
done

# Probe common endpoints
endpoints=("/api/v1/status" "/api/status" "/api/v1/info" "/api/version" "/api/v1/version" "/api/health" "/api")
success=0
for ep in "${endpoints[@]}"; do
  out=$(curl -s -w "\n%{http_code}" -H "X-Api-Key: ${CLEANUPARR_API_KEY}" "${CLEANUPARR_URL}${ep}" || true)
  status=$(printf '%s' "${out}" | tail -n1)
  body=$(printf '%s' "${out}" | sed '$d')
  if [ "${status}" = "200" ]; then
    echo "Endpoint ${ep} OK — status ${status}. Response preview:"
    echo "${body}" | head -n 5
    success=1
    break
  fi
done

if [ "${success}" -ne 1 ]; then
  echo "Warning: no probed endpoint returned HTTP 200. The service may still be initializing or API path differs."
else
  echo "CleanupArr API reachable and authenticated."
fi

# Optional: create a rule if RULE_JSON is provided in env
if [ -n "${RULE_JSON:-}" ]; then
  echo "Posting provided rule to /api/rules"
  resp=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -H "X-Api-Key: ${CLEANUPARR_API_KEY}" -X POST "${CLEANUPARR_URL}/api/rules" -d "${RULE_JSON}" || true)
  status=$(printf '%s' "${resp}" | tail -n1)
  body=$(printf '%s' "${resp}" | sed '$d')
  echo "POST /api/rules status=${status}, body=${body}"
fi

echo "CleanupArr auto-setup probe complete."
exit 0
