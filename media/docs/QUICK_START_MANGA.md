# Manga/Comics Pipeline - Quick Start Guide

## Service Status ✅
All services are running and configured:
- **Sonarr** (Automation): http://localhost:8989 
- **Komga** (Reader): http://localhost:8081
- **Jellyfin** (Discovery): http://localhost:8096 (needs Bookshelf plugin)
- **Prowlarr** (Indexers): http://localhost:9696
- **qBittorrent** (Downloads): http://localhost:8080

## Next Steps (In Order)

### Step 1: Add Your First Manga Series to Sonarr (5 minutes)
1. Open **Sonarr** → http://localhost:8989
2. Click **"Series"** in left menu
3. Click **"Add New"** button (top right)
4. Search for a manga title (try: `Bleach`, `Trigun`, or `Sword Art Online`)
5. Click the series result
6. Under **"Root Folder"** select `/data/manga`
7. Click **"Add Series"**
8. **Sonarr will immediately start searching** for the latest episodes/chapters from Nyaa.si

**What to expect:** 
- Sonarr queries Prowlarr → Nyaa.si
- Matches appear in Sonarr activity
- Downloads start automatically in qBittorrent
- Files land in `/data/manga/[Series Name]/`

### Step 2: Monitor Your First Download (2-3 minutes)
1. Open **qBittorrent** → http://localhost:8080 (admin/admin)
2. You should see torrent(s) downloading
3. Open **Sonarr** → **Activity** tab to watch progress
4. Once complete, file appears in `/data/manga/`

### Step 3: View in Komga (2 minutes)
1. Open **Komga** → http://localhost:8081 (kero66/temppwd)
2. Click **"Settings"** (left menu, bottom)
3. Click **"Libraries"**
4. Click **"+"** to add new library
5. Set:
   - **Name:** `Manga`
   - **Path:** `/books/manga` (or wherever first download landed)
6. Click **"Add"**
7. Wait ~30 seconds for scan to complete
8. Click **"Books"** in left menu → Your manga appears! ✅

### Step 4: Optional - Install Jellyfin Bookshelf Plugin (5 minutes)
1. Open **Jellyfin** → http://localhost:8096 (dashboard)
2. Go to **Settings** (icon, top right) → **Plugins** → **Catalog** (tab)
3. Search **"Bookshelf"** → Click result → **"Install"**
4. After install, go to **Settings** → **Plugins** → **Bookshelf** (click name)
5. Paste Comic Vine API key from your `.config/.credentials` file (`MYLAR_COMICVINE_API`)
6. Click **"Save"**
7. Add library: **Settings** → **Libraries** → **"+"**
   - **Name:** Books
   - **Folders:** Select `/data/manga/`
   - **Content type:** Select **"Books"**
   - Click **"Add Library"**

Your manga now appears in Jellyfin! 🎉

## File Organization

```
/data/manga/
  └── Series Name/
      ├── Chapter 001.cbz
      ├── Chapter 002.cbz
      └── Chapter 003.cbz
```

## Troubleshooting

**Nothing downloading?**
- Check Sonarr → Activity → Search logs for errors
- Verify Prowlarr → Indexers shows "Nyaa.si" as green/working
- Ensure qBittorrent is accessible at http://localhost:8080

**Komga not finding files?**
- Open Komga → Settings → Libraries → Click library → Check "Path"
- Verify path matches where files actually are
- Click the refresh icon to force rescan

**Downloads appearing in wrong folder?**
- Check Sonarr → Settings → Media Management → Root Folders
- Should show `/data/manga` - this is where new series get added

## Performance Tips

- **Adding multiple series?** Sonarr will spread out searches to avoid hitting Nyaa.si too hard
- **Large downloads slow?** Check qBittorrent → Options → Speed → Bandwidth settings
- **Komga taking time?** Large libraries can take 30+ seconds to scan first time

## Key URLs & Credentials

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| Sonarr | localhost:8989 | N/A | N/A |
| Komga | localhost:8081 | kero66 | temppwd |
| Prowlarr | localhost:9696 | N/A | N/A |
| qBittorrent | localhost:8080 | admin | admin |
| Jellyfin | localhost:8096 | (your user) | (your pass) |

## What's Happening Behind the Scenes?

1. **You add series to Sonarr** → Sonarr stores it in database
2. **Sonarr searches Prowlarr** → Prowlarr queries all indexers (including Nyaa.si)
3. **Nyaa.si results come back** → Sonarr evaluates quality/version
4. **Best match found** → Sonarr sends torrent to qBittorrent
5. **qBittorrent downloads** → Files land in `/data/manga/[Series]/`
6. **Komga auto-detects** → Komga scans folder and indexes new manga
7. **Jellyfin discovers** → Bookshelf plugin fetches metadata from Comic Vine
8. **You read!** → Open Komga (best reading experience) or Jellyfin (best discovery)

## Need More Help?

See `/home/kero66/repos/homelab/media/docs/MANGA_COMICS_SETUP.md` for:
- Advanced Sonarr configuration
- Custom quality profiles for manga
- Troubleshooting guide
- Performance optimization
- Alternative indexers (AnimeTosho, Anidex, etc.)

---

**Questions?** All three services have web interfaces - click around and explore! Sonarr and Komga both have excellent built-in help documentation.
