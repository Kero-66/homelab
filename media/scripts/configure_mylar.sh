#!/usr/bin/env bash
set -euo pipefail

# Idempotent Mylar configuration helper
# - ensures API key exists
# - aligns destination/import dirs to /data/books
# - normalizes qBittorrent and NZBGet settings
# - sets client downloader IDs (qBittorrent=0, NZBGet=3)
# - enables Prowlarr integration (uses PROWLARR_API_KEY and IP_PROWLARR from .env)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

# load environment
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

# load optional credentials and make them available to child processes
if [[ -f .config/.credentials ]]; then
    set -a
    source .config/.credentials || true
    set +a
fi

CONFIG_FILE="${CONFIG_DIR:-.}/mylar3/mylar/config.ini"
mkdir -p "$(dirname "$CONFIG_FILE")"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Mylar config missing at $CONFIG_FILE; creating a minimal config"
  cat > "$CONFIG_FILE" <<EOF
[Interface]
http_host = 0.0.0.0
http_port = 8090
http_username = ${MYLAR3_USER:-}
http_password = ${MYLAR3_PASS:-}

[API]
api_enabled = True
api_key = 

[Import]
comic_dir = /data/books

[Client]
# 0 = qBittorrent, 3 = NZBGet
torrent_downloader = 0
nzb_downloader = 3
EOF
fi

echo "Configuring Mylar at $CONFIG_FILE"
python3 - <<PY
import os
from configparser import ConfigParser
cfg = ConfigParser()
cfg.optionxform = str
path = os.path.expanduser('$CONFIG_FILE')
cfg.read(path)

def ensure(s):
    if not cfg.has_section(s):
        cfg.add_section(s)

# General/destination
ensure('General')
cfg['General']['create_folders'] = 'True'
cfg['General']['destination_dir'] = '/data/books'

# Interface
ensure('Interface')
cfg['Interface']['http_host'] = os.environ.get('MYLAR3_HOST','0.0.0.0')
cfg['Interface']['http_port'] = os.environ.get('MYLAR3_PORT','8090')
cfg['Interface']['http_username'] = os.environ.get('MYLAR3_USER','') or ''
cfg['Interface']['http_password'] = os.environ.get('MYLAR3_PASS','') or ''
cfg['Interface']['authentication'] = '1'

# API
ensure('API')
cfg['API']['api_enabled'] = 'True'
env_api = os.environ.get('MYLAR3_API_KEY','')
if env_api:
    cfg['API']['api_key'] = env_api
else:
    existing = cfg['API'].get('api_key','') if cfg.has_option('API','api_key') else ''
    if not existing or existing.lower() in ('none','null',''):
        import secrets
        cfg['API']['api_key'] = secrets.token_hex(16)

# Import
ensure('Import')
cfg['Import']['comic_dir'] = '/data/books'

# NZBGet
ensure('NZBGet')
cfg['NZBGet']['nzbget_host'] = os.environ.get('NZBGET_HOST','nzbget')
cfg['NZBGet']['nzbget_port'] = os.environ.get('NZBGET_PORT','6789')
cfg['NZBGet']['nzbget_username'] = os.environ.get('USERNAME','') or ''
cfg['NZBGet']['nzbget_password'] = os.environ.get('PASSWORD','') or ''

# qBittorrent
ensure('qBittorrent')
qhost = os.environ.get('QBITTORRENT_HOST','qbittorrent')
qport = os.environ.get('QBIT_WEBUI_PORT','8080')
# prefer hostnames (container names) with scheme
cfg['qBittorrent']['qbittorrent_host'] = f'http://{qhost}:{qport}'
cfg['qBittorrent']['qbittorrent_username'] = os.environ.get('USERNAME','') or ''
cfg['qBittorrent']['qbittorrent_password'] = os.environ.get('PASSWORD','') or ''

# Client flags
ensure('Client')
cfg['Client']['torrent_downloader'] = '0'
cfg['Client']['nzb_downloader'] = '3'

# ComicVine
ensure('CV')
cv_key = os.environ.get('MYLAR_COMICVINE_API','').strip()
if cv_key:
    cfg['CV']['comicvine_api'] = cv_key
    cfg['CV']['cv_verify'] = 'True'

# Enable torrents/search
ensure('Torrents')
cfg['Torrents']['enable_torrents'] = 'True'
cfg['Torrents']['enable_torrent_search'] = 'True'

# Enable Prowlarr integration if api key present
ensure('Prowl')
if os.environ.get('PROWLARR_API_KEY'):
    cfg['Prowl']['prowl_enabled'] = 'True'
else:
    cfg['Prowl']['prowl_enabled'] = cfg['Prowl'].get('prowl_enabled','False')

# Write Prowlarr section (separate block used by some installs)
ensure('Prowlarr')
if os.environ.get('PROWLARR_API_KEY'):
    prowl_url = os.environ.get('IP_PROWLARR','172.39.0.8')
    prowl_port = os.environ.get('PROWLARR_PORT','9696')
    cfg['Prowlarr']['url'] = f'http://{prowl_url}:{prowl_port}'
    cfg['Prowlarr']['api_key'] = os.environ.get('PROWLARR_API_KEY')

# remove any stray numeric-only client values that look off
if cfg.has_section('Client'):
    if cfg['Client'].get('nzb_downloader') in ('1','5','None'):
        cfg['Client']['nzb_downloader'] = '3'
    if cfg['Client'].get('torrent_downloader') in ('5','None'):
        cfg['Client']['torrent_downloader'] = '0'

with open(path,'w') as fh:
    cfg.write(fh)
print('Mylar config updated at', path)
PY

# Restart container to pick up changes
echo "Restarting mylar3 container"
docker compose -f "${MEDIA_DIR}/compose.yaml" restart mylar3 || true

echo "Done. You can test the API with: curl -i \"http://localhost:${MYLAR3_PORT:-8090}/api?apikey=<APIKEY>&cmd=getVersion\""
