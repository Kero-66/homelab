# TrueNAS State Assessment
_Captured: 2026-05-31, refreshed 2026-08-15_

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

| App | State |
|-----|-------|
| adguard-home | RUNNING |
| arr-stack | RUNNING |
| caddy | RUNNING |
| commafeed | RUNNING |
| dockhand | RUNNING |
| downloaders | RUNNING |
| fileflows | RUNNING |
| homepage | RUNNING |
| infisical-agent | RUNNING |
| jellyfin | RUNNING |
| tailscale | RUNNING |

11 apps, unchanged since 2026-05-31 — live migration to Dockhand has not progressed on this set. `arcane` and `portainer` are gone entirely (no container, no midclt entry) — removed deliberately, not doc drift.

Note: `autobrr`, `suggestarr`, and `infisical` (self-hosted secrets server) run as containers but are NOT TrueNAS native apps — deployed directly via Dockhand. `comicarr` (the previous Dockhand-managed app in this slot) was replaced by `suggestarr` on 2026-08-xx (commit `fbcecec`).

## Running Containers

_As of 2026-08-15 (names only — ports/uptime not re-captured, see Port Map below):_

adguard-home, autobrr, bazarr, caddy, cleanuparr, commafeed, commafeed-db, fileflows, flaresolverr, homepage, infisical, infisical-agent, infisical-db, infisical-redis, ix-dockhand-dockhand-1, jellyfin, jellyseerr, jellystat, jellystat-db, prowlarr, qbittorrent, radarr, recyclarr, sabnzbd, sonarr, suggestarr, tailscale

Changes since 2026-05-31: `comicarr` → `suggestarr` (replaced, commit `fbcecec`); `arcane` and `portainer` removed entirely; `infisical`/`infisical-db`/`infisical-redis` added (self-hosted Infisical migrated from workstation, commit `9e64e8a`).

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

## Docker Networks (live, 2026-08-15)

ix-* networks are TrueNAS auto-generated (midclt). Plain named networks are Dockhand-managed.

| Network | Type |
|---------|------|
| ix-adguard-home_default | TrueNAS |
| ix-arr-stack_default | TrueNAS |
| ix-caddy_default | TrueNAS |
| ix-commafeed_default | TrueNAS |
| ix-dockhand_default | TrueNAS |
| ix-downloaders_default | TrueNAS |
| ix-fileflows_default | TrueNAS |
| ix-homepage_default | TrueNAS |
| ix-infisical-agent_default | TrueNAS |
| ix-jellyfin_default | TrueNAS |
| autobrr_default | Dockhand |
| infisical_default | Dockhand |
| arr-stack_default | Pre-created (empty) |
| downloaders_default | Pre-created (empty) |
| jellyfin_default | Pre-created (empty) |
| rendered_default | Unknown |

`comicarr_default` is gone (comicarr removed). `arr-stack_default`, `downloaders_default`, `jellyfin_default` were created ahead of migration (2026-08-15, via `docker network create`) so dependent stacks can target final names immediately — currently empty, no containers joined yet. The corresponding `ix-*` networks still exist and are still in active use by the midclt-managed apps.

## Secrets Management

- **Infisical**: self-hosted on TrueNAS (192.168.20.22:8081) — migrated from workstation 2026-06-18
- **Project ID**: `5086c25c-310d-4cfb-9e2c-24d1fa92c152`
- **All secrets**: `--env dev`, paths `/TrueNAS` and `/media` and `/networking`
- **Infisical agent**: running on TrueNAS, renders `.env` files to `/mnt/Fast/docker/<stack>/`
- **Bitwarden**: personal passwords (not infrastructure)
- **Stack**: Dockhand-managed (`infisical` stack), uses `env_file:` with an absolute path (`/mnt/Fast/docker/infisical/.env`) — works fine through Dockhand

## Dockhand Migration Status (refreshed 2026-08-15)

- **Dockhand**: installed as TrueNAS native app, port 30328
- **Currently Dockhand-managed**: autobrr, suggestarr (comicarr's replacement), infisical (new — migrated for an unrelated reason, not part of this migration plan)
- **Currently midclt-managed**: 11 apps (adguard-home, arr-stack, caddy, commafeed, dockhand, downloaders, fileflows, homepage, infisical-agent, jellyfin, tailscale) — unchanged since 2026-05-31
- **Compose files**: ix-* network references renamed to plain names (commit 3d98525, 2026-05-31)
- **Live migration**: proceeding — decision made 2026-08-15 to move the remaining 11 apps to Dockhand. `arr-stack`/`downloaders`/`jellyfin` keep their current multi-container grouping (not splitting into one-service-per-stack — see `DOCKHAND_READINESS.md`).
- **Networks pre-created 2026-08-15**: `arr-stack_default`, `downloaders_default`, `jellyfin_default` exist now, ahead of any stack migrating — removes the need for a follow-up redeploy once dependent stacks (`arr-stack`'s jellyfin join, `suggestarr`) reference them. `suggestarr`'s compose file was updated to point at `jellyfin_default` but it hasn't been redeployed yet — still live on `ix-jellyfin_default` until that happens.
- **`DOCKHAND_GITOPS_GUIDE.md` is stale**: describes git-push-triggers-auto-deploy; current pattern is manual `scp` + `docker compose up -d --force-recreate` per `CLAUDE.md`. Needs reconciling or archiving — not a blocker for migration, just doc drift.
- See `DOCKHAND_READINESS.md` for the current per-stack status and deployment order.

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
