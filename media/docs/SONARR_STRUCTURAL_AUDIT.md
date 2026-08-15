# Sonarr Library Structural Audit — Specials, Duplicate Series, Recap Content

Three related design flaws found and being corrected in the Sonarr library, all stemming from the same root cause: TVDB/scene metadata sometimes represents a single piece of real-world content in more than one place in Sonarr's data model.

1. **Specials that are actually movies** — belong in Radarr, not as a Sonarr TV special. See "Movie audit" section below.
2. **Whole series/seasons that duplicate another series** — the same content tracked twice under two different Sonarr series entries (or a season within one series duplicating an entire separate series). See "Duplicate series" section below.
3. **Specials that are recap/alternate-cut versions of episodes already owned in a numbered season** — different title, same underlying content, so not real gaps even though `hasFile: false`. See "Recap/alternate-cut specials" section below.

Older shows in particular often ship their movie/OVA content bundled inside the same download pack as the TV episodes (see the VOTOMS and Macross Dynamite 7 precedents this session) — when hunting for a missing Radarr movie from an older franchise, check whether a TV batch pack for the parent series already contains it before searching separately.

## Per-series workflow (repeat this for each series in the gap list)

Developed and validated on the Macross cluster (series 70, 73) 2026-08-15. Follow in order — each step is cheap and can resolve the gap without needing the next step:

**1. Pull the full picture for the series** — don't just look at the aggregate gap count, get per-season breakdown plus every monitored-missing episode's title/runtime:
```bash
curl -sL "http://sonarr.home/api/v3/series/<ID>?apikey=$SONARR_KEY" | jq '{title, seasons: [.seasons[]|{seasonNumber,monitored,statistics}]}'
curl -sL "http://sonarr.home/api/v3/episode?seriesId=<ID>&apikey=$SONARR_KEY" | jq '.[] | select(.monitored==true and .hasFile==false) | {seasonNumber, episodeNumber, title, id, runtime}'
```
Numbered seasons (1+) are usually where the real, worth-chasing gaps are. Season 0 (specials) is where all three structural-flaw patterns above hide — triage those separately from real gaps.

**2. For each Season 0 gap, check runtime first** — this alone tells you which pattern you're likely looking at:
- **≥60min** → probably a movie. Check the Movie audit cross-reference method below.
- **<60min** → probably NOT core story content (bonus feature, alt broadcast cut, anniversary featurette, promotional short). Don't assume it's junk though — verify via research (step 4) before deprioritizing, since some short specials genuinely matter to the user.

**3. For movie-length specials, check Radarr/TMDB directly — don't trust fuzzy title matching alone:**
```bash
grep -i "<keyword>" radarr_all.txt   # cached full Radarr list, see "How to regenerate this data" below
curl -sL -G "http://radarr.home/api/v3/movie/lookup" --data-urlencode "term=<exact special title>" --data-urlencode "apikey=$RADARR_KEY" | jq '.[] | {title, year, tmdbId}'
```
If TMDB lookup returns a match — even under a *different* title than the Sonarr special — that's usually the same film (see Macross Plus "Movie Edition" → "Macross Plus: The Movie" case). If Radarr already has the file (`hasFile: true`), the Sonarr special is a false gap: unmonitor it, don't search for it.

**4. If TMDB/Radarr comes back completely empty, don't assume "doesn't exist" or "definitely missing" — look it up online.** A title with zero TMDB hits is often a historical alternate release name for content that *does* exist under a different title (see "Clash of the Bionoids" case — a censored US re-edit of a film Radarr already had). Use `WebSearch` with the special's exact title plus the franchise name; if a specific promising source turns up (forum post, wiki, TVDB episode page), follow up with `WebFetch` on that URL directly rather than re-searching — note that **Reddit blocks WebFetch directly**, so for Reddit results, either rely on the WebSearch snippet or fetch an alternate source (Wikipedia, wiki, TheTVDB) that surfaces the same information instead.

**5. Document the finding immediately, in this file, with the source link** — don't just act on it and move on. Every research result in this doc exists so nobody (including a future session) has to re-derive it. Use whichever table/section fits: Movie audit (if it's a Radarr-copy or Radarr-covered case), Duplicate series (if it's a whole-series/season duplicate), or a new franchise-specific "niche specials" table like the Macross one (if it's genuinely non-core bonus content).

