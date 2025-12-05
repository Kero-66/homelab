claude# Homelab Project Memory

## Project Overview
- **Repository**: kieranmcjannett-coder/homelab (fork of TechHutTV/homelab)
- **Current Branch**: main
- **Status**: Recently copied from Windows to WSL, git configured and synced

## Current Setup
- Location: /home/kero66/repos/homelab
- Git User: kieranmcjannett-coder (kieranmcjannett-coder@github.local)
- Remote: origin (fork) + upstream (TechHutTV)

> **Note:** Many directories contain detailed `README.md` files authored by the project maintainer. Avoid duplicating large blocks of README content into `memory.md`. Instead, reference the README file (path) and summarize only the key points needed for quick context.

## Directory Structure
- `/apps/` - Application configurations and images
- `/automations/` - n8n automation setup with Docker
- `/cloud/` - Cloud-related services
- `/homeassistant/` - Home Assistant configs (dashboard, localtuya, zigbee)
- `/media/` - Media services (Jellyfin, Plex, arr stack, etc.)
- `/monitoring/` - Prometheus, Grafana, Telegraf monitoring
- `/proxy/` - Nginx Proxy Manager
- `/storage/` - Storage configuration docs and images
- `/surveillance/` - Frigate NVR configuration

## Key Files
- `glance.yml` - Main dashboard configuration
- `compose.yml` files in root and various subdirectories for services
- `README.md` files documenting each service

## Docker Compose Services
All docker compose services have been torn down and volumes removed for fresh start.
Services include: automations, media, monitoring, surveillance, proxy, cloud, etc.

## Project Goals & Scope
- **Primary Focus**: Media server configuration and testing
- **Current Environment**: WSL on desktop
- **Future Target**: Dedicated machine/server
- **Out of Scope (for now)**: automations, cloud, monitoring, surveillance, proxy, homeassistant, storage, apps

## Media Server Architecture
- **Gluetun**: VPN container (AirVPN with WireGuard) - acts as network gateway
- **Download Clients** (run through VPN):
  - qBittorrent (port 8080, torrent port 6881)
  - NZBget (port 6789)
- **Arr Apps** (on servarrnetwork 172.39.0.0/24):
  - Prowlarr (port 9696, IP 172.39.0.8) - Indexer manager
  - Sonarr (port 8989, IP 172.39.0.3) - TV shows
  - Radarr (port 7878, IP 172.39.0.4) - Movies
  - Lidarr (port 8686, IP 172.39.0.5) - Music
  - Bazarr (port 6767, IP 172.39.0.6) - Subtitles
  - NZBget (port 6789, IP 172.39.0.7) - Usenet client
  - qBittorrent (port 8080, IP 172.39.0.12) - Torrent client
  - FlareSolverr (port 8191, IP 172.39.0.9) - Cloudflare bypass
- **Jellyfin Stack** (on servarrnetwork):
  - Jellyfin (port 8096, IP 172.39.0.10) - Media server
  - Jellyseerr (port 5055, IP 172.39.0.11) - Request management
  - Jellystat (port 3000, IP 172.39.0.14) - Statistics
  - Jellystat-db (IP 172.39.0.13) - PostgreSQL database

## Required Configuration
1. **Data Directory**: `/data` with structure:
   ```
   data/
   ├── downloads/
   │   ├── qbittorrent/{completed,incomplete,torrents}
   │   └── nzbget/{completed,intermediate,nzb,queue,tmp}
   ├── movies/
   ├── shows/
   ├── music/
   └── books/
   ```

2. **.env File** (`media/.env`): 
  - PUID/PGID: Unix user/group IDs
  - TZ: Timezone
  - DATA_DIR: Base media data directory (default `/data`)
  - SERVARR_SUBNET: Docker network subnet (default `172.39.0.0/24`)
  - IP_*: Static IPs for each service (defaults provided)
  - *_PORT: Published port numbers for each service (defaults provided)
  - VPN (when enabled later): `VPN_SERVICE_PROVIDER`, `VPN_TYPE`, `FIREWALL_VPN_INPUT_PORTS`, WireGuard keys, server location vars

## Current State (December 2025)

### Jellyfin Stack - CONFIGURED ✅
| Component | Status | Notes |
|-----------|--------|-------|
| Jellyfin 10.11.4 | ✅ Running | Libraries: TV Shows, Movies, Music |
| Jellyseerr | ✅ Running | Integrated with Jellyfin |
| Jellystat | ✅ Running | Statistics dashboard |
| Trickplay (scrubber) | ✅ Enabled | Generating thumbnails for TV/Movies |
| Jellyfin Enhanced | ✅ Installed | Jellyseerr search, quality tags, .arr links |
| Skin Manager | ✅ Installed | Theme applied |
| Radarr→Jellyfin notify | ✅ Configured | Auto library refresh on download |
| Sonarr→Jellyfin notify | ✅ Configured | Auto library refresh on download |

