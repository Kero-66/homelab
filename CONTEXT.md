# Homelab — Domain Map

## Infrastructure Layer

| Module | Host | Purpose |
|---|---|---|
| TrueNAS | 192.168.20.22 | Host OS — runs all Docker apps via `midclt` |
| Pools | `/mnt/Fast` (NVMe), `/mnt/Data` (HDD) | Storage — configs on Fast, media on Data |
| AdGuard Home | 192.168.20.22 | DNS — sole resolver, no fallback |
| Tailscale | TrueNAS app | Remote access / subnet router |

## Secrets & Config Rendering

```
Infisical (cloud) → Infisical Agent (TrueNAS container)
                          ↓ renders .tmpl → .env
         arr-stack / downloaders / jellyfin / homepage
```

All secrets use `--env dev`, path `/TrueNAS`. Agent templates: `truenas/stacks/infisical-agent/`.

## Media Pipeline

```
Autobrr (torrent announce) ──→ qBittorrent / SABnzbd (downloaders)
Prowlarr (indexer aggregator) ──→ Sonarr / Radarr (arr-stack)
                                         ↓
                              /mnt/Data/media/{shows,movies,anime}
                                         ↓
                                Jellyfin (media server)
                                Jellyseerr (request UI)
                                Jellystat (playback stats)
```

## Stack Locations

| Stack | Path | Services |
|---|---|---|
| arr-stack | `truenas/stacks/arr-stack/` | Sonarr, Radarr, Prowlarr, Bazarr, FlareSolverr, Cleanuparr |
| downloaders | `truenas/stacks/downloaders/` | qBittorrent, SABnzbd |
| jellyfin | `truenas/stacks/jellyfin/` | Jellyfin, Jellyseerr, Jellystat |
| autobrr | `truenas/stacks/autobrr/` | Autobrr + seed script |
| recyclarr | `truenas/stacks/recyclarr/` | Recyclarr (TRaSH quality profile sync) |
| caddy | `truenas/stacks/caddy/` | Reverse proxy — all service hostnames |
| homepage | `truenas/stacks/homepage/` | Service dashboard |
| adguard-home | `truenas/stacks/adguard-home/` | DNS |
| tailscale | `truenas/stacks/tailscale/` | VPN / subnet router |
| monitoring | `monitoring/compose.yaml` | Beszel (server monitoring) |
| infisical-agent | `truenas/stacks/infisical-agent/` | Secret rendering |

## Proxy

Caddy handles all reverse proxy. Caddyfile changes: `scp` to live location → `docker exec caddy caddy reload` (no app restart needed).

## Deployment Model

- Compose source-of-truth: `truenas/stacks/<stack>/compose.yaml`
- Deploy via `midclt` over SSH (`kero66` with `sudo`) — never docker-compose CLI or REST API
- Lifecycle: `app.stop` → `app.update` → `app.start`
- Caddyfile changes: reload only, no app restart

## Key Paths on TrueNAS

| Path | Contents |
|---|---|
| `/mnt/Fast/docker/<service>/` | Live configs, rendered `.env` files |
| `/mnt/Data/media/` | shows, movies, anime, music, tv |
| `/mnt/Data/downloads/` | qbittorrent, sabnzbd, complete, incomplete |
