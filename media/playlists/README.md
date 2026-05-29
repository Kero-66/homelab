# Watch Order Playlists

Canonical watch order database for anime franchises. Used to build and update Jellyfin playlists.

## Format

Each `<franchise>.yaml` file contains:
- `jellyfin_playlist_id` — existing playlist in Jellyfin (update this after rebuilding)
- `entries[]` — full franchise watch order
  - `jellyfin_id: null` → **GAP** — not yet in library, acquire and update

## Franchises

| File | Gaps | Jellyfin Playlist |
|------|------|-------------------|
| [macross.yaml](macross.yaml) | Flash Back 2012, Mac7 Encore, Dynamite 7, Frontier movies ×2, Delta movies ×2 | `89f8fafd8409a0798569199b793da23f` |
| [tekkaman-blade.yaml](tekkaman-blade.yaml) | — | `e0d15ebfa210c1f47d9e43e147f4222f` |

## Workflow

1. Acquire missing entry → Sonarr/Radarr picks it up → Jellyfin scans it
2. Find the new Jellyfin ID: search `/Items?searchTerm=<title>`
3. Update `jellyfin_id` in the yaml (replace `null`)
4. Re-run the playlist rebuild script (todo #83) to add it in the correct position
