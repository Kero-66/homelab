# TrueNAS State Assessment
_Captured: 2026-05-31_

## Hardware

| Item | Value |
|------|-------|
| Manufacturer | AZW (Beelink) |
| Model | ME Pro |
| CPU | Intel N150 |
| RAM | 16GB (15Gi usable) |
| OS Version | TrueNAS Scale 25.10.1 |
| Hostname | truenas |
| IP | 192.168.20.22 |
| NIC | enp2s0 (active), enp3s0 (down/spare) |
| Tailscale IP | 100.98.14.66 |

## Storage Pools

| Pool | Size | Used | Free | Health | Layout |
|------|------|------|------|--------|--------|
| Data | 7.27T | 6.46T (88%) | 823G | ONLINE | mirror-0 (2x HDD) |
| Fast | 944G | 13.1G (1%) | 931G | ONLINE | mirror-0 (2x NVMe) |
| boot-pool | 952G | 3.2G (0%) | 949G | ONLINE | nvme0n1p3 (single) |

### Disks

| Device | Size | Type | Role |
|--------|------|------|------|
| sda | 7.3T | HDD | Data pool mirror |
| sdb | 7.3T | HDD | Data pool mirror |
| nvme0n1 | 953.9G | NVMe | boot-pool |
| nvme1n1 | 953.9G | NVMe | Fast pool mirror |
| nvme2n1 | 953.9G | NVMe | Fast pool mirror |

### Key Dataset Mount Points

| Dataset | Mount | Size Used |
|---------|-------|-----------|
| Data | /mnt/Data | 6.60T |
| Data/media | /mnt/Data/media | 5.85T |
| Data/media/shows | /mnt/Data/media/shows | 2.99T |
| Data/media/movies | /mnt/Data/media/movies | 1.01T |
| Data/downloads | /mnt/Data/downloads | 771G |
| Fast | /mnt/Fast | 13.4G |
| Fast/docker | /mnt/Fast/docker | 2.95G |
| Fast/databases | /mnt/Fast/databases | 53M |
| Fast/ix-apps | /mnt/.ix-apps | 10.3G |

⚠️ **Data pool at 88% capacity** — ZFS performance degrades above 80%. Consider expanding or cleaning downloads.

## SMB Shares

| Share Name | Path | Enabled |
|------------|------|---------|
| media | /mnt/Data/media | Yes |
| docker-configs | /mnt/Fast/docker | Yes |

## TrueNAS Native Apps (midclt-managed)

| App | Version | State |
|-----|---------|-------|
| adguard-home | v1.0.0 | RUNNING |
| arcane | v1.0.59 | RUNNING |
| arr-stack | v1.0.0 | RUNNING |
| caddy | v1.0.0 | RUNNING |
| commafeed | v1.0.0 | RUNNING |
| dockhand | v1.1.10 | RUNNING |
| downloaders | v1.0.0 | RUNNING |
| fileflows | v1.0.0 | RUNNING |
| homepage | v1.0.0 | RUNNING |
| infisical-agent | v1.0.0 | RUNNING |
| jellyfin | v1.0.0 | RUNNING |
| portainer | v1.7.1 | RUNNING |
| tailscale | v1.0.0 | RUNNING |

Note: `autobrr` and `comicarr` are running as containers but NOT listed as TrueNAS native apps — deployed directly via Dockhand.

## Running Containers

| Container | Uptime | Ports |
|-----------|--------|-------|
| infisical-agent | 12h (healthy) | — |
| tailscale | 36h (healthy) | — |
| comicarr | 39h | 8090 |
| qbittorrent | 4d (healthy) | 8080, 6881 |
| flaresolverr | 4d (healthy) | 8191 |
| jellyfin | 5d (healthy) | 8096, 8920 |
| sonarr | 5d (healthy) | 8989 |
| adguard-home | 8d (healthy) | 53, 3080, 4443, 5443, 853 |
| sabnzbd | 9d (healthy) | 8085 |
| autobrr | 9d | 7474 |
| bazarr | 9d (healthy) | 6767 |
| cleanuparr | 9d (healthy) | 11011 |
| recyclarr | 9d (healthy) | — |
| radarr | 9d (healthy) | 7878 |
| prowlarr | 9d (healthy) | 9696 |
| jellystat-db | 2w (healthy) | 5432 |
| commafeed-db | 2w (healthy) | 5432 (internal) |
| caddy | 2w (healthy) | 80 |
| homepage | 2w (healthy) | 3000 |
| jellystat | 6w (healthy) | 3002 |
| commafeed | 6w (healthy) | 8088 |
| fileflows | 7w (healthy) | 19200 |
| dockhand | 7w (healthy) | 30328 |
| portainer | 7w | 31015 |
| arcane | 7w (healthy) | 30258 |
| jellyseerr | 2mo (healthy) | 5055 |

## Port Map