### Arr Stack - CONFIGURED ✅
| Component | Status | Notes |
|-----------|--------|-------|
| Prowlarr | ✅ Running | FlareSolverr integrated |
| Sonarr | ✅ Running | Anime profile configured (Japanese audio) |
| Radarr | ✅ Running | Anime auto-detection enabled |
| Lidarr | ✅ Running | Music management |
| Bazarr | ✅ Running | Subtitles - Podnapisi/Gestdown providers |
| qBittorrent | ✅ Running | Download client |
| NZBGet | ✅ Running | Usenet client |

### Known Issues / Quirks
- **Playback progress**: May not save reliably (investigate `Sessions/Playing/Stopped` errors in logs)
- **Bazarr IPs**: Use container names (`radarr`, `sonarr`) not hardcoded IPs in config.yaml
- **Plugin UI mods**: Require `web-index.html` mounted as volume (done in compose.yaml)

## Setup Steps (Required for New Machine Deployment)

### 1. Environment Variables (.env file)
Location: `/home/kero66/repos/homelab/media/.env`

Required variables:
```
TZ=Australia/Brisbane          # Timezone (adjust as needed)
PUID=1000                        # User ID (get with: id -u)
PGID=1000                        # Group ID (get with: id -g)

# Only needed when VPN is enabled:
VPN_SERVICE_PROVIDER=airvpn
VPN_TYPE=wireguard
FIREWALL_VPN_INPUT_PORTS=port
WIREGUARD_PUBLIC_KEY=key
WIREGUARD_PRIVATE_KEY=key
WIREGUARD_PRESHARED_KEY=key
WIREGUARD_ADDRESSES=ip
SERVER_COUNTRIES=country
SERVER_CITIES=city
HEALTH_VPN_DURATION_INITIAL=120s
```

### 2. Data Directory Structure
Location: `/data`

Create directory structure:
```bash
mkdir -p /data/downloads/qbittorrent/{completed,incomplete,torrents}
mkdir -p /data/downloads/nzbget/{completed,intermediate,nzb,queue,tmp}
mkdir -p /data/{movies,shows,music,books}
```

Full structure:
```
/data/
├── downloads/
│   ├── qbittorrent/
│   │   ├── completed/
│   │   ├── incomplete/
│   │   └── torrents/
│   └── nzbget/
│       ├── completed/
│       ├── intermediate/
│       ├── nzb/
│       ├── queue/
│       └── tmp/
├── movies/
├── shows/
├── music/
└── books/
```

### 3. Service Configuration Directories
These are created automatically by docker compose on first run:
- `media/qbittorrent/` - qBittorrent config
- `media/nzbget/` - NZBget config
- `media/prowlarr/` - Prowlarr config
- `media/sonarr/` - Sonarr config
- `media/radarr/` - Radarr config
- `media/lidarr/` - Lidarr config
- `media/bazarr/` - Bazarr config

### 4. Docker Compose Startup
From `/home/kero66/repos/homelab/media/`:
```bash
docker compose up -d
```

### 4.1 Seeded App Configs with Full Automation
To minimize manual UI configuration, we provide scripts that generate seeded config files and automatically configure root folders.

**Workflow:**
1. Create your credentials file:
   ```bash
   cp media/.config/.credentials.template media/.config/.credentials
   nano media/.config/.credentials  # Set USERNAME and PASSWORD
   ```

2. **Recommended: Use deploy.sh for full automation:**
   ```bash
   cd media
   ./deploy.sh --full    # One command does everything
   ```

3. **Or run scripts manually:**
   ```bash
   bash media/scripts/setup_seed_configs.sh  # Generates configs in .config/
   bash media/scripts/init_configs.sh        # Copies to service directories
   docker compose up -d                       # Start all services
   bash media/scripts/automate_all.sh        # Run all configuration scripts
   ```

4. **One-time qBittorrent setup:**
   - Access qBittorrent at `localhost:8080`
   - Go to Tools → Options → Web UI
   - Set Username: `kero66` and Password: `temppwd` (or your custom credentials)
   - **Uncheck** "Bypass authentication for clients in whitelisted IP subnets"
   - Click Save

5. **Access Arr apps:**
   - Navigate to any Arr app (Sonarr/Radarr/Lidarr/Prowlarr)
   - Browser will prompt for Basic authentication (username/password popup)
   - Enter credentials from `.credentials` file
   - Root folders are already configured - start adding content!

**What gets configured automatically:**
- **qBittorrent**: Download directories, WebUI port (8080), WebUI username pre-set (password must be set manually via WebUI)
- **NZBGet**: Credentials and download paths configured automatically via `configure_nzbget.sh`
- **Prowlarr**: FlareSolverr proxy configured via `configure_prowlarr.sh` for Cloudflare-protected indexers (no VPN required)
- **All Arr apps**: 
  - API keys (randomly generated)
  - Authentication method (Basic)
  - Authentication requirement (Enabled)
  - Root folders automatically added via API:
    - Sonarr: `/data/shows`
    - Radarr: `/data/movies`
    - Lidarr: `/data/music`

**Known Limitations:**
- **qBittorrent password**: Cannot be fully automated due to qBittorrent's internal PBKDF2 hashing implementation. Password must be set once via WebUI after first deployment. Once set, it persists in the qBittorrent database.

