---
name: feedback_trash_guides_primary_source
description: For TRaSH-Guides custom format IDs/specs, go straight to github.com/TRaSH-Guides/Guides raw JSON, not search results or summarized doc-page fetches
metadata:
  type: feedback
---

When looking up TRaSH-Guides custom format details (trash_id, specifications, whether a format is "guide-only" vs syncable), go directly to the primary source: raw JSON files under `github.com/TRaSH-Guides/Guides/blob/master/docs/json/<sonarr|radarr>/cf/*.json`, not WebSearch results or AI-summarized WebFetch of trash-guides.info doc pages.

**Why:** During a diagnosis of a mis-grabbed Russian-audio anime release, I initially claimed the "Language: Not Original" custom format was "guide-only" (not syncable via recyclarr `trash_ids`) based on a WebSearch summary and a WebFetch-summarized doc page. This was wrong — a PR (TRaSH-Guides/Guides#2159, merged Dec 2024) had already added a real, syncable `trash_id` (`ae575f95ab639ba5d15f663bf019e3e8`). The user caught the inconsistency and pushed back twice before I checked the raw file directly. TRaSH's catalog changes over time; secondary/summarized sources go stale or lossy in ways the primary repo doesn't.

**How to apply:** For any TRaSH custom-format research (does this trash_id exist, is it current, what's its exact spec), fetch the raw JSON from the GitHub repo directly as the first move, not the last. Same applies generally to [[feedback_check_docs_before_fixing]] — verify against the authoritative source, not summaries of it.
