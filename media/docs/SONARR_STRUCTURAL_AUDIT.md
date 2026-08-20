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

**Critical: "Season 0 = specials" is not the same as "Season 0 = movies."** Every monitored+missing Season 0 item needs to go through this workflow, not just the ones ≥60min. Runtime is a triage *signal* for which pattern you're probably looking at (step 2b below), not a filter for what counts as worth checking — a 4-minute purchaser-bonus OVA short is just as real a gap as a 90-minute film, and gets missed entirely if you only ever query `runtime>=60`. (Confirmed miss 2026-08-20: Gundam 0083's "The Mayfly of Space 1/2" bonus shorts, 4min/12min, were skipped this way across an entire audit pass — see the numbered-season-gap-diagnosis section below for the full scope of what else this blind spot hit.)

**2. Check `monitored` status before anything else.** An unmonitored Season 0 special is a signal someone already decided it's not wanted (bonus content, deprioritized, or otherwise not worth chasing) — don't treat "no Radarr entry" as sufficient justification to add one on its own. **Known gap (2026-08-20): this step was skipped for the entire 2026-08-20 batch-add session** (Overlord, Made in Abyss, Bleach, Black Butler, Robotech, Battlestar Galactica, Kizumonogatari, and the earlier AoT/Gundam/JJK/Macross Delta round) — none of those were checked for Sonarr `monitored` status before adding Radarr entries and searching. Confirmed at least Overlord's 3 specials (Sonarr eps 1266/1276/1277) were `monitored:false` the whole time. Left as-is per user decision (2026-08-20) rather than unwound, but **any future pass through this doc's "Verified matches" or the newly-added Radarr entries should re-check monitored status** before trusting the earlier reasoning.

**2b. For each Season 0 gap, check runtime next** — this tells you which pattern you're likely looking at:
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
| Macross Frontier | Galaxy Tour FINAL in Budokan | false | Macross Frontier Galaxy Tour Final in Budokan (2009) | missing | Grabbed 2026-08-18 (`[Hi10P][Covad]` release, 1 seeder, clean parse) — downloading |
| Macross Frontier | Choujikuu SUPER LIVE cosmic nyaan | false | (no Radarr entry — concert film, TV special only) | n/a | Grabbed 2026-08-18 (`[랑이-Raws]` release, 1 seeder, clean parse) — downloading |
| Macross Frontier | Macross Frontier The Movie - The False Songstress | true | Macross Frontier: The False Songstress (2009) | covered (copied 2026-08-18) | none — done |
| Macross Frontier | Macross Frontier The Movie - The Wings of Goodbye | true | Macross Frontier: The Wings of Farewell (2011) | covered (copied 2026-08-18) | none — done |
| Macross Frontier | Macross FB7: Listen to My Song! | false | Macross FB7: Listen to My Song! (2012) | missing | Missing on both sides — needs fresh grab. Re-checked 2026-08-18: zero results on Prowlarr (Nyaa.si) and AnimeTosho — this title is legally streaming (Hulu/Disney+/Plex per public listings) which likely explains the total lack of fansub/scene coverage. TMDB id 258156 confirmed correct (real 2012 crossover film blending Macross 7 archival footage into Frontier, not a mismatch). May need a non-indexer acquisition path if this is wanted. |
| Steins;Gate | Steins;Gate the Movie: Load Region of Déjà Vu | false | Steins;Gate: The Movie - Load Region of Déjà Vu (2013) | covered | none |
| .hack | .hack//The Movie | false | .hack//The Movie (2012) | missing | Missing on both sides — needs fresh grab |
| .hack | .hack//G.U. Trilogy | false | .hack//G.U. Trilogy (2007) | missing | Missing on both sides — needs fresh grab |

**Macross 7** — "The Galaxy Is Calling Me!" and **The Super Dimension Fortress Macross: Flash Back 2012** — both copied into Radarr 2026-08-18 (same batch as the two Macross Frontier movies above). All 4 movies from [[project_sonarr_radarr_movie_migration]] are now done.

## Needs manual check — RESOLVED 2026-08-20

Previously flagged as unreliable fuzzy matches. All four resolved by pulling exact Sonarr special IDs + Radarr entries directly (no more fuzzy matching needed):

