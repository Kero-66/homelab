---
name: feedback_verify_api_before_calling
description: "Check an API's actual OpenAPI/swagger spec (or source) for the correct HTTP method and body shape before calling an unfamiliar endpoint — don't guess and iterate through 400/404/405s live"
metadata:
  type: feedback
---

During the 2026-08-24 Shoko/Jellyfin session, at least five separate endpoint calls were guessed wrong on the first (and often second) try: Jellyfin plugin restart, Shoko's `/api/v3/Settings` update (tried POST, then PUT, both wrong — it's PATCH with a JSON-Patch body), Shoko's `/Action/RecreateAllGroups` (tried POST, wrong — it's GET), Dockhand's stack-status endpoint (tried GET, wrong — 405), and `/api/v3/File/Unrecognized` (doesn't exist as a path at all — `Unrecognized` is an enum value for the `include_only` query parameter on the base `/File` endpoint, discovered only after a failed call was misreported as a real "zero results" finding).

**Why:** User called this out directly and repeatedly ("WHY ARE YOU GUESSING", "you aren't researching how to use the api properly"). Every one of these services exposes a real, fetchable OpenAPI/swagger spec (`/swagger/v3/swagger.json` for Shoko and Jellyfin's `/api-docs/openapi.json`) or has source on GitHub — the correct method and body shape were always one `curl`/`gh api` call away, but got reached for only after 2-3 failed guesses each, burning the user's patience and trust on avoidable trial-and-error.

**How to apply:** Before calling any endpoint on a service for the first time in a session (or one not already documented in `ai/PATTERNS.md`), fetch its spec first — `curl -s <base>/swagger/v3/swagger.json | jq '.paths."/Some/Path"'` (or the OpenAPI equivalent) — and read the actual method + request body schema. For a plugin/service without its own reachable spec, check its GitHub source directly (`gh api repos/<org>/<repo>/contents/<path>`) rather than assuming based on a similar-looking API from a different service. A single spec lookup is cheaper than any failed call, and far cheaper than a failed call followed by misinterpreting its error response as real data (see `feedback_never_dump_full_records_with_secret_fields.md`'s sibling issue: a 400 error response has no `Total` key, so `.get('Total')` on it silently returns `None` — which was then reported as "zero unrecognized files," a fabricated finding).
