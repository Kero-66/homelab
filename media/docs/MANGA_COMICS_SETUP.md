# Manga, Comics, Webtoons & eBooks Pipeline

Complete guide to downloading and managing manga, comics, webtoons, and eBooks in your Jellyfin media stack.

## Overview

This setup provides three complementary tools for different content types:

| Tool | Purpose | Content Type | Best For |
|------|---------|--------------|----------|
| **Sonarr** | Auto-download from indexers | Anime/Manga/Light Novels | Automated downloads from Nyaa.si |
| **Komga** | Dedicated reader | CBZ, CBR, EPUB, PDF | Web-based manga/comic reading |
| **Jellyfin Bookshelf** | Jellyfin integration | All formats | Unified library with other media |

## Services & Access

### Sonarr (Anime/Manga Downloader)
- **URL:** http://localhost:8989
- **Purpose:** Auto-download manga/anime from indexers
- **API Key:** Check Infisical `/media` (`SONARR_API_KEY`)
- **Download Client:** qBittorrent (configured automatically)

### Komga (Manga/Comic Reader)
- **URL:** http://localhost:8081
- **Default Credentials:** 
  - Username: `kero66`
  - Password: `temppwd` (change in settings)
- **Mount Point:** `/books` (maps to `/mnt/d/homelab-data/`)
- **Supported Formats:** CBZ, CBR, EPUB, PDF, MOBI

### Jellyfin (Media Server)
- **URL:** http://localhost:8096
- **Bookshelf Plugin:** Provides book/comic metadata and display
- **Comic Vine API:** Check Infisical `/media` for `MYLAR_COMICVINE_API`

### Prowlarr (Indexer Aggregator)
- **URL:** http://localhost:9696
- **Indexers for Manga:**
  - Nyaa.si (Anime/Manga torrents)
  - AnimeTosho (Anime files)
  - Anidex (Manga, anime)

## Directory Structure

All content goes to `/mnt/d/homelab-data/`:

```
/mnt/d/homelab-data/
├── manga/              # Sonarr downloads here
│   └── Bleach/         # Auto-organized by Sonarr
│       ├── Season 1/
│       └── Season 2/
├── comics/             # Western comics
├── webtoons/           # Webtoon series
└── ebooks/             # eBooks & light novels
```

## Setup Instructions

### 1. Add Manga to Sonarr

1. Go to **Sonarr** → **Series**
2. Click **Add New** (+ button)
3. Search for your manga (e.g., "Bleach", "Sword Art Online", "Trigun")
4. Select the series
5. Choose folder: `/data/manga`
6. Set minimum availability to **"Any"**
7. Click **Add Series**

**Example Series to Add:**
- Bleach
- Sword Art Online
- Trigun
- One Punch Man
- Demon Slayer (Kimetsu no Yaiba)

### 2. Configure Quality Profiles (Optional)

In Sonarr → Settings → Quality:
- Create profile for **Manga** with preferred resolution/codec
- Sonarr will auto-match releases from Nyaa.si

### 3. Using Komga for Reading

