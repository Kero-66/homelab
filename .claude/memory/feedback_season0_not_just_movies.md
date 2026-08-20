---
name: feedback_season0_not_just_movies
description: Sonarr Season 0 "specials" includes short bonus/OVA/promo content, not just movie-length items — runtime is a triage signal, not a filter for what to check
metadata:
  type: feedback
---

The Sonarr-specials-vs-Radarr-movie audit workflow (`media/docs/SONARR_STRUCTURAL_AUDIT.md`) used `runtime>=60min` to decide which Season 0 episodes to even look at, treating everything shorter as out of scope. That's wrong — Season 0 holds movies, but also short purchaser-bonus OVAs, promo shorts, recap compilations, and spinoff content, all of which can be genuinely monitored-and-missing gaps regardless of runtime.

**Why:** An entire audit pass (2026-08-20, ~15 series) only ever queried `runtime>=60`, so every short Season 0 special across the whole library was silently excluded from consideration — not deprioritized, just never looked at. User caught it on Gundam 0083's "The Mayfly of Space 1/2" (4min/12min bonus shorts, confirmed real content via IMDb/Gundam Wiki). Re-checking the other "closed" series found the same gap was live across .hack, Gurren Lagann, Gundam Wing, and Tekkaman Blade (the last one *also* had wrong Sonarr runtime metadata claiming 25min for what are actually real movies — same "trust but verify metadata" lesson as the VOTOMS Stage I-IV recap discovery).

**How to apply:** When triaging a series's Season 0, pull *every* monitored+missing episode regardless of runtime. Use runtime only to guess which pattern you're looking at (≥60min → check Radarr/TMDB as a movie; <60min → check whether it's bonus/promo/recap content via research) — never as a pre-filter that excludes items from being looked at in the first place. See [[feedback_check_sonarr_monitored_before_radarr_action]] for the related monitored-status blind spot found the same session.
