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

**2026-08-25 addendum — the mistake this rule exists to prevent still happened.** During a full Season 0 reassessment, 7 VOTOMS OVAs (50-120min each) were checked against Sonarr's `series/lookup` (TVDB) only, got no dedicated match, and were about to be monitored+searched as plain Sonarr specials. User asked "if they are movies, where do they go?" — checking Radarr's `movie/lookup` (TMDB) instead immediately found all 7 as genuine separate films, **already fully owned in Radarr** (`hasFile:true`). The Sonarr entries were stale duplicate cross-listings, same pattern as Robotech's "Do You Remember Love" duplicating the Macross original.

**Root cause of the repeated mistake:** TVDB does not model movies as separate entries the way TMDB does — a "no TVDB match" on movie-length content is not evidence it lacks a separate identity, it's evidence the wrong database was checked. **The rule is not "check Radarr only when Sonarr's TVDB lookup fails" — for anything ≥~50min runtime, check Radarr/TMDB first and skip the TVDB lookup entirely**, since TVDB will almost always give a false "stays as a TV special" answer for real films.

**Two more corrections from the same session, same root cause (skipping steps under time pressure):** (1) Don't classify a Season 0 item as junk/promo from its title alone unless the title is unambiguously self-describing (contains "Interview," "Q&A," "Behind the Scenes," "Trailer," "Making of," "Recap," "Panel" — the format word IS the classification). Anything else — named OVAs, numbered specials — needs an actual content check (WebSearch), not a guess. (2) A franchise being "not committed to acquiring/continuing" (a real, separate decision) does not exempt its Season 0 content from being classified in the first place — classification and acquisition are different steps; don't skip the first because the second is out of scope.
