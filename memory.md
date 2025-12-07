claude# Homelab Project Memory

## Agent Instructions

### Mission
Build a **fully automated, reproducible homelab deployment** that can be torn down and recreated on any machine with minimal manual intervention.

### Core Principles
1. **Automate everything** - Never ask the user to manually configure something if it can be scripted
2. **Use APIs and config files** - Prefer programmatic configuration over UI clicks
3. **Idempotent scripts** - Scripts should be safe to run multiple times
4. **Store credentials securely** - Use `.env` files (gitignored) and reference them in scripts
5. **Document in memory.md** - Keep this file updated with current state, not just instructions

### Behavior Guidelines
- **Don't search for things you already know** - Check memory.md and conversation context first
- **Execute, don't ask** - When a task is clear, do it rather than asking for confirmation
- **Chain commands** - Use `&&` to run related commands together efficiently
- **Update memory.md** - After significant changes, update the relevant sections
- **Commit often** - After completing a logical unit of work, commit with descriptive message

### Known Credentials & Endpoints
| Service | URL | Auth Method |
|---------|-----|-------------|
| Jellyfin | http://localhost:8096 | User: kero66 / temppwd, API: `$JELLYFIN_API_KEY` in `.env` |
| Jellyseerr | http://localhost:5055 | API: `$JELLYSEERR_API_KEY` in `.env` |
| Sonarr | http://localhost:8989 | API Key in `/media/sonarr/config.xml` |
| Radarr | http://localhost:7878 | API Key in `/media/radarr/config.xml` |
| Lidarr | http://localhost:8686 | API Key in `/media/lidarr/config.xml` |
| Prowlarr | http://localhost:9696 | API Key in `/media/prowlarr/config.xml` |
| Bazarr | http://localhost:6767 | API Key in `/media/bazarr/config/config.yaml` |
| qBittorrent | http://localhost:8080 | User: admin (check logs for temp password) |
| Jellystat | http://localhost:3000 | Postgres: jellystat/jellystat |

### File Locations
- **Credentials**: `/media/.config/.credentials` (username/password)
- **Environment**: `/media/.env` (DATA_DIR, IPs, ports, API keys) - **gitignored**
- **Arr API Keys**: In each service's `config.xml` under `<ApiKey>`
- **Jellyfin plugins**: `/config/data/plugins/` inside container

### Automation Scripts
| Script | Purpose |
|--------|---------|
| `media/deploy.sh` | Full stack deployment |
| `media/jellyfin/install_plugins.sh` | Install Jellyfin plugins |
| `media/jellyfin/configure_jellyfin.sh` | Configure Jellyfin settings |
| `media/jellyfin/configure_jellyseerr.sh` | Configure Jellyseerr integration |

### Integration Status
| Service | Integration / API hook | Standard automation |
|---------|----------------------|---------------------|
| Jellyfin | Notifications wired to Sonarr/Radarr via `scripts/configure_jellyfin_notifications.sh`; API key exposed through `media/jellyfin/jellyseerr/settings.json` and `.env` (`JELLYFIN_API_KEY`). | ✅ Automated after Jellyfin setup script runs. |
| Jellyseerr | Points at Jellyfin server already in `settings.json`, pulls Sonarr/Radarr API keys from `${CONFIG_DIR}/sonarr/config.xml` and `${CONFIG_DIR}/radarr/config.xml`, and adds anime-aware profiles via `media/scripts/configure_jellyseerr_anime.sh`. | ✅ Automated; run `jellyfin/configure_jellyseerr.sh` plus anime helper. Still requires first-run wizard (choose Jellyfin server → sign in). |
| Sonarr / Radarr / Lidarr | API keys created in `config.xml` and used by Prowlarr, Jellyseerr, and download-client scripts. Authentication + root folders handled by `scripts/wait_and_configure_auth.sh`, download clients by `scripts/configure_download_clients.sh`, and anime hints by respective scripts. | ✅ Fully automated via `scripts/automate_all.sh` sequence. |
| Prowlarr | Reads API key from `prowlarr/config.xml`, connects to Arr apps via `scripts/configure_prowlarr.sh`, and routes indexers through FlareSolverr proxy. | ✅ Automated with dedicated script; integration references static IPs (`${IP_*}`). |
| Bazarr | Integrates with Sonarr/Radarr through `scripts/configure_bazarr.sh`. Notifications and authentication depend on Arr API keys. | ✅ Automated; manual provider choices still optional. |
| Jellystat | Consumes the Jellyfin API key and PostgreSQL credentials from `.env`. Setup script generates JWT+API values and prompts for UI-based server addition. | ✅ Mostly automated; requires logging into `http://localhost:3000` to add server using stored Jellyfin API token. |
| Jellyfin plugins | Installed via `media/jellyfin/install_plugins.sh` (runs after Jellyfin is healthy) and recorded under `media/jellyfin/plugin-configs`; the script now covers the JS Injector, Jellyfin Tweaks, Plugin Pages, and NextPVR additions on top of File Transformation/Jellyfin Enhanced/Media Bar/Home Screen Sections/Custom Tabs. Plugin-specific XML/JSON configs (e.g., `Jellyfin.Plugin.JellyfinEnhanced.xml` and `Jellyfin.Plugin.HomeScreenSections.xml`) are part of the repo so the Arr links (Jellyseerr/Sonarr/Radarr/Bazarr/Lidarr) and UI overrides stay consistent. Custom Tabs now defines Home/TV Shows/Movies/Favorites/Watchlist/Requests buttons, the home screen sections plugin ships an `external` Jellyseerr URL pointing at `localhost:5055`, and the JavaScript Injector loads KefinTweaks plus a mutation-observer script that rewrites any `jellyseerr:5055` links to the host the browser is actually using so every Discover/Request click works. | ✅ Automated; run `media/jellyfin/install_plugins.sh` during a bootstrap and restart Jellyfin so the plugin configs are reloaded. |

