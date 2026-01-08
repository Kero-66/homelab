#!/usr/bin/env bash
set -euo pipefail

# Generates/updates apps/homepage/.env with API keys read from media service configs
# Safe to run multiple times. Does not commit or push secrets.

# Resolve paths relative to this script for robustness
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MEDIA_DIR="$SCRIPT_ROOT/../../media"
OUT_ENV="$SCRIPT_ROOT/.env"
TMP_ENV="${OUT_ENV}.tmp"

mkdir -p "$(dirname "$OUT_ENV")"
: > "$TMP_ENV"

# helper: write or update a key=value in TMP
write_kv() {
  local key="$1" value="$2"
  if [[ -z "$value" ]]; then
    return
  fi
  # Escape any % or newline just in case
  printf '%s=%s\n' "$key" "$value" >> "$TMP_ENV"
}

# RADARR: try config.xml first, fallback to media/.env
RADARR_API_KEY=""
if [[ -f "$MEDIA_DIR/radarr/config.xml" ]]; then
  RADARR_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$MEDIA_DIR/radarr/config.xml" | tr -d '[:space:]' || true)
fi
if [[ -z "$RADARR_API_KEY" && -f "$MEDIA_DIR/.env" ]]; then
  RADARR_API_KEY=$(grep -E '^RADARR_API_KEY=' "$MEDIA_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi
write_kv "RADARR_API_KEY" "$RADARR_API_KEY"

# PROWLARR
PROWLARR_API_KEY=""
if [[ -f "$MEDIA_DIR/prowlarr/config.xml" ]]; then
  PROWLARR_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$MEDIA_DIR/prowlarr/config.xml" | tr -d '[:space:]' || true)
fi
if [[ -z "$PROWLARR_API_KEY" && -f "$MEDIA_DIR/.env" ]]; then
  PROWLARR_API_KEY=$(grep -E '^PROWLARR_API_KEY=' "$MEDIA_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi
write_kv "PROWLARR_API_KEY" "$PROWLARR_API_KEY"

# SONARR (optional)
SONARR_API_KEY=""
if [[ -f "$MEDIA_DIR/sonarr/config.xml" ]]; then
  SONARR_API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$MEDIA_DIR/sonarr/config.xml" | tr -d '[:space:]' || true)
fi
if [[ -z "$SONARR_API_KEY" && -f "$MEDIA_DIR/.env" ]]; then
  SONARR_API_KEY=$(grep -E '^SONARR_API_KEY=' "$MEDIA_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi
write_kv "SONARR_API_KEY" "$SONARR_API_KEY"

# BAZARR
BAZARR_API_KEY=""
if [[ -f "$MEDIA_DIR/bazarr/config/config.yaml" ]]; then
  # find first occurrence of apikey under auth block
  BAZARR_API_KEY=$(grep -E '^[[:space:]]*apikey:' "$MEDIA_DIR/bazarr/config/config.yaml" | head -n1 | sed -E 's/^[[:space:]]*apikey:[[:space:]]*//' || true)
fi
if [[ -z "$BAZARR_API_KEY" && -f "$MEDIA_DIR/.env" ]]; then
  BAZARR_API_KEY=$(grep -E '^BAZARR_API_KEY=' "$MEDIA_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi
write_kv "BAZARR_API_KEY" "$BAZARR_API_KEY"

# SABNZBD
SABNZBD_API_KEY=""
SABNZBD_INI="$MEDIA_DIR/sabnzbd/sabnzbd.ini"
if [[ -f "$SABNZBD_INI" ]]; then
  # Credentials and IPs: Copy everything homepage needs from media stack
  CRED_FILE="$MEDIA_DIR/.config/.credentials"

  # Automate security hardening (ensure Homepage and Reverse Proxy can work)
  # Set inet_exposure = 0 (Full access) to allow browser UI through the proxy
  sed -i 's/^inet_exposure =.*/inet_exposure = 0/' "$SABNZBD_INI"
  sed -i 's|^local_ranges =.*|local_ranges = 127.0.0.1, 10.0.0.0/8, 172.0.0.0/8, 192.168.0.0/16|' "$SABNZBD_INI"
  sed -i 's|^host_whitelist =.*|host_whitelist = sabnzbd, sabnzbd:8080, localhost, localhost:80, localhost:8085, 127.0.0.1, 10.0.0.0/8, 172.0.0.0/8, 192.168.0.0/16|' "$SABNZBD_INI"
  # Ensure it listens on all interfaces (IPv4 and IPv6)
  sed -i 's/^host =.*/host = ::/' "$SABNZBD_INI"
  # Set url_base to match proxy path
  sed -i 's|^url_base =.*|url_base = /sabnzbd|' "$SABNZBD_INI"
  # Set download paths relative to /data
  sed -i 's|^download_dir = .*|download_dir = /data/downloads/sabnzbd/intermediate|' "$SABNZBD_INI"
  sed -i 's|^complete_dir = .*|complete_dir = /data/downloads/sabnzbd/completed|' "$SABNZBD_INI"
  sed -i 's|^nzb_backup_dir = .*|nzb_backup_dir = /data/downloads/sabnzbd/nzb_backup|' "$SABNZBD_INI"

  # Inject Easynews server from credentials
  EASYNEWS_USER=$(grep -E "^EASYNEWS_USER=" "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
  EASYNEWS_PASS=$(grep -E "^EASYNEWS_PASS=" "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)

  if [[ -n "$EASYNEWS_USER" && -n "$EASYNEWS_PASS" ]]; then
    # Ensure [servers] section exists
    if ! grep -q "\[servers\]" "$SABNZBD_INI"; then
      echo -e "\n[servers]" >> "$SABNZBD_INI"
    fi
    
    # Remove all indexed servers to ensure a clean state
    # This deletes everything from [[...]] blocks until the next section or dummy notes
    sed -i '/^\[\[.*\]\]/,/notes = ""/d' "$SABNZBD_INI"
    sed -i '/^\[\[.*\]\]/,/priority = 0/d' "$SABNZBD_INI"

    # Create a temporary file for the server configuration
    # Connections set to 20 as per Easynews guide recommendation
    SAB_SERVER_TMP=$(mktemp)
    cat <<EOF > "$SAB_SERVER_TMP"
[[news.easynews.com]]
name = easynews
displayname = easynews
host = news.easynews.com
port = 563
timeout = 60
username = $EASYNEWS_USER
password = $EASYNEWS_PASS
connections = 20
ssl = 1
ssl_verify = 2
ssl_ciphers = ""
enable = 1
required = 0
optional = 0
retention = 0
expire_date = ""
quota = ""
usage_at_start = 0
priority = 0
notes = ""
EOF
    # Insert the server block immediately after [servers]
    sed -i '/^\[servers\]/r '"$SAB_SERVER_TMP" "$SABNZBD_INI"
    rm -f "$SAB_SERVER_TMP"
  fi
  
  SABNZBD_API_KEY=$(grep -E '^api_key =' "$SABNZBD_INI" | cut -d'=' -f2- | tr -d ' ' || true)
fi
if [[ -z "$SABNZBD_API_KEY" && -f "$MEDIA_DIR/.env" ]]; then
  SABNZBD_API_KEY=$(grep -E '^SABNZBD_API_KEY=' "$MEDIA_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi
write_kv "SABNZBD_API_KEY" "$SABNZBD_API_KEY"

# Also update the main media/.env if it has placeholders
if [[ -f "$MEDIA_DIR/.env" && -n "$SABNZBD_API_KEY" ]]; then
  sed -i "s|^SABNZBD_API_KEY=.*|SABNZBD_API_KEY=${SABNZBD_API_KEY}|" "$MEDIA_DIR/.env"
fi

# Credentials and IPs: Copy everything homepage needs from media stack
CRED_FILE="$MEDIA_DIR/.config/.credentials"
MEDIA_ENV="$MEDIA_DIR/.env"

copy_from_file() {
  local key="$1" file="$2"
  if [[ -f "$file" ]]; then
    local val=$(grep -E "^${key}=" "$file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
    if [[ -n "$val" ]]; then
      write_kv "$key" "$val"
    fi
  fi
}

# Pull everything mentioned in compose.yaml to avoid "variable not set" warnings
copy_from_file "JELLYFIN_API_KEY" "$CRED_FILE"
copy_from_file "JELLYSEERR_API_KEY" "$CRED_FILE"
copy_from_file "JACKETT_PASS" "$CRED_FILE"
copy_from_file "JACKETT_API_KEY" "$CRED_FILE"
copy_from_file "JELLYSTAT_API_KEY" "$CRED_FILE"
copy_from_file "HUNTARR_API_KEY" "$CRED_FILE"
copy_from_file "CLEANUPARR_API_KEY" "$CRED_FILE"

# IP Addresses from media/.env
if [[ -f "$MEDIA_ENV" ]]; then
  while read -r ip_var; do
    copy_from_file "$ip_var" "$MEDIA_ENV"
  done < <(grep -oE '^IP_[A-Z_]+' "$MEDIA_ENV" || true)
fi

# Credentials: copy specific or generic PASSWORD/USERNAME into service-specific env vars
GENERIC_PASSWORD=""
GENERIC_USERNAME=""
if [[ -f "$CRED_FILE" ]]; then
  GENERIC_PASSWORD=$(grep -E '^PASSWORD=' "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
  GENERIC_USERNAME=$(grep -E '^USERNAME=' "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
  
  QBIT_USER=$(grep -E '^QBITTORRENT_USER=' "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
  QBIT_PASS=$(grep -E '^QBITTORRENT_PASS=' "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
  NZB_USER=$(grep -E '^NZBGET_USER=' "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
  NZB_PASS=$(grep -E '^NZBGET_PASS=' "$CRED_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
fi

write_kv "QBITTORRENT_USER" "${QBIT_USER:-$GENERIC_USERNAME}"
write_kv "QBITTORRENT_PASS" "${QBIT_PASS:-$GENERIC_PASSWORD}"
write_kv "NZBGET_USER" "${NZB_USER:-$GENERIC_USERNAME}"
write_kv "NZBGET_PASS" "${NZB_PASS:-$GENERIC_PASSWORD}"

# Write out or update the resulting env: preserve existing values in apps/homepage/.env by replacing specific keys
if [[ ! -f "$OUT_ENV" ]]; then
  # create a minimal file copying static defaults (if any) from template or leave blank
  : > "$OUT_ENV"
fi
# For each key in TMP_ENV, replace or append in OUT_ENV
while IFS= read -r line; do
  k=$(echo "$line" | cut -d= -f1)
  v=$(echo "$line" | cut -d= -f2-)
  if grep -q "^${k}=" "$OUT_ENV"; then
    sed -i "s|^${k}=.*|${k}=${v}|" "$OUT_ENV"
  else
    echo "${k}=${v}" >> "$OUT_ENV"
  fi
done < "$TMP_ENV"
# If TMP_ENV was empty, no changes are made
rm -f "$TMP_ENV"


# Render services.yaml: substitute ${VAR} placeholders using the generated env file
CONFIG_DIR="$SCRIPT_ROOT/config"
SERV_FILE="$CONFIG_DIR/services.yaml"
if [[ -f "$SERV_FILE" ]] && grep -q '\${' "$SERV_FILE"; then
  # backup original for safety
  cp -a "$SERV_FILE" "$SERV_FILE.bak"
  # export variables from OUT_ENV and media env/credentials into environment, then envsubst
  set -a
  # shellcheck disable=SC1090
  if [[ -f "$OUT_ENV" ]]; then
    source "$OUT_ENV"
  fi
  if [[ -f "$MEDIA_DIR/.env" ]]; then
    # shellcheck disable=SC1090
    source "$MEDIA_DIR/.env"
  fi
  if [[ -f "$CRED_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CRED_FILE"
  fi
  set +a
  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$SERV_FILE" > "$SERV_FILE.tmp" && mv "$SERV_FILE.tmp" "$SERV_FILE"
  else
    # fallback: use perl to replace ${VAR} tokens
    perl -pe 's/\$\{([A-Z0-9_]+)\}/$ENV{$1} || ""/ge' "$SERV_FILE" > "$SERV_FILE.tmp" && mv "$SERV_FILE.tmp" "$SERV_FILE"
  fi
fi

# cleanup
rm -f "$TMP_ENV"

echo "Generated/updated $OUT_ENV"

exit 0