1. Go to **Komga** (http://localhost:8081)
2. Go to **Settings** → **Libraries**
3. Add Library:
   - Name: "Manga"
   - Path: `/books/manga`
   - Media Type: Manga
4. Click **Scan** to index your files
5. Browse and read via web interface

**Komga Features:**
- Web-based reader
- Chapter-by-chapter navigation
- OPDS support for eReader apps
- Mihon extension for mobile reading

### 4. Jellyfin Bookshelf Plugin

1. In **Jellyfin** → **Settings** → **Plugins** → **Catalog**
2. Search for **Bookshelf**
3. Install the plugin
4. **Restart Jellyfin**
5. Go to **Settings** → **Plugins** → **Bookshelf**
6. Configure:
   - Comic Vine API: Use value from Infisical `/media` (`MYLAR_COMICVINE_API`)
   - Enable metadata providers
   - Select libraries to scan

## How It Works

### Manga Download Pipeline

```
1. Add series in Sonarr
   ↓
2. Sonarr searches Nyaa.si via Prowlarr
   ↓
3. Release found → Downloads to qBittorrent
   ↓
4. File lands in /data/manga/SeriesName/
   ↓
5. Komga indexes it automatically
   ↓
6. Available in Komga + Jellyfin Bookshelf
```

### Supported File Formats

#### Manga/Comics
- **CBZ** (ZIP-based comic format) - RECOMMENDED
- **CBR** (RAR-based comic format)
- **EPUB** (eBook format with pages)
- **PDF** (Document format)
- **MOBI** (Kindle format)

#### Metadata Formats
- **ComicInfo.xml** - Comic metadata (embedded in CBZ)
- **OPF** - Open Packaging Format
- **ComicBookInfo** - Alternative comic metadata

## Important Configuration Notes

### Sonarr → Prowlarr Sync

Sonarr is already registered with Prowlarr with:
- **Name:** Sonarr
- **Sync Categories:** 5070 (TV/Anime), 7000 (Books)
- **Sync Level:** Add Only

To modify:
1. Go to **Prowlarr** → **Applications** → **Sonarr**
2. Adjust sync categories if needed
3. Save and resync

### qBittorrent Category

Downloads are tagged with category `manga` for easy identification:
- Access qBittorrent: http://localhost:8080
- Filter by category "manga" to see only manga downloads

### Nyaa.si Indexer Configuration

Nyaa.si in Prowlarr supports:
- Anime (5070, 5000)
- Manga (7000, 7030)
- Light Novels
- Anime Music Videos

The indexer is already enabled and synced with Sonarr.

## Troubleshooting

### Sonarr Not Finding Manga

1. Check **Prowlarr** → **Indexers** → **Nyaa.si** is enabled
2. Verify **Sonarr** → **Settings** → **Indexers** has Nyaa.si
3. Check Sonarr logs for search errors
4. Manually test Prowlarr search: http://localhost:9696/search

### Files Not Appearing in Komga

1. Ensure files are in correct format (CBZ, EPUB, PDF, etc.)
2. Go to **Komga** → **Settings** → **Libraries** → **Scan**
3. Check file permissions (PUID/PGID match)
4. Check Komga logs: `docker compose logs komga`

### Jellyfin Not Showing Books

1. Ensure **Bookshelf plugin** is installed and enabled
2. **Restart Jellyfin** after plugin installation
3. Create **Jellyfin library** pointing to `/books/`
4. Go to library settings → metadata providers → enable **Comic Vine**
5. Refresh metadata for books

### API Key Issues

**Comic Vine API:**
- Stored in: `.config/.credentials` file as `MYLAR_COMICVINE_API`
- For Jellyfin Bookshelf plugin configuration
- Also used by Mylar3 for metadata

**Sonarr API:**
- Get from: `.env` file (`SONARR_API_KEY`)
- Reset: Sonarr → Settings → Show API Key

## Advanced Configuration

### Custom Sonarr Naming

To organize manga differently, modify **Sonarr** → **Settings** → **Media Management**:

**Example: Organize by volume number**
```
Series Folder Format: {Series Title}
Season Folder Format: Volume {season}
Episode Format: Ch {episode:000} - {episode title}
```

### Multiple Sonarr Instances

For different content types (anime vs. manga):
1. Create second Sonarr instance with different config directory
2. Both can use same Prowlarr and download clients
3. Keep manga and anime organized in separate folders

### Backup & Restore

**Backup Komga:**
```bash
docker cp komga:/config komga_backup/
```

**Backup Sonarr:**
```bash
docker cp sonarr:/config sonarr_backup/
```

## Performance Tuning

### Memory Limits (Current)
- Sonarr: 512 MB
- Komga: 512 MB
- Adjust in `compose.yaml` if needed

### Storage Requirements
- CBZ/CBR files: ~30-100 MB per volume
- EPUB/PDF: ~10-50 MB per volume
- With metadata: +1-5 MB per file

Estimate: 1000 manga volumes ≈ 30-150 GB

## Related Services

- **Mylar3:** Western comics management (still available)
- **Kavita:** Alternative manga reader
- **Ubooquity:** eBook server
- **Jellyfin:** Main media server

## Getting Help

If something isn't working:

1. Check logs: `docker compose logs sonarr komga`
2. Verify API keys in `.env` file
3. Ensure directories exist and have correct permissions
4. Test API endpoints manually with `curl`
5. Check Jellyfin logs for Bookshelf plugin issues

## Quick Reference

### Add Manga Series
1. Sonarr → Series → Add New
2. Search and select series
3. Choose `/data/manga` folder
4. Set monitor for new releases

### Read Manga
1. **Web:** Komga (http://localhost:8081)
2. **Mobile:** Mihon app with Komga OPDS
3. **Jellyfin:** Bookshelf plugin integration

### Search Manually
- Prowlarr: http://localhost:9696/search
- Test indexers from Prowlarr web UI

### Monitor Downloads
- qBittorrent: http://localhost:8080 (category: manga)
- Sonarr: http://localhost:8989 → Activity → Queue

---

**Last Updated:** December 8, 2025
**Version:** 1.0
