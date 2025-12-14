# Homelab

Personal fork of [TechHutTV/homelab](https://github.com/TechHutTV/homelab) - huge thanks to Brandon for the original project and inspiration!

## About This Fork

This is my personal homelab configuration, heavily customized for my own setup. I'm using this as a learning project to automate media server deployment and home infrastructure.

**Key differences from upstream:**
- Focused on Jellyfin stack (not Plex)
- Automated configuration via scripts and APIs
- WSL2/Windows host environment
- Different hardware

## What's Here

| Directory | Purpose |
|-----------|---------|
| [media/](media/) | Jellyfin, *arr stack, download clients |
| [media/jellyfin/](media/jellyfin/) | Jellyfin + Jellyseerr + Jellystat |
| [monitoring/](monitoring/) | Grafana, Prometheus, Telegraf |
| [proxy/](proxy/) | Reverse proxy setup |
| [homeassistant/](homeassistant/) | Smart home (WIP) |
| [surveillance/](surveillance/) | Frigate NVR (WIP) |

## Quick Start

```bash
cd media
cp .env.example .env  # Edit with your paths
docker compose up -d
./jellyfin/install_plugins.sh
```

## My Setup

- **Host**: Windows 11 + WSL2 (Fedora) → Migrating to native Linux
- **Storage**: HDD mounted at `/mnt/d/homelab-data`
- **Media Server**: Jellyfin with Jellyseerr for requests
- **Arr Stack**: Sonarr, Radarr, Lidarr, Prowlarr, Bazarr

## 🚀 Migrating to Linux?

Complete backup and migration tools included! See [BACKUP_README.md](BACKUP_README.md).

**Quick Start:**
```bash
./backup_quick_start.sh  # Interactive backup wizard
# or
./verify_before_migration.sh  # Check your system
./backup_to_d_drive.sh        # Backup everything
```

All your configurations, databases, and scripts will be safely backed up to D drive, ready for restore on your new Linux system. Full migration guide included!


## Unified Credentials and Proxy Authentication

All media services (Jellyfin, *arr apps, Jackett, etc.) use a single set of credentials, stored in `media/.config/.credentials` (gitignored). This file is referenced by all Docker Compose files and injected into containers as environment variables. The same username and password are used for all web UIs and API authentication.

**Security Model:**
- **Reverse Proxy (NGINX Proxy Manager):** All external access is routed through the proxy, which enforces HTTP Basic Authentication using the unified credentials. This means you only need to log in once at the proxy, and backend services (including Jackett) do not store or enforce their own admin passwords.
- **No Plaintext Passwords in App Configs:** Jackett and other services do not store the admin password in their config files. Authentication is handled at the proxy layer.
- **Credential Changes:** To change your password, update `media/.config/.credentials` and restart the affected containers and proxy.

**Credential Flow Example:**
1. User requests `https://jackett.example.com` (or any media service).
2. NGINX Proxy Manager prompts for Basic Auth using the credentials from `media/.config/.credentials`.
3. Upon successful login, the request is forwarded to the backend service (e.g., Jackett), which does not require a separate password.
4. All other media services follow the same pattern.

**Note:**
- If you want to enforce per-service credentials, you can set admin passwords in each app, but this is not recommended for most home lab setups.

See `media/jackett/README.md` and `proxy/README.md` for more details.

## Credits

- Original project: [TechHutTV/homelab](https://github.com/TechHutTV/homelab) by [Brandon](https://github.com/TechHutTV)
- TRaSH Guides: https://trash-guides.info/
- Servarr Wiki: https://wiki.servarr.com/

## License

See upstream repository for license information.
