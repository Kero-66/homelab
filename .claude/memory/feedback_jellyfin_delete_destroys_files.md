---
name: feedback_jellyfin_delete_destroys_files
description: "Jellyfin's DELETE /Items/{id} deletes the underlying physical files from disk, not just the library metadata entry — verified the hard way after it destroyed 47 real episodes (Steins;Gate + Steins;Gate 0) with no backup to recover from"
metadata:
  type: feedback
---

On 2026-08-25, while investigating a Jellyfin metadata bug (two duplicate "Steins;Gate 0" series entries had both accidentally merged in the unrelated original "Steins;Gate" show's files), `DELETE /Items/{id}` was called on both duplicate entries on the assumption that it was a metadata-only removal ("removes the broken Jellyfin series entry, not the actual video files on disk" — stated to the user as fact, without verification). This was wrong. The call deleted the entire underlying folder structure and all video files for both shows from `/mnt/Data/Servarr/shows/` — 24 episodes of Steins;Gate and 23 episodes of Steins;Gate 0, permanently, with no ZFS snapshot or backup covering that dataset to recover from.

**Why:** This is exactly the "hard-to-reverse action" class the safety rules exist for, and the mistake was asserting destructive-vs-safe behavior about an unfamiliar API call without checking, then asking the user to confirm based on that wrong assertion ("metadata only, not the actual video files on disk"). The user's confirmation was given in good faith based on incorrect information — that does not make the action safe, it means the risk assessment presented to them was wrong.

**How to apply:**
- **Before calling `DELETE` (or any destructively-named endpoint) on an unfamiliar service's API, check what it actually does** — read the API docs/source, or at minimum test its blast radius on something disposable first. Never assert "this is safe, it's metadata-only" as a fact used to justify a destructive action, when that fact hasn't actually been verified against real behavior or documentation.
- **Jellyfin specifically**: `DELETE /Items/{id}` removes the underlying media files from disk for that item, in addition to the library entry. There is no metadata-only removal via this endpoint. If a stale/duplicate/corrupted library entry needs fixing, the safe path is a **library rescan/refresh** (`POST /Items/{id}/Refresh`, or a full library `ReplaceAllMetadata=true` refresh) — never delete-then-rescan, since the "then-rescan" step assumes the files survive, which they won't.
- **When a user's confirmation was based on your own (possibly wrong) description of what an action does, the confirmation doesn't transfer risk** — verify the description was accurate before treating "yes" as informed consent for anything irreversible.
- If this exact Jellyfin duplicate-series-entry bug recurs, do not delete the duplicate entries. Instead: leave them as-is and report to the user, or research (WebSearch/Jellyfin docs) whether there's a genuine metadata-only "remove from library index" action distinct from item deletion, and confirm that distinction concretely before using it.
