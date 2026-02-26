# Frontend Stack Migration: Homepage, Caddy, AdGuard Home

This guide covers migrating the frontend stack (Homepage, Caddy, AdGuard Home) from workstation to TrueNAS.

## Overview

**What's being migrated:**
- Homepage dashboard (with all API keys)
- Caddy reverse proxy
- AdGuard Home DNS server

**Why this migration:**
- Centralize all services on TrueNAS
- Enable network-wide DNS with custom `.home` domains
- Allow workstation to be shut down
- Clean URLs instead of IPs (jellyfin.home vs 192.168.20.22:8096)

## Prerequisites

- [ ] TrueNAS accessible at 192.168.20.22
- [ ] SSH access configured (`ssh kero66@192.168.20.22`)
- [ ] Infisical Agent running on TrueNAS
- [ ] Arr stack and downloaders already migrated
- [ ] Review `truenas/MIGRATION_CHECKLIST.md`

## Phase 1: Migrate Configurations

### Step 1: Create Backup

```bash
cd /mnt/library/repos/homelab
bash truenas/scripts/migrate_frontend_stack.sh
```

**This script will:**
1. Create backup of all configs
2. Create directories on TrueNAS
3. Copy Caddy, AdGuard, and Homepage configs
4. Fix ownership to 1000:1000

**Backup location:** `~/frontend_stack_backup_TIMESTAMP.tar.gz`

### Step 2: Upload Infisical Template

```bash
# Upload Homepage template
scp truenas/stacks/infisical-agent/homepage.tmpl \
  kero66@192.168.20.22:/mnt/Fast/docker/infisical-agent/config/

# Upload updated agent config
scp truenas/stacks/infisical-agent/agent-config.yaml \
  kero66@192.168.20.22:/mnt/Fast/docker/infisical-agent/config/
```

### Step 3: Restart Infisical Agent

Via TrueNAS Web UI:
1. Apps → infisical-agent → Stop
2. Wait 10 seconds
3. Apps → infisical-agent → Start

**Verify .env generated:**
```bash
ssh kero66@192.168.20.22 'cat /mnt/Fast/docker/homepage/.env | head -5'
```

Should show: `HOMEPAGE_VAR_SONARR_API_KEY=...`

### Step 4: Update Caddyfile

```bash
# Upload updated Caddyfile
scp truenas/stacks/caddy/Caddyfile \
  kero66@192.168.20.22:/mnt/Fast/docker/caddy/
```

## Phase 2: Deploy Services

### Deploy AdGuard Home

1. **TrueNAS Web UI:** Apps → Discover → Custom App
2. **Release Name:** `adguard-home`
3. **Version:** `1.0.0`
4. **Compose YAML:** Copy from `truenas/stacks/adguard-home/compose.yaml`
5. Click **Install**

**First-time setup:**
1. Access http://192.168.20.22:3080
2. Follow setup wizard
3. Set admin username/password
4. Configure upstream DNS: 1.1.1.1, 8.8.8.8
5. Skip DHCP configuration (using router DHCP)

### Deploy Caddy

1. **TrueNAS Web UI:** Apps → Discover → Custom App
2. **Release Name:** `caddy`
3. **Version:** `1.0.0`
4. **Compose YAML:** Copy from `truenas/stacks/caddy/compose.yaml`
5. Click **Install**

**Verify Caddy started:**
```bash
ssh kero66@192.168.20.22 'docker logs caddy --tail 20'
```

### Deploy Homepage

1. **TrueNAS Web UI:** Apps → Discover → Custom App
2. **Release Name:** `homepage`
3. **Version:** `1.0.0`
4. **Compose YAML:** Copy from `truenas/stacks/homepage/compose.yaml`
5. Click **Install**

**Verify Homepage started:**
```bash
ssh kero66@192.168.20.22 'docker ps | grep homepage'
curl http://192.168.20.22:3000/
```

## Phase 3: Configure DNS

### Add Local DNS Entries in AdGuard Home

1. Access http://192.168.20.22:3080
2. Filters → DNS rewrites → Add DNS rewrite
3. Add these entries (all pointing to 192.168.20.22):

```
homepage.home     → 192.168.20.22
jellyfin.home     → 192.168.20.22
jellyseerr.home   → 192.168.20.22
jellystat.home    → 192.168.20.22
sonarr.home       → 192.168.20.22
radarr.home       → 192.168.20.22
prowlarr.home     → 192.168.20.22
bazarr.home       → 192.168.20.22
qbittorrent.home  → 192.168.20.22
sabnzbd.home      → 192.168.20.22
adguard.home      → 192.168.20.22
cleanuparr.home   → 192.168.20.22
flaresolverr.home → 192.168.20.22
truenas.home      → 192.168.20.22
jetkvm.home       → 192.168.20.22
```

4. Click **Save**

### Update Router DNS Settings

**Option 1: Router DHCP (Recommended)**
1. Access router admin (usually 192.168.1.1 or 192.168.0.1)
2. DHCP Settings → DNS Servers
3. Primary DNS: `192.168.20.22` (AdGuard Home)
4. Secondary DNS: `1.1.1.1` (Cloudflare fallback)
5. Save and reboot router

**Option 2: Manual DNS on Each Device**
On workstation (Fedora):
```bash
# Edit NetworkManager connection
sudo nmcli connection modify "Your Connection Name" ipv4.dns "192.168.20.22 1.1.1.1"
sudo nmcli connection down "Your Connection Name"
sudo nmcli connection up "Your Connection Name"

# Verify
cat /etc/resolv.conf | grep nameserver
```

