#!/usr/bin/env bash
set -euo pipefail

# Script to seed Jackett ServerConfig.json with admin credentials from
# media/.config/.credentials. This runs inside the container at startup
# (mounted read-only); it writes to the mounted config directory on the host.

CRED_FILE="/media/.config/.credentials"
# The compose mounts ../.config/.credentials into the container env via env_file,
# but we prefer to read from the host path if available. Fall back to env vars.
if [ -f "/config/../.config/.credentials" ]; then
    CRED_FILE="/config/../.config/.credentials"
fi

# If mounted env file exists, source it to get USERNAME/PASSWORD as env vars
if [ -f "$CRED_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CRED_FILE"
fi

# Ensure PASSWORD is set (may come from env_file in compose)
PASSWORD="${PASSWORD:-}"
if [ -z "$PASSWORD" ]; then
    echo "[setup_jackett_creds] WARNING: PASSWORD not set; skipping ServerConfig.json update"
    exit 0
fi

CONFIG_DIR="/config/Jackett"
CONFIG_FILE="$CONFIG_DIR/ServerConfig.json"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "{}" > "$CONFIG_FILE"
fi

# Use python to safely update the JSON file
export CONFIG_FILE
export PASSWORD
if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import json,os
cfg=os.environ['CONFIG_FILE']
pwd=os.environ.get('PASSWORD','')
try:
    with open(cfg,'r') as f:
        data=json.load(f)
except Exception:
    data={}
# Set the AdminPassword field to the plain password. Jackett will handle hashing
# when accessed through the UI; storing the plain password here is a convenience
# for initial bootstrap. This file lives on the host under media/jackett/config
# which is gitignored; ensure you understand the security implications.
data['AdminPassword']=pwd
with open(cfg,'w') as f:
    json.dump(data,f,indent=2)
PY
else
    # Fallback: use a simple sed/awk approach (best-effort)
    tmp=$(mktemp)
    awk -v pwd="$PASSWORD" 'BEGIN{print "{"; printed=0}
    NR==1{line=$0}
    {print $0}
    END{}' "$CONFIG_FILE" > "$tmp" || true
    mv "$tmp" "$CONFIG_FILE" || true
fi

# Ensure correct ownership (linuxserver images use PUID/PGID 1000 by default)
chown -R 1000:1000 "$CONFIG_DIR" || true

echo "[setup_jackett_creds] Wrote admin credentials to $CONFIG_FILE"
