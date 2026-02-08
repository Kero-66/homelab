#!/usr/bin/env bash
set -euo pipefail

# This script generates seeded config files for qBittorrent and arr apps
# using values from media/.config/.credentials and media/.env (for DATA_DIR).
# It writes into media/.config/* and can optionally copy into live config dirs.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$MEDIA_DIR/.config"
CRED_FILE="$CONFIG_DIR/.credentials"
ENV_FILE="$MEDIA_DIR/.env"

if [[ ! -f "$CRED_FILE" ]]; then
  echo "ERROR: Credentials file not found: $CRED_FILE" >&2
  echo "Create it from template and set USERNAME and PASSWORD." >&2
  exit 1
fi

# Load credentials
source "$CRED_FILE"
: "${USERNAME:?USERNAME missing in .credentials}"
: "${PASSWORD:?PASSWORD missing in .credentials}"

# Load DATA_DIR from .env if present
DATA_DIR="/data"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC2046
  DATA_DIR=$(grep -E "^DATA_DIR=" "$ENV_FILE" | tail -n1 | cut -d'=' -f2)
  DATA_DIR=${DATA_DIR:-/data}
fi

mkdir -p "$CONFIG_DIR/qbittorrent" "$CONFIG_DIR/sonarr" "$CONFIG_DIR/radarr" "$CONFIG_DIR/lidarr" "$CONFIG_DIR/prowlarr" "$CONFIG_DIR/bazarr" "$CONFIG_DIR/cleanuparr"

# Generate PBKDF2 hash for qBittorrent password
echo "Generating PBKDF2 hash for qBittorrent password..."
QBIT_PASSWORD_HASH=$(python3 -c "
import hashlib
import secrets
import base64

password = '$PASSWORD'
salt = secrets.token_bytes(16)
iterations = 100000
hash_obj = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, iterations)
salt_hex = salt.hex()
hash_hex = hash_obj.hex()
print(f'@ByteArray(PBKDF2:SHA512:{iterations}:{salt_hex}:{hash_hex})')
")

# Generate qBittorrent config with directories and WebUI creds
cat > "$CONFIG_DIR/qbittorrent/qBittorrent.conf" <<EOF
[Preferences]
Downloads\\SavePath=$DATA_DIR/downloads/qbittorrent/completed
Downloads\\TempPathEnabled=true
Downloads\\TempPath=$DATA_DIR/downloads/qbittorrent/incomplete
Downloads\\UseIncompleteExtension=true
Downloads\\ExportDir=$DATA_DIR/downloads/qbittorrent/torrents
WebUI\\Enabled=true
WebUI\\Port=${QBIT_WEBUI_PORT:-8080}
WebUI\\Username=$USERNAME
WebUI\\Password_PBKDF2=$QBIT_PASSWORD_HASH
EOF

# Generate config.xml for Arr apps with Forms authentication pre-configured
# This skips the first-run authentication wizard and uses form-based login
echo "Generating Arr app configs with Forms authentication pre-configured..."

# Ensure ApiKeys exist in credentials or import from live configs / generate them
ensure_api_key() {
  local var_name="$1"    # e.g. SONARR_API_KEY
  local live_conf="$2"   # e.g. media/sonarr/config.xml
  # If variable already set (sourced from CRED_FILE), use it
  if [ -n "${!var_name:-}" ]; then
    return 0
  fi
  # Try importing from live config
  if [ -f "$live_conf" ]; then
    val=$(grep -oP '<ApiKey>\K[^<]+' "$live_conf" 2>/dev/null || true)
    if [ -n "$val" ]; then
      echo "Importing $var_name from live config"
      echo "$var_name=$val" >> "$CRED_FILE"
      # export for current shell
      export "$var_name"="$val"
      return 0
    fi
  fi
  # Generate a new key and append to credentials
  newkey=$(python3 - <<PY
import secrets
print(secrets.token_hex(16))
PY
)
  echo "Generating new $var_name"
  echo "$var_name=$newkey" >> "$CRED_FILE"
  export "$var_name"="$newkey"
}

# Create or import keys for each Arr app
ensure_api_key SONARR_API_KEY "$MEDIA_DIR/sonarr/config.xml"
ensure_api_key RADARR_API_KEY "$MEDIA_DIR/radarr/config.xml"
ensure_api_key LIDARR_API_KEY "$MEDIA_DIR/lidarr/config.xml"
ensure_api_key PROWLARR_API_KEY "$MEDIA_DIR/prowlarr/config.xml"
ensure_api_key CLEANUPARR_API_KEY "$MEDIA_DIR/cleanuparr/config.yml"


