# Anime Configuration for Sonarr & Radarr - Technical Overview

## How It Works

The anime configuration is **fully automated** as part of the media stack initialization. When you run `automate_all.sh`, it automatically sets up:

### Sonarr (TV Shows)
1. **Japanese Audio Custom Format** - Boosts releases with "japanese" in the name
2. **Anime Quality Profile** - Dedicated profile with Japanese audio preference  
3. **Anime Tagging** - Automatically tags anime series with the "anime" tag
4. **Series Configuration** - Applies the anime profile to all `seriesType: anime` series

### Radarr (Movies)
1. **Japanese Audio Custom Format** - Boosts releases with "japanese" in the name
2. **Anime Quality Profile** - Dedicated profile with Japanese audio preference  
3. **Anime Tagging** - Automatically tags anime movies with the "anime" tag
4. **Movie Configuration** - Applies the anime profile to tagged anime movies

## Database Seeding Strategy

Unlike static config files (qBittorrent, NZBGet, etc.), Sonarr and Radarr's custom formats and quality profiles are stored in their **SQLite databases** (`sonarr.db`/`radarr.db`), which don't exist until the services first start.

Therefore, anime configuration uses this approach:

### Option A: API-Based Seeding (Current Implementation)
- **When:** During `automate_all.sh`, after containers start
- **How:** Uses Sonarr/Radarr API v3 to create/update settings
- **Idempotent:** Won't duplicate if run multiple times
- **Reliable:** Works even if config changes manually
- **Speed:** ~10-15 seconds per service

### Option B: Database Seeding (Not Used)
- Would require direct SQLite modification before services start
- Risk of database corruption or version incompatibility
- More complex and brittle
- Not recommended for production

## File Structure

```
media/
├── .config/
│   ├── sonarr/
│   │   ├── config.xml              (seed file - copied to sonarr/config.xml)
│   │   ├── rootfolders.json        (root folders - applied via API)
│   │   └── (anime config: API only, no seed file)
│   └── radarr/
│       ├── config.xml              (seed file - copied to radarr/config.xml)
│       ├── rootfolders.json        (root folders - applied via API)
│       └── (anime config: API only, no seed file)
│
├── scripts/
│   ├── configure_sonarr_anime.sh   ✨ Sonarr anime automation
│   ├── configure_radarr_anime.sh   ✨ Radarr anime automation
│   └── automate_all.sh             (calls both anime scripts)
└── deploy.sh                       (orchestrates full deployment)
```

## Running the Setup

### Automatic (Initial Setup)
```bash
cd /home/kero66/repos/homelab/media
docker compose up -d
bash scripts/automate_all.sh
```

### Manual (Add New Anime Series)
When you add new anime series to Sonarr, run:
```bash
cd /home/kero66/repos/homelab/media
bash scripts/configure_sonarr_anime.sh
```

### Manual (Add New Anime Movies)
When you add new anime movies to Radarr, run:
```bash
cd /home/kero66/repos/homelab/media
bash scripts/configure_radarr_anime.sh
```

These will:
- Tag new anime with the "anime" tag
- Apply the anime quality profile
- Ensure Japanese audio preference is set

## Configuration Details

### Custom Format: Japanese Audio (Both Services)
```
Name: Japanese Audio
Pattern: (?i)(japanese|jap\b|jpn|日本)
Score: (applied in quality profile as +100)
```

### Quality Profile: HD-1080p - Anime (Radarr)
- **Name:** HD-1080p - Anime
- **Custom Formats:** Japanese Audio (+100 score)
- **Quality Preference:** HD 1080p and above
- **Purpose:** Prioritizes Japanese audio releases over dubs

### Quality Profile: HD-720p - Anime/Japanese (Sonarr)
- **Name:** HD-720p - Anime/Japanese
- **Custom Formats:** Japanese Audio (+100 score)
- **Quality Preference:** HD 720p and above
- **Purpose:** Prioritizes Japanese audio releases over dubs