| Port | Service | Notes |
|------|---------|-------|
| 22 | sshd | TrueNAS SSH |
| 53 | adguard-home | DNS |
| 80 | caddy | HTTP reverse proxy |
| 443 | nginx | TrueNAS UI (HTTPS) |
| 445/139 | smbd | SMB shares |
| 853 | adguard-home | DNS-over-TLS |
| 3000 | homepage | Dashboard |
| 3002 | jellystat | Analytics UI |
| 3080 | adguard-home | Web UI |
| 4443 | adguard-home | HTTPS |
| 5055 | jellyseerr | Request UI |
| 5432 | jellystat-db | PostgreSQL (exposed — consider restricting) |
| 5443 | adguard-home | Alt HTTPS |
| 6767 | bazarr | Subtitles |
| 6881 | qbittorrent | Torrent port |
| 7474 | autobrr | Release automation |
| 7878 | radarr | Movie management |
| 8080 | qbittorrent | Web UI |
| 8082 | nginx | TrueNAS UI alt |
| 8085 | sabnzbd | Usenet client |
| 8088 | commafeed | RSS reader |
| 8090 | comicarr | Comic/manga manager |
| 8096 | jellyfin | Media server |
| 8191 | flaresolverr | Cloudflare bypass |
| 8920 | jellyfin | HTTPS |
| 8989 | sonarr | TV management |
| 9696 | prowlarr | Indexer manager |
| 11011 | cleanuparr | Queue cleanup |
| 19200 | fileflows | Media transcoding |
| 30258 | arcane | (TrueNAS app) |
| 30328 | dockhand | Container manager |
| 31015 | portainer | Container UI |

## Docker Networks (live)

ix-* networks are TrueNAS auto-generated. Plain named networks are Dockhand-managed.

| Network | Type | Status |
|---------|------|--------|
| ix-arr-stack_default | TrueNAS | Active (to be removed post-Dockhand) |
| ix-jellyfin_default | TrueNAS | Active (to be removed post-Dockhand) |
| ix-downloaders_default | TrueNAS | Active (to be removed post-Dockhand) |
| autobrr_default | Dockhand | Active |
| comicarr_default | Dockhand | Active |
| rendered_default | Unknown | Active |

Note: arr-stack_default, jellyfin_default, downloaders_default networks (from new compose files) will be created when stacks are migrated to Dockhand.

## Secrets Management

- **Infisical**: self-hosted on TrueNAS (192.168.20.22:8081) — migrated from workstation 2026-06-18
- **Project ID**: `5086c25c-310d-4cfb-9e2c-24d1fa92c152`
- **All secrets**: `--env dev`, paths `/TrueNAS` and `/media` and `/networking`
- **Infisical agent**: running on TrueNAS, renders `.env` files to `/mnt/Fast/docker/<stack>/`
- **Bitwarden**: personal passwords (not infrastructure)
- **Stack**: Dockhand-managed (`infisical` stack), env vars inlined in compose (env_file not supported through Dockhand)

## Dockhand Migration Status (2026-05-31)

- **Dockhand**: already installed as TrueNAS native app v1.1.10, port 30328
- **Currently Dockhand-managed**: autobrr, comicarr (confirmed by no ix-* network prefix)
- **Currently midclt-managed**: all other apps (13 apps)
- **Compose files**: updated — all ix-* network references renamed to plain names (commit 3d98525)
- **Live migration**: NOT started — stacks still running under midclt

### Migration order when proceeding:
1. infisical-agent (already running — verify .env files present before proceeding)
2. commafeed, fileflows (no cross-stack deps — lowest risk test)
3. adguard-home, tailscale (independent)
4. arr-stack (defines arr-stack_default network — must be first of the cross-stack group)
5. downloaders (joins arr-stack_default)
6. jellyfin (defines jellyfin_default)
7. autobrr (joins arr-stack_default + downloaders_default) — already on Dockhand, needs network rename applied
8. caddy, homepage (join multiple networks — migrate last)
9. comicarr (joins downloaders_default) — already on Dockhand, needs network rename applied

## Access Summary

| Service | URL | Notes |
|---------|-----|-------|
| TrueNAS UI | https://192.168.20.22 | truenas_admin (break-glass) |
| AdGuard Home | http://192.168.20.22:3080 | DNS admin |
| Jellyfin | http://jellyfin.home | Media |
| Homepage | http://homepage.home | Dashboard |
| Sonarr | http://sonarr.home | TV |
| Radarr | http://radarr.home | Movies |
| Prowlarr | http://prowlarr.home | Indexers |
| Bazarr | http://bazarr.home | Subtitles |
| qBittorrent | http://qbittorrent.home | Torrents |
| SABnzbd | http://sabnzbd.home | Usenet |
| Autobrr | http://autobrr.home | Releases |
| Jellyseerr | http://jellyseerr.home | Requests |
| Jellystat | http://jellystat.home | Analytics |
| Dockhand | http://192.168.20.22:30328 | Container manager |
| Portainer | http://192.168.20.22:31015 | Container UI |
| Infisical | http://192.168.20.22:8081 | Secrets (TrueNAS-hosted) |
