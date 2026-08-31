---
name: feedback_use_import_downloads_script_not_handrolled
description: "Never hand-roll a ManualImport curl/jq command for Sonarr/Radarr — always use truenas/scripts/import_downloads.sh (--plan/--apply/--scan-folder), even when it feels faster to write the payload directly"
metadata:
  type: feedback
---

Always use `truenas/scripts/import_downloads.sh` for any Sonarr/Radarr manual import — `--plan`/`--apply` for queue-tracked stuck downloads, `--scan-folder` only as the documented fallback. Never construct a `POST /api/v3/command` ManualImport payload by hand with curl/jq, even for a "quick" one-off case.

**Why:** Did this twice in one session (2026-08-31) despite the script existing and being explicitly documented as "the canonical way to import stuck/manual downloads — run this BEFORE reaching for ad-hoc curl." Both hand-rolled attempts had real bugs the script's own hardened code avoids: wrong `quality.id` (sourced from the wrong Sonarr endpoint — `qualitydefinition` id-space differs from the `Quality` enum id-space used in import payloads), `languages: Unknown` left unfixed, and omitted `indexerFlags`/`releaseGroup` fields. Both imports reported `"Manually imported N files"` with N>0 and looked successful, but the queue item never actually cleared — silent partial success is not visible unless you check the queue afterward, and the script does that automatically while a hand-rolled command does not. The user caught both instances by checking the queue directly; I should have caught them by using the tool built for this instead of reconstructing its logic from memory.

**How to apply:** Whenever a Sonarr/Radarr import is needed — a stuck `importBlocked` queue item, an escape-hatch grab that needs mapping, anything — reach for `import_downloads.sh` first. If a genuinely novel case isn't covered by the script, say so explicitly and ask before hand-rolling, rather than silently improvising and presenting it as equivalent.