**Notes:**
- All generated config files are gitignored (regenerate locally after git clone)
- Authentication uses Basic auth (browser popup) with credentials from `.credentials`
- Root folders are added via API after services start
- Change default credentials after verifying setup works

### 5. Service Access
After startup, services available at:
- qBittorrent: http://localhost:8080
- Prowlarr: http://localhost:9696
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878
- Lidarr: http://localhost:8686
- Bazarr: http://localhost:6767
- NZBget: http://172.39.0.7:6789

## Automation Roadmap
TODO: Create setup script to automate:
- [ ] Create .env file with prompts for TZ, PUID, PGID
- [ ] Create data directory structure
- [ ] Validate directory permissions
- [ ] Run docker compose
- [x] Health checks on services (added to compose.yaml)
- [ ] Output access URLs

## Next Steps
1. ✅ Set up .env file with required variables (PUID=1000, PGID=1000, TZ=Australia/Brisbane)
2. ✅ Create data directory structure at /data
3. Test docker compose startup

---

## Project Review (December 2024)

### Improvements Made (Phase 1)
1. **Removed duplicate scripts**: Deleted `automate_anime.sh`, `automate_anime_japanese.sh`, `setup_anime_japanese.sh` - `configure_sonarr_anime.sh` is the authoritative anime config script
2. **Updated .gitignore**: Added runtime service config directories (`sonarr/`, `radarr/`, etc.) to prevent accidental commits of API keys and databases
3. **Added healthchecks**: All services in `compose.yaml` now have proper Docker healthchecks for better container monitoring

### Improvements Made (Phase 2)
4. **Created `.env.example`**: Comprehensive template with all variables documented and grouped by category
5. **Consolidated Prowlarr scripts**: Merged `configure_prowlarr.sh` + `configure_prowlarr_apps.sh` into single `configure_prowlarr.sh` that handles both FlareSolverr and app connections
6. **Added Docker Compose profiles**: VPN (gluetun) and Jellyfin stack now use profiles instead of commented blocks
   - `docker compose up -d` - Base stack (no VPN, no Jellyfin)
   - `docker compose --profile vpn up -d` - With VPN
   - `docker compose --profile jellyfin up -d` - With Jellyfin stack
   - `docker compose --profile all up -d` - Everything
7. **Merged Jellyfin stack**: Jellyfin, Jellyseerr, Jellystat now in main `compose.yaml` (with profiles)
8. **Created backup script**: `backup.sh` creates timestamped backups of all configs and databases
   - Excludes logs/cache for smaller backups
   - Supports restore: `./backup.sh --restore latest`
   - Auto-cleans old backups (keeps last 5)

### Script Inventory

**Directory Structure (reorganized for clarity):**
```
media/
├── compose.yaml          # Docker Compose - all services
├── deploy.sh             # One-command deployment entry point
├── backup.sh             # Backup/restore utility
├── .env                  # Environment configuration (gitignored)
├── .env.example          # Template with all variables documented
├── README.md             # Main documentation
│
├── scripts/              # Automation scripts
│   ├── automate_all.sh          # Orchestrates all other scripts
│   ├── init_configs.sh          # Seeds config files before container start
│   ├── setup_seed_configs.sh    # Generates seed configs from credentials
│   ├── wait_and_configure_auth.sh   # Arr app authentication + root folders
│   ├── configure_download_clients.sh # qBittorrent/NZBGet to Arr apps
│   ├── configure_prowlarr.sh    # FlareSolverr + Sonarr/Radarr/Lidarr connections
│   ├── configure_sonarr_anime.sh    # Sonarr Japanese audio preference
│   ├── configure_radarr_anime.sh    # Radarr Japanese audio preference + auto-detection
│   ├── configure_jellyseerr_anime.sh # Jellyseerr anime profile integration
│   ├── configure_bazarr.sh      # Subtitle integration + provider setup
│   ├── configure_nzbget.sh      # NZBGet credentials/paths
│   ├── configure_nzbget_categories.sh # NZBGet categories
│   ├── configure_jellyfin_notifications.sh # Radarr/Sonarr → Jellyfin library refresh
│   ├── configure_jellyfin_plugins.sh # Plugin repos + trickplay setup
│   ├── add_root_folders.sh      # Add root folders via API
│   ├── add_memory_limits.sh     # Add Docker memory limits
│   └── verify_setup.sh          # Health check all services
│
├── docs/                 # Documentation
│   ├── AUTOMATION_STATUS.md     # Tracks automation progress
│   ├── ANIME_CONFIG.md          # Anime configuration details
│   ├── DEPLOYMENT_CHECKLIST.md  # Step-by-step deployment
│   └── MIGRATION.md             # Server migration guide
│
├── .config/              # Seed configs and credentials (gitignored)
│   ├── .credentials             # USERNAME/PASSWORD
│   ├── .credentials.template    # Template file
│   └── [service subdirs]/       # Generated seed configs
│
├── jellyfin/             # Jellyfin ecosystem configs
│   ├── compose.yaml             # Jellyfin stack (separate from arr apps)
│   ├── configure_jellyfin.sh
│   ├── configure_jellyseerr.sh
│   ├── configure_jellystat.sh
│   ├── fix_jellyseerr_apikeys.sh
│   ├── show_jellyseerr_config.sh
│   └── config/                  # Runtime configs (gitignored)
│       ├── web-index.html       # Mounted for plugin UI modifications
│       └── data/plugins/        # Installed plugins
│
└── [service dirs]/       # Runtime configs (gitignored)
    ├── sonarr/
    ├── radarr/
    ├── lidarr/
    ├── prowlarr/
    ├── bazarr/
    ├── nzbget/
    └── qbittorrent/
```

