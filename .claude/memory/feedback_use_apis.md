---
name: feedback_use_apis
description: Use service APIs (Jellyfin, Sonarr, Bazarr) to query media/stream info — never jump to raw ffprobe/python when an API exists
metadata:
  type: feedback
---

Use the correct API for each service before reaching for shell commands or python scripts.

**Why:** User corrected directly: "why are you doing it this hard way, you always jump to python when we have api for so much".

**How to apply:** Jellyfin → `/Items/{id}/PlaybackInfo`, Sonarr → `/episodefile?seriesId=X`, Bazarr → `/episodes?seriesid[]=X`. Only reach for ffprobe/mediainfo when APIs lack the data.