**6. Only actively search-and-grab for content that survived steps 2-4 as genuinely real, story-relevant, and missing.** Don't spend search effort on confirmed bonus/promotional material unless the user explicitly asks for it.

## Movie audit

Generated 2026-08-15 by pulling every Season 0 episode across all 67 Sonarr series that have any specials, filtering to runtime ≥60 minutes (the signal used for "probably a movie, not a short clip"), then fuzzy-matching titles against the full Radarr movie list. **The fuzzy match is noisy on generic titles — treat "Verified" rows as trustworthy, "Needs check" rows as a lead only, not a fact.**

## Legend
- **Sonarr file**: whether the episode already has a file in Sonarr (`true` = ready to copy into Radarr right now)
- **Radarr status**: `covered` (Radarr already has the file), `missing` (Radarr entry exists but no file — either copy from Sonarr if Sonarr has it, or grab fresh), `no entry` (not in Radarr at all — needs adding), `needs check` (fuzzy match was low-confidence, verify manually before acting)

## Verified matches — action needed

| Series | Special | Sonarr file | Radarr entry | Radarr status | Action |
|---|---|---|---|---|---|
| Armitage III | Dual Matrix | true | Armitage: Dual Matrix (2002) | missing | **Copy Sonarr file → Radarr** |
| Armored Trooper VOTOMS | Pailsen Files the Movie | false | Armored Trooper VOTOMS: Pailsen Files The Movie (2009) | covered | none — Radarr already has it |
| Armored Trooper VOTOMS | The Big Battle | false | Armored Trooper VOTOMS: The Big Battle (1988) | covered | none |
| Armored Trooper VOTOMS | Red Shoulder Document: Origin of Ambition | false | Armored Trooper VOTOMS: Red Shoulder Document - Origin of Ambition (1988) | covered | none |
| Babylon 5 | In the Beginning / Thirdspace / The River of Souls / A Call to Arms / The Legend of the Rangers / The Gathering / The Road Home (7 total) | false | matching Babylon 5 Radarr entries | covered (all `hasFile=true`) | none — Sonarr specials are pure duplicates, safe to unmonitor |
| Blue Gender | Blue Gender: The Warrior | true | Blue Gender: The Warrior (2002) | covered | none — but Sonarr also has the file; harmless duplicate, unmonitor optional |
| Goblin Slayer | Goblin's Crown | false | Goblin Slayer: Goblin's Crown (2020) | covered (grabbed this session) | none |
| Gurren Lagann | Gurren Lagann the Movie - The Lights in the Sky Are Stars | true | Gurren Lagann the Movie: The Lights in the Sky Are Stars (2009) | covered | none — duplicate, unmonitor optional |
| Gurren Lagann | Gurren Lagann the Movie - Childhood's End | true | Gurren Lagann The Movie: Childhood's End (2008) | covered | none — duplicate, unmonitor optional |
| MF GHOST | MF GHOST BATTLE DIGEST | false | MF Ghost Battle Digest (2024) | missing | Same content missing on both sides — grab attempts already exhausted (dead seeders, see [[project_media_gap_survey]]); try Radarr search independently, may have different indexer luck |
| Macross | Do You Remember Love | false | Macross: Do You Remember Love? (1984) | covered | none |
| Macross Frontier | Galaxy Tour FINAL in Budokan | false | Macross Frontier Galaxy Tour Final in Budokan (2009) | missing | Missing on both sides — needs a fresh grab (concert film, may be hard to find) |
| Macross Frontier | Macross Frontier The Movie - The False Songstress | true | Macross Frontier: The False Songstress (2009) | missing | **Copy Sonarr file → Radarr** (already flagged in [[project_sonarr_radarr_movie_migration]]) |
| Macross Frontier | Macross Frontier The Movie - The Wings of Goodbye | true | Macross Frontier: The Wings of Farewell (2011) | missing | **Copy Sonarr file → Radarr** (already flagged in [[project_sonarr_radarr_movie_migration]]) |
| Macross Frontier | Macross FB7: Listen to My Song! | false | Macross FB7: Listen to My Song! (2012) | missing | Missing on both sides — needs fresh grab |
| Steins;Gate | Steins;Gate the Movie: Load Region of Déjà Vu | false | Steins;Gate: The Movie - Load Region of Déjà Vu (2013) | covered | none |
| .hack | .hack//The Movie | false | .hack//The Movie (2012) | missing | Missing on both sides — needs fresh grab |
| .hack | .hack//G.U. Trilogy | false | .hack//G.U. Trilogy (2007) | missing | Missing on both sides — needs fresh grab |

