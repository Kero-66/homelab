# Franchise Watch-Order Playlists

Built 2026-09-12. Two methods, pick based on whether a franchise needs a movie/OVA to slot
*mid-season* (not just before/after a whole series):

- **SmartLists** (`smartlist.py`) — auto-refreshing, driven by an IMDb/Trakt/MDBList/TMDB external
  list or native field-sort rules. Use when it works; check first.
- **Manual playlist** (`build_playlist.py` + a `<franchise>.json`, via `watch-orders-runner`) — a
  plain Jellyfin playlist, rebuilt daily from a curated JSON. Auto-grows within any already-written
  entry (a new episode airing in a referenced season splices in on the next daily sweep, no JSON
  edit) and self-prunes on *removal* for free (Jellyfin drops a dead item reference from a playlist
  automatically when the item is deleted — confirmed empirically, Tekkaman Blade session
  2026-09-13). Builds a **partial** playlist from whatever's available if some entries aren't
  downloaded yet, rather than an all-or-nothing block (fixed 2026-09-15, see `build_playlist.py`'s
  module docstring). A genuinely new title still needs a human to add a JSON line — inherent to
  hand-curated order, not fixable by more automation (confirmed 2026-09-15, see the MDBList/Linearr
  writeup below).

  **Correction (2026-09-15): IMDb lists CAN do episode-level ordering** (proven — the Star Wars:
  Clone Wars SmartList below is 39/39 episodes including the film, via a plain IMDb list). The
  earlier "no external-list provider supports episode-level ordering except Trakt" claim in this
  README was wrong for IMDb specifically — only MDBList/TMDB/Letterboxd are structurally
  movie/show-only. **The real reason a franchise needs the manual path isn't "mid-season insertion
  is impossible externally" — it's one of these two narrower things:** (1) no existing public list
  encodes the exact structure wanted (a real *availability* gap — worth actually searching for
  before assuming, not asserting from category alone), or (2) the correct order depends on a
  decision specific to what *we* own/prefer (e.g. Gundam UC's movie-trilogy-over-TV-series choice)
  that no generic external list can make for us.

  **A further, sharper point (2026-09-15): even a *found* external list still needs the same
  verification effort as building one ourselves.** The Gundam UC IMDb list sat live, apparently
  fine, until we happened to actually check it against what we own and found it was both missing
  entries and using the wrong version of the content — proof that "trust an external curator" isn't
  free, it's a standing risk of silent drift, whether checked once or never. Given verification cost
  is paid either way, prefer building it ourselves for anything with real curatorial judgment in it
  (which movie/version counts, where side content slots) — SmartLists' remaining clear win is only
  the *zero-judgment* case: plain release-order sorts / genre-rule matches where there's no opinion
  being encoded at all (see Attack on Titan/Zoids/Maison Ikkoku checks below), where it also gets
  genuine unattended growth for wholly new titles that the manual path can never replicate.

**Considered and rejected (2026-09-15): hosting our own curated order on MDBList instead of a
local JSON.** SmartLists has no native "hand-specify this exact order" concept — the *only* way to
get a custom order out of it is `Sort: External List Order`, which requires the order to live on
an external list (MDBList/IMDb/Trakt/TMDB/Letterboxd). We could create our own MDBList lists and
point SmartLists at them, but it buys nothing over the status quo: removal is already automatic
(above), and addition/re-sequencing needs the same manual curation work either way — it would just
move from editing this repo's JSON to editing mdblist.com's UI, adding an external account/API-key
dependency for no functional gain. Decision: prefer an existing well-curated external list when one
exists (current practice for Macross/BSG/Black Butler/etc.); fall back to a manual JSON here when it
doesn't (Gundam UC, Trigun, Votoms, .hack, Tekkaman, Steins;Gate) — never host our own curation
externally just to get SmartLists' auto-refresh.

## Status

| Franchise | Method | Source | Verified |
|---|---|---|---|
| Macross | SmartLists | IMDb list `ls560970728` ("Continuity Order") | 163 items, 2026-09-11 |
| Monogatari | SmartLists | native rule, sort by ReleaseDate — release order is the community-*preferred* order here, not a stand-in for continuity (chronological "removes a lot of the fun") | 107 items, 2026-09-11 |
| Gurren Lagann | SmartLists | native rule, sort by ReleaseDate — the 2 movies are recap compilations of the same TV series, no separate continuity slot exists for them | 33 items, 2026-09-11 |
| Gundam Universal Century | Manual (`gundam_uc.json`) | Superseded the SmartLists IMDb-list version (`ls560971030`) 2026-09-15: that list was missing Doan's Island/G-Saviour (mid-sequence, same limitation as Trigun/Votoms/etc.) and used the raw 43-episode 1979 TV series instead of the community-preferred movie trilogy. **Partially built, mid-acquisition** — several titles still missing content (IGLOO x2, G-Saviour, Gundam ZZ, `Mobile Suit Gundam Narrative`) get skipped (not blocking) every sweep, see `ai/todo.md`; the rest of the sequence is live and splices in the missing entries automatically once each lands. | partial, growing daily as content downloads — see container logs for exactly what's still missing |
| Star Wars: The Clone Wars | SmartLists | IMDb list `ls544963772` (chronological, incl. film) | 39/39 episodes, 2026-09-11 |
| Trigun | Manual (`trigun.json`) | community consensus (movie between ep10/11) | 27 items, 100% content owned, 2026-09-12 |
| Votoms | Manual (`votoms.json`) | HIDIVE viewing guide + library season mapping | 81 items, 100% content owned, 2026-09-12 |
| .hack | Manual (`hack.json`) | multiple community guides, cross-checked | 77 items, 100% content owned, 2026-09-12 |
| Steins;Gate | Manual (`steinsgate.json`) | "ideal order" — series ep1-22, episode 23β (Season 0 special, a 2015 Blu-ray-bonus alternate finale bridging to the sequel), all of Steins;Gate 0, then the real episode 23, then the movie. Replaced an earlier SmartLists ReleaseDate-sort version (series → movie → 0, the "simple order") once the mid-series insertion requirement was identified — same category as Trigun. | 48 items, 100% content owned, 2026-09-12 |
| Battlestar Galactica | SmartLists | IMDb list `ls062079166` ("Timeline (The modern franchise)") — replaced the earlier native ReleaseDate-sort version once a community continuity-order list was found (2026-09-13) that places `Razor`/`The Plan`/`Blood & Chrome` at their correct story slots instead of release-date slots. Still **deliberately dynamic**: only Season 1 + the 2 movies owned today (Miniseries search queued, Razor just added to Radarr) — auto-grows if S2-4/Miniseries/Razor land, zero-maintenance like Macross/Gundam UC. Not independently verified end-to-end (IMDb blocks WebFetch so the full list couldn't be read directly) — confirmed only that it's episode-level and currently renders Season 1 → The Plan → Blood & Chrome with no S2-4/Miniseries/Razor owned yet to expose whether the mid-series placement is actually correct; re-check ordering once those land | 15 items, 2026-09-13 |
| Black Butler | SmartLists | native rule (`SeriesName contains "Black Butler" AND NotContains "II"`), sort by ReleaseDate — same "only S1 owned, might continue" situation as BSG, but here release order genuinely matches the correct sequence (Book of Circus/Book of Murder/movie all released in the right order), so no ordering tradeoff. "Black Butler II" excluded by name as a guard against the non-canon S2 spinoff ever polluting the list if added later | 25 items, 2026-09-12 |
| Blue Gender | No playlist | "The Warrior" confirmed to be a pure recap compilation with an alternate ending (not new content) — same category as the excluded Gundam 0083 recap; left as an optional standalone alternate, not part of any combined list |
| Robotech | Manual (`robotech.json`) | 3 seasons → `The Shadow Chronicles` as a coda. Technically overlaps the tail of Season 3 rather than following it cleanly, but a scene-level interleave isn't practical — using the common watch-guide simplification | 86 items, 100% content owned, 2026-09-12 |
| Tekkaman Blade | Manual (`tekkaman.json`) | `Prelude to a Long Battle` (pre-series clip-show) → Season 1 → `Twin Blood`/`Burning Clock` (side-story extras, no confirmed exact episode slot so placed here rather than guessed) → `Missing Link` (confirmed bridge to TBII) → `Virgin Memory` (billed as TBII's own "Episode 00") → Tekkaman Blade II | 60 items, 100% content owned, 2026-09-12 |

## Automation (`watch-orders-runner`, added 2026-09-15)

Manual playlists are automatically rerun daily by a small dedicated container —
`truenas/stacks/watch-orders-runner/` (Dockhand-managed, `python:3.13-alpine` + a plain sleep
loop, no cron daemon). It loops over a **fixed, explicit list** of franchise JSONs (hardcoded in
`entrypoint.sh`, must be kept in sync with this README's "Manual" rows — deliberately not a glob
over `*.json`, since this directory also holds JSONs superseded by the SmartLists path, e.g.
`macross.json`, which must never be rerun or it'd create a duplicate playlist).

What this buys, and what it doesn't:
- **Removal was already free** before this existed — Jellyfin silently drops a dead item
  reference from a playlist when the underlying item is deleted (confirmed empirically, Tekkaman
  Blade session 2026-09-13). No script involvement either way.
- **Growth within an already-referenced season/series is now automatic** — `season_episodes()`
  queries Jellyfin live on every run, so a new episode airing in a season a JSON entry already
  points at (e.g. `{"series": "X", "season": 1}`) splices in on the next daily sweep, no JSON edit.
- **A genuinely new title (never referenced by any entry) still needs a human** — add a line to
  the JSON, same as it always did. No amount of automation removes this decision; it's inherent to
  hand-curated chronological order (confirmed this isn't unique to our approach — even the
  MDBList-hosting alternative considered and rejected above needs the same manual step).
- **A franchise still mid-acquisition gets a real, partial playlist today, not nothing** —
  `build_playlist.py` builds from whatever resolves and logs (not fails on) any entry it can't find
  yet, so e.g. Gundam UC gets a playlist covering however much is downloaded right now, and the
  missing entries splice in automatically as each one lands. Originally shipped as an all-or-nothing
  design (one missing title blocked the whole file) — changed 2026-09-15 after this defeated the
  actual point of automating reruns for an in-progress franchise.

**Considered and rejected: a real Jellyfin plugin, TrueNAS host crontab, or Linearr** (a
third-party "show sequencer" tool, evaluated 2026-09-15) — see `.claude/memory/` /
`ai/SESSION_NOTES.md` for that day's session for the full reasoning. Short version: a Jellyfin
plugin is disproportionate effort for a script rerun; TrueNAS-level crontab sits outside this
repo's git-IaC/Dockhand pattern that every other scheduled thing here follows; Linearr requires a
Jellyfin username+password (not a revocable API key, due to an upstream Jellyfin bug on its
playlist endpoints) and doesn't actually add capability over what a scheduled rerun of our own
script already provides for this Jellyfin-only, niche-anime-franchise use case.

Manually forcing a rerun any time (e.g. right after adding a new JSON entry, without waiting for
the next daily sweep) still works exactly as before:
```bash
JELLYFIN_KEY=... python3 build_playlist.py <franchise>.json
```
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
