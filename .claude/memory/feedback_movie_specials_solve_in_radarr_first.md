---
name: feedback_movie_specials_solve_in_radarr_first
description: "For Sonarr movie-length specials (>=60min), add/verify a Radarr entry and search there first rather than grabbing the movie file through Sonarr"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bf60f53f-96d8-4fc1-9d6b-d111d0212ec1
  modified: 2026-08-18T03:17:10.374Z
---

When a Sonarr Season 0 special turns out to be movie-length (the ≥60min threshold from the structural-audit workflow), and no Radarr entry exists for it yet, add it to Radarr first and solve the gap there — not by searching/grabbing it as a Sonarr episode.

**Why:** User's explicit instruction (2026-08-18) during the Trigun/VOTOMS gap-investigation session: "if the movie isn't in radarr we should add it... for anything else we should try to solve in radarr first." Keeps movies in the correct library rather than perpetuating the Sonarr-special-that's-actually-a-movie pattern this whole audit exists to clean up (see `media/docs/SONARR_STRUCTURAL_AUDIT.md`).

**How to apply:** Whenever a Season 0 gap is ≥60min: (1) check/add a Radarr entry via `movie/lookup`, (2) search and grab through Radarr's `/release` + grab flow, (3) leave the Sonarr special unmonitored once Radarr has the file (or leave monitored if genuinely still missing everywhere, same as any other real gap). Don't default to grabbing the file through Sonarr's own release search for anything movie-length.
