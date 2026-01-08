# Complete Indexer & FlareSolverr Automation Setup

## ✅ Current Status

### Prowlarr
- **Database**: SQLite (`prowlarr/prowlarr.db`)
- **Total Indexers**: 13
- **FlareSolverr**: Configured and active at `http://172.39.0.9:8191/`
- **Applications**: Sonarr, Radarr, Lidarr, Mylar3 (all synced with indexers)

### Jackett
- **Status**: Running with FlareSolverr enabled
- **Configured Indexers**: DMHY, 52BT, Nyaa.si
- **Torznab Proxies**: All 3 proxies seeded into Prowlarr

### FlareSolverr
- **Status**: Running at `http://172.39.0.9:8191/` on Docker network
- **Configured In**:
  - ✅ Prowlarr (IndexerProxies table)
  - ✅ Jackett (ServerConfig.json)

---

## 📊 Indexer Breakdown

### Direct Prowlarr Indexers (10)
| Name | Type | Purpose |
|------|------|---------|
| 1337x | Cardigann | General torrents |
| Anidex | Cardigann | Anime torrents |
| AnimeTosho | Torznab | Anime torrents (aggregator) |
| AnimeTosho (Usenet) | Torznab | Anime usenet |
| EZTV | Cardigann | TV show torrents |
| Generic Newznab | Newznab | Generic usenet |
| Nyaa.si | Cardigann | Anime site scraper |
| RARBG | Cardigann | General torrents |
| The Pirate Bay | Cardigann | General torrents |
| TorrentGalaxy | Cardigann | General torrents |

### Jackett-Based Indexers (3 via Torznab proxy)
| Name | Jackett Tracker | Purpose |
|------|-----------------|---------|
| DMHY | dmhy | Anime distribution (Chinese) |
| 52BT | 52bt | Anime distribution |
| Nyaa.si (Jackett) | nyaasi | Nyaa.si via Jackett |

---

## 🛠️ Automation Scripts

### Core Scripts

**`seed_prowlarr_indexers.sh`**
- Adds 10 direct indexers to Prowlarr database
- Uses SQLite INSERT commands
- Idempotent (safe to run multiple times)
- Indexers created with proper Settings JSON for each implementation type

**`seed_jackett_indexers.sh`** (NEW)
- Adds 3 Jackett-based Torznab proxies to Prowlarr
- Configures Torznab URLs pointing to Jackett
- Uses same SQLite approach as Prowlarr seeder
- Depends on Jackett being running with FlareSolverr enabled

### Orchestration

**`automate_all.sh`** (Updated)
- Step 4: Seed Prowlarr indexers
- Step 4a: Seed Jackett indexers (NEW)
- Step 4b: Configure Prowlarr (FlareSolverr + app sync)

---

## 🔧 Key Configurations

### Prowlarr FlareSolverr (IndexerProxies table)
```
Name: FlareSolverr
Host: http://172.39.0.9:8191/
RequestTimeout: 60000ms
```

### Jackett FlareSolverr (ServerConfig.json)
```json
"FlareSolverrUrl": "http://172.39.0.9:8191/",
"FlareSolverrMaxTimeout": 55000
```

### Jackett Torznab URL Pattern
```
http://jackett:9117/torznab/{trackerId}
API Path: /api/v2.0/indexers/{indexerId}/results/torznab
API Key: {JACKETT_API_KEY}
```

---

## 📝 Implementation Details

### Why SQLite Direct Seeding?
1. **No API complexity**: Prowlarr stores configs in database, not API
2. **Idempotent**: Can safely re-run multiple times
3. **Immediate**: Changes take effect without restart
4. **Verifiable**: Query database to confirm additions
5. **Reliable**: No timeout/connection issues like API calls

### Indexer Implementation Types

**Cardigann** (Site Scrapers)
- Settings JSON includes `definitionFile` (site definition)
- Example: `{"definitionFile":"nyaasi","extraFieldData":[]}`

**Torznab** (Feed Aggregators)
- Settings JSON includes `baseUrl`, `apiPath`, `apiKey`
- Example: `{"baseUrl":"http://jackett:9117/torznab/dmhy","apiPath":"/api/v2.0/indexers/{indexerId}/results/torznab","apiKey":"..."}`

**Newznab** (Usenet Indexers)
- Similar to Torznab but for usenet sources
- Example: `{"baseUrl":"...","apiPath":"...","apiKey":"..."}`

---

## 🔄 How Indexers Flow Through Services

```
Prowlarr Database (13 Indexers)
    ↓
    ├→ Sonarr (TV shows)
    ├→ Radarr (Movies)
    ├→ Lidarr (Music)
    └→ Mylar3 (Comics)
```

Each application has indexed categories:
- **Sonarr**: TV categories (5000-5099)
- **Radarr**: Movie categories (2000-2099)
- **Lidarr**: Music categories (3000-3099)
- **Mylar3**: Comic categories (7000-7099)

---

## 🧪 Verification Commands

### Check all indexers
```bash
sqlite3 prowlarr/prowlarr.db "SELECT Name, Implementation FROM Indexers ORDER BY Name;"
```

### Count indexers by type
```bash
sqlite3 prowlarr/prowlarr.db "SELECT Implementation, COUNT(*) FROM Indexers GROUP BY Implementation;"
```

### Verify Jackett Torznab settings
```bash
sqlite3 prowlarr/prowlarr.db "SELECT Name, json_extract(Settings, '$.baseUrl') FROM Indexers WHERE Implementation='Torznab';"
```

### Check FlareSolverr in Prowlarr
```bash
sqlite3 prowlarr/prowlarr.db "SELECT * FROM IndexerProxies WHERE Name='FlareSolverr';"
```

### Check Jackett is running with FlareSolverr
```bash
docker logs jackett | grep "Using FlareSolverr"
```

---

## 🚀 Deployment with Full Automation

```bash
cd /home/kero66/repos/homelab/media
docker compose up -d

# Automated setup
bash scripts/automate_all.sh
```

This single command will:
1. ✅ Configure all Arr apps (Sonarr, Radarr, Lidarr)
2. ✅ Configure download clients (qBittorrent, NZBGet)
3. ✅ **Seed 10 Prowlarr indexers into database**
4. ✅ **Seed 3 Jackett-based indexers into database**
5. ✅ Configure Prowlarr (FlareSolverr + app sync)
6. ✅ Configure anime support in Sonarr

**Total setup time**: ~10 minutes (mostly container startup)

---

## 📚 Related Documentation

- `PROWLARR_INDEXERS_NOTES.md`: Technical details on Prowlarr indexer formats
- `media/README.md`: Complete media stack documentation
- `docs/AUTOMATION_STATUS.md`: Overall automation progress tracker

---

## 🔍 Troubleshooting

### "Challenge detected but FlareSolverr is not configured"
- **Cause**: Jackett FlareSolverr URL is null
- **Fix**: Ensure `jackett/Jackett/ServerConfig.json` has `"FlareSolverrUrl": "http://172.39.0.9:8191/"`
- **Solution**: Run container restart: `docker compose restart jackett`

### Indexers not appearing in Sonarr/Radarr
- **Cause**: Indexer Settings JSON malformed
- **Fix**: Query database to verify entries: `sqlite3 prowlarr/prowlarr.db "SELECT * FROM Indexers;"`
- **Solution**: Run seed script again or manually fix in database

### Jackett Torznab returns "not authorized"
- **Cause**: API key mismatch
- **Fix**: Verify `JACKETT_API_KEY` in script matches Jackett ServerConfig.json
- **Solution**: Update script and re-run seeder

---

Last Updated: 2025-12-12
