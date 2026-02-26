# TrueNAS Stack Deployment Guide

## Overview

This guide covers deploying all Custom App stacks on **TrueNAS Scale 25.10.1** with Infisical Agent for secrets management.

**Deployed stacks (all running):**
- `infisical-agent` — renders `.env` files from Infisical secrets
- `jellyfin` — Jellyfin, Jellyseerr, Jellystat + DB
- `arr-stack` — Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr, FlareSolverr, Cleanuparr
- `downloaders` — qBittorrent, SABnzbd
- `caddy` — reverse proxy for all `.home` domains
- `adguard-home` — local DNS (resolves `.home` → 192.168.20.22)
- `homepage` — dashboard
- `tailscale` — subnet router for remote access

**Important:** Custom Apps cannot be created via the REST API. Use `midclt call -j app.create` via SSH — see `ai/PATTERNS.md` → "Create a new Custom App".

---

## Prerequisites

1. **Infisical Machine Identity** configured with `Universal Auth` credentials
2. **TrueNAS API Key** stored in Infisical at `/TrueNAS/truenas_admin_api`
3. **SSH access** via kero66 key from Infisical (`kero66_ssh_key` at `/TrueNAS`)
4. **Docker IPv6 fix** applied (Job 5442 — IPv6 pools removed, forcing IPv4-only)

---

## Deploying a New Stack

### Preferred: midclt via SSH (no Web UI needed)

```bash
# From workstation repo root
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null

APP_NAME=my-app  # replace with actual app name
python3 -c "
import json
compose = open('truenas/stacks/$APP_NAME/compose.yaml').read()
payload = json.dumps({
    'custom_app': True,
    'app_name': '$APP_NAME',
    'train': 'stable',
    'custom_compose_config_string': compose
})
print(payload)
" | ssh kero66@192.168.20.22 "cat > /tmp/app_payload.json && sudo midclt call -j app.create \"\$(cat /tmp/app_payload.json)\" 2>&1; rm /tmp/app_payload.json"

ssh-agent -k > /dev/null
```

See `ai/PATTERNS.md` for the full verified pattern.

### Alternative: Web UI

1. TrueNAS Web UI → Apps → Discover → Custom App
2. Release Name: `<app-name>`
3. Version: `1.0.0`
4. Paste compose YAML from `truenas/stacks/<app-name>/compose.yaml`
5. Click Install

---

## Updating a Running Stack's Caddyfile

The live Caddyfile is at `/mnt/Fast/docker/caddy/Caddyfile` on TrueNAS (the repo file is source of truth).

```bash
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null

# Copy repo file to live location
scp truenas/stacks/caddy/Caddyfile kero66@192.168.20.22:/mnt/Fast/docker/caddy/Caddyfile

# Reload Caddy (graceful, no restart needed)
ssh kero66@192.168.20.22 "sudo docker exec caddy caddy reload --config /etc/caddy/Caddyfile"

ssh-agent -k > /dev/null
```

---

## Stack Details

### infisical-agent

Renders `.env` files from Infisical secrets for other stacks.

- Config: `/mnt/Fast/docker/infisical-agent/config/`
- Output: `/mnt/Fast/docker/{arr-stack,downloaders,jellyfin,homepage}/`
- Templates: `truenas/stacks/infisical-agent/*.tmpl`

### jellyfin

Media server stack.

- Jellyfin: port 8096 → `http://jellyfin.home`
- Jellyseerr: port 5055 → `http://jellyseerr.home`
- Jellystat: port 3001 → `http://jellystat.home`
- Hardware transcoding: Intel N150 VAAPI via iHD driver (see `ai/PATTERNS.md` → Intel N150 VAAPI)
- Config: `/mnt/Fast/docker/jellyfin/`
- Media: `/mnt/Data/media/`

### arr-stack

- Sonarr: `http://sonarr.home`
- Radarr: `http://radarr.home`
- Prowlarr: `http://prowlarr.home`
- Bazarr: `http://bazarr.home`
- Recyclarr, FlareSolverr, Cleanuparr (no web UI for last two)
- Config: `/mnt/Fast/docker/arr-stack/`
- Secrets: rendered from Infisical by infisical-agent

