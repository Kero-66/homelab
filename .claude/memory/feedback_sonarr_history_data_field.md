---
name: feedback_sonarr_history_data_field
description: Sonarr history API's raw `data` field embeds Prowlarr API key in downloadUrl/guid — strip before printing
metadata:
  type: feedback
---

When querying Sonarr's `/api/v3/history` endpoint with `jq '.records[] | {..., data}'` (dumping the full `data` object instead of specific subfields), the `data.downloadUrl` and `data.guid` fields contain a full Prowlarr download URL with an embedded `apikey=` query parameter in cleartext.

**Why:** While diagnosing a stuck Clevatess S02E04 queue item, a full `data` field dump printed the live Prowlarr API key to terminal output/transcript. It's a local-network-only key (Prowlarr isn't internet-exposed), so impact was low, but it's still an unnecessary secret exposure that [[feedback_no_secret_output]] and [[feedback_no_api_keys_in_output]] exist to prevent.

**How to apply:** When jq-querying Sonarr/Radarr history for diagnostic purposes, explicitly select only the fields needed (e.g. `{date, eventType, sourceTitle, downloadId, customFormatScore}` or `.data.indexer`, `.data.releaseSource` individually) rather than dumping the whole `data` object. If the full object is genuinely needed for debugging, pipe through `jq 'del(.data.downloadUrl, .data.guid)'` first.
