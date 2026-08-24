---
name: feedback_never_dump_full_records_with_secret_fields
description: "Never jq-dump a whole object/record when any field on it can embed a live secret (Sonarr/Radarr release/history records AND Prowlarr's own /search endpoint results all carry the Prowlarr API key in guid/downloadUrl/magnetUrl) — always allowlist specific fields, on every endpoint that returns these record shapes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bf60f53f-96d8-4fc1-9d6b-d111d0212ec1
  modified: 2026-08-22T00:00:00.000Z
---

Never pipe a full API record through `jq '.'` or `jq '{...., data}'`/similar wholesale-object dumps when the record type is known to carry a secret-bearing field. This applies to **every endpoint that returns this record shape**, not just the one where it was first caught: Sonarr/Radarr `release`/`history`/`queue` records (`guid`, `data.downloadUrl`) AND **Prowlarr's own `/api/v1/search` endpoint** (`guid`, `downloadUrl`, `magnetUrl` — confirmed 2026-08-22, a second incident after the first) AND **Shoko Server's `/api/v3/Settings` endpoint** (`AniDb.Password` — confirmed 2026-08-24, a third incident, third distinct service).

**Why:** Incident 1 (2026-08-15/16): printed `.data` in full while debugging a disappeared Sonarr grab — included `data.downloadUrl` with the cleartext Prowlarr API key. Required a key rotation. Incident 2 (2026-08-22): while using the documented Prowlarr free-text search "escape hatch" (PATTERNS.md's own workflow) to find a release Sonarr's structured search missed, ran `jq '.[] | select(...)'` with no field allowlist on a Prowlarr `/search` response to inspect the release — this printed `downloadUrl` and `magnetUrl` in full, both embedding the live `PROWLARR_API_KEY` in cleartext (visible as `?apikey=...` in the URL). The user was extremely clear after incident 1 that this must never happen again, and it happened again on a different endpoint of the same record family. Required another key rotation (`ai/todo.md` #95).

**How to apply:** Before piping ANY Sonarr/Radarr/Prowlarr API response through `jq` — including Prowlarr's own `/search`, `/indexer`, and any endpoint returning release-like objects — explicitly allowlist fields (e.g. `{title, seeders, indexerId}`) and never use `.data`, bare `.`, or any wildcard/whole-object dump, even mid-debugging, even "just to inspect one field's presence." This applies transitively: a field that *contains* a flagged field (`data` containing `downloadUrl`) is just as unsafe as the flagged field itself. When a release actually needs to be grabbed via the escape hatch, extract `guid`/`downloadUrl`/`magnetUrl` directly into a shell variable with a targeted `jq -r '.[N].fieldName'` — never a broad select+dump — and pass the variable straight into the next command without ever echoing or printing it.
