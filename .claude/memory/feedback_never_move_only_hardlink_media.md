---
name: feedback_never_move_only_hardlink_media
description: "Never manually mv/cp media files between downloads and library, and never use importMode: move — the unified Data/Servarr dataset exists specifically so imports hardlink; a move breaks the torrent's seed data"
metadata:
  type: feedback
---

Investigating a `missingFiles` qBittorrent torrent (Gasaraki), the user identified that a past manual "rectification" of media files moved a file out of the downloads folder into the library by hand instead of preserving the hardlink — root-caused to stale docs, not a one-off mistake: `CLAUDE.md` and `media/AGENTS.md` still documented the pre-migration `/mnt/Data/media` and `/mnt/Data/downloads` paths as live, so there was nothing in the always-loaded context stating that hardlinks are the load-bearing invariant on this dataset. Both docs have now been corrected (see current `/mnt/Data/Servarr/{downloads,shows,movies,...}` layout and the explicit hardlink warnings added to each).

**Why:** Since the `Data/Servarr` unified-dataset migration (#92, confirmed live 2026-08-24 — see `ai/COMPLETED.md` #92 and `ai/PATTERNS.md` "Manual Import `importMode`"), downloads and the media library are one ZFS dataset specifically so *arr imports can hardlink instead of copy. Any raw `mv`/`cp` (or an import call with `importMode: "move"`) physically relocates the file, silently breaking the torrent's on-disk data — qBittorrent then reports `missingFiles`/`checkingUP` on its next recheck, with no error surfaced at the time of the move.

**How to apply:**
- Never manually move or copy a media file between the downloads folder and the library. If a file needs to be relocated/fixed by hand, use `cp -al` (hardlink copy) or `ln`, never plain `cp`/`mv`.
- Never call the Sonarr/Radarr Manual Import API with `importMode: "move"` — always `"copy"` (which is a hardlink on this dataset, confirmed live).
- If asked to "manually rectify" any media file placement, treat hardlink preservation as a hard constraint and say so explicitly before acting, not just quietly do the safe thing — the user has been burned by silent assumptions like this before (see [[feedback_jellyfin_delete_destroys_files]]).
- Before touching file layout, check current live paths against `ai/COMPLETED.md` #92 and #93 (old `Data/downloads`/`Data/media` datasets still exist with legacy content but are not mounted by any app) rather than trusting a doc that hasn't been re-verified since a migration.