### Reference Documentation

#### Jellyfin (v10.11.x)
| Topic | URL |
|-------|-----|
| API Documentation | https://api.jellyfin.org/ |
| Configuration Guide | https://jellyfin.org/docs/general/administration/configuration |
| Hardware Acceleration | https://jellyfin.org/docs/general/administration/hardware-acceleration |
| Networking | https://jellyfin.org/docs/general/networking/ |
| Plugin Development | https://jellyfin.org/docs/general/server/plugins/ |
| Transcoding | https://jellyfin.org/docs/general/administration/encoding |

#### Arr Stack
| Service | API Docs | Wiki |
|---------|----------|------|
| Sonarr | https://sonarr.tv/docs/api/ | https://wiki.servarr.com/sonarr |
| Radarr | https://radarr.video/docs/api/ | https://wiki.servarr.com/radarr |
| Lidarr | https://lidarr.audio/docs/api/ | https://wiki.servarr.com/lidarr |
| Prowlarr | https://prowlarr.com/docs/api/ | https://wiki.servarr.com/prowlarr |
| Bazarr | https://wiki.bazarr.media/ | https://www.bazarr.media/wiki/ |

#### Servarr Wiki (Essential Reading)
- **TRaSH Guides** (quality profiles, naming): https://trash-guides.info/
- **Docker Guide**: https://wiki.servarr.com/docker-guide
- **Hardlinks/Atomic Moves**: https://trash-guides.info/Hardlinks/Hardlinks-and-Instant-Moves/

#### Jellyseerr
| Topic | URL |
|-------|-----|
| API Reference | https://api-docs.jellyseerr.dev/ |
| Configuration | https://docs.jellyseerr.dev/getting-started/installation |
| Notifications | https://docs.jellyseerr.dev/using-jellyseerr/notifications |

#### Docker/Compose
| Topic | URL |
|-------|-----|
| Compose Spec | https://docs.docker.com/compose/compose-file/ |
| Networking | https://docs.docker.com/network/ |
| Healthchecks | https://docs.docker.com/compose/compose-file/05-services/#healthcheck |

#### VPN (Gluetun)
| Topic | URL |
|-------|-----|
| Gluetun Wiki | https://github.com/qdm12/gluetun-wiki |
| AirVPN Setup | https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/airvpn.md |
| Port Forwarding | https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/port-forwarding.md |

#### Plugin Repositories
| Repo | Manifest URL |
|------|--------------|
| Jellyfin Official | https://repo.jellyfin.org/files/plugin/manifest.json |
| n00bcodr (Enhanced, JS Injector) | https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/10.11/manifest.json |
| IAmParadox27 (Media Bar, File Transform) | https://www.iamparadox.dev/jellyfin/plugins/manifest.json |
| Intro Skipper | https://intro-skipper.org/manifest.json |
| LizardByte | https://app.lizardbyte.dev/jellyfin-plugin-repo/manifest.json |

