# Prowlarr Indexer Configuration - Implementation Notes

## Problem
Prowlarr stores indexers in SQLite database (`prowlarr.db`), not in XML config files. The API approach has limits and complexities.

## Solution: Database Direct Seeding

Indexers are stored in the `Indexers` SQLite table with these key fields:
- `Name`: Unique indexer name (e.g., "Nyaa.si")
- `Implementation`: Type of indexer implementation (Cardigann, Torznab, Newznab)
- `ConfigContract`: Settings schema type (CardigannSettings, TorznabSettings, NewznabSettings)
- `Settings`: JSON blob containing indexer-specific settings
- `Enable`: 1 for enabled, 0 for disabled
- `Priority`: Priority order (default 25)

## Indexer Types

### Cardigann (Site Scrapers)
- **Implementation:** `Cardigann`
- **ConfigContract:** `CardigannSettings`
- **Settings format:**
```json
{
  "definitionFile": "nyaasi",
  "extraFieldData": {...},
  "baseSettings": {"limitsUnit": 0},
  "torrentBaseSettings": {"preferMagnetUrl": false}
}
```
- **Examples:** Nyaa.si, The Pirate Bay, TorrentGalaxy, 1337x, RARBG, Anidex

### Torznab (Torrent Feeds)
- **Implementation:** `Torznab`
- **ConfigContract:** `TorznabSettings`
- **Settings format:**
```json
{
  "baseUrl": "https://feed.animetosho.org",
  "apiPath": "/api",
  "apiKey": "",
  "baseSettings": {"limitsUnit": 0},
  "torrentBaseSettings": {"preferMagnetUrl": false}
}
```
- **Examples:** AnimeTosho, Jackett scrapers

### Newznab (Usenet)
- **Implementation:** `Newznab`
- **ConfigContract:** `NewznabSettings`
- **Settings format:**
```json
{
  "baseUrl": "https://nzbgeek.info",
  "apiPath": "/api",
  "apiKey": "",
  "baseSettings": {"limitsUnit": 0}
}
```
- **Examples:** NZBGeek, Generic Newznab

## Implementation

**File:** `scripts/seed_prowlarr_indexers.sh`

Uses SQLite `INSERT` statements directly into `prowlarr.db` before/after container startup.
- Checks if indexer already exists by Name (unique constraint)
- Only adds missing indexers
- Can be run at any time (idempotent)

## Workflow

1. **Initial Setup:** Run `seed_prowlarr_indexers.sh` after `docker compose up -d`
   - Creates indexers in database
   - No manual UI configuration needed
   - Indexes automatically sync to Sonarr/Radarr/Lidarr

2. **For New Deployments:** Database seeding happens as part of deployment automation

3. **Adding Custom Indexers:** Add INSERT statements to the script with proper Settings JSON

## Limitations
- Can't use API if database is locked (container running)
- Database manipulation requires direct SQLite access
- Complex Settings JSON requires accurate formatting

## Future Improvements
- Build Settings JSON from templates/JSON files instead of inline strings
- Support for Jackett Torznab URL detection/syncing
- Backup/restore indexer configurations