- **JUJUTSU KAISEN** — confirmed genuinely two different movies, not a duplicate pair. "Jujutsu Kaisen 0" (Sonarr ep 1848) is covered by Radarr id 85 (`hasFile:true`) — **unmonitored** in Sonarr. "Hidden Inventory / Premature Death - The Movie" (Sonarr ep 1852) is covered by Radarr id 153 (`hasFile:true`) — **unmonitored** in Sonarr. "JUJUTSU KAISEN: Execution" (Sonarr ep 1851) is genuinely missing on both sides (Radarr id 2) — search triggered, **zero indexer results**, still open.
- **Mobile Suit Gundam Wing** "Endless Waltz: The Movie" (Sonarr ep 1192) — no Radarr entry at all (not a real match to junk "Gundam (0)"). Search triggered in Sonarr directly, **zero indexer results**, still open. Needs a Radarr entry added if pursuing a copy-in later, or keep chasing via Sonarr.
- **Mobile Suit Gundam 0083: Stardust Memory** "Afterglow of Zeon" (Sonarr ep 5445) — same as above, no real Radarr match. Search triggered in Sonarr, **zero indexer results**, still open.
- **"Gundam (0)" Radarr entry (id 11)** — confirmed junk: TMDB id 534083 resolves to a nonsense placeholder (year 0, generic "rival mech pilots" overview). Not a real film, not a match for anything. Flagged for user to delete manually (not deleted automatically).
- **Macross Delta / Macross Plus** — "Movie Edition" (Macross Plus special) confirmed already resolved as a duplicate of "Macross Plus: The Movie" (see Resolved-via-web-research section below). Macross Delta's own two specials — "Passionate Walkure" (Sonarr ep 3038) and "Absolute Live!!!!!!" (Sonarr ep 3041) — have their own correct Radarr entries (ids 54, 63, both `hasFile:false`) — genuinely missing on both sides, not duplicates of the Plus movie. Search triggered on both Radarr ids, **zero indexer results**, still open.
- **Attack on Titan** — of the 7 movie-length specials, only 2 have Radarr entries: "Part I: Crimson Bow and Arrow" (Radarr id 138) and "Part III: The Roar of Awakening" (Radarr id 140). Search triggered 2026-08-20 — **both grabbed** (German BluRay releases via `MARTYRS`, downloading as of this writing). "Part II: Wings of Freedom" (Sonarr ep 2012) has no Radarr entry — search triggered in Sonarr directly, zero results, still open. The remaining specials (live-action films, Chronicle, THE LAST ATTACK, No Regrets OVA, Final Season SPECIAL EVENT, Chibi Theatre/4-Koma shorts, Special Omnibus recap episodes) are out of scope — not yet individually researched, likely a mix of recap/bonus content per the pattern established elsewhere in this doc.

## Resolved via web research (title didn't match anything in Sonarr/Radarr/TMDB)

Sometimes a Sonarr special's title is a genuinely different historical release name for content Radarr already has under its "real"/modern title — TMDB lookup returns nothing because it was never catalogued separately. When Radarr/TMDB search comes back empty, don't assume "no separate content exists" or "must be missing" — look it up. Confirmed case:

- **Macross (series 70) "Clash of the Bionoids"** (episode id 3082) — this is the 1980s-90s US theatrical/video re-edit of "Do You Remember Love?" (Radarr already has, `hasFile: true`) with ~20-40 minutes cut for content (gore/nudity). Not a distinct film — same underlying movie, different historical dub/cut name. No TMDB entry exists under "Clash of the Bionoids" at all. **Unmonitored** 2026-08-15, same treatment as the "Do You Remember Love" duplicate itself.
- **Macross Plus (series 73) "Macross Plus: Movie Edition"** (episode id 3104, 115min) — confirmed via Radarr/TMDB lookup (not web search) to be the exact same film as "Macross Plus: The Movie (1995)" (TMDB id 18837, Radarr already has, `hasFile: true`) — just catalogued under a different title. **Unmonitored** 2026-08-15.

## VOTOMS — repass findings (2026-08-18)

Full repass of all Season 0 specials requested by user to verify nothing was incorrectly unmonitored and movie coverage is accurate. Found one real miss:

- **"The Grey Witch, Part One"** (episode id 3897) was unmonitored in Sonarr under the assumption it was covered by Radarr — it wasn't. Radarr entry "Die Graue Hexe - Part 1" (id 127) also has `hasFile: false`. **Re-monitored in Sonarr 2026-08-18.** Checked Radarr release search: zero indexer results anywhere. TMDB confirms why — release year is **2026**, i.e. this is a brand-new release, not yet available on any indexer. Not a dead-end, just too new; revisit later. No "Part 2" exists in TMDB or Sonarr's episode list yet either.
- All other unmonitored Season 0 specials verified correct: "The Last Red Shoulder", "The Big Battle", "Red Shoulder Document", "Pailsen Files the Movie", "Case;Irvine", "Votoms Finder" all confirmed `hasFile: true` in their matching Radarr entries.
- "Chirico's Return" (Sonarr title) confirmed to be the same film as Radarr's "Alone Again" (2011 OVA, both titles used interchangeably per [IMDb](https://www.imdb.com/title/tt8965474/)/[Blu-ray.com](https://www.blu-ray.com/movies/Armored-Trooper-Votoms-Chiricos-Return-Blu-ray/291178/)) — correctly matched, `hasFile: true`.
- Numbered TV season: 0 monitored gaps — fully complete.

## VOTOMS — recap specials confirmed not real gaps (2026-08-18)

| Series | Special | Runtime | What it actually is |
|---|---|---|---|
| Armored Trooper VOTOMS (97) | Stage I: Woodo City | 25min (Sonarr; actual ~55min) | 1985-86 compilation OVA — condensed recap of the already-owned 52-episode TV series, covering the Woodo City arc. Not new content. |
| Armored Trooper VOTOMS (97) | Stage II: Kummen Jungle Wars | 25min (Sonarr; actual ~56min) | Same compilation series, Kummen Jungle Wars arc recap. |
| Armored Trooper VOTOMS (97) | Stage III: Deadworld Sunsa | 25min | Same compilation series, Deadworld Sunsa arc recap. |
| Armored Trooper VOTOMS (97) | Stage IV: God Planet Quaint | 25min | Same compilation series, God Planet Quaint arc recap. |

