---
name: feedback_never_dump_full_records_with_secret_fields
description: "Never jq-dump a whole object/record when any field on it can embed a live secret (e.g. Sonarr/Radarr release or history records' guid/downloadUrl carry the Prowlarr API key) — always allowlist specific fields"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bf60f53f-96d8-4fc1-9d6b-d111d0212ec1
  modified: 2026-08-15T14:16:14.596Z
---

Never pipe a full API record through `jq '.'` or `jq '{...., data}'`/similar wholesale-object dumps when the record type is known to carry a secret-bearing field. Sonarr/Radarr `release` and `history` records embed the live Prowlarr API key inside `guid` (for some indexers) and `data.downloadUrl` — PATTERNS.md already documented this for `guid`/`downloadUrl` specifically, but the mistake happened by dumping the *parent* `data` object instead of the flagged field directly, which still contains it.

**Why:** During a live debugging session (2026-08-15/16), printed `.data` in full while investigating why a Sonarr grab disappeared from the queue — this included `data.downloadUrl` with the cleartext Prowlarr API key, exposing it in the transcript. Required a key rotation. The user was very clear this must not happen again.

**How to apply:** Before piping any Sonarr/Radarr/Prowlarr API response through `jq`, check whether the object type is release/history/queue (or anything indexer-adjacent) — if so, explicitly allowlist fields (`{date, eventType, sourceTitle, message: .data.message}` etc.) and never use `.data`, `.` , or other wildcard/whole-object dumps on it, even when debugging. This applies transitively: a field that *contains* a flagged field (like `data` containing `downloadUrl`) is just as unsafe as the flagged field itself — check nested contents, not just top-level field names, before dumping.