Also confirmed from earlier this session (already actioned, not re-listed above in full): **Macross 7** — "The Galaxy Is Calling Me!" already copied logic pending (see [[project_sonarr_radarr_movie_migration]] — 4 movies total unmonitored in Sonarr, awaiting the actual copy step), and **The Super Dimension Fortress Macross: Flash Back 2012** likewise.

## Needs manual check (fuzzy match unreliable — generic titles caused false positives)

These series have movie-length specials where the automated cross-reference could not be trusted (common words like "Attack", "Titan", "Gundam" produced spurious matches across unrelated entries). Each needs a human or a careful manual grep-by-hand before acting:

- **Attack on Titan** — 7 movie-length specials (Final Season events, Part I/II/III, Chronicle, 2 live-action films) vs. 2 Radarr entries (`Crimson Bow and Arrow`, `The Roar of Awakening`, both missing). Likely partial overlap, not 1:1 — verify each title individually.
- **Mobile Suit Gundam 0083: Stardust Memory** ("Afterglow of Zeon") and **Mobile Suit Gundam Wing** ("Endless Waltz: The Movie") both fuzzy-matched to a single junk Radarr entry titled "Gundam (0)" (year 0 — likely a placeholder/bad metadata entry, not real). Check what "Gundam (0)" actually is in Radarr before trusting any match here.
- **JUJUTSU KAISEN** — "Jujutsu Kaisen: Hidden Inventory / Premature Death - The Movie" and "Jujutsu Kaisen 0" (Sonarr specials) vs. "Jujutsu Kaisen 0 (2021)" [covered] and "JUJUTSU KAISEN: Execution (2025)" [missing] in Radarr — these are likely two different movies, not the same one twice; verify before merging.
- **Macross Delta** ("Passionate Walkure", "Absolute Live!!!!!!") and **Macross Plus** ("Movie Edition") all fuzzy-matched to "Macross Plus: The Movie (1995)" [covered] — that Radarr entry can only be one of these three at most; the other two need their own check (Macross Delta has separate Radarr entries "Macross Delta: Passionate Walküre (2018)" and "Macross Delta: Zettai Live!!!!!!" — likely the real matches, algorithm just picked wrong candidate).

## Resolved via web research (title didn't match anything in Sonarr/Radarr/TMDB)

Sometimes a Sonarr special's title is a genuinely different historical release name for content Radarr already has under its "real"/modern title — TMDB lookup returns nothing because it was never catalogued separately. When Radarr/TMDB search comes back empty, don't assume "no separate content exists" or "must be missing" — look it up. Confirmed case:

- **Macross (series 70) "Clash of the Bionoids"** (episode id 3082) — this is the 1980s-90s US theatrical/video re-edit of "Do You Remember Love?" (Radarr already has, `hasFile: true`) with ~20-40 minutes cut for content (gore/nudity). Not a distinct film — same underlying movie, different historical dub/cut name. No TMDB entry exists under "Clash of the Bionoids" at all. **Unmonitored** 2026-08-15, same treatment as the "Do You Remember Love" duplicate itself.
- **Macross Plus (series 73) "Macross Plus: Movie Edition"** (episode id 3104, 115min) — confirmed via Radarr/TMDB lookup (not web search) to be the exact same film as "Macross Plus: The Movie (1995)" (TMDB id 18837, Radarr already has, `hasFile: true`) — just catalogued under a different title. **Unmonitored** 2026-08-15.

## Macross franchise — niche/bonus specials researched and confirmed low-priority (not core story content)

These were flagged as monitored-but-missing but confirmed via web research (2026-08-15) to be bonus/promotional/historical-curiosity material, not story content worth actively pursuing. Documented here so this research doesn't need repeating. All left monitored (not unmonitored — they're genuinely missing, just deprioritized) unless noted.

