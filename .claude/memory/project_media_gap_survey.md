---
name: project_media_gap_survey
description: "In-progress audit of missing episodes/movies across the Sonarr and Radarr libraries, started 2026-08-08"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-15T01:34:06.897Z
---

User is auditing the whole media library for missing content, following on from fixing VOTOMS/Armitage III/Macross Dynamite 7/GetBackers imports. Two gap lists were pulled 2026-08-08 (see [[project_sonarr_radarr_movie_migration]] for the Macross-franchise cross-reference work already done against these):

**Sonarr — 25 monitored series with missing episodes** (id, files/total, title): MF GHOST 0/1, Broken Blade 0/12, GUN×SWORD 0/26, Mars Daybreak 0/26, GRIP. A Toyota Story 0/5, Mazinkaiser 0/7, Macross Zero 1/6, The Big O 11/13, Mobile Suit Gundam 0083 13/16, Trigun 18/27, Gasaraki 23/25, Tekkaman Blade 3/55, Macross Frontier 30/40, Robotech 36/92, Macross 37/44, Macross Plus 4/6, Gurren Lagann 41/49, Zoids: Chaotic Century 5/34, Macross II 5/7, Mobile Suit Gundam Wing 57/60, .hack 67/96, Macross 7 68/70, Armored Trooper VOTOMS 75/81, Attack on Titan 8/9, Blue Gender 9/27.

**Update 2026-08-15:** GUN×SWORD and Mars Daybreak fully resolved (both 26/26 now, imported via manual grab + force-mapped manual import — see [[feedback_sonarr_queue_hides_unmatched]] and PATTERNS.md manual-import section for the queue-orphan cleanup this required). MF GHOST and GRIP dropped off the monitored-missing filter too — MF GHOST's only remaining gap is an unaired "TBA" episode (not a real gap), GRIP's episodes got unmonitored (matches it being genuinely unavailable on any indexer, confirmed earlier). Remaining 20-series gap list as of this date: Broken Blade 0/12, Mazinkaiser 0/7, Macross Zero 1/6, The Big O 11/13, Mobile Suit Gundam 0083 13/16, Trigun 18/27, Gasaraki 23/25, Tekkaman Blade 3/55, Macross Frontier 30/39, Robotech 36/92, Macross 37/44, Macross Plus 4/6, Gurren Lagann 41/49, Zoids: Chaotic Century 5/34, Macross II 5/7, Mobile Suit Gundam Wing 57/60, .hack 67/96, Macross 7 68/70, Armored Trooper VOTOMS 75/81, Attack on Titan 8/9, Blue Gender 9/27. Broken Blade and Mazinkaiser are confirmed dead ends (no live seeders / blocklisted+profile-excluded respectively) — don't re-attempt without new indexer results. The Macross cluster (ids 67/68/70/72/73, 5 series) is the next logical target since 67 is already partly resolved and the franchise-movie overlap pattern with Radarr is established — see [[project_sonarr_radarr_movie_migration]].

**Radarr — 38 monitored movies missing files**, notably clustered around: Macross franchise (many titles), Tekkaman Blade (4 movies), .hack (5 movies), plus one-offs (Gundam Hathaway, VOTOMS Vol.1/Vol.2, M.D. Geist, Goblin Slayer's Crown — the last one already grabbed/downloading this session).

**Why:** User wants to find cases where a "missing" Radarr movie is actually already sitting as a completed Sonarr TV special (as happened with Macross Dynamite 7) before spending effort re-downloading it, and generally close out the gap lists.

**How to apply:** This snapshot will go stale fast as items get fixed — re-run the filter queries (see [[project_sonarr_radarr_movie_migration]] for exact API filters) before trusting these numbers. Priority order suggested: finish the Macross cross-reference (2 titles still genuinely missing everywhere), then check Tekkaman Blade and .hack for the same specials-vs-movie overlap pattern, then work the remaining large TV gaps (Robotech 36/92, .hack 67/96, VOTOMS 75/81 — note VOTOMS gap here is likely just the still-genuinely-unavailable Vol.1/Vol.2 movies, already known dead-ends from earlier this session).
