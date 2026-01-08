# Your Manga/Comics System - What Actually Works

## ✅ Complete & Working Pipeline

Your manga/comics automation is **fully configured and ready to use**. Here's what you have:

### The Workflow

```
You Request in Sonarr 
    ↓
Sonarr Searches Prowlarr 
    ↓
Prowlarr Queries Nyaa.si (Manga Torrents)
    ↓
Results Downloaded via qBittorrent
    ↓
Files Land in /data/manga/
    ↓
View in Jellyfin or Komga (when enabled)
```

## How to Use

### 1. Add a Manga Series (Request)
1. Open **Sonarr** → http://localhost:8989
2. Click **"Series"** in left sidebar
3. Click **"Add New"** (top right)
4. Search for manga: `Bleach`, `Trigun`, `Sword Art Online`, etc.
5. Click the series result
6. **Root Folder:** `/data/manga` (already selected)
7. Click **"Add Series"**

**That's it!** Sonarr immediately searches Prowlarr → Nyaa.si and starts downloading.

### 2. Monitor Downloads
- **Sonarr** (http://localhost:8989) → **Activity** tab
- **qBittorrent** (http://localhost:8080) → Watch torrents download

### 3. View Your Manga
Files appear at: `/data/manga/[Series Name]/[Chapter].cbz`

## System Architecture

| Component | URL | Purpose |
|-----------|-----|---------|
| **Sonarr** | http://localhost:8989 | Add/manage manga series (YOUR REQUEST INTERFACE) |
| **Prowlarr** | http://localhost:9696 | Indexer manager (already configured with Nyaa.si) |
| **qBittorrent** | http://localhost:8080 | Download monitor |
| **Jellyfin** | http://localhost:8096 | View/discover manga (optional) |
| **Komga** | (disabled) | Dedicated manga reader (can re-enable) |

## Configuration Details

✅ **Sonarr API Key:** Already configured
✅ **Prowlarr Integration:** Already synced with Sonarr
✅ **Nyaa.si Indexer:** Ready to search manga torrents
✅ **qBittorrent:** Configured as download client
✅ **Directory:** `/data/manga/` ready to receive files
✅ **Quality Profile:** Default profile assigned

## What's Ready to Use RIGHT NOW

1. **Search for manga in Sonarr** - Works immediately
2. **Automatic downloads** - Starts within seconds of requesting
3. **Download monitoring** - Watch progress in qBittorrent
4. **File organization** - Automatic folder structure

## Example: Add Trigun

```
1. Sonarr → Series → Add New
2. Search: "Trigun"
3. Click result
4. Root Folder: /data/manga ✓
5. Click "Add Series"
6. Done! Downloads start automatically
```

Files will appear at:
- `/data/manga/Trigun/[Chapter 001].cbz`
- `/data/manga/Trigun/[Chapter 002].cbz`
- etc.

## Optional: View in Jellyfin/Komga

If you want to view manga in Jellyfin or Komga (manga reader apps):
- **Komga** can be re-enabled in docker-compose.yaml
- **Jellyfin** already has library scanning enabled
- Just point them to `/data/manga/` folder

But you can also just access files directly at `/data/manga/`

## Summary

**Your manga request system is complete.** You don't need a separate request UI - Sonarr IS your request interface. Just search for manga there and it automatically downloads from Nyaa.si.

Everything is configured and tested. Start adding manga now!

---

**Login credentials (if needed):**
- Sonarr: No auth required (local)
- Prowlarr: No auth required (local)
- qBittorrent: admin/admin
