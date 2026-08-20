---
name: feedback_queue_cleanup_respects_seeding
description: "Never use removeFromClient=true or blocklist on Sonarr/Radarr queue items that aren't genuinely dead — it kills seeding and permanently blocks a valid release"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ea1453dc-a224-4546-9eb2-6afca3367b7b
  modified: 2026-08-18T11:20:31.357Z
---

When cleaning up redundant/duplicate grabs in the Sonarr/Radarr queue (e.g. multiple releases racing for the same episodes), do NOT touch the ones that were simply not the winning pick. Only intervene on entries that are actually broken: stalled/dead magnets, `downloadFailed`, or confirmed corrupt.

**Why:** Deleting a queue entry with `removeFromClient=true` pulls the torrent out of qBittorrent entirely, killing seeding — this matters on private trackers with ratio/seed-time requirements and is not reversible once qBit drops it. Blocklisting a release that wasn't actually bad (just not the chosen one) permanently prevents Sonarr from ever grabbing it again, which is destructive for no benefit — a redundant grab that already imported into a different episode slot or is simply superseded will resolve itself once the real pick is imported (Sonarr/cleanuparr handle this without intervention).

**How to apply:** Before deleting/blocklisting anything from the arr queue, classify it first: (1) genuinely dead — stalled with 0 progress for a long time, marked `downloadFailed`, or explicitly abandoned by the user — safe to remove+blocklist+re-search; (2) just not the chosen release among several valid candidates — leave it alone, let it keep seeding, do not touch the queue or blocklist. When in doubt, ask before deleting anything from a download client, not just from the arr app's queue view.