| Series | Special | Runtime | What it actually is | Source |
|---|---|---|---|---|
| Macross (70) | 20th Anniversary Premium Collection | 25min | 2002 promo DVD: 3D CG Valkyrie showcase reel + movie previews + game footage clips, made 4 months before Macross Zero premiered | [gubabablog rewatch](https://gubabablog.wordpress.com/2016/05/15/the-great-macross-rewatch-20th-anniversary-premium-collection/) |
| Macross (70) | Macross Ep. 11 (Original Broadcast Version) | 25min | The *unfinished* original 1982 broadcast of episode 11 "First Contact" — animation wasn't done in time, so it's mostly static keyframes with no in-betweening. Inferior to the finished version we already have (Season 1, complete). Historical curiosity only. | [Great Macross Rewatch](https://gubabablog.wordpress.com/2015/12/03/the-great-macross-rewatch-12-first-contact/) |
| Macross (70) | SDF Macross 01&02 Special Version | 46min | Confirmed: the pilot broadcast from Oct. 3, 1982 — episodes 1 and 2 merged into one 46-minute program to introduce the series to Japanese TV audiences. Same content as the two episodes we already have (Season 1, complete), just presented as a single combined pilot cut rather than two separate episodes. | [TheTVDB episode page](https://thetvdb.com/series/macross/episodes/8991215) (user-supplied source, 2026-08-15) |
| Macross (70) | Mech Graffiti | 40min | 1984 rare VHS-only music-video-style compilation: existing TV mecha/character scenes re-cut to Macross BGM and Lynn Minmay songs, plus alternate title-card versions. No new footage. | [Macross World Forums](https://www.macrossworld.com/mwf/topic/26524-macross-mech-graffiti/) |
| Macross (70) | 30th Anniversary Special | 25min | Part of the 2012 "Macross 30th Anniversary Project" — bonus-disc featurette bundled with Blu-ray box sets (behind-the-scenes/celebration material alongside concerts, exhibitions, a stage musical). Not story content. | [Macross Wiki](https://macross.fandom.com/wiki/Macross_30th_Anniversary_Project) |
| Macross Plus (73) | Macross A Future Chronicle | 17min | A narrated clip-show retrospective covering the entire Macross franchise's story so far, bundled as a video special with the first Macross Plus OVA volume (Aug 1994) — not part of Macross Plus's own story. | [gubabablog rewatch](https://gubabablog.wordpress.com/2016/01/31/the-great-macross-rewatch-a-future-chronicle/) |

## Not movies — confirmed short-form content (excluded from action)

Runtime ≥60min but confirmed to be behind-the-scenes/panel/OVA-short content, not theatrical/OVA movies: **The Mighty Nein** (all entries are "Inside the Mighty Nein" behind-the-scenes panels), **Black Butler** "Book of Murder Part 1/2" (60min OVA episodes, not a movie), **Initial D** "Legend 1/2/3" (recap/compilation OVAs, not new content), **Overlord**, **Made in Abyss**, **Monogatari**, **Full Metal Panic!**, **Bleach**, **JoJo's Bizarre Adventure**, **Battlestar Galactica (2003)**, **Robotech**, **Farscape**, **Fallout**, **Is It Wrong to Pick Up Girls in a Dungeon?**, **Andor** — spot-checked and either already correctly categorized elsewhere, franchise films likely already covered by existing Radarr entries under a Radarr-native search, or too ambiguous to auto-classify; **not audited in depth this pass** — re-run the same runtime/fuzzy-match query (see below) if picking this up again, these were simply out of scope for the first pass.

## Duplicate series (whole season/series duplicates another series entry)

Confirmed cases where an entire series, or a whole season within one, is the exact same content as a separately-tracked series entry. Fix: unmonitor (or delete, if genuinely empty) the duplicate side, keep the one with the imported files.

| Series A (kept/source of truth) | Series B (duplicate, fixed) | Status |
|---|---|---|
| Armored Trooper VOTOMS (series 97, seasons 1-4) | series 98/99/100 (Phantom Chapter / Shining Heresy / Pailsen Files as standalone series) | Fixed — 98/99/100 deleted, content lives in series 97's seasons |
| Macross 7 (series 67, Season 0 specials 17-20) | Macross Dynamite 7 (series 101) | Fixed — series 101 deleted, content lives in series 67 |
| Tekkaman Blade II (series 79, Season 1, 6/6 episodes) | Tekkaman Blade (series 80) Season 2 (6 episodes, same content) | Fixed — series 80 Season 2 unmonitored |

**Why the standalone series usually grabs successfully when the parent-series season doesn't**: release groups title files after the *real* release name (e.g. "Tekkaman Blade II"), not Sonarr's season-based grouping. A parent series' automated search for "Season 2" constructs a query like "Show S02E0X" that no release is actually titled — the standalone series' search for its own real title matches directly. This is expected behavior, not a fluke, for any franchise where TVDB keeps both a combined parent entry and separate per-arc entries (common for older anime).

**Standing resolution policy** (2026-08-15): when a franchise has both a standalone series and a "this is also a season of the parent series" duplicate,
1. **Priority 1 — try the standalone series first.** Add it to Sonarr if missing, search/grab there. This is almost always what release groups actually name things after.
2. **Priority 2 — fall back to the parent series' season slot** only if the standalone series genuinely can't find/grab the content (no releases indexed, dead seeders, etc.).
3. **Actual availability overrules preference** — whichever approach actually lands a successful download wins; don't keep trying priority 1 indefinitely once priority 2 has already succeeded, and don't undo a working priority-2 grab just to force priority 1.

Once content lands via either path, unmonitor the losing side (same as the fixes above) so Sonarr doesn't keep re-searching for something it will never find.

**How to find more**: group series by a normalized franchise-name stem (strip numerals/subtitles) and check for episode-count collisions between a season in one series and a whole separate series of the same stem. Checked 2026-08-15 for the Macross family (6 series), Gundam family (3 series), Star Trek (2 series) — no further duplicates found; those are genuinely distinct shows within the same franchise, not the same content twice. Re-check any newly-added series against this list.

## Recap/alternate-cut specials (different title, same underlying content as a numbered-season episode)

Distinct from the duplicate-series case above — these are *individual* specials whose title differs from the season episode they overlap with (so exact-title matching won't catch them), typically theatrical "Stage"/compilation releases of TV episodes repackaged under new names.

**Confirmed**: Armored Trooper VOTOMS (series 97) Season 0 has four "Stage I-IV" specials, each 25 minutes (TV-episode length, not movie length — these were excluded from the movie audit above for exactly that reason):
- "Stage I: Woodo City" — shares "Woodo" with Season 4 episode "Woodo" (Phantom Chapter arc)
- "Stage II: Kummen Jungle Wars" — shares "Kummen" with Season 4 episode "Kummen"
- "Stage III: Deadworld Sunsa" — shares "Sunsa" with Season 1 episode "Planet Sunsa"
- "Stage IV: God Planet Quaint" — not yet matched to a specific season episode, same pattern likely applies

These are very likely alternate/theatrical titles for content already owned via the numbered seasons, not real gaps — treat as low-priority even though Sonarr shows them as monitored-and-missing. **Not fully verified** (word-overlap only, not confirmed by watching/checking runtime-exact overlap) — worth a final confirmation pass before unmonitoring, but strong enough evidence to deprioritize searching for them.

**How to find more**: for each series with Season 0 content, compare Season 0 episode titles against numbered-season episode titles for significant shared words (not exact match) — the query used in the movie audit's regeneration section pulls the raw data; do the word-overlap comparison per-series rather than exact-string match, which found zero hits library-wide when tried 2026-08-15.

## How to regenerate this data

```bash
# 1. Get all series with any Season 0 content
curl -sL "http://sonarr.home/api/v3/series?apikey=$SONARR_KEY" | \
  jq -r '.[] | select(.seasons[] | select(.seasonNumber==0 and .statistics.totalEpisodeCount>0)) | "\(.id)\t\(.title)"'

# 2. For each series id, pull Season 0 episodes (runtime, hasFile) — do this in the FOREGROUND,
#    not backgrounded; backgrounding this loop hangs indefinitely for unknown reasons (confirmed
#    2026-08-15, cost significant time — just run in batches of ~15-20 series per foreground call)
curl -sL "http://sonarr.home/api/v3/episode?seriesId=<ID>&apikey=$SONARR_KEY" | \
  jq -r '.[] | select(.seasonNumber==0) | "\(.hasFile)\t\(.runtime)\t\(.title)"'

# 3. Filter runtime >= 60, cross-reference against Radarr's full movie list
curl -sL "http://radarr.home/api/v3/movie?apikey=$RADARR_KEY" | jq -r '.[] | "\(.hasFile)\t\(.title) (\(.year))"'
```
