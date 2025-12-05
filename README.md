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

- **Host**: Windows 11 + WSL2 (Fedora)
- **Storage**: HDD mounted at `/mnt/d/homelab-data`
- **Media Server**: Jellyfin with Jellyseerr for requests
- **Arr Stack**: Sonarr, Radarr, Lidarr, Prowlarr, Bazarr

## Credits

- Original project: [TechHutTV/homelab](https://github.com/TechHutTV/homelab) by [Brandon](https://github.com/TechHutTV)
- TRaSH Guides: https://trash-guides.info/
- Servarr Wiki: https://wiki.servarr.com/

## License

See upstream repository for license information.
