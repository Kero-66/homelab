---
name: feedback_verify_queue_before_reporting_zero_results
description: "Don't report \"zero indexer results\" from a single immediate queue check after triggering a search — grabs can take time to appear"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 791a1331-0ccf-4a42-ab62-dae7ffae93cd
  modified: 2026-08-20T01:40:42.525Z
---

After triggering a Sonarr/Radarr search command (MoviesSearch, EpisodeSearch), don't treat one immediate queue check as proof of "zero results." Search + grab + queue registration isn't instant — checking too soon can show an empty queue for an item that actually grabbed successfully seconds later.

**Why:** Reported 5 movies as "zero indexer results, still open" after triggering Radarr MoviesSearch and checking the queue once; 2 of the 5 (both Attack on Titan specials) had actually grabbed and were downloading — the user caught the false negative, not me.

**How to apply:** After triggering a search, either wait a beat and re-check the queue before reporting results, or explicitly caveat a same-instant check as provisional ("queue empty as of this check, may still be searching"). Prefer checking movie/episode `hasFile` or querying history a bit later over trusting one instant queue snapshot as final. See [[project_media_gap_survey]] for the incident.
