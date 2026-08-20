---
name: feedback_check_quality_profile_per_title
description: "When batch-adding Radarr movies, pick qualityProfileId per title (anime vs live-action) — don't copy one existing movie's profile as a template for the whole batch"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 791a1331-0ccf-4a42-ab62-dae7ffae93cd
  modified: 2026-08-20T01:57:34.548Z
---

Radarr's `qualityProfileId` (this library uses 13=Standard/live-action, 14=Anime, 15=Ultra-HD, 1=Any) must match the actual content, not whatever the first movie in a batch happened to use.

**Why:** Batch-added 21 movies (Overlord, Made in Abyss, Bleach, Robotech, Kizumonogatari, Battlestar Galactica, etc.) using `qualityProfileId:14` copied from an existing anime movie's record as the template for the whole payload. 19 of 21 were correctly anime; Battlestar Galactica (2003, live-action Western sci-fi) got the anime profile by mistake — user caught it, not me.

**How to apply:** Before batch-adding movies via the Radarr API, check each title's actual genre/format against the franchise it's sourced from — don't assume a franchise cluster is uniform (Robotech is a Western dub of Japanese source anime and correctly anime-profiled; Battlestar Galactica, sourced from the same "not movies — confirmed short-form" sweep, is not anime at all). When in doubt, look up the existing profile used by other entries in the same franchise/show before templating a payload. See [[feedback_spot_check_grab_titles]] for the related "verify the batch, don't trust it blind" lesson from the same session.