### Tag: anime
- Applied to all anime series/movies
- Useful for filtering and organization
- Can be extended for other anime-specific rules

## Integration with Automation

The anime config is part of the standard automation flow:

```
automate_all.sh
├── Step 1: Wait for services
├── Step 2: Configure Arr auth (Sonarr, Radarr, Lidarr)
├── Step 3: Configure download clients
├── Step 4: Configure Prowlarr
├── Step 5: Configure Sonarr anime ✨
├── Step 6: Configure Radarr anime ✨
├── Step 7: Configure Bazarr
├── Step 8: Configure Jellyfin
├── Step 9: Configure Jellyseerr anime ✨
└── Done!
```

## Jellyseerr Integration

When users request anime through Jellyseerr:

### For TV Shows (Sonarr)
- Jellyseerr **automatically detects** anime content
- Uses the Sonarr anime profile with Japanese audio preference
- No user action required - it just works!

### For Movies (Radarr)
- A separate "**Radarr (Anime)**" server is configured in Jellyseerr
- Users should **select "Radarr (Anime)"** when requesting anime movies
- This ensures Japanese audio is preferred over dubs

### Auto-Detection for Existing Movies
The `configure_radarr_anime.sh` script auto-detects anime movies by:
- Animation genre + Japanese original language
- Known anime studios (Ghibli, MAPPA, ufotable, etc.)
- Anime keywords in titles
- Already tagged with 'anime'

Run the script periodically to catch new anime added by Jellyseerr:
```bash
bash scripts/configure_radarr_anime.sh
```

## Troubleshooting

### Script Fails to Connect to Sonarr/Radarr
```bash
# Check if services are running
docker compose ps | grep -E "(sonarr|radarr)"

# Check if APIs are responding
curl -s http://localhost:8989/ping  # Sonarr
curl -s http://localhost:7878/ping  # Radarr
```

### Custom Format Not Applied
- Run the respective anime script again
- Verify API key in `sonarr/config.xml` or `radarr/config.xml`
- Check logs: `docker compose logs sonarr` or `docker compose logs radarr`

### New Anime Not Getting Profile
- For Sonarr: Ensure series is marked as `seriesType: anime`
- For Radarr: Ensure movie has the "anime" tag applied
- Run the respective configure script after adding content
- Manually apply profile via UI if needed

### Idempotency (Safe to Run Multiple Times)
```bash
# Both scripts are safe to run multiple times
bash scripts/configure_sonarr_anime.sh
bash scripts/configure_radarr_anime.sh

# Won't create duplicates or errors
# Perfect for automation and CI/CD pipelines
```

## Future Enhancements

Possible improvements for anime configuration:

1. **Cron Job** - Auto-run anime scripts weekly
   ```bash
   0 2 * * 0 /home/kero66/repos/homelab/media/scripts/configure_sonarr_anime.sh
   0 3 * * 0 /home/kero66/repos/homelab/media/scripts/configure_radarr_anime.sh
   ```

2. **Anime-Specific Indexers** - Configure Prowlarr with anime indexers
   - AniDex
   - Nyaa.si
   - Subsplease

3. **Subtitle Language Preference** - Set preferred subtitle languages
   - English subtitles for Japanese audio
   - Auto-fetch subtitles via Bazarr

4. **Advanced Profiles** - Create multiple anime profiles
   - `Anime-1080p` for high quality
   - `Anime-480p` for low bandwidth

## Related Files

- `scripts/configure_sonarr_anime.sh` - Sonarr anime implementation
- `scripts/configure_radarr_anime.sh` - Radarr anime implementation
- `scripts/configure_jellyseerr_anime.sh` - Jellyseerr anime integration
- `scripts/automate_all.sh` - Main automation orchestrator
- `deploy.sh` - Full deployment script
- `docs/AUTOMATION_STATUS.md` - Status documentation
