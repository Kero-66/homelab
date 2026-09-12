# Franchise Watch-Order Playlists

Built 2026-09-12. Two methods, pick based on whether a franchise needs a movie/OVA to slot
*mid-season* (not just before/after a whole series):

- **SmartLists** (`smartlist.py`) — auto-refreshing, driven by an IMDb/Trakt/MDBList/TMDB external
  list or native field-sort rules. Use when it works; check first.
- **Manual playlist** (`build_playlist.py` + a `<franchise>.json`) — a plain Jellyfin playlist
  built once from a curated JSON. Does **not** auto-refresh — rerun the script if content changes.
  Necessary whenever a movie/OVA needs mid-season placement, since no external-list provider
  supports episode-level ordering except Trakt (paywalled, see below).

## Status

| Franchise | Method | Source | Verified |
|---|---|---|---|
| Macross | SmartLists | IMDb list `ls560970728` ("Continuity Order") | 163 items, 2026-09-11 |
| Monogatari | SmartLists | native rule, sort by ReleaseDate — release order is the community-*preferred* order here, not a stand-in for continuity (chronological "removes a lot of the fun") | 107 items, 2026-09-11 |
| Gurren Lagann | SmartLists | native rule, sort by ReleaseDate — the 2 movies are recap compilations of the same TV series, no separate continuity slot exists for them | 33 items, 2026-09-11 |
| Gundam Universal Century | SmartLists | IMDb list `ls560971030` ("Continuity Order") | 24 items, 2026-09-11 |
| Star Wars: The Clone Wars | SmartLists | IMDb list `ls544963772` (chronological, incl. film) | 39/39 episodes, 2026-09-11 |
| Trigun | Manual (`trigun.json`) | community consensus (movie between ep10/11) | 27 items, 100% content owned, 2026-09-12 |
| Votoms | Manual (`votoms.json`) | HIDIVE viewing guide + library season mapping | 81 items, 100% content owned, 2026-09-12 |
| .hack | Manual (`hack.json`) | multiple community guides, cross-checked | 77 items, 100% content owned, 2026-09-12 |
| Steins;Gate | Manual (`steinsgate.json`) | "ideal order" — series ep1-22, episode 23β (Season 0 special, a 2015 Blu-ray-bonus alternate finale bridging to the sequel), all of Steins;Gate 0, then the real episode 23, then the movie. Replaced an earlier SmartLists ReleaseDate-sort version (series → movie → 0, the "simple order") once the mid-series insertion requirement was identified — same category as Trigun. | 48 items, 100% content owned, 2026-09-12 |
| Battlestar Galactica | SmartLists | native rule, sort by ReleaseDate — **deliberately dynamic**: only Season 1 owned (user still deciding whether to continue), so a rerun-free playlist that auto-grows if S2-4 get added. Caveat: `Blood & Chrome` (2012 release, story-wise a prequel) and `The Plan` (ideal slot: after S4E15) will land at release-order positions, not their true chronological ones — same tradeoff as Monogatari/Gurren Lagann, accepted here in exchange for zero-maintenance | 15 items, 2026-09-12 |
| Black Butler | SmartLists | native rule (`SeriesName contains "Black Butler" AND NotContains "II"`), sort by ReleaseDate — same "only S1 owned, might continue" situation as BSG, but here release order genuinely matches the correct sequence (Book of Circus/Book of Murder/movie all released in the right order), so no ordering tradeoff. "Black Butler II" excluded by name as a guard against the non-canon S2 spinoff ever polluting the list if added later | 25 items, 2026-09-12 |
| Blue Gender | No playlist | "The Warrior" confirmed to be a pure recap compilation with an alternate ending (not new content) — same category as the excluded Gundam 0083 recap; left as an optional standalone alternate, not part of any combined list |
| Robotech | Manual (`robotech.json`) | 3 seasons → `The Shadow Chronicles` as a coda. Technically overlaps the tail of Season 3 rather than following it cleanly, but a scene-level interleave isn't practical — using the common watch-guide simplification | 86 items, 100% content owned, 2026-09-12 |
| Tekkaman Blade | Manual (`tekkaman.json`) | `Prelude to a Long Battle` (pre-series clip-show) → Season 1 → `Twin Blood`/`Burning Clock` (side-story extras, no confirmed exact episode slot so placed here rather than guessed) → `Missing Link` (confirmed bridge to TBII) → `Virgin Memory` (billed as TBII's own "Episode 00") → Tekkaman Blade II | 60 items, 100% content owned, 2026-09-12 |

## When a manual playlist needs a rerun

The three manual playlists are plain Jellyfin playlists (fixed item IDs at creation time) — they
do **not** watch the library. Since all three had **complete** content when built, nothing will
silently go stale. Rerun `build_playlist.py <franchise>.json` only if:

- New content is acquired for that franchise (a new movie/OVA/season) that should be inserted
  into the curated order — add an entry to the JSON first, then rerun.
- An item is deleted and later re-added as a genuinely new library item (rare — quality
  upgrades/replacements keep the same episode ID, so this normally does *not* require a rerun).

A rerun deletes and recreates the playlist by name — safe to do any time, no manual ID lookups.

## External-list provider capability matrix (checked from plugin source, not just docs)

Only matters for the SmartLists path. Confirmed 2026-09-12 by reading each provider's actual
parsing code in `jyourstone/jellyfin-smartlists-plugin`:

| Provider | Needs API key | Episode-level items | Notes |
|---|---|---|---|
| Trakt | Yes | ✅ only provider that tags `Episode` kind | **Dead** — app creation now VIP-paywalled (2026-07-30), see `ai/todo.md` #124 |
| IMDb | No | Technically yes (tags everything `Unknown`, still ID-matches) | No list-creation API — browser-only to build your own; fine for consuming others' public lists |
| MDBList | Yes | ❌ no — only `Movie`/`Show` kinds exist in its data model | Structurally cannot express mid-season insertion, ever |
| TMDB | Yes | ❌ movies/shows/collections only | Good for movie-collection lists |
| Letterboxd | No | ❌ movies only | N/A for TV |
| ListenBrainz | No | N/A (music) | Not relevant |
| Scrob | Yes (self-hosted) | Season-level only | Not relevant here |

**Bottom line:** with Trakt paywalled, no remaining provider can slot a movie mid-season. Manual
curation (`build_playlist.py`) is the correct tool for that case, not a workaround.

## SmartLists API reference

Smart lists are managed via `POST/GET/PUT/DELETE /Plugins/SmartLists` — see the plugin's own
`docs/content/development/integration-api.md` for the documented contract. Key gotchas found this
session:

- Creating a Playlist requires `UserPlaylists: [{"UserId": "..."}]` — get IDs from
  `GET /Plugins/SmartLists/users`.
- `MemberName: "ExternalList"`, `Operator: "Equal"`, `TargetValue: "<list url>"` for an
  external-list rule; sort `SortBy: "External List Order Ascending"`.
- The admin UI's "Rule Group Order" sort option is **not backed by the live API** — checked
  `GET /Plugins/SmartLists/fields`, it's not in the real `OrderOptions` list. Don't trust the UI
  dropdown as proof a feature works; verify against `/fields` directly.
- IMDb/Trakt fetches can fail transiently (rate-limit) with `success:true` and 0 matched items, or
  a `RESOURCE_NOT_FOUND`/private-list error in history — always retry once and check
  `GET /Plugins/SmartLists/Status/History` before concluding a list is broken.
- `WebSearch`'s AI-synthesized IMDb list URLs can be **fabricated** — one returned a 404, another
  a private list, presented confidently as real. Always verify a candidate URL (browser, or a text
  proxy like `r.jina.ai/<url>` when the browser tool is unavailable/rate-limited) before wiring it
  into a smart list.