#### Useful Community Resources
- **Awesome Jellyfin**: https://github.com/awesome-jellyfin/awesome-jellyfin
- **LinuxServer.io Images**: https://docs.linuxserver.io/
- **Servarr Discord**: Community support for arr apps

### Host Dependencies
Tools required on the host machine for automation scripts:

| Tool | Purpose | Install (Fedora) | Install (Debian/Ubuntu) |
|------|---------|------------------|-------------------------|
| `jq` | JSON parsing in shell scripts | `dnf install jq` | `apt install jq` |
| `yq` | YAML parsing in shell scripts | `dnf install yq` | `snap install yq` |
| `sqlite3` | Query arr app databases directly | `dnf install sqlite` | `apt install sqlite3` |
| `curl` | API calls, downloads | Pre-installed | Pre-installed |
| `unzip` | Extract plugin archives | `dnf install unzip` | `apt install unzip` |
| `docker` | Container runtime | `dnf install docker-ce` | `apt install docker-ce` |
| `docker-compose` | Multi-container orchestration | Included with Docker | Included with Docker |
| `grep` | Text search (use `-P` for PCRE) | Pre-installed | Pre-installed |
| `xmllint` | Parse XML config files | `dnf install libxml2` | `apt install libxml2-utils` |

**Quick install (Fedora):**
```bash
sudo dnf install -y jq yq sqlite unzip libxml2
```

**Quick install (Debian/Ubuntu):**
```bash
sudo apt install -y jq sqlite3 unzip libxml2-utils && sudo snap install yq
```

### Common API Endpoints

#### Jellyfin API Cheatsheet
```bash
# Source .env first: source /path/to/media/.env
BASE="http://localhost:8096"
API_KEY="$JELLYFIN_API_KEY"  # From .env

# List libraries
curl "$BASE/Library/VirtualFolders" -H "X-Emby-Token: $API_KEY"

# Get users
curl "$BASE/Users" -H "X-Emby-Token: $API_KEY"

# Trigger library scan
curl -X POST "$BASE/Library/Refresh" -H "X-Emby-Token: $API_KEY"

# Get installed plugins
curl "$BASE/Plugins" -H "X-Emby-Token: $API_KEY"

# Get system info
curl "$BASE/System/Info" -H "X-Emby-Token: $API_KEY"

# List available packages (from all configured repos)
curl "$BASE/Packages" -H "X-Emby-Token: $API_KEY"

# Install plugin by name (URL-encode spaces as %20)
curl -X POST "$BASE/Packages/Installed/Home%20Screen%20Sections" -H "X-Emby-Token: $API_KEY"

# Restart server (required after plugin install)
curl -X POST "$BASE/System/Restart" -H "X-Emby-Token: $API_KEY"
```

#### Arr API Cheatsheet (Sonarr/Radarr/Lidarr)
```bash
# API key from config.xml: grep -oP '<ApiKey>\K[^<]+' config.xml
BASE="http://localhost:8989"  # Sonarr (8989), Radarr (7878), Lidarr (8686)
API_KEY="your-api-key"

# Get root folders
curl "$BASE/api/v3/rootfolder" -H "X-Api-Key: $API_KEY"

# Get quality profiles
curl "$BASE/api/v3/qualityprofile" -H "X-Api-Key: $API_KEY"

# Get download clients
curl "$BASE/api/v3/downloadclient" -H "X-Api-Key: $API_KEY"

# Get system status
curl "$BASE/api/v3/system/status" -H "X-Api-Key: $API_KEY"

# Test notification (Jellyfin connection)
curl "$BASE/api/v3/notification/test" -H "X-Api-Key: $API_KEY"
```

#### Prowlarr API Cheatsheet
```bash
BASE="http://localhost:9696"
API_KEY="your-api-key"

# Get indexers
curl "$BASE/api/v1/indexer" -H "X-Api-Key: $API_KEY"

# Get applications (Sonarr, Radarr, etc.)
curl "$BASE/api/v1/applications" -H "X-Api-Key: $API_KEY"

# Sync indexers to apps
curl -X POST "$BASE/api/v1/applications/sync" -H "X-Api-Key: $API_KEY"
```

