---
name: feedback_sonarr_queue_hides_unmatched
description: "Sonarr's /api/v3/queue endpoint hides items it can't map to a known series/episode unless includeUnknownSeriesItems=true is passed"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-08T10:35:04.834Z
---

Sonarr's default `GET /api/v3/queue` response silently omits queue entries with `trackedDownloadState` types it can't cleanly match to a series/episode (e.g. "Unknown Series" batch releases grabbed manually via the UI). This caused a false "it's not downloading" conclusion during the VOTOMS/Armitage/GetBackers cleanup session (2026-08-08) — user had grabbed Mars Daybreak manually in the UI, it was actively downloading in qBittorrent, but repeated `/api/v3/queue?pageSize=200` calls showed nothing for it.

**Why:** Discovered when user insisted "it's definitely there in Sonarr" and was right — adding `&includeUnknownSeriesItems=true` to the queue query revealed it immediately.

**How to apply:** Always include `includeUnknownSeriesItems=true` on Sonarr queue checks (`/api/v3/queue?pageSize=200&includeUnknownSeriesItems=true`) when checking whether a manually-grabbed or unparseable-release download is actually in progress. This matters most right after grabbing releases that hit the "Unable to find matching series and episodes" block — those items are exactly the ones the default filter hides. See also [[feedback_prefer_nzb_over_torrent]] for related grab-workflow context from the same session.