### downloaders

- qBittorrent: `http://qbittorrent.home`
- SABnzbd: `http://sabnzbd.home`
- Config: `/mnt/Fast/docker/downloaders/`
- Downloads: `/mnt/Data/downloads/`

### caddy

Reverse proxy. Listens on :80 and :443.

- Live config: `/mnt/Fast/docker/caddy/Caddyfile`
- Source of truth: `truenas/stacks/caddy/Caddyfile`
- To update: scp + `caddy reload` (see above)
- All `.home` domains proxied except `truenas.home` (redirect to HTTPS IP)
- External devices (JetKVM, TrueNAS) proxied by IP, not container name

### adguard-home

Local DNS resolver.

- Admin UI: `http://adguard.home` (port 3000 internally, proxied by Caddy)
- DNS port: 53 (receives queries from router DHCP clients)
- DNS rewrites: all `.home` domains → 192.168.20.22
- Upstream DNS: 1.1.1.1 (Cloudflare)
- Router DHCP: only sends 192.168.20.22 as DNS (no secondary fallback)

### homepage

Dashboard at `http://homepage.home`.

- Config: `/mnt/Fast/docker/homepage/config/`
- Secrets injected via `.env` from infisical-agent

### tailscale

Subnet router for remote access.

- Advertises `192.168.20.0/24`
- Split DNS in Tailscale admin: `home` domain → TrueNAS Tailscale IP
- Result: all `*.home` services work identically over Tailscale
- Auth key: `TRUENAS_TAILSCALE_AUTH_KEY` in Infisical at `/TrueNAS`
- State: `/mnt/Fast/docker/tailscale/`

---

## DNS Rewrites (AdGuard Home)

All entries point to `192.168.20.22`. Add/verify at http://adguard.home → Filters → DNS rewrites.

| Domain | Target |
|--------|--------|
| `homepage.home` | 192.168.20.22 |
| `jellyfin.home` | 192.168.20.22 |
| `jellyseerr.home` | 192.168.20.22 |
| `jellystat.home` | 192.168.20.22 |
| `sonarr.home` | 192.168.20.22 |
| `radarr.home` | 192.168.20.22 |
| `prowlarr.home` | 192.168.20.22 |
| `bazarr.home` | 192.168.20.22 |
| `qbittorrent.home` | 192.168.20.22 |
| `sabnzbd.home` | 192.168.20.22 |
| `adguard.home` | 192.168.20.22 |
| `cleanuparr.home` | 192.168.20.22 |
| `flaresolverr.home` | 192.168.20.22 |
| `truenas.home` | 192.168.20.22 |
| `jetkvm.home` | 192.168.20.22 |

---

## Troubleshooting

### Image Pull Failures

IPv6 pools were removed (Job 5442) — all image pulls now use IPv4 only. If pulls fail again:

```bash
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain)
curl -sk "https://192.168.20.22/api/v2.0/docker" \
  -H "Authorization: Bearer $TRUENAS_API_KEY" | jq '.address_pools[].base'
# Expected: only 172.17.0.0/12
```

### Infisical Agent Not Rendering Secrets

```bash
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null
ssh kero66@192.168.20.22 "sudo docker logs infisical-agent --tail 30"
ssh-agent -k > /dev/null
```

### Caddy Not Proxying Correctly

```bash
# Check live Caddyfile matches repo
ssh kero66@192.168.20.22 "sudo docker exec caddy cat /etc/caddy/Caddyfile"

# Reload if needed
ssh kero66@192.168.20.22 "sudo docker exec caddy caddy reload --config /etc/caddy/Caddyfile"
```

---

## References

- **Verified commands**: `ai/PATTERNS.md` — check before trial-and-error
- **Architecture**: `truenas/README.md`
- **Frontend stack**: `truenas/FRONTEND_STACK_DEPLOYMENT.md`
- **Migration checklist**: `truenas/MIGRATION_CHECKLIST.md`
- **Troubleshooting**: `.github/TROUBLESHOOTING.md`
- **TrueNAS API**: https://www.truenas.com/docs/scale/api/