Main automation: `scripts/automate_all.sh` → orchestrates all other scripts

### Docker Compose Profiles
| Profile | Services |
|---------|----------|
| (none) | qBittorrent, NZBGet, FlareSolverr, Prowlarr, Sonarr, Radarr, Lidarr, Bazarr |
| `vpn` | + Gluetun (routes qBittorrent/NZBGet through VPN) |
| `jellyfin` | + Jellyfin, Jellyseerr, Jellystat, Jellystat-DB |
| `all` | All services |

### Improvements Made (Phase 3 - Full Automation)
9. **Created `deploy.sh`**: Single-command deployment script that:
   - Checks prerequisites (Docker, Docker Compose)
   - Prompts for credentials (or uses env vars with `--non-interactive`)
   - Auto-detects timezone, PUID, PGID
   - Creates data directory structure with proper permissions
   - Generates seed configurations
   - Starts Docker containers with selected profiles
   - Waits for services with proper healthchecks (not hardcoded sleep)
   - Runs all automation scripts in correct order
   - Verifies deployment
   - Supports `--destroy` mode for clean reinstall

10. **Created `MIGRATION.md`**: Comprehensive guide for moving to a new server:
    - Backup/restore workflow
    - Network storage setup (NFS, CIFS/SMB)
    - Server-specific configs (Proxmox LXC, Unraid, TrueNAS)
    - Post-migration checklist
    - Rollback instructions

11. **Updated README.md**: New quick-start section with one-command deployment

### Improvements Made (Phase 4 - CONFIG_DIR Best Practice)
12. **Added CONFIG_DIR support**: Following Servarr Wiki best practices, configs can now be stored separately from the git repo.

**Default (development)**: `CONFIG_DIR=.` - Configs in same directory as compose.yaml
**Production**: `CONFIG_DIR=/opt/docker/media` - Configs separate from code