### Test DNS Resolution

```bash
# Should return 192.168.20.22
nslookup jellyfin.home
nslookup homepage.home
nslookup sonarr.home
```

## Phase 4: Verification

### Test Each Service

```bash
# Homepage
curl http://homepage.home/
firefox http://homepage.home

# Jellyfin
curl http://jellyfin.home/health
firefox http://jellyfin.home

# Sonarr
curl http://sonarr.home/sonarr/api/v3/system/status -H "X-Api-Key: YOUR_KEY"
firefox http://sonarr.home/sonarr

# Radarr
firefox http://radarr.home/radarr

# AdGuard Admin
firefox http://adguard.home
```

### Verify Homepage Widgets

1. Open http://homepage.home
2. Check all widgets load correctly:
   - [ ] Jellyfin widget shows library counts
   - [ ] Sonarr widget shows series count
   - [ ] Radarr widget shows movie count
   - [ ] qBittorrent widget shows download stats
   - [ ] SABnzbd widget shows queue

**If widgets fail:**
```bash
# Check Homepage logs
ssh kero66@192.168.20.22 'docker logs homepage --tail 50'

# Check API keys are loaded
ssh kero66@192.168.20.22 'docker exec homepage env | grep HOMEPAGE_VAR'
```

### Verify All Containers Healthy

```bash
ssh kero66@192.168.20.22 'docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(homepage|caddy|adguard)"'
```

All should show `Up X minutes (healthy)`.

## Phase 5: Update Homepage Config (Optional)

Since services now use `.home` domains, update Homepage's `services.yaml`:

**Before:**
```yaml
- Sonarr:
    href: http://192.168.20.22:8989/sonarr
```

**After:**
```yaml
- Sonarr:
    href: http://sonarr.home/sonarr
```

**Update on TrueNAS:**
1. Edit `/mnt/Fast/docker/homepage/config/services.yaml`
2. Replace IPs with .home domains
3. Restart Homepage: `docker restart homepage`

Or update locally and re-migrate.

## Troubleshooting

### DNS Not Resolving

**Check AdGuard is running:**
```bash
ssh kero66@192.168.20.22 'docker ps | grep adguard'
```

**Test DNS from workstation:**
```bash
nslookup jellyfin.home 192.168.20.22
# Should return 192.168.20.22
```

**Check router DNS settings applied:**
```bash
cat /etc/resolv.conf
# Should show: nameserver 192.168.20.22
```

### Caddy 404 Errors

**Check Caddyfile loaded:**
```bash
ssh kero66@192.168.20.22 'docker exec caddy cat /etc/caddy/Caddyfile | head -20'
```

**Check Caddy logs:**
```bash
ssh kero66@192.168.20.22 'docker logs caddy --tail 50'
```

**Verify Caddy can reach services:**
```bash
ssh kero66@192.168.20.22 'docker exec caddy wget -O- http://jellyfin:8096/health'
```

### Homepage API Keys Missing

**Check Infisical Agent rendered .env:**
```bash
ssh kero66@192.168.20.22 'cat /mnt/Fast/docker/homepage/.env'
```

Should contain `HOMEPAGE_VAR_*` variables.

**If empty, check Infisical Agent logs:**
```bash
ssh kero66@192.168.20.22 'docker logs infisical-agent --tail 50'
```

**Manually restart agent:**
```bash
ssh kero66@192.168.20.22 'docker restart infisical-agent'
sleep 30
ssh kero66@192.168.20.22 'cat /mnt/Fast/docker/homepage/.env'
```

### Port 53 Conflict (AdGuard DNS)

If TrueNAS is running its own DNS on port 53:

**Option 1: Disable TrueNAS DNS**
```bash
# Via TrueNAS Web UI: Network → Global Configuration
# Uncheck "Enable DNS Service"
```

**Option 2: Use Different Port**
Update compose.yaml:
```yaml
ports:
  - "5353:53/tcp"  # Use 5353 instead
  - "5353:53/udp"
```

Then clients must use port 5353 for DNS queries.

## Success Criteria

- [x] All three services deployed and healthy
- [x] DNS resolves `.home` domains to 192.168.20.22
- [x] Caddy proxies requests to correct services
- [x] Homepage dashboard accessible at http://homepage.home
- [x] All Homepage widgets loading with correct data
- [x] Can access Jellyfin at http://jellyfin.home
- [x] Can access Sonarr at http://sonarr.home
- [x] Can access Radarr at http://radarr.home

## Next Steps

1. Configure Tailscale for external access (see `truenas/ARR_DEPLOYMENT.md`)
2. Enable HTTPS in Caddy with Let's Encrypt (future enhancement)
3. Stop services on workstation (cold spare)
4. Update todo list with completed tasks

## Rollback

If migration fails:

```bash
# Stop services on TrueNAS
ssh kero66@192.168.20.22 'docker stop homepage caddy adguard-home'

# Restore backup on workstation
cd /mnt/library/repos/homelab
tar xzf ~/frontend_stack_backup_*.tar.gz

# Start services on workstation
docker compose -f networking/compose.yaml --profile network up -d
docker compose -f apps/homepage/compose.yaml up -d

# Revert router DNS to original settings
```
