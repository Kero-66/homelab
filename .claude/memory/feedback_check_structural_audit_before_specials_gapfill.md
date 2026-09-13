---
name: feedback-check-structural-audit-before-specials-gapfill
description: Before gap-filling a Sonarr Season 0/special, check media/docs/SONARR_STRUCTURAL_AUDIT.md for an existing Radarr movie entry — don't duplicate content across both apps
metadata:
  type: feedback
---

Before acquiring/fixing a Sonarr Season 0 episode or "special," check whether that title already
has a Radarr movie entry (grep `media/docs/SONARR_STRUCTURAL_AUDIT.md` for the show name, or check
TMDB). If a Radarr entry with `hasFile:true` already exists, fix/acquire content there — never
grab a duplicate copy into Sonarr's Season 0.

**Why:** `media/docs/SONARR_STRUCTURAL_AUDIT.md` already encodes this exact rule in multiple places
(Tekkaman Blade II Season 2 unmonitored in favor of the standalone series; Broken Blade unmonitored
in favor of 6 Radarr movies) — "if a special has its own series or movie, it should be those
things, not Season 0/special." A 2026-09-12 session violated this for Tekkaman Blade: grabbed a
91GB BD-BOX into Sonarr for 4 OVAs that were already complete, working Radarr movies (ids 68-71),
creating a duplicate. Follow-up work (subtitle fixes, title fixes, a Jellyfin playlist rewrite) was
built on the wrong copy for an entire session before the user caught it by pointing at the
already-existing doc. See `ai/SESSION_NOTES.md` "Session 2026-09-12 (latest)" for the full
correction (moved the improved files into Radarr instead of discarding them, unmonitored+deleted
the Sonarr duplicates).

**How to apply:** Any time a task starts with "X special/OVA is missing" for a franchise with both
Sonarr and Radarr entries (common for anime — TV series + movie-style OVAs), check the structural
audit doc FIRST, before touching Sonarr's search/grab/import pipeline. If unsure whether a title is
"Sonarr-native" or "Radarr movie masquerading as a special," check TMDB/Radarr for an existing
entry before assuming Sonarr is the right target.