cat > "$CONFIG_DIR/sonarr/config.xml" <<EOF
<Config>
  <BindAddress>*</BindAddress>
  <Port>8989</Port>
  <SslPort>9898</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>True</LaunchBrowser>
  <ApiKey>${SONARR_API_KEY}</ApiKey>
  <AuthenticationMethod>forms</AuthenticationMethod>
  <AuthenticationRequired>Enabled</AuthenticationRequired>
  <Branch>main</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <InstanceName>Sonarr</InstanceName>
  <UpdateMechanism>Docker</UpdateMechanism>
</Config>
EOF

cat > "$CONFIG_DIR/radarr/config.xml" <<EOF
<Config>
  <BindAddress>*</BindAddress>
  <Port>7878</Port>
  <SslPort>6868</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>True</LaunchBrowser>
  <ApiKey>${RADARR_API_KEY}</ApiKey>
  <AuthenticationMethod>forms</AuthenticationMethod>
  <AuthenticationRequired>Enabled</AuthenticationRequired>
  <Branch>master</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <InstanceName>Radarr</InstanceName>
  <UpdateMechanism>Docker</UpdateMechanism>
</Config>
EOF

cat > "$CONFIG_DIR/lidarr/config.xml" <<EOF
<Config>
  <BindAddress>*</BindAddress>
  <Port>8686</Port>
  <SslPort>6868</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>True</LaunchBrowser>
  <ApiKey>${LIDARR_API_KEY}</ApiKey>
  <AuthenticationMethod>forms</AuthenticationMethod>
  <AuthenticationRequired>Enabled</AuthenticationRequired>
  <Branch>master</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <InstanceName>Lidarr</InstanceName>
  <UpdateMechanism>Docker</UpdateMechanism>
</Config>
EOF

cat > "$CONFIG_DIR/prowlarr/config.xml" <<EOF
<Config>
  <BindAddress>*</BindAddress>
  <Port>9696</Port>
  <SslPort>6969</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>True</LaunchBrowser>
  <ApiKey>${PROWLARR_API_KEY}</ApiKey>
  <AuthenticationMethod>forms</AuthenticationMethod>
  <AuthenticationRequired>Enabled</AuthenticationRequired>
  <Branch>master</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <InstanceName>Prowlarr</InstanceName>
  <UpdateMechanism>Docker</UpdateMechanism>
</Config>
EOF

cat > "$CONFIG_DIR/bazarr/config.yaml" <<EOF
# Bazarr configuration
general:
  ip: 0.0.0.0
  port: 6767
  base_url: ''
auth:
  type: none
EOF

# Generate CleanupArr sample config
cat > "$CONFIG_DIR/cleanuparr/config.yml" <<EOF
# CleanupArr minimal config (seeded)
bind_address: 0.0.0.0
port: ${CLEANUPARR_PORT:-8002}
api_key: ${CLEANUPARR_API_KEY}
paths:
  media_root: ${DATA_DIR:-/data}
# Add cleanup rules below as needed
EOF

# Generate root folder configs for Arr apps
# These will be imported on first startup
echo "Generating root folder configs for Arr apps..."

cat > "$CONFIG_DIR/sonarr/rootfolders.xml" <<EOF
<RootFolders>
  <RootFolder>
    <Path>$DATA_DIR/shows</Path>
  </RootFolder>
</RootFolders>
EOF

cat > "$CONFIG_DIR/radarr/rootfolders.xml" <<EOF
<RootFolders>
  <RootFolder>
    <Path>$DATA_DIR/movies</Path>
  </RootFolder>
</RootFolders>
EOF

cat > "$CONFIG_DIR/lidarr/rootfolders.xml" <<EOF
<RootFolders>
  <RootFolder>
    <Path>$DATA_DIR/music</Path>
  </RootFolder>
</RootFolders>
EOF

echo ""
echo "Seed configs generated in $CONFIG_DIR."
echo ""
echo "To use these configs, run: bash init_configs.sh"
echo "This will copy configs to service directories before first start."
echo ""
echo "qBittorrent also has optional read-only mounts in compose.yaml."
