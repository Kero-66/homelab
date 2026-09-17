---
name: feedback_unmonitor_sonarr_after_radarr_add
description: "When adding a Radarr entry for content that also exists as a monitored Sonarr special, unmonitor the Sonarr side immediately — don't wait to be asked"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 791a1331-0ccf-4a42-ab62-dae7ffae93cd
  modified: 2026-08-20T01:50:00.187Z
---

Whenever a Sonarr Season-0 special turns out to be a real movie and gets a Radarr entry added (or is confirmed covered by an existing one), check and fix the Sonarr-side `monitored` flag as part of the same action, not as a follow-up.

**Why:** Batch-added 21 movies to Radarr for specials found across Overlord/Made in Abyss/Bleach/Robotech/etc. but didn't check whether the matching Sonarr episodes were still monitored — user had to ask. Turned out 5 Robotech specials were still monitored and would have kept getting searched by Sonarr in parallel with the new Radarr entries.

**How to apply:** This is the same "unmonitor the losing side" policy already documented in `media/docs/SONARR_STRUCTURAL_AUDIT.md` for duplicate-series and specials-are-movies cases — apply it proactively every time, as a standard last step of any Radarr add/grab for content sourced from a Sonarr special, not just when explicitly asked.

**This rule is what CREATES `monitored:false` (noted 2026-09-18).** Worth holding both halves together: the placement decision says "this belongs in Radarr", *this* rule unmonitors the Sonarr side, and the resulting `monitored:false` therefore means **"Radarr owns it, don't grab it here"** — not "nobody wants it". Reading that flag as a verdict on the content inverts the whole lifecycle; see [[feedback_check_sonarr_monitored_before_radarr_action]] and the corrected Standing rule in `media/docs/SONARR_ACQUISITION_PROCESS.md`.
