---
name: service_shoko_manual_linking
description: "The exact API sequence to manually identify Shoko unrecognized files against an AniDB anime that isn't in the local collection yet — the missing piece is createSeriesEntry=true on the Refresh call"
metadata:
  type: service
---

Shoko's "unrecognized files" are files whose ED2K hash isn't in AniDB's crowd-sourced database (common for private-tracker remuxes/re-encodes that were never hash-submitted by anyone — see `feedback_never_dump_full_records_with_secret_fields.md`'s sibling context and the 2026-08-24/25 session notes). Hash matching will never resolve these; they need manual identification against the correct AniDB anime.

**The full working sequence** (all via `apikey` header auth, base `http://192.168.20.22:8111/api/v3`):

1. **Find the right AniDB anime**: `GET /Series/AniDB/Search/{query}` (fuzzy title search against AniDB's full title dump, not just your local collection). Verify the match against Wikipedia/TMDB before proceeding if there's any ambiguity — AniDB search is fuzzy and returns lots of noise.
2. **Create the local series record** — this is the step that's easy to miss: `POST /Series/AniDB/{anidbID}/Refresh?createSeriesEntry=true&immediate=true`. Without `createSeriesEntry=true`, this call only refreshes/caches AniDB metadata — it does **not** create a local `AnimeSeries` record, and every `File/Link` call will then fail with `"Unable to find series with id X"` even though the AniDB data looks cached. This flag is what's actually missing 90% of the time. For a series that already exists locally but shows 0 episodes, re-run via `POST /Series/{shokoSeriesID}/AniDB/Refresh?force=true&createSeriesEntry=true&immediate=true` instead (force is needed since the series already exists).
3. **Wait for the queue to drain** (`GET /Queue`, poll `TotalCount` until 0) — episode record creation happens as a queued job, not synchronously, even with `immediate=true`.
4. **Get local episode IDs**, not AniDB episode IDs: `GET /Series/{shokoSeriesID}/Episode?includeMissing=true&pageSize=100`. The `includeMissing=true` flag is required — without it, episodes with no linked file (which is all of them, pre-link) are silently excluded from the response, making a freshly-created series look empty even when it isn't. Match by `.Name` field, not `.EpisodeNumber`/`.Type` — the local episode model's `EpisodeNumber` and `Type` fields are unreliable/null in some series instances (root cause not identified during this session's debugging — don't assume they're populated, always verify against the response before writing matching logic around them). If matching by extracted title from the filename, be careful with punctuation (apostrophes, colons) — normalize both sides (strip non-alphanumerics, lowercase) before comparing.
5. **Link**: `POST /File/{fileID}/Link` with body `{"EpisodeIDs": [localEpisodeID]}` (the local ID from step 4, never the AniDB-native episode ID from `/Series/AniDB/{anidbID}/Episode` — those are a different ID space and will 400 with "Unable to find shoko episode with id X" if used directly).

**Two AniDB entries can be legitimate duplicates.** During this work, "Megazone 23 Part III" had two separate AniDB IDs with identical title/type/episode count — a genuine AniDB data duplication, not a search error. Either is fine to use.

**A file can belong to a completely different show than its folder name suggests, cross-listed by AniDB.** "Macross FB7: Listen to My Song!" appeared as a Season 0 special under both "Macross 7" and "Macross Frontier" in Sonarr/TVDB (it's a crossover film) — only one of the two actually had the downloaded file; check both before assuming a gap doesn't exist, or that a duplicate does.

**Structural non-matches, not linking failures**: Western-produced or heavily-adapted content (RWBY — Western CGI; Robotech — a re-edited Western dub of Japanese source shows) has no AniDB entry at all and never will, regardless of search effort — AniDB is anime-only and doesn't catalog Western/adapted works. Verify this once via `Series/AniDB/Search` (a real miss returns nothing relevant) and stop, rather than repeatedly re-searching.

**How to apply:** Anytime "sort out Shoko's unrecognized files" comes up again, work title-by-title through the current unrecognized list, applying this exact sequence — the `createSeriesEntry=true` flag is the detail most likely to be forgotten and cause the whole flow to silently fail at the Link step.
