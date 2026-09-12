---
name: feedback_prefer_series_movie_over_specials
description: Standing preference — content should live as a proper Series/Movie item, not a Season 0 special, unless that's genuinely its only real form
metadata:
  type: feedback
---

Default assumption when a title shows up as a Season 0 special: that's wrong unless proven otherwise. Prefer it exist as its own Movie (in Radarr) or its own Series (in Sonarr) instead.

**Why:** User's explicit statement (2026-09-12), triggered by finding .hack//Liminality's "In the Case of Mai Minase" and the movie ".hack//Legend of the Twilight: Let's Meet Offline" both duplicated as Season 0 specials under the merged ".hack" series — a Sonarr/TVDB import artifact, not real content living only there. This is the same root cause as [[feedback_movie_specials_solve_in_radarr_first]] (TVDB doesn't model movies separately, so movie-length content gets miscast as a TV special) and [[feedback_season0_not_just_movies]] (don't filter what to check by runtime), but stated as a general standing rule rather than only within the Sonarr-structural-audit workflow — it applies any time Season 0/specials content is encountered, including incidentally (e.g. while building a SmartLists watch-order playlist, not auditing).

**How to apply:** Whenever Season 0/specials content is encountered for any reason, check whether it's a duplicate or misfiled version of something that should be (or already is) a real Movie/Series item — via Radarr/TMDB lookup for movie-length items, or checking if a same-titled proper Series entry already exists. Only accept it staying in Season 0 if genuine research confirms no separate release exists (true bonus/promo/recap shorts, or content that was never released as a standalone work). Don't fix the library structure without asking first — flag findings and confirm before merging/reclassifying/deleting.
