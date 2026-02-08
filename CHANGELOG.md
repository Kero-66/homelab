# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **TVHeadend Service**: Added optional TVHeadend container for live TV/IPTV support
  - New configuration script: `media/scripts/configure_tvheadend.sh`
  - Integrated into `automate_all.sh` as Step 10
  - Added to compose.yaml with proper health checks and network configuration
  - Accessible at `http://localhost:9981` (default port configurable via `TVHEADEND_PORT`)

- **Jellyfin Plugin Enhancements**: Expanded plugin management and customization
  - Added JavaScript Injector plugin for UI customization
  - Added Jellyfin Tweaks plugin for enhanced UI features
  - Added Plugin Pages plugin for extended plugin management
  - Added NextPVR plugin for TV integration
  - Updated `media/jellyfin/install_plugins.sh` to install all new plugins
  - Created `media/jellyfin/plugin-configs/javascript-injector-live-snapshot-20251206.xml` with:
    - KefinTweaks configuration for enhanced UI
    - Jellyseerr URL rewriting for cross-network access
    - Automatic link rewriting via MutationObserver

- **Download Client Configuration**: Enhanced IP address management
  - Updated `media/scripts/configure_download_clients.sh` to use environment variables
  - Added support for `IP_QBITTORRENT` environment variables
  - Allows dynamic IP assignment instead of hardcoded values

### Changed
- **Docker Compose**: Removed hardcoded `/etc/localtime` mounts
  - Affects: prowlarr, sonarr, radarr, lidarr, bazarr
  - Timezone now controlled exclusively via `TZ` environment variable
  - Improves reproducibility across different host systems

- **Automation Scripts**: Updated overall completion status
  - Changed `automate_all.sh` final message from ~97% to ~98% complete
  - Added TVHeadend service information to output summary

- **Documentation**: Enhanced `memory.md` with integration status table
  - Added detailed service integration information
  - Documented Jellyfin plugin configuration approach
  - Added JavaScript Injector and custom script details

### Fixed
- **Git Ignore**: Updated `.gitignore` to properly handle TVHeadend
  - Added `media/tvheadend/` to runtime exclusions
  - Ensures plugin configuration directory is tracked while runtime data is excluded
  - Added exception rules for `media/jellyfin/plugin-configs/` to track customizations

### Security
- **Verified**: No credentials exposed in committed files
  - All API keys, passwords, and tokens reference external `.env` and `.credentials` files
  - Plugin configurations contain no sensitive data
  - Environment variable usage for dynamic credential injection

### Migration Notes
For existing deployments:
1. Update `.env` to include `IP_QBITTORRENT` if using environment-based IPs
2. TVHeadend is optional; uncomment in compose.yaml if needed
3. New Jellyfin plugins will be installed on next `media/jellyfin/install_plugins.sh` run
4. Restart Jellyfin after plugin installation to load configurations

### Testing Status
- ✅ Configuration files validated (no credential leaks)
- ✅ Git ignore rules verified
- ✅ Plugin configuration XML validated
- ✅ Download client configuration compatibility confirmed
- ⏳ TVHeadend functionality pending manual integration testing
