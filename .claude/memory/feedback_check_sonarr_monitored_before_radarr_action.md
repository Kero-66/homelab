---
name: feedback_check_sonarr_monitored_before_radarr_action
description: "Before adding a Radarr entry or searching for a Sonarr Season 0 special, check whether it's actually monitored in Sonarr first"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 791a1331-0ccf-4a42-ab62-dae7ffae93cd
  modified: 2026-08-20T02:03:38.007Z
---

An unmonitored Sonarr episode/special is a signal someone already decided it's not wanted (bonus content, deprioritized, not core) — "no matching Radarr entry" alone is not sufficient justification to add one and trigger a search.

**Why:** The whole 2026-08-20 Sonarr-specials-movie-audit session (`media/docs/SONARR_STRUCTURAL_AUDIT.md`) queried Season 0 episodes by `runtime>=60` only, never checking `monitored` status, then added 21+ Radarr entries and triggered searches for anything without an existing match. User caught that Overlord's 3 specials (and likely others in the batch) were `monitored:false` in Sonarr the whole time — meaning they'd already been deliberately deprioritized, not overlooked. Left unwound per user's call this time, but the pattern is real and will recur on any future pass through this data.

**How to apply:** Before adding any Radarr entry or triggering a search sourced from a Sonarr special, pull the episode's `monitored` field first. If `false`, treat it as already-triaged/deprioritized and don't act without asking — don't let "hasFile:false + no Radarr entry" alone drive action. See [[project_media_gap_survey]] and the audit doc's step 2 for the fix applied to the workflow.
