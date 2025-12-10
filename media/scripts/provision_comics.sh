#!/usr/bin/env bash
set -euo pipefail

# Locate script and media directory, and load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# Load .env if present
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

# Load credentials if present
if [[ -f .config/.credentials ]]; then
  # file sets USERNAME and PASSWORD variables used by download-client scripts
  source .config/.credentials
fi

# Provision comics/manga/webtoons services as much as possible via APIs and config files.
# - creates library folders
# - writes a basic Mylar3 config and API key
# Generate a Mylar3 API key if not set in config
MY3_CONFIG_DIR="${CONFIG_DIR:-.}/mylar3/mylar"
MY3_CONFIG_FILE="$MY3_CONFIG_DIR/config.ini"
mkdir -p "$MY3_CONFIG_DIR"

# Ensure host-side books dir exists and map inside container as /data/books
mkdir -p "${BOOKS_DIR}"

# Helper to obtain credentials from .config/.credentials or environment
CREDS_FILE="${CONFIG_DIR:-.}/.config/.credentials"
if [[ -f .config/.credentials ]]; then
  # already sourced earlier in script; USERNAME and PASSWORD variables may be set
  :
fi

if [[ -f "$MY3_CONFIG_FILE" ]]; then
  echo "Patching existing Mylar3 config at $MY3_CONFIG_FILE"
  python3 - <<PY
import os
from configparser import ConfigParser
cfg = ConfigParser()
cfg.optionxform = str
path = os.path.expanduser('${MY3_CONFIG_FILE}')
cfg.read(path)

def ensure_section(s):
    if not cfg.has_section(s):
        cfg.add_section(s)

ensure_section('General')
cfg['General']['create_folders'] = 'True'
cfg['General']['destination_dir'] = '/data/books'

ensure_section('Interface')
cfg['Interface']['http_host'] = os.environ.get('MYLAR3_HOST','0.0.0.0')
cfg['Interface']['http_port'] = os.environ.get('MYLAR3_PORT','8090')
cfg['Interface']['http_username'] = os.environ.get('MYLAR3_USER','') or ''
cfg['Interface']['http_password'] = os.environ.get('MYLAR3_PASS','') or ''

ensure_section('API')
cfg['API']['api_enabled'] = 'True'
env_api = os.environ.get('MYLAR3_API_KEY','')
if env_api:
    cfg['API']['api_key'] = env_api
else:
    existing = cfg['API'].get('api_key','') if cfg.has_option('API','api_key') else ''
    if not existing or existing.lower() in ('none','null',''):
        import secrets
        cfg['API']['api_key'] = secrets.token_hex(16)

ensure_section('Import')
# Mylar container mounts ${DATA_DIR} at /data
cfg['Import']['comic_dir'] = '/data/books'

ensure_section('NZBGet')
cfg['NZBGet']['nzbget_host'] = os.environ.get('NZBGET_HOST','nzbget')
cfg['NZBGet']['nzbget_port'] = os.environ.get('NZBGET_PORT','6789')
cfg['NZBGet']['nzbget_username'] = os.environ.get('USERNAME','') or ''
cfg['NZBGet']['nzbget_password'] = os.environ.get('PASSWORD','') or ''

ensure_section('qBittorrent')
qhost = os.environ.get('QBITTORRENT_HOST','qbittorrent')
qport = os.environ.get('QBIT_WEBUI_PORT','8080')
cfg['qBittorrent']['qbittorrent_host'] = f'http://{qhost}:{qport}'
cfg['qBittorrent']['qbittorrent_username'] = os.environ.get('USERNAME','') or ''
cfg['qBittorrent']['qbittorrent_password'] = os.environ.get('PASSWORD','') or ''

ensure_section('Torrents')
cfg['Torrents']['enable_torrents'] = 'True'
cfg['Torrents']['enable_torrent_search'] = 'True'

ensure_section('Client')
# 0 = qBittorrent, 3 = NZBGet (matches Mylar expected codes)
cfg['Client']['torrent_downloader'] = '0'
cfg['Client']['nzb_downloader'] = '3'

# Optional: placeholder for ComicVine API key
ensure_section('CV')
if os.environ.get('COMICVINE_API_KEY'):
    cfg['CV']['comicvine_api'] = os.environ.get('COMICVINE_API_KEY')
else:
    # preserve existing if set; otherwise leave blank
    pass

with open(path,'w') as fh:
    cfg.write(fh)
print('Patched')
PY
else
  echo "Writing new Mylar3 config to $MY3_CONFIG_FILE"
  GENERATED_API_KEY=$(python3 - <<PY
import secrets
print(secrets.token_hex(16))
PY
)
  export GENERATED_API_KEY
  cat > "$MY3_CONFIG_FILE" <<EOF
[General]
create_folders = True
destination_dir = /data/books

[Interface]
http_host = 0.0.0.0
http_port = 8090
http_username = ${MYLAR3_USER:-}
http_password = ${MYLAR3_PASS:-}

[API]
api_enabled = True
api_key = ${MYLAR3_API_KEY:-$GENERATED_API_KEY}

[Import]
comic_dir = /data/books

[NZBGet]
nzbget_host = ${NZBGET_HOST:-nzbget}
nzbget_port = ${NZBGET_PORT:-6789}
nzbget_username = ${USERNAME:-}
nzbget_password = ${PASSWORD:-}

[qBittorrent]
qbittorrent_host = http://${QBITTORRENT_HOST:-qbittorrent}:${QBIT_WEBUI_PORT:-8080}
qbittorrent_username = ${USERNAME:-}
qbittorrent_password = ${PASSWORD:-}
qbittorrent_folder = 
qbittorrent_loadaction = default

[Torrents]
enable_torrents = True
enable_torrent_search = True

[Client]
# 0 = qBittorrent, 3 = NZBGet
torrent_downloader = 0
nzb_downloader = 3

[Prowlarr]
enabled = true
url = http://${IP_PROWLARR:-172.39.0.8}:${PROWLARR_PORT:-9696}
api_key = ${PROWLARR_API_KEY:-}

[CV]
comicvine_api = ${COMICVINE_API_KEY:-}
EOF
fi

# Restart mylar3 to pick up config changes (use absolute compose path)
echo "Restarting mylar3 container to apply config changes"
docker compose -f "${MEDIA_DIR}/compose.yaml" restart mylar3 || true

# Configure Prowlarr apps (attempt to add Mylar3 and connect Arr apps)
echo "Configuring Prowlarr integrations (adds FlareSolverr and apps including Mylar3)"
if [[ -x "./scripts/configure_prowlarr.sh" ]]; then
  ./scripts/configure_prowlarr.sh || echo "Warning: configure_prowlarr.sh exited with non-zero"
else
  echo "configure_prowlarr.sh not found or not executable; skipping automated Prowlarr app registration"
fi

echo "Provisioning completed."
echo "Notes:"
echo " - Komga/Kavita/Ubooquity still require a small UI-based first-run for admin user/library mapping in most installs."
echo " - Mylar3 basic config written to: $MY3_CONFIG_FILE"
echo " - If any API calls failed, check logs and run scripts/manual steps in media/scripts/"

exit 0