#### Jellyseerr API Cheatsheet
```bash
BASE="http://localhost:5055"
API_KEY="your-api-key"  # Base64 decode the stored key

# Get settings
curl "$BASE/api/v1/settings/main" -H "X-Api-Key: $API_KEY"

# Get Jellyfin settings
curl "$BASE/api/v1/settings/jellyfin" -H "X-Api-Key: $API_KEY"

# Get requests
curl "$BASE/api/v1/request" -H "X-Api-Key: $API_KEY"
```

### Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `connection refused` on arr API | Service not ready | Wait for healthcheck, check `docker logs <service>` |
| `401 Unauthorized` | Wrong/missing API key | Get key from `config.xml` or service UI |
| `database is locked` (SQLite) | Service is running | Stop service before direct DB queries |
| `ECONNREFUSED 172.39.0.x` | Container not on network | Check `docker network inspect servarrnetwork` |
| Prowlarr sync fails | App API key changed | Re-add application in Prowlarr UI or API |
| Jellyfin plugin not loading | Wrong version/permissions | Check `docker logs jellyfin`, ensure `chown abc:abc` |
| qBittorrent 403 Forbidden | CSRF protection | Use `Referer` header or disable CSRF in settings |
| Bazarr can't reach Sonarr | Using IP instead of hostname | Use container name `sonarr` not `172.39.0.3` |
| Transcoding fails | Missing codecs/hardware | Check `ffmpeg -codecs`, enable hardware accel |
| Subtitles not burning | Wrong transcode setting | Set "Burn subtitles" to "All complex formats" |

### Shell Script Patterns

#### Extract API key from config.xml
```bash
get_api_key() {
    local config_file="$1"
    grep -oP '<ApiKey>\K[^<]+' "$config_file"
}
API_KEY=$(get_api_key "/path/to/config.xml")
```

#### Wait for service to be ready
```bash
wait_for_service() {
    local url="$1"
    local max_attempts="${2:-30}"
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0
        fi
        echo "Waiting for $url... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    return 1
}
wait_for_service "http://localhost:8989/api/v3/system/status"
```

#### Safe JSON POST with curl
```bash
api_post() {
    local url="$1"
    local data="$2"
    local api_key="$3"
    curl -sf -X POST "$url" \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $api_key" \
        -d "$data"
}
```

---

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
- **Subtitle burn-in**: Set "Burn subtitles" to "All complex formats" in user settings for ASS/SSA subs when transcoding

## Jellyfin Plugins & Extensions Tracker

### Currently Installed ✅
| Plugin | Version | Purpose | Notes |
|--------|---------|---------|-------|
| Jellyfin Enhanced | 9.6.2.0 | Quality tags, Jellyseerr search, .arr links, subtitle styling | Press `?` to open settings panel |
| File Transformation | 2.5.1.0 | Allows plugins to modify web files | Required by Media Bar |
| Media Bar | 2.4.4.0 | Netflix-style featured content slider | Auto-rotates featured content on home |

### Not Needed ❌
| Plugin | Reason |
|--------|--------|
| KefinTweaks | Features already in Jellyfin Enhanced |
| JS Injector | Only needed for KefinTweaks |
| Custom Tabs | Only needed for KefinTweaks Watchlist |
| Skin Manager | Themes caused issues - skip for now |

### Reviewed - Maybe Later 📋
| Plugin | Purpose | Repo | Notes |
|--------|---------|------|-------|
| intro-skipper | Auto-detect and skip intros/outros | [intro-skipper/intro-skipper](https://github.com/intro-skipper/intro-skipper) | Check if chapters already work |
| jellyscrub | Mouse-over video scrubbing previews | [nicknsy/jellyscrub](https://github.com/nicknsy/jellyscrub) | Native trickplay in 10.9+, may be redundant |
| Shokofin | Shoko anime management integration | [ShokoAnime/Shokofin](https://github.com/ShokoAnime/Shokofin) | For advanced anime library management |
| jellyfin-ani-sync | Sync anime progress to AniList | [vosmiic/jellyfin-ani-sync](https://github.com/vosmiic/jellyfin-ani-sync) | If using AniList |

### Reviewed - Avoid ❌
| Plugin | Reason |
|--------|--------|
| Themes (all) | Broke stuff last time - skip for now |

### Reference Lists
- **Awesome Jellyfin**: https://github.com/awesome-jellyfin/awesome-jellyfin
- **Themes List**: https://github.com/awesome-jellyfin/awesome-jellyfin/blob/main/THEMES.md
- **IAmParadox27 Plugin Repo**: https://www.iamparadox.dev/jellyfin/plugins/manifest.json

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