This is the **recommended approach** from the [Servarr Docker Guide](https://wiki.servarr.com/docker-guide):
> "/path/to/config/sonarr:/config" - Configs should be stored in a dedicated location

**Benefits of separate CONFIG_DIR:**
- Git repo stays clean (no runtime files/databases)
- Easier backups (config separate from code)
- Better security (API keys not near source code)
- Follows Docker best practices

**Changes made:**
- All services in `compose.yaml` use `${CONFIG_DIR:-.}/service:/config`
- `.env.example` documents CONFIG_DIR with examples
- `deploy.sh` prompts for CONFIG_DIR (interactive) or uses `MEDIA_CONFIG_DIR` env var
- All scripts load CONFIG_DIR from .env and use it for config file paths

### One-Command Deployment
```bash
# Fresh install (everything)
git clone https://github.com/kieranmcjannett-coder/homelab.git
cd homelab/media
./deploy.sh --full

# Non-interactive (for scripts/automation)
MEDIA_USERNAME=admin MEDIA_PASSWORD=secret ./deploy.sh --full --non-interactive

# Migration to new server
./backup.sh                           # On old server
scp backups/*.tar.gz newserver:/tmp/  # Transfer
./backup.sh --restore /tmp/backup.tar.gz  # On new server
./deploy.sh --full --non-interactive  # Deploy
```

### YAMS-Style CLI Tool
Inspired by [YAMS](https://yams.media/), we now have a simple CLI tool:

```bash
./yams --help           # Show all commands
./yams status           # Show service status
./yams urls             # Show all service URLs (saves to ~/media_services.txt)
./yams start [service]  # Start all or specific service
./yams stop [service]   # Stop all or specific service
./yams restart [service] # Restart all or specific service
./yams logs [service]   # Show logs
./yams check-vpn        # Verify VPN is working (compares IPs)
./yams scan-library     # Trigger Jellyfin library scan
./yams fix-anime        # Run anime configuration scripts
./yams configure        # Run all configuration scripts
./yams backup [dest]    # Backup configs
./yams destroy          # Remove all containers/volumes (with confirmation)
```

### Remaining Manual Steps (Cannot Be Automated)
1. **Jellyseerr first-time wizard** (~2 min) - Security requirement, must create account in browser
2. **Jellystat account creation** (~2 min) - No API for initial account
3. **Bazarr subtitle providers** (~2 min) - Requires manual provider account setup

**Total automation: 97%** - The remaining 3% are security/UI requirements that cannot be bypassed.

---

## Working Patterns & Troubleshooting Reference

### API Access Patterns (VERIFIED WORKING)

#### Sonarr/Radarr/Lidarr API
```bash
# Get API key from config.xml
API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "${CONFIG_DIR:-.}/sonarr/config.xml" | tr -d '[:space:]')

# API calls - use X-Api-Key header (NOT query param for reliability)
curl -s -H "X-Api-Key: $API_KEY" "http://localhost:8989/api/v3/movie"

# POST/PUT requests
curl -s -X POST \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  "http://localhost:8989/api/v3/endpoint" \
  -d '{"json": "payload"}'
```

#### Jellyfin API
```bash
# Get API key from Jellyseerr settings (Jellyfin API key stored there)
JELLYFIN_API=$(python3 -c "import json; print(json.load(open('jellyfin/jellyseerr/settings.json'))['jellyfin']['apiKey'])")

# API calls - use X-Emby-Token header
curl -s -H "X-Emby-Token: $JELLYFIN_API" "http://localhost:8096/Library/VirtualFolders"

# Trigger library scan
curl -s -X POST -H "X-Emby-Token: $JELLYFIN_API" "http://localhost:8096/Library/Refresh"

# List movies
curl -s -H "X-Emby-Token: $JELLYFIN_API" "http://localhost:8096/Items?IncludeItemTypes=Movie&Recursive=true"
```

### Python in Bash Scripts (VERIFIED PATTERNS)

#### DON'T: Pass large JSON via shell variable (breaks with special chars)
```bash
# BAD - breaks with unicode, large data, special characters
MOVIES=$(curl -s ... )
echo "$MOVIES" | python3 -c "import sys,json; data=json.load(sys.stdin)..."
```

#### DO: Fetch data inside Python directly
```bash
# GOOD - Python handles HTTP and JSON natively
API_KEY="$API_KEY" python3 << 'PYTHON_SCRIPT'
import json, urllib.request, os

api_key = os.environ.get('API_KEY', '')
req = urllib.request.Request(
    'http://localhost:8989/api/v3/movie',
    headers={'X-Api-Key': api_key}
)
with urllib.request.urlopen(req) as resp:
    data = json.load(resp)
# Process data...
PYTHON_SCRIPT
```

#### DO: Pass shell variables via environment
```bash
# GOOD - Pass variables via env, use quoted heredoc to prevent expansion
API_KEY="$API_KEY" SOME_ID="$SOME_ID" python3 << 'PYTHON_SCRIPT'
import os
api_key = os.environ.get('API_KEY', '')
some_id = os.environ.get('SOME_ID', '0')
# Use variables...
PYTHON_SCRIPT
```

### Common Issues & Solutions

#### Issue: Jellyfin not showing downloaded movies
**Cause**: Jellyfin doesn't auto-scan on file changes in all configurations
**Solution**: Trigger library scan via API
```bash
JELLYFIN_API="your_api_key"
curl -s -X POST "http://localhost:8096/Library/Refresh" -H "X-Emby-Token: $JELLYFIN_API"
```

#### Issue: JSON decode error in Python heredoc
**Cause**: Shell variable interpolation issues with large JSON data
**Solution**: Fetch data inside Python using urllib.request (see patterns above)

#### Issue: JSONDecodeError when piping command output to Python
**Cause**: Command returned empty output (error suppressed by `2>/dev/null`)
**Solution**: Always handle empty/error cases:
```bash
# DON'T: Pipe directly and suppress errors
some_command 2>/dev/null | python3 -c "import json; json.load(sys.stdin)..."

# DO: Check output exists first, or handle in Python
OUTPUT=$(some_command 2>&1)
if [[ -n "$OUTPUT" && ! "$OUTPUT" =~ "error" ]]; then
    echo "$OUTPUT" | python3 -c "..."
fi

# OR: Handle empty input in Python
some_command 2>&1 | python3 -c "
import sys, json
data = sys.stdin.read()
if data.strip():
    d = json.loads(data)
else:
    print('No output')
"
```

#### Issue: API key extraction fails
**Cause**: Whitespace/newlines in extracted value
**Solution**: Always pipe through `tr -d '[:space:]'`
```bash
API_KEY=$(grep -oP '<ApiKey>\K[^<]+' config.xml | tr -d '[:space:]')
```

#### Issue: Service not responding after docker compose up
**Solution**: Check healthcheck status, don't rely on arbitrary sleep
```bash
# Check health status
docker compose ps --format "table {{.Name}}\t{{.Status}}"

# Wait for healthy with timeout
timeout 60 bash -c 'until curl -s http://localhost:8989/ping > /dev/null; do sleep 2; done'
```

### Anime Detection Logic (Specific, Not Generic)

**DO detect as anime:**
- Animation genre + Japanese original language (most reliable)
- Known Japanese anime studios (Ghibli, MAPPA, ufotable, etc.)
- Specific anime keywords in title (Gundam, Digimon, Dragon Ball, etc.)
- Already tagged with "anime"

**DON'T detect as anime:**
- Generic "Animation" genre alone (catches Pixar, Disney, DreamWorks)
- Non-Japanese animation regardless of keywords
- Japanese certification alone (not reliable)

### Service Ports Reference
| Service | Port | API Base |
|---------|------|----------|
| Sonarr | 8989 | /api/v3 |
| Radarr | 7878 | /api/v3 |
| Lidarr | 8686 | /api/v3 |
| Prowlarr | 9696 | /api/v1 |
| Bazarr | 6767 | /api |
| qBittorrent | 8080 | /api/v2 |
| NZBGet | 6789 | /jsonrpc |
| Jellyfin | 8096 | (various) |
| Jellyseerr | 5055 | /api/v1 |

### Config File Locations
| Service | Config XML | Database |
|---------|------------|----------|
| Sonarr | `${CONFIG_DIR}/sonarr/config.xml` | `sonarr.db` |
| Radarr | `${CONFIG_DIR}/radarr/config.xml` | `radarr.db` |
| Lidarr | `${CONFIG_DIR}/lidarr/config.xml` | `lidarr.db` |
| Prowlarr | `${CONFIG_DIR}/prowlarr/config.xml` | `prowlarr.db` |
| Jellyfin | N/A | `jellyfin.db` in data/data/ |
| Jellyseerr | `jellyfin/jellyseerr/settings.json` | `db/` folder |
| Bazarr | `bazarr/config/config.yaml` | `bazarr.db` in db/ |

### Useful External Resources
- [Servarr Docker Guide](https://wiki.servarr.com/docker-guide) - Official Docker setup guide
- [TRaSH Guides](https://trash-guides.info/) - Advanced configuration guides:
  - [TRaSH Guide for Radarr](https://trash-guides.info/Radarr/)
  - [TRaSH Guide for Sonarr](https://trash-guides.info/Sonarr/)
  - [TRaSH Guide for Prowlarr](https://trash-guides.info/Prowlarr/)
  - [TRaSH Guide for Bazarr](https://trash-guides.info/Bazarr/) - Subtitle scoring
- [YAMS](https://yams.media/) - Yet Another Media Server (inspiration for our CLI)
- [awesome-jellyfin](https://github.com/awesome-jellyfin/awesome-jellyfin) - Comprehensive list of Jellyfin plugins, themes, tools
  - [THEMES.md](https://github.com/awesome-jellyfin/awesome-jellyfin/blob/main/THEMES.md) - All available themes
  - [CLIENTS.md](https://github.com/awesome-jellyfin/awesome-jellyfin/blob/main/CLIENTS.md) - Alternative clients


### Jellyfin Library Refresh - Automatic Setup

#### Why Real-Time Monitoring Doesn't Work in Docker
- Jellyfin has `EnableRealtimeMonitor: True` by default but **inotify events don't propagate** across Docker bind mounts (especially on WSL)
- Default scheduled scan is every 12 hours (too slow)

#### Solution: Connect Notifications from Radarr/Sonarr to Jellyfin
Configure *arr apps to notify Jellyfin when downloads complete. This triggers instant library refresh.

**IMPORTANT**: Radarr and Jellyfin are on different Docker networks:
- Radarr: `servarrnetwork`
- Jellyfin: `jellyfin_default`

Use `host.docker.internal` to route through the host.

#### API Payload for Radarr -> Jellyfin Notification
```bash
# Get API keys
RADARR_API=$(grep -oP '<ApiKey>\K[^<]+' "${CONFIG_DIR:-.}/radarr/config.xml" | tr -d '[:space:]')
JELLYFIN_API=$(python3 -c "import json; print(json.load(open('${CONFIG_DIR:-.}/jellyfin/jellyseerr/settings.json'))['jellyfin']['apiKey'])")

# Add Jellyfin notification (implementation is "MediaBrowser", NOT "Emby")
curl -s -X POST "http://localhost:7878/api/v3/notification" \
  -H "X-Api-Key: $RADARR_API" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jellyfin",
    "implementation": "MediaBrowser",
    "configContract": "MediaBrowserSettings",
    "onGrab": false,
    "onDownload": true,
    "onUpgrade": true,
    "onRename": true,
    "onMovieDelete": true,
    "onMovieFileDelete": true,
    "onMovieFileDeleteForUpgrade": true,
    "fields": [
      {"name": "host", "value": "host.docker.internal"},
      {"name": "port", "value": 8096},
      {"name": "useSsl", "value": false},
      {"name": "urlBase", "value": ""},
      {"name": "apiKey", "value": "YOUR_JELLYFIN_API_KEY"},
      {"name": "notify", "value": false},
      {"name": "updateLibrary", "value": true},
      {"name": "mapFrom", "value": ""},
      {"name": "mapTo", "value": ""}
    ]
  }'
```

#### Sonarr uses same pattern with different event names:
- `onSeriesAdd`, `onSeriesDelete`, `onEpisodeFileDelete`, etc.

#### Checking configured notifications:
```bash
curl -s "http://localhost:7878/api/v3/notification" -H "X-Api-Key: $RADARR_API" | \
  python3 -c "import sys,json; [print(f'{n[\"name\"]}: updateLibrary={[f for f in n[\"fields\"] if f[\"name\"]==\"updateLibrary\"][0][\"value\"]}') for n in json.load(sys.stdin)]"
```

### Jellyfin Plugin Ecosystem

#### Jellyfin Version: 10.11.4

#### Recommended Plugin Repositories
```
# File Transformation (required for UI-modifying plugins)
https://www.iamparadox.dev/jellyfin/plugins/manifest.json

# Jellyfin Enhanced (10.11 version)
https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/10.11/manifest.json

# Intro Skipper (auto-detects Jellyfin version)
https://intro-skipper.org/manifest.json

# Ani-Sync (anime watch sync)
https://raw.githubusercontent.com/vosmiic/jellyfin-ani-sync/master/manifest.json

# danieladov (Merge Versions, Skin Manager, Theme Songs)
https://raw.githubusercontent.com/danieladov/JellyfinPluginManifest/master/manifest.json

# LizardByte (Themerr theme songs)
https://app.lizardbyte.dev/jellyfin-plugin-repo/manifest.json
```

#### Essential Plugins
| Plugin | Purpose | Repo |
|--------|---------|------|
| File Transformation | Allows plugins to modify web UI (required for Enhanced/Intro Skipper) | IAmParadox |
| Jellyfin Enhanced | Quality tags, Jellyseerr search, .arr links, pause screen, keyboard shortcuts | n00bcodr |
| Intro Skipper | Auto-detect and skip intros/credits | intro-skipper.org |

#### Official Plugins (in default catalog)
- **Open Subtitles** - Auto-download subtitles
- **Playback Reporting** - Watch statistics
- **TMDb Box Sets** - Auto-create movie collections
- **AniDB / AniList** - Anime metadata

#### Jellyfin Enhanced + Jellyseerr Integration
After installing Jellyfin Enhanced:
1. Dashboard > Plugins > Jellyfin Enhanced
2. Jellyseerr Settings tab
3. Enable "Show Jellyseerr Results in Search"
4. URL: `http://jellyseerr:5055` (internal Docker) or `http://localhost:5055`
5. API Key: Get from Jellyseerr Settings > General

Requirements in Jellyseerr:
- Settings > Users > Enable "Jellyfin Sign-In"
- Import Jellyfin users into Jellyseerr

---

## Jellyfin API Reference (Complete)

### Authentication
```bash
# Get API key from Jellyseerr (it stores Jellyfin's key)
JELLYFIN_API=$(python3 -c "import json; print(json.load(open('jellyfin/jellyseerr/settings.json'))['jellyfin']['apiKey'])")

# All requests use X-Emby-Token header
curl -s -H "X-Emby-Token: $JELLYFIN_API" "http://localhost:8096/endpoint"
```

### Core Endpoints

| Task | Method | Endpoint |
|------|--------|----------|
| System info/version | GET | `/System/Info` |
| Server configuration | GET | `/System/Configuration` |
| List all plugins | GET | `/Plugins` |
| Plugin repositories | GET | `/Repositories` |
| Add plugin repository | POST | `/Repositories` |
| Install plugin by name | POST | `/Packages/Installed/{name}?version={ver}&repositoryUrl={url}` |
| List libraries | GET | `/Library/VirtualFolders` |
| Update library options | POST | `/Library/VirtualFolders/LibraryOptions?refreshLibrary=false` |
| Trigger library scan | POST | `/Library/Refresh` |
| List scheduled tasks | GET | `/ScheduledTasks` |
| Get task details | GET | `/ScheduledTasks/{taskId}` |
| Run scheduled task | POST | `/ScheduledTasks/Running/{taskId}` |
| List items | GET | `/Items?IncludeItemTypes={type}&Recursive=true` |
| Get user data | GET | `/Users` |

### Plugin Management

#### List Plugin Repositories
```bash
curl -s "http://localhost:8096/Repositories" -H "X-Emby-Token: $JELLYFIN_API"
```

#### Add Plugin Repository
```bash
curl -s -X POST "http://localhost:8096/Repositories" \
  -H "X-Emby-Token: $JELLYFIN_API" \
  -H "Content-Type: application/json" \
  -d '[
    {"Name": "Jellyfin Enhanced", "Url": "https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/10.11/manifest.json", "Enabled": true},
    {"Name": "Skin Manager", "Url": "https://raw.githubusercontent.com/danieladov/JellyfinPluginManifest/master/manifest.json", "Enabled": true}
  ]'
```

#### Install Plugin
```bash
# URL-encode the repository URL
REPO_URL_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('https://raw.githubusercontent.com/.../manifest.json', safe=''))")

curl -s -X POST "http://localhost:8096/Packages/Installed/PluginName?version=1.0.0.0&repositoryUrl=$REPO_URL_ENCODED" \
  -H "X-Emby-Token: $JELLYFIN_API"
```

#### Manual Plugin Installation (when API install fails)
```bash
# 1. Download from GitHub releases
wget https://github.com/author/plugin/releases/download/v1.0/plugin.zip

# 2. Extract to plugins directory
unzip plugin.zip -d jellyfin/config/data/plugins/PluginName/

# 3. Restart Jellyfin
docker compose restart jellyfin
```

### Library Management

#### Get Libraries with Settings
```bash
curl -s "http://localhost:8096/Library/VirtualFolders" -H "X-Emby-Token: $JELLYFIN_API" | \
  python3 -c "
import sys, json
for lib in json.load(sys.stdin):
    opts = lib.get('LibraryOptions', {})
    print(f\"{lib['Name']}: Trickplay={opts.get('EnableTrickplayImageExtraction', False)}\")
"
```

#### Enable Trickplay (Video Scrubber) on Library
```bash
curl -s -X POST "http://localhost:8096/Library/VirtualFolders/LibraryOptions?refreshLibrary=false" \
  -H "X-Emby-Token: $JELLYFIN_API" \
  -H "Content-Type: application/json" \
  -d '{
    "Id": "LIBRARY_ITEM_ID",
    "LibraryOptions": {
      "EnableTrickplayImageExtraction": true,
      "ExtractTrickplayImagesDuringLibraryScan": true,
      "EnablePhotos": true,
      "EnableRealtimeMonitor": true,
      "PathInfos": [{"Path": "/data/movies"}],
      "SaveLocalMetadata": false,
      "EnableInternetProviders": true
    }
  }'
```

### Scheduled Tasks

#### List All Tasks
```bash
curl -s "http://localhost:8096/ScheduledTasks" -H "X-Emby-Token: $JELLYFIN_API" | \
  python3 -c "import sys,json; [print(f\"{t['Name']}: {t['Id']}\") for t in json.load(sys.stdin)]"
```

#### Common Task IDs (vary by installation)
| Task | Purpose |
|------|---------|
| Generate Trickplay Images | Create video scrubbing thumbnails |
| Scan Media Library | Full library rescan |
| Refresh Internet Metadata | Update metadata from providers |

#### Run a Task
```bash
curl -s -X POST "http://localhost:8096/ScheduledTasks/Running/{taskId}" \
  -H "X-Emby-Token: $JELLYFIN_API"
```

#### Check Task Progress
```bash
curl -s "http://localhost:8096/ScheduledTasks/{taskId}" -H "X-Emby-Token: $JELLYFIN_API" | \
  python3 -c "
import sys, json
task = json.load(sys.stdin)
print(f\"State: {task.get('State')}\")
if task.get('CurrentProgressPercentage'):
    print(f\"Progress: {task['CurrentProgressPercentage']}%\")
"
```

### Docker Networking Gotchas

#### Cross-Container Communication
- Jellyfin and Arr apps are on different Docker networks
- Use `host.docker.internal` to route through host
- Or use container names if on same network

#### Plugin Web UI Modifications
Plugins like Jellyfin Enhanced need to modify `index.html`. In Docker, the web files are read-only.

**Workaround**: Mount `index.html` as a volume
```bash
# Copy from container
docker cp jellyfin:/usr/share/jellyfin/web/index.html jellyfin/config/web-index.html

# Add to compose.yaml volumes:
# - ./jellyfin/config/web-index.html:/usr/share/jellyfin/web/index.html
```

### Jellyfin Enhanced Plugin Configuration

Config location: `jellyfin/config/data/plugins/configurations/Jellyfin.Plugin.JellyfinEnhanced.xml`

Key settings:
```xml
<JellyseerrEnabled>true</JellyseerrEnabled>
<JellyseerrUrls>http://host.docker.internal:5055</JellyseerrUrls>
<JellyseerrApiKey>YOUR_KEY</JellyseerrApiKey>
<QualityTagsEnabled>true</QualityTagsEnabled>
<ArrLinksEnabled>true</ArrLinksEnabled>
<ArrLinksRadarrUrl>http://localhost:7878</ArrLinksRadarrUrl>
<ArrLinksSonarrUrl>http://localhost:8989</ArrLinksSonarrUrl>
```

---

## Bazarr API & Configuration

### Fix Connection Issues
Bazarr config: `bazarr/config/config.yaml`

**Common Issue**: Hardcoded IPs don't work in Docker
```yaml
# BAD - hardcoded IPs
radarr:
  ip: 172.39.0.4

# GOOD - use container names  
radarr:
  ip: radarr
```

### Enable Subtitle Providers (No Account Required)
```yaml
podnapisi:
  username: null
  password: null
gestdown:
  timeout: 60
  
general:
  enabled_providers:
    - podnapisi
    - gestdown
```

### Apply Default Profile to All Media
```bash
# Get Bazarr API key
BAZARR_API=$(grep -oP 'apikey: \K.+' bazarr/config/config.yaml | tr -d '[:space:]"')

# List all series
curl -s "http://localhost:6767/api/series" -H "X-API-KEY: $BAZARR_API"

# Apply English profile (ID 1) to series
curl -s -X POST "http://localhost:6767/api/series" \
  -H "X-API-KEY: $BAZARR_API" \
  -H "Content-Type: application/json" \
  -d '{"seriesid": [123, 456], "profileid": [1]}'
```

### TRaSH Recommended Scores
```yaml
sonarr:
  series_default_profile: 1
  minimum_score: 90

radarr:  
  movies_default_profile: 1
  minimum_score: 80
```
