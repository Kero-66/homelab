---
name: feedback_sonarr_queue_hides_unmatched
description: "Sonarr's /api/v3/queue endpoint hides items it can't map to a known series/episode unless includeUnknownSeriesItems=true is passed"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-18T03:05:46.994Z
---

Sonarr's default `GET /api/v3/queue` response silently omits queue entries with `trackedDownloadState` types it can't cleanly match to a series/episode (e.g. "Unknown Series" batch releases grabbed manually via the UI). This caused a false "it's not downloading" conclusion during the VOTOMS/Armitage/GetBackers cleanup session (2026-08-08) — user had grabbed Mars Daybreak manually in the UI, it was actively downloading in qBittorrent, but repeated `/api/v3/queue?pageSize=200` calls showed nothing for it.

**Why:** Discovered when user insisted "it's definitely there in Sonarr" and was right — adding `&includeUnknownSeriesItems=true` to the queue query revealed it immediately.

**How to apply:** ALWAYS include `includeUnknownSeriesItems=true` on every Sonarr `/api/v3/queue` call, unconditionally — do not treat it as optional or add it only after a problem shows up. This matters most right after grabbing releases that hit the "Unable to find matching series and episodes" block, and — confirmed again 2026-08-18 — releases grabbed via `shouldOverride: true` (manual-override grabs, e.g. the "Unable to parse release" fix pattern documented in PATTERNS.md) also show up with `seriesId: null` and get hidden the same way. Repeated this exact mistake once already on 2026-08-08 and again on 2026-08-18 despite having this memory — an empty/filtered queue result must never be reported as "the download isn't there" without first confirming `includeUnknownSeriesItems=true` was actually on the request. See also [[feedback_prefer_nzb_over_torrent]] for related grab-workflow context from the same session.
