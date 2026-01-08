# Fresh Deployment Checklist

Use this checklist when deploying the media stack on a new server.

## Pre-Deployment (5 minutes)

### 1. System Requirements
- [ ] Docker and Docker Compose installed
- [ ] At least 8GB RAM available
- [ ] `/data` directory created with proper permissions
- [ ] User added to `docker` group: `sudo usermod -aG docker $USER`

### 2. Repository Setup
```bash
git clone https://github.com/TechHutTV/homelab.git
cd homelab/media
```

### 3. Configuration Files

#### Create `.env` file
```bash
cp .env.example .env
nano .env  # Edit with your settings
```

Key settings to configure:
- `PUID` and `PGID` (run `id` command to get yours)
- `TZ` (your timezone, e.g., `America/New_York`)
- `DATA_DIR` (default: `/data`)
- Port numbers (if defaults conflict)

#### Create `.config/.credentials` file
```bash
mkdir -p .config
nano .config/.credentials
```

Add:
```
USERNAME=your_admin_username
PASSWORD=your_secure_password
```

**Important:** This file is gitignored and contains your master credentials for all services.

### 4. Data Directory Structure
```bash
sudo mkdir -p /data/{downloads/{qbittorrent/{completed,incomplete,torrents},nzbget/{completed,intermediate,nzb,queue,tmp}},movies,shows,music,books,youtube}
sudo chown -R $USER:$USER /data
```

## Deployment (10 minutes)

### 5. Start Services
```bash
# Start all containers
docker compose up -d

# Wait for services to initialize (~30 seconds)
sleep 30
```

### 6. Run Automation
```bash
# This configures everything automatically (~5 minutes)
bash automate_all.sh
```

The script will:
- ✅ Configure authentication for all Arr apps
- ✅ Add root folders (`/data/movies`, `/data/shows`, `/data/music`)
- ✅ Configure download clients (qBittorrent, NZBGet)
- ✅ Set up Prowlarr with indexers
- ✅ Connect Prowlarr to all Arr apps
- ✅ Configure Bazarr subtitle integration
- ✅ Set up Jellyfin with user account and libraries
- ✅ Pre-configure Jellyseerr for Sonarr/Radarr integration

### 7. Manual Configuration Steps (~5 minutes)

#### Jellyseerr (2 minutes)
1. Visit http://YOUR_SERVER:5055
2. Click "Configure Jellyfin"
3. Server: `jellyfin` (or leave default)
4. Port: `8096`
5. Click "Next"
6. Sign in with your credentials from `.config/.credentials`
7. Email: `admin@localhost`
8. Complete wizard - Sonarr/Radarr already configured!

#### Jellystat (Optional, 2 minutes)
1. Visit http://YOUR_SERVER:3000
2. Create an account
3. Add Jellyfin server:
   - Name: `Jellyfin`
   - URL: `http://jellyfin:8096`
   - API Key: Check `jellyfin/jellyseerr/settings.json` (search for first `apiKey`)

#### Bazarr Subtitle Providers (Optional, 2-3 minutes)
1. Visit http://YOUR_SERVER:6767
2. Settings → Providers
3. Add providers:
   - OpenSubtitles (recommended)
   - Subscene
   - BSPlayer
   - etc.

## Verification

### 8. Run Verification Script
```bash
bash verify_setup.sh
```

This checks:
- ✅ All services are responding
- ✅ Configuration files exist
- ✅ API integrations are working
- ✅ Memory limits are applied

### 9. Test the Stack

#### Request Content via Jellyseerr
1. Visit Jellyseerr: http://YOUR_SERVER:5055
2. Search for a movie or TV show
3. Click "Request"
4. Watch it appear in:
   - Sonarr/Radarr (within seconds)
   - qBittorrent/NZBGet (when downloading starts)
   - Jellyfin (after download completes)

#### Play Content in Jellyfin
1. Visit Jellyfin: http://YOUR_SERVER:8096
2. Sign in with your credentials
3. Browse movies/TV shows
4. Play content

## Troubleshooting

### Services Not Starting
```bash
# Check logs
docker compose logs [service_name]

# Restart specific service
docker compose restart [service_name]

# Restart all services
docker compose restart
```

### Permission Issues
```bash
# Fix data directory permissions
sudo chown -R $PUID:$PGID /data

# Check container user
docker exec sonarr id
```

### API Authentication Failures
```bash
# Re-run specific configuration
bash wait_and_configure_auth.sh       # Arr apps
bash configure_prowlarr.sh            # Prowlarr
bash jellyfin/configure_jellyfin.sh   # Jellyfin

# Check API keys manually
grep -oP '<ApiKey>\K[^<]+' sonarr/config.xml
```

### Jellyseerr Connection Issues
```bash
# Check network connectivity
docker exec jellyseerr wget -qO- http://sonarr:8989/ping
docker exec jellyseerr wget -qO- http://radarr:7878/ping

# Fix API keys
bash jellyfin/fix_jellyseerr_apikeys.sh
```

### Memory Issues
All services have memory limits. Check usage:
```bash
docker stats
```

Limits can be adjusted in `compose.yaml` files (look for `mem_limit`).

## Service Access

After deployment, services are available at:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Sonarr | http://YOUR_SERVER:8989 | Your `.credentials` |
| Radarr | http://YOUR_SERVER:7878 | Your `.credentials` |
| Lidarr | http://YOUR_SERVER:8686 | Your `.credentials` |
| Prowlarr | http://YOUR_SERVER:9696 | Your `.credentials` |
| Bazarr | http://YOUR_SERVER:6767 | Your `.credentials` |
| qBittorrent | http://YOUR_SERVER:8080 | Your `.credentials` |
| NZBGet | http://YOUR_SERVER:6789 | Your `.credentials` |
| Jellyfin | http://YOUR_SERVER:8096 | Your `.credentials` |
| Jellyseerr | http://YOUR_SERVER:5055 | Jellyfin SSO |
| Jellystat | http://YOUR_SERVER:3000 | Create account |
| FlareSolverr | http://YOUR_SERVER:8191 | No login |

## Post-Deployment

### Backup Configuration
```bash
# Backup all config files
tar -czf media-stack-backup-$(date +%Y%m%d).tar.gz \
  .config/ \
  sonarr/config.xml \
  radarr/config.xml \
  lidarr/config.xml \
  prowlarr/config.xml \
  bazarr/config/ \
  jellyfin/config/ \
  jellyfin/jellyseerr/settings.json
```

### Add Indexers to Prowlarr
1. Visit Prowlarr settings
2. Indexers → Add Indexer
3. Search for your preferred indexers
4. Configure with your credentials
5. They'll automatically sync to all Arr apps

### Customize Quality Profiles
Each Arr app has quality profiles in Settings → Profiles.
Adjust based on your storage/bandwidth.

### Set Up Notifications (Optional)
Configure notifications in each Arr app:
- Discord
- Telegram
- Email
- etc.

## Maintenance

### Update Containers
```bash
docker compose pull
docker compose up -d
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f sonarr
```

### Database Backups
Jellyfin and Jellystat store data in their directories.
Include them in your backup strategy.

## Done! 🎉

Your media stack is now fully operational with **97% automation**.

Total setup time: **~15 minutes**
- Pre-deployment: 5 min
- Deployment: 10 min (5 automated + 5 manual)

For detailed automation status, see [AUTOMATION_STATUS.md](AUTOMATION_STATUS.md)
