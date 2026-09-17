---
name: feedback_check_sonarr_monitored_before_radarr_action
description: "Don't add a Radarr entry / trigger a search for a Sonarr Season 0 special without first making the placement decision — and note that monitored:false does NOT mean the content is unwanted"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 791a1331-0ccf-4a42-ab62-dae7ffae93cd
  modified: 2026-08-20T02:03:38.007Z
---

Don't add a Radarr entry and trigger a search off the back of "Sonarr special has no file and no Radarr match" alone. Make the **placement decision** first — does this content belong in Radarr, as its own Sonarr series, or genuinely as a special? — with research behind it, and record it.

**CORRECTED 2026-09-18 — the original framing of this memory was wrong.** It read: *"An unmonitored Sonarr episode/special is a signal someone already decided it's not wanted (bonus content, deprioritized, not core)"*. That inverts what the flag means. Owner's correction:

> As part of the process we determine whether we want something monitored in Sonarr or not. Once that's determined — either by it needing to be in Radarr, or a separate series, or a season — it is unmonitored under specials in Sonarr. Then it just means we won't grab it in Sonarr, because it's unmonitored.

So `monitored:false` is the **output** of a placement decision, not a verdict on the content. Very often a special is unmonitored *precisely because Radarr owns it* (Kizumonogatari: three unmonitored Sonarr S0 entries, three fully-owned Radarr films — correct). Treating the flag as "not wanted anywhere" would forbid the Radarr add that a "belongs in Radarr" verdict requires, and directly contradicts [[feedback_movie_specials_solve_in_radarr_first]].

**Why:** The 2026-08-20 Sonarr-specials-movie-audit session (`media/docs/SONARR_STRUCTURAL_AUDIT.md`) queried Season 0 by `runtime>=60`, then added 21+ Radarr entries and triggered searches for anything without an existing match. The genuine failure was that **no placement assessment happened** — action was driven mechanically by "long runtime + no Radarr match", with no research into what each item actually was and no recorded decision. Several of those Radarr adds were in fact the right destination; what was missing was the deliberate call. (The runtime filter was its own separate bug, since retired — see [[feedback_season0_not_just_movies]] and [[feedback_movie_specials_solve_in_radarr_first]].)

**How to apply:** Before adding a Radarr entry or triggering a search from a Sonarr special: (1) research what the content actually is, (2) decide where it belongs — Radarr / separate series / stays a special, (3) act on that, and (4) record the decision and its reasoning in `SONARR_STRUCTURAL_AUDIT.md`. `monitored:false` tells you only "don't grab it in Sonarr" — it is not a stop sign on the Radarr add, and it is not a substitute for making the decision. If you cannot tell *why* something is unmonitored, find out (Radarr/separate-series entry? watched-and-cleaned? genuinely unwanted?) rather than inferring intent from the flag. See [[project_media_gap_survey]] and `media/docs/SONARR_ACQUISITION_PROCESS.md`'s Standing rule + STEP 0.
