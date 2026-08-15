---
name: feedback_prefer_nzb_over_torrent
description: "When both usenet/NZB and torrent releases are available for a grab, prefer the NZB release"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-08T09:34:18.575Z
---

User has a standing preference for usenet (NZB/SABnzbd) releases over torrent (qBittorrent) releases when both are available for the same content.

**Why:** Stated directly by user during VOTOMS/Armitage III cleanup session (2026-08-08) — not tied to a specific incident, just a general preference.

**How to apply:** When picking a release to grab (via Sonarr/Radarr release search or manual grabs), if multiple quality-equivalent options exist across protocols, choose the usenet indexer (altHUB, DrunkenSlug, Treasure Maps(SceneNZB)) over torrent indexers (AnimeTosho, Nyaa.si, SubsPlease) unless usenet has no seeders/availability or is clearly worse quality. If only torrent releases exist for a given piece of content, torrent is fine — this is a preference between equal options, not a hard requirement.
