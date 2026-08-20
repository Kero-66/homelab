---
name: feedback_spot_check_grab_titles
description: "After any Radarr/Sonarr search-and-grab, sanity-check the actual grabbed release title against the intended movie/episode before trusting it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 791a1331-0ccf-4a42-ab62-dae7ffae93cd
  modified: 2026-08-20T01:45:45.314Z
---

Radarr's automated title matching can seize on a single generic shared word and grab something completely unrelated — it's not just a fuzzy-match risk during manual cross-referencing (already known), it happens on live grabs too.

**Why:** Batch-added 21 movies to Radarr with `searchForMovie:true`. One grab for "Bleach: The DiamondDust Rebellion" (Radarr id 169) actually pulled down "The Rebel (1961)" — a 24GB unrelated French film — matched purely on "Rebel"/"Rebellion". Caught only because a full queue title sanity pass was run after the batch, not because Radarr flagged anything.

**How to apply:** After any batch add-and-search or triggered MoviesSearch/EpisodeSearch, pull the queue and eyeball every grabbed release title against the intended target title — don't just check `hasFile`/queue-presence as success. If a title doesn't contain the expected franchise/movie name, remove from queue + blocklist immediately before it finishes downloading. See [[feedback_verify_queue_before_reporting_zero_results]] for the related "don't trust an instant queue check" lesson from the same session.