Matches the "recap/alternate-cut specials" structural pattern (see intro) — same underlying story already owned via the numbered TV season. Left monitored but deprioritized, same treatment as the Macross niche specials below. Source: publisher listings (Sunrise official work pages) confirm ~55min/episode runtime and recap nature.

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
| Macross Zero (71) | Macross 25th Anniversary Special Air Show Macross Zero version | 30min (Sonarr metadata; actual runtime ~2min) | "ALL THAT Variable Fighter" — a 2008 web-exclusive CG promo short unlocked via a code bundled with first-press Blu-ray volume 1. VF-0 air-show demo set to a Yoko Kanno orchestral track, no story content. Not indexed anywhere (checked Sonarr/Prowlarr release search — zero results, not even mismatched). | [AniList](https://anilist.co/anime/5164/ALL-THAT-VF-Macross-25th-Anniversary-Air-Show--VerZERO), [gubabablog rewatch](https://gubabablog.wordpress.com/2016/05/22/the-great-macross-rewatch-25th-anniversary-special/) |
| Macross Frontier (68) | Macross 25th Anniversary Special Air Show | 25min (Sonarr metadata; actual ~2min per the Zero-version precedent) | Frontier's counterpart to the Macross Zero Air Show promo above — same 2008 25th-anniversary web-exclusive CG short campaign, Frontier-side VF-25 demo. Same non-story bonus content, same expected zero-indexer-coverage pattern. | (inferred from the Zero-version precedent; not independently re-verified) |
| Macross Frontier (68) | Macross Frontier Music Clip Collection - Nyan Kuri | 38min | Music video compilation bonus disc, not story content — same pattern as the other franchise "clip collection"/"mech graffiti" bonus discs already documented. | (inferred from pattern; not independently verified) |
| Macross Frontier (68) | Macross Fufonfia 1-20 + Specials 1-3 (23 episodes total, ids 2976-2995, 2997-2999) | 2-4min each | **Macross Fufonfia** — a real 2008 ONA web-short series (Satelight, aired on MBS) placing the Frontier cast as comedy office-AU employees at a fictional software company. Non-canon spinoff comedy, not part of Frontier's actual story. Confirmed via [AniList](https://anilist.co/anime/4939/Macross-fufonfia) and [Anime News Network](https://www.animenewsnetwork.com/encyclopedia/anime.php?id=11484). **Unmonitored 2026-08-18** — 23 individual 2-4min shorts, not worth chasing one-by-one. |

## Not movies — confirmed short-form content (excluded from action)

Runtime ≥60min but confirmed to be behind-the-scenes/panel/OVA-short content, not theatrical/OVA movies: **The Mighty Nein** (all entries are "Inside the Mighty Nein" behind-the-scenes panels), **Black Butler** "Book of Murder Part 1/2" (60min OVA episodes, not a movie — but see "Book of the Atlantic" below, which *is* a real movie), **Initial D** "Legend 1/2/3" (recap/compilation OVAs, not new content), **Andor** ("Rogue One" Season 0 entry — it's the parent film for the show, not a gap to chase separately), **Is It Wrong to Pick Up Girls in a Dungeon?** — not audited this pass (title didn't match the search pattern used, revisit separately).

## Previously "not audited in depth" — resolved 2026-08-20

Full runtime≥60 pull done for Mighty Nein, Fallout, Black Butler, Overlord, Initial D, Monogatari, Farscape, JoJo's Bizarre Adventure, Robotech, Full Metal Panic!, Made in Abyss, Battlestar Galactica (2003), Bleach. Result: **zero of these ~30 movie-length specials had any pre-existing Radarr entry** — this franchise cluster had never been cross-referenced before.

**Added to Radarr + search triggered (18 new entries, ids 162-179), all `monitored:true`, `searchForMovie:true` on add:**

| Franchise | Movies added | Result so far |
|---|---|---|
| Overlord | The Sacred Kingdom (162), The Undead King (163), The Dark Hero (164) | **All 3 grabbed** (RUDY BD Remux / [Moxie] BD Remux) |
| Made in Abyss | Dawn of the Deep Soul (165), Journey's Dawn (166), Wandering Twilight (167) | **All 3 grabbed** ([eldon]/[PL3X] BD releases) |
| Bleach | Memories of Nobody (168), The DiamondDust Rebellion (169), Fade to Black (170), Hell Verse (171) | 3 of 4 grabbed ([nekotan] BD). **169 (DiamondDust Rebellion) had a bad match** — Radarr grabbed "The Rebel (1961)" (unrelated French film, matched on the word "Rebel"/"Rebellion") — caught, removed from queue + blocklisted before completion, movie still open/monitored, needs a manual re-check |
| Black Butler | Book of the Atlantic (172) | **Grabbed** (German BluRay, ANiMEHD) |
| Robotech | The Movie (173), II: The Sentinels (174), The Shadow Chronicles (175), Love Live Alive (176), Codename: Robotech (177) | No match yet, left monitored in Radarr. Sonarr side (eps 3108-3112) was still monitored — **unmonitored 2026-08-20** so Sonarr stops duplicating the search |
| Battlestar Galactica (2003) | The Plan (178), Blood & Chrome (179) | **Wrong quality profile caught 2026-08-20**: added with profile 14 (Anime) copied from the batch template — BSG is live-action Western sci-fi, should be profile 13 (Standard). Fixed, re-searched under correct profile, no match yet |
| Monogatari (Kizumonogatari trilogy) | Part 1: Tekketsu (180), Part 2: Nekketsu (181), Part 3: Reiketsu (182) | No match yet, left monitored |

**Sonarr-side monitoring check (2026-08-20):** verified all 21 corresponding Sonarr specials — only the 5 Robotech ones were still monitored (now fixed, above). Overlord, Made in Abyss, Bleach, Black Butler, Battlestar Galactica, and Kizumonogatari specials were already `monitored:false` in Sonarr (Season 0 defaults), so no action was needed there.

**Bad-match incident:** always spot-check grabbed release titles against the intended movie after any batch add+search — Radarr's title matching can seize on a generic word (here "Rebel"/"Rebellion") and grab something totally unrelated. Caught this time via a full title sanity pass across the queue after grabs settled.

**Deliberately not added — recap/alternate-cut, not new content (same pattern as VOTOMS Stage I-IV):**
- **JoJo's Bizarre Adventure** "Re-Edited Part 1/2/3" (Sonarr eps 2731-2733) — title says "Re-Edited," these are compilation re-cuts of the TV series, not standalone films.
- **Full Metal Panic!** "Director's Cut Part 1/2/3" (Sonarr eps 4395-4397, titled "Boy Meets Girl"/"One Night Stand"/"Into the Blue") — same pattern, extended-cut versions of existing TV episodes, not separate movies.
- **Monogatari** "Kizumonogatari I/II/III" (Sonarr eps 1737/1754/1755) — these ARE real theatrical films (not recaps), but not added this pass — **needs follow-up**, they were missed in the batch-add above.
- **Initial D** "Battle Stage 2/3", "Project D to the Next Stage" (Sonarr, `hasFile:true` already) — real theatrical films but already owned as Sonarr files; not a gap, no Radarr action needed unless de-duplication is wanted later.

**Ambiguous, needs a judgment call before adding:**
- **Fallout** "A Special LIVE Report from Galaxy News" (Sonarr ep 899, 60min) — likely an in-universe faux-newscast bonus feature bundled with the show, not a real standalone film. Not researched further; not added.
- **Battlestar Galactica** "The Miniseries" Part 1/2 (Sonarr eps 4591/4592) — the show's pilot TV movie; arguably part of the series itself rather than a separate film. Not added — flag for user to decide whether it belongs in Radarr.

**Kizumonogatari trilogy (Monogatari)** — added same session, ids 180-182 (Part 1: Tekketsu, Part 2: Nekketsu, Part 3: Reiketsu), `searchForMovie:true` on add.

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

**The reverse direction (2026-08-20): a Sonarr Season 0 special can also duplicate a whole separate standalone series**, not just a season-within-a-series. Same underlying root cause (TVDB tracks the same real-world content in more than one place), opposite shape: instead of "series B is really a season of series A," it's "this special under series A is really the same content as all of series B." Confirmed case: `.hack` (55)'s Season 0 special "Let's Meet Offline" (id 2393) is the exact same film as `.hack//Legend of the Twilight` (146)'s own Season 0 "Offline Meeting Special" — both are ".hack//Legend of the Twilight: Let's Meet Offline (2003)" per [TMDB](https://themoviedb.org/movie/364369-hack-legend-of-the-twilight-offline-meeting-special), which also has a matching Radarr entry (id 40). All three copies are missing, so no unmonitor-as-duplicate action was needed here, but it means don't chase the same content three times once one copy lands.

**Bigger finding from the same check**: `.hack//Roots` (145) and `.hack//Legend of the Twilight` (146) exist as full standalone Sonarr series (added by the user 2026-08-20, prompted by spotting this exact pattern) and were **completely missing — 0/27 and 0/13 episodes, never surfaced in any prior gap list** because they didn't exist in Sonarr until now. Season searches triggered for both — **zero results on both**, no releases found on any indexer. Given how often searches this session came back completely empty (Robotech S2/S3, Zoids S1, these two), see `ai/todo.md` #94 — worth rechecking these once Prowlarr's indexer sync-category scoping is reviewed, since 100%-empty results this consistently is suspicious of a scoping problem rather than genuine unavailability across every indexer.

**How to find more of this direction**: for any franchise with a parent series that has Season 0 specials, check whether a same-named-or-clearly-related standalone series also exists in Sonarr (or should exist, per franchise research) — the `.hack` franchise alone has 3 separate Sonarr entries (`.hack`, `.hack//Roots`, `.hack//Legend of the Twilight`) that could easily have looked like "just Season 0 bonus content" under the main series if the standalone entries hadn't existed. Not yet swept across the rest of the library — worth a dedicated pass grouping series by franchise stem and checking whether any Season 0 special title matches another existing (or plausible-but-missing) standalone series.

## Recap/alternate-cut specials (different title, same underlying content as a numbered-season episode)

Distinct from the duplicate-series case above — these are *individual* specials whose title differs from the season episode they overlap with (so exact-title matching won't catch them), typically theatrical "Stage"/compilation releases of TV episodes repackaged under new names.

**Confirmed**: Armored Trooper VOTOMS (series 97) Season 0 has four "Stage I-IV" specials, each 25 minutes (TV-episode length, not movie length — these were excluded from the movie audit above for exactly that reason):
- "Stage I: Woodo City" — shares "Woodo" with Season 4 episode "Woodo" (Phantom Chapter arc)
- "Stage II: Kummen Jungle Wars" — shares "Kummen" with Season 4 episode "Kummen"
- "Stage III: Deadworld Sunsa" — shares "Sunsa" with Season 1 episode "Planet Sunsa"
- "Stage IV: God Planet Quaint" — not yet matched to a specific season episode, same pattern likely applies

These are very likely alternate/theatrical titles for content already owned via the numbered seasons, not real gaps — treat as low-priority even though Sonarr shows them as monitored-and-missing. **Not fully verified** (word-overlap only, not confirmed by watching/checking runtime-exact overlap) — worth a final confirmation pass before unmonitoring, but strong enough evidence to deprioritize searching for them.

**How to find more**: for each series with Season 0 content, compare Season 0 episode titles against numbered-season episode titles for significant shared words (not exact match) — the query used in the movie audit's regeneration section pulls the raw data; do the word-overlap comparison per-series rather than exact-string match, which found zero hits library-wide when tried 2026-08-15.

## Numbered-season gap diagnosis (2026-08-20) — closing the loop on the movie-audit-only series

The movie/specials audit above never checked actual numbered-season gaps for most series — only Season 0. Ran that check now for every series still showing a monitored gap:

**Closed — zero numbered-season gaps, entire "gap" was Season 0 specials already resolved:** Attack on Titan, Gundam Wing, Gundam 0083, .hack, Macross 7, Macross Frontier, Macross, Macross Zero, Macross Plus, Tekkaman Blade, Gurren Lagann. 11 series fully closed out.

**Real numbered-season gaps found and searched:**
- **Gasaraki** (96) — 1 episode (S1E12 "Unravel", id 3795). This is the previously-confirmed dead magnet from the 2026-08-18 session (0 bytes, stalled) — re-searched again, still zero results.
- **The Big O** (106) — 2 episodes (S1E12/13, ids 4043/4044). Searched, zero results so far.
- **Macross II** (72) — 1 episode (S1E6 "Sing Along", id 3098). Searched, zero results so far.
- **Robotech** (74) — 49 episodes, entire Season 2 (Southern Cross, 24 eps) + Season 3 (Mospeada, 25 eps). Ran `SeasonSearch` per season instead of 49 individual searches — both completed, **zero results**. Matches the known content-scarcity diagnosis from the 2026-08-07 session (SacReD/SceneNZB source doesn't have these seasons currently indexed) — not a new finding, confirms the prior one still holds.
- **Zoids: Chaotic Century** (112) — 29 episodes (S1E6-34, near-continuous block). `SeasonSearch` triggered, took several minutes and was still running as of last check — no result confirmed yet, needs a follow-up check next session.

**Confirmed blind spot (2026-08-20): the "closed, zero numbered-season gaps" series above were never checked for short (<60min) Season 0 specials either** — only movie-length (≥60min) specials were ever audited. User caught this on Gundam 0083 specifically ("Afterglow of Zeon" was checked, but "The Mayfly of Space 1/2" — 4min and 12min bonus OVA content, confirmed via [Gundam Wiki](https://gundam.fandom.com/wiki/Mobile_Suit_Gundam_0083:_Stardust_Memory_-_The_Mayfly_of_Space)/[IMDb](https://www.imdb.com/title/tt6460664/) to be real purchaser-bonus animated shorts, not junk — were not). Both now searched.

Ran the same short-special check across all 10 other "closed" series. Result:
- **Already correctly documented as bonus/non-core** (no new action needed): all of Macross (70)'s and Macross Frontier (68)/Macross Zero (71)/Macross Plus (73)'s short specials — these match the existing "Macross franchise — niche/bonus specials" table above, already researched and deprioritized.
- **Real gap, had a Radarr entry but zero file, never searched**: `.hack//G.U. Trilogy`, `.hack//G.U. Returner`, `.hack//Versus: The Thanatos Report`, `.hack//Legend of the Twilight: Let's Meet Offline` (ids 36/38/39/40), and all 5 Tekkaman Blade movies (`Missing Link`, `Twin Blood`, `The Prelude to a Long Battle`, `Burning Clock`, `Virgin Memory` — ids 68-72) — Sonarr's Season 0 runtime metadata for the Tekkaman Blade ones is wrong (shows 25min, same "bad metadata" pattern as VOTOMS Stage I-IV) which is likely why they were missed by any runtime filter. **Searched 2026-08-20**, result pending.
- **New, not yet triaged — needs research before acting**: Gundam Wing (29) "30th Anniversary Video" + "Introducing Gundam Wing from ZERO" (promo content, likely non-core); Macross 7 (67) "Let's Bomber" (2min, likely non-core).
- **Gurren Lagann "Parallel Works" — RESOLVED 2026-08-20, same pattern as `.hack//Roots`/`.hack//Legend of the Twilight` below**: confirmed via TVDB lookup that "Tengen Toppa Gurren Lagann: Parallel Works" is a real standalone anthology series (tvdbId 423104, 2 seasons), not bonus content. **Added to Sonarr as series id 147**, search triggered on add — zero results, 0/15 episodes, same pattern as the other zero-hit searches this session (see `ai/todo.md` #94). The 7 corresponding specials under the parent Gurren Lagann series (118) — Parallel Works 2-1 through 2-7 — unmonitored as duplicates of the new standalone entry. ("Yoko Goes To Gainax: Behind The Scenes Of Gurren Lagann", id 4471, is unrelated making-of content, left as-is.)
- **Not yet re-checked at all**: Attack on Titan, Gundam Wing, Gundam 0083 (now done), .hack (now fully done, see below), Macross 7/Frontier/Macross/Zero/Plus (done above), Tekkaman Blade (done above), Gurren Lagann (flagged above).

### .hack (series 55) — full Season 0 assessment (2026-08-20)

Full 28-item monitored+missing Season 0 list researched and resolved:

| Item(s) | Finding | Action |
|---|---|---|
| `.hack//GIFT` (2336) | Radarr already has it, `hasFile:true` | **Unmonitored** — duplicate |
| `.hack//Quantum` main episodes: "Walking Party" (2379), "Wired Prisoner" (2380), "The Worldend Pallbearer" (2381) | These ARE the 3 core .hack//Quantum episodes (confirmed via [IMDb](https://www.imdb.com/title/tt3954404/)) — Radarr's single `.hack//Quantum` entry (`hasFile:true`) is the compiled release covering all 3 | **Unmonitored** — duplicates, same pattern as VOTOMS Stage/Macross Dynamite |
| `.hack//G.U. Trilogy` (2382), `.hack//G.U. Returner` (2384), `.hack//Versus: The Thanatos Report` (2386), `Let's Meet Offline` (2393), `.hack//The Movie` (2385) | Real content, Radarr entries exist, `hasFile:false` | Searched (this session + earlier round) |
| "In the Case of Mai Minase" (2375), "In the Case of Yuki Aihara" (2376), "In the Case of Kyoko Tohno" (2377), "Trismegistus" (2378) | The 4 real episodes of **.hack//Liminality** OVA (confirmed via [.hack Wiki](https://dothack.fandom.com/wiki/In_the_Case_of_Mai_Minase), [.hack Wiki](https://dothack.fandom.com/wiki/Trismegistus)) — no Radarr equivalent needed, correctly modeled as Sonarr TV content (it's an anthology OVA series, not a single film) | **Genuine gap — searched 2026-08-20** |
| `.hack//G.U. Trilogy (Parody Mode)` (2383, 6min) | Confirmed bonus gag-reel feature bundled with the G.U. Trilogy game/movie release, not story content ([AniSearch](https://www.anisearch.com/anime/4664,hack-g-u-trilogy-parody-mode)) | Left monitored, deprioritized — bonus content |
| `.hack//Quantum: Go, Our Chim Chims!!` Parts 1-3 (2387-2389) | Confirmed DVD/Blu-ray bonus featurette shorts (chibi-style character banter), not story content, per web search | Left monitored, deprioritized — bonus content |
| `.hack//Quantum: Ogura Yui's YuiYui...` x3 (2390-2392) | Same DVD-bonus-extras pattern as Chim Chims (Ogura Yui = a voice actor doing character bits) — not independently confirmed with a source, but same category | Left monitored, deprioritized — bonus content |
| `Online Jack` 01-09 (2394-2396, 3944-3949, 2-4min each) | Confirmed to be a real distinct .hack franchise piece running parallel to G.U., but exact format/significance not pinned down by research | **Not resolved** — flagged for further research or explicit deprioritization decision, left monitored |

**Maison Ikkoku** (144, new series from this session) — first grab attempt (pack covering eps 1-6) stalled with zero torrent connections for ~2 hours, blocklisted and re-searched. Second attempt landed episodes 3-6 individually ([Pizza] BD 720p HEVC); episodes 1-2 not found this round, needs a follow-up search. Episodes 22-26 (later in S1) still uncovered, never searched this pass.

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
