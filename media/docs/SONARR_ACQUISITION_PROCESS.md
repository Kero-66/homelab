# Sonarr/Radarr Missing-Episode Acquisition Process

The reusable process for chasing any missing episode/special/movie gap. Franchise-specific findings, the consolidated gap index, and incident history live in `media/docs/SONARR_STRUCTURAL_AUDIT.md` — this file is process only. Read this before touching any item on that doc's gap list or `ai/todo.md`'s escape-hatch items.

For the actual API commands (release search, the manual-mapping override, queue/history checks), see `ai/PATTERNS.md`'s "Grab a specific release" and "'Unable to parse release'" sections — that's the canonical command reference, kept in sync with this process.

**For any manual import (stuck queue item, escape-hatch grab, folder scan) — always use `truenas/scripts/import_downloads.sh` (`--plan`/`--apply`/`--scan-folder`). Never hand-roll a `ManualImport` curl/jq command.** Confirmed failure twice in one session (2026-08-31): hand-rolled imports for both a Sonarr episode batch and a Radarr movie batch each had a real bug the script's hardened code avoids (wrong `quality.id` — pulled from the wrong endpoint's id-space — and missing `languages`/`indexerFlags`/`releaseGroup` fields), and both reported a false "success" message while the queue item silently never cleared. The script checks the queue afterward automatically; a hand-rolled command does not, so the failure is invisible unless someone thinks to check.

## STEP 0 — Is it actually missing? (rewritten 2026-09-18, was step 7)

**Run this before anything else, on every item, every time.** `hasFile: false` does NOT mean
"missing". On this setup maintainerr deletes watched content, so the *normal steady state* of a
library is full of episodes that are absent because they were watched — not because they were
never acquired. Chasing those re-downloads content deliberately thrown away.

This check used to be step 7, *after* step 6 ("search-and-grab"). That ordering is what produced
the Made in Abyss and Attack on Titan recap-movie grabs: the acquisition decision was made before
the "was this actually wanted?" question was asked. It is now step 0 and is a hard gate.

The old check ("files exist in `/mnt/Data/media/.recycle`") was also **broken**: `/mnt/Data/media`
is a legacy pre-migration path that no app has written to since the 2026-08-24 unified-dataset
migration (see `CLAUDE.md` — "never search or write there"). It could only ever return "nothing
found", which reads as "not a watched-and-cleaned item" — i.e. it silently failed open, toward
grabbing. Replaced with the authoritative checks below.

**These signals answer two DIFFERENT questions. Don't conflate them** (this exact mistake was made
and caught on 2026-09-18):
- *"Should I chase this **in Sonarr**?"* → `monitored` answers it, and only that. `monitored:false`
  = don't grab it here. It does **not** mean the content is unwanted, and it is **never** a reason
  not to add a Radarr entry — see the Standing rule below.
- *"Was this watched?"* → **only jellystat answers it.** `monitored:false` does **not** mean
  watched; it lumps together watched-and-cleaned, deliberately-skipped recaps, and content owned
  in Radarr instead.

Worked proof (Monogatari, 2026-09-18): 12 episodes were `monitored:false, hasFile:false`. Reading
that as "all watched and cleaned" was wrong — the owner had watched exactly **5**. The true split
was 5 watched, 4 never-wanted recaps (Episode 5.5, Summary I/II/III), and 3 that are the
Kizumonogatari films, tracked as Sonarr Season 0 specials but legitimately owned in Radarr
(structural flaw #1). One signal, three different causes.

**Signal 0 — jellystat, the authoritative watch record.** Jellyfin itself is NOT usable for this:
once maintainerr deletes the file, the item goes `LocationType: Virtual` and its `UserData` resets
to `played:false, playCount:0` — verified 2026-09-18, so play state does not survive deletion.
Jellystat keeps its own playback database and does survive.
```bash
JS=$(infisical secrets get JELLYSTAT_API_KEY --env dev --path /media --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null)
# auth header is x-api-token (NOT Authorization/Bearer, NOT x-api-key - both 401)
curl -s -H "x-api-token: $JS" "http://jellystat.home/api/getHistory?page=<N>" \
  | jq -r '.results[] | "\(.ActivityDateInserted[0:10]) | \(.UserName) | \(.SeriesName) | S\(.SeasonNumber)E\(.EpisodeNumber)"'
```
Paginated (`.pages` tells you how many; ~50 per page), so loop pages and filter by `SeriesName`.
A hit means watched — the absence is correct and must not be re-acquired. Note the real viewing
account is **kero66**; `/Users[0]` on this server is `Addz`, so never assume index 0.

**Signal 1 — `monitored` (fastest gate for "should I chase this").**
```bash
curl -sL "http://sonarr.home/api/v3/episode?seriesId=<ID>&apikey=$SONARR_KEY" \
  | jq -r '.[] | "S\(.seasonNumber)E\(.episodeNumber) hasFile=\(.hasFile) monitored=\(.monitored) id=\(.id)"'
```
- `hasFile:false, monitored:false` → **Do not grab it in Sonarr.** A decision was already taken
  that Sonarr's specials lane isn't where this lives. It does *not* tell you *why* (see the three
  causes above), does *not* mean the content is unwanted, and does *not* block adding it to Radarr
  or as its own series if that is the correct placement. If you need to know whether it was
  watched, use Signal 0. See the corrected Standing rule below.
- `hasFile:false, monitored:true` → continue to Signal 2.

**Signal 1b — has it even aired?** Check `airDate`/`hasAired` before treating a monitored gap as
real. Monogatari's single monitored+missing episode (S7E1 `WAZAMONOGATARI: Karen Ogre`) is simply
`unaired` — a future episode, not a gap. Same pattern as the Lord of Mysteries "TBA" Season 0 rows
in the audit index.

**Signal 2 — Sonarr history (authoritative; distinguishes "never had it" from "had it, removed it").**
```bash
curl -sL "http://sonarr.home/api/v3/history?episodeId=<EPISODE_ID>&apikey=$SONARR_KEY" \
  | jq -r '.records[]? | "\(.date[0:19]) | \(.eventType) | \(.data.reason // "-")"'
```
- Contains `episodeFileDeleted` with reason **`Manual`** → the file was acquired and later removed
  deliberately. **That is maintainerr's fingerprint** (it deletes through the API, which Sonarr
  records as `Manual`). NOT a gap.
- Contains `downloadFolderImported` at any point → we have had this file before, so it is **not a
  never-acquired gap**. It does *not* prove it was watched (that is Signal 0's job — a file can also
  be removed by a failed upgrade, a quality purge, or manual cleanup). Either way, re-grabbing
  something we deliberately removed needs a reason beyond `hasFile:false`.
- Reason `Upgrade` is just a quality replacement, and `MissingFromDisk` is Sonarr noticing a file
  vanished — neither means "wanted again".
- **No import history at all** → genuinely never acquired. This is a real gap; proceed.

Worked example (verified 2026-09-18) — `.hack` S1E1-E8 read as an obvious "gap": eight consecutive
missing episodes at the very start of a series. Signal 1 shows all eight `monitored:false` while
E9+ are `monitored:true, hasFile:true`. Signal 2 on E1 shows
`2026-09-15 episodeFileDeleted | Manual`, preceded by successful imports back in March. Conclusion:
watched and cleaned up, exactly as intended — nothing to chase. A season that *starts partway in*
is the classic shape of this.

**Corollary for playlists:** the watch-order playlists are built from what exists, so they
naturally shrink to "what's left to watch". A shrinking playlist is the system working — see
`truenas/stacks/watch-orders-runner/scripts/README.md`.

## Standing rule (CORRECTED 2026-09-18): unmonitored is the RESULT of a placement decision, not a verdict on the content

**`monitored:false` on a Sonarr Season 0 special means "do not grab this *in Sonarr*". That is all it means.** It is the *record of a decision already taken*, not evidence the underlying content is unwanted.

The normal lifecycle is:
1. The placement decision gets made (see "What the structural audit is actually FOR") — does this belong in Radarr, as its own Sonarr series, or genuinely as a special?
2. If the answer is Radarr or a separate series, **the Sonarr special is unmonitored** — because Sonarr's specials lane is not where it lives.
3. From then on, `monitored:false` simply stops Sonarr grabbing it. Nothing more is implied.

So **very often a special is unmonitored precisely BECAUSE Radarr owns it.** Kizumonogatari is exactly this: three unmonitored Sonarr S0 entries, three fully-owned Radarr films. Correct in every respect.

**What this section used to say, and why it was wrong.** The earlier version read: *"that is a hard 'not wanted' signal for the underlying content in any app… before adding a Radarr entry, check that counterpart's monitored status first and treat false as a stop, not something to route around."* That is backwards, and following it breaks the audit: it would forbid adding the Radarr entry, which is the *intended outcome* of a "belongs in Radarr" verdict. It also contradicts the placement framework above and the `feedback_movie_specials_solve_in_radarr_first` rule, which says to solve movie content in Radarr first.

**How to actually use the flag:**
- **Don't grab it in Sonarr.** (The one thing it reliably tells you.)
- **Never treat it as a blocker on creating a Radarr entry or a separate series entry.** That's the placement decision doing its job.
- **To learn whether the content is wanted at all, find out *why* it's unmonitored** — is there a Radarr entry or standalone series covering it (placement done)? Was the file watched and cleaned up (Signal 0)? Or was it assessed as genuinely unwanted? Three different causes, same flag — see STEP 0.

**Re-framing the 2026-08-20 batch-add session** (Overlord, Made in Abyss, Bleach, Black Butler, Battlestar Galactica, Kizumonogatari — see `SONARR_STRUCTURAL_AUDIT.md`'s "2026-08-20 batch violations"). The real failure there was **grabbing without doing the placement assessment at all** — not "routing around an unmonitored flag". Several of those Radarr adds were the correct destination; what was missing was the deliberate decision, the research behind it, and the record of it. Adding a Radarr entry for an unmonitored Sonarr special is only a mistake when nobody established that Radarr is where the content belongs.

## What the structural audit is actually FOR (clarified 2026-09-18)

**It is a placement decision, not a gap hunt.** This was misread during the 2026-09-18 session —
the audit was treated as "find missing content and acquire it", which is backwards and is how
content gets acquired into the wrong lane (or twice).

Sonarr and Radarr are both acquisition tools, but TVDB dumps a great deal into **Season 0 /
specials**: theatrical films, sequel series, OVAs, recaps, live-action adaptations, promo shorts.
So for every Season 0 item the real question is:

> **Where should this content live — a Radarr movie, its own Sonarr series, or genuinely a special
> under this parent series?**

Exactly **one** system should own each piece of content. Everything else follows from that:

| Verdict | When | Action |
|---|---|---|
| **Radarr movie** | It's a standalone/theatrical film with its own TMDB movie entry (Kizumonogatari I/II/III, the `.hack` films) | Add to Radarr; **unmonitor the Sonarr S0 entry** so it stops reading as a gap |
| **Separate Sonarr series** | It's really its own series that TVDB filed under the parent's specials (or a standalone entry duplicating a parent's season — `.hack//Liminality`) | Track as its own series; unmonitor the duplicate side |
| **Stays a special** | Genuine OVA/short/bonus tied to the parent, no separate movie/series identity | Leave in Season 0, monitored only if actually wanted |

**The three failure modes this prevents:**
1. **Both systems own it** → the same file stored twice. Real waste, not cosmetic — see step 6b.
2. **Neither owns it** → *orphaned* content: files on disk that no app manages, so they can never
   be upgraded, replaced, or tracked, while the Sonarr S0 row reads as a permanent gap.
3. **Wrong lane monitored** → Sonarr tries to acquire a *film* as a TV special. Title parsing
   rarely matches, so it either never resolves or grabs something wrong.

**Worked example — Attack on Titan (found 2026-09-18, unresolved).** All three states at once:
- Two films exist on disk and in Jellyfin —
  `/data/movies/Attack on Titan Crimson Bow and Arrow (2014) [tmdbid-379088]/` and
  `.../The Roar of Awakening (2018) [tmdbid-492999]/`
- **Radarr tracks neither** → failure mode 2, orphaned.
- Sonarr lists them as S0E14 / S0E21, `hasFile:false` — so they look like gaps forever even though
  the files are right there.
- S0E50 `Attack on Titan: THE LAST ATTACK` is `monitored:true` → failure mode 3: Sonarr is set to
  chase a 2024 compilation *film* as a TV special.

The placement verdict for AOT's films is "Radarr movie" (they have TMDB ids already, visible in the
folder names). Until that's actioned, they stay orphaned. Note Crimson Bow and Arrow and Roar of
Awakening are **recap compilations** of S1 and S2 respectively, so the placement verdict and the
"do we even want it" verdict are separate questions — decide placement first, then whether to keep.

## Original three structural flaws

**How this relates to the section above:** the placement table answers *"where should this live?"*; this list is the catalogue of *specific patterns* that signal the answer. Flaw 1 → "Radarr movie". Flaw 2 → "separate Sonarr series". Flaw 3 → usually "stays a special", but only after deciding whether we actually prefer that cut. Same decision, different level of detail.

Three related design flaws found in the Sonarr library, all stemming from the same root cause: TVDB/scene metadata sometimes represents a single piece of real-world content in more than one place in Sonarr's data model.

1. **Specials that are actually movies** — belong in Radarr, not as a Sonarr TV special. See `SONARR_STRUCTURAL_AUDIT.md`'s "Movie audit" section.
2. **Whole series/seasons that duplicate another series** — the same content tracked twice under two different Sonarr series entries (or a season within one series duplicating an entire separate series), **in either direction**: a standalone series can be really a season of a parent series, OR (confirmed 2026-08-31, `.hack//Liminality`) a parent series' Season 0 special can duplicate a whole separate standalone series entry that exists at the same time. Before working any Season 0 item, check Sonarr's series list for a standalone entry matching that special's title/franchise stem, not just after the fact. See `SONARR_STRUCTURAL_AUDIT.md`'s "Duplicate series" section.
3. **Specials that are recap/alternate-cut versions of content already owned in a numbered season** — different title, same underlying story. **These are a "which version do we want to watch?" decision, NOT automatically junk.** See `SONARR_STRUCTURAL_AUDIT.md`'s "Recap/alternate-cut specials" section.

   **Corrected 2026-09-18** — this entry previously read "so not real gaps even though `hasFile:false`", i.e. recap ⇒ discard. That is wrong, and following it produces bad calls in both directions:
   - Sometimes the compilation IS the preferred way to watch. **Gundam's original-series movie trilogy (I / II / III) is exactly this** — `gundam_uc.json` deliberately uses the three films *instead of* the 43-episode 1979 TV series, because that is the community-preferred viewing route. A blanket "recaps aren't real gaps" rule would have thrown away the version we actually want.
   - Sometimes it genuinely is redundant — Made in Abyss's *Journey's Dawn* and *Wandering Twilight* are straight recaps of S1 eps 1-8 and 9-13, and were deleted 2026-09-18 as content that should never have been acquired. Note its third film, *Dawn of the Deep Soul*, is a **sequel with new content** and was kept — "it's one of the movies" is not the test.

   So: identify that something is a recap/alternate cut, then **assess whether we prefer it over the series content**. Record the decision and the reason. Never auto-drop on the recap label alone.

Older shows in particular often ship their movie/OVA content bundled inside the same download pack as the TV episodes (see the VOTOMS and Macross Dynamite 7 precedents) — when hunting for a missing Radarr movie from an older franchise, check whether a TV batch pack for the parent series already contains it before searching separately.

## Per-series workflow (repeat this for each series in the gap list)

Developed and validated on the Macross cluster (series 70, 73) 2026-08-15. Follow in order — each step is cheap and can resolve the gap without needing the next step:

**1. Pull the full picture for the series** — don't just look at the aggregate gap count, get per-season breakdown plus every monitored-missing episode's title/runtime:
```bash
curl -sL "http://sonarr.home/api/v3/series/<ID>?apikey=$SONARR_KEY" | jq '{title, seasons: [.seasons[]|{seasonNumber,monitored,statistics}]}'
curl -sL "http://sonarr.home/api/v3/episode?seriesId=<ID>&apikey=$SONARR_KEY" | jq '.[] | select(.monitored==true and .hasFile==false) | {seasonNumber, episodeNumber, title, id, runtime}'
```
Numbered seasons (1+) are usually where the real, worth-chasing gaps are. Season 0 (specials) is where all three structural-flaw patterns above hide — triage those separately from real gaps.

**Critical: "Season 0 = specials" is not the same as "Season 0 = movies."** Every monitored+missing Season 0 item needs to go through this workflow, not just the ones ≥60min. Runtime is neither a classifier nor a filter (see 2c below, which retires that inference) — a 4-minute purchaser-bonus OVA short is just as real a gap as a 90-minute film, and gets missed entirely if you only ever query `runtime>=60`. (Confirmed miss 2026-08-20: Gundam 0083's "The Mayfly of Space 1/2" bonus shorts, 4min/12min, were skipped this way across an entire audit pass.)

**2. `monitored` — already covered by STEP 0, Signal 1.** Kept here as a pointer so the numbering below still reads: an unmonitored Season 0 special means **"don't grab it in Sonarr"**, nothing more — it is the recorded output of a placement decision, not a verdict that the content is unwanted, and not a blocker on a Radarr entry (see the corrected Standing rule above). Separately, "no Radarr entry exists" is not on its own a justification to add one — make the placement decision, with research, first. If you have not run STEP 0 yet, stop and run it — it is the gate, not this step.

**2a. A doc row marked ✅/resolved/deprioritized is a claim, not proof — re-pull live `hasFile`/`monitored` before trusting or acting on it.** Confirmed failure (2026-08-31, `.hack` Season 0): a prior session's "✅ Full Season 0 assessed" row claimed 4 items were "imported this session" and several others were "deprioritized" — live Sonarr showed every one of those specific items still `hasFile:false`/`monitored:true`. The doc is a cache of this process's output, not the process itself; a cache can go stale silently (a session records the intended outcome without the API call actually landing, or without ever verifying it did). Whenever a doc claim is about to be relied on — cited to the user, used to skip a step, or treated as settled — re-check the live episode/movie state for those specific items first, don't propagate the claim forward unverified.

**2b. Never classify Season 0 content as bonus/non-story from runtime or title pattern alone — check Radarr/TMDB AND actually research what it is, every time.** Runtime (step 2c below) is a triage *signal* for which pattern you're probably looking at, not a substitute for verification. Confirmed failure (2026-08-31): almost wrote off `.hack`'s "Online Jack" (nine 2-4min Season 0 specials) as a bonus Blu-ray extra purely from its short runtime, before checking anything — it turned out to be real narrative content (an in-universe news-show tied directly into the .hack//G.U. game story). Conversely, don't skip the Radarr check either: several other short/long .hack specials that looked like open gaps already had real files sitting in Radarr under a different title (structural flaw #1) — the doc's own step 3 below covers this, but it's easy to skip when an item "feels" like bonus content and step 4's web-research check gets skipped along with it.

**2c. Runtime is NOT a way to judge what a piece of content is** (rewritten 2026-09-18 — owner's call: "length isn't a good enough judgement to determine what an episode is". Also renumbered: this and 2b were *both* labelled "2b", and 2b's "step 2b below" pointer was self-referential.)

The old version of this step said `≥60min → probably a movie` and `<60min → probably NOT core story content`. **That inference is retired.** It was wrong often enough to cause real misses, and the doc's own incident log proves it twice over:
- `.hack`'s "Online Jack" — nine specials of 2-4 minutes each — is genuine narrative content (an in-universe news show tied into the .hack//G.U. game story), and was nearly written off on runtime alone.
- Gundam 0083's "The Mayfly of Space 1/2" bonus shorts (4min/12min) were skipped across an *entire* audit pass because the query filtered on `runtime>=60`.

Runtime is fine to **collect** (step 1 pulls it) as context, and a very long item is a reasonable prompt to check Radarr/TMDB *first* rather than last. But it never decides what something is, and it must never narrow the set of items you examine. Classification comes from step 2b: check Radarr/TMDB, then research what the content actually is. Every monitored+missing Season 0 item goes through that, regardless of length.

**3. For EVERY Season 0 item, check Radarr/TMDB directly — don't trust fuzzy title matching alone.** (Was "for movie-length specials" — corrected 2026-09-18 along with 2c, since gating this check on runtime is the same retired inference. `.hack` had short *and* long specials already sitting in Radarr under different titles, so length told you nothing about whether to look.)
```bash
grep -i "<keyword>" radarr_all.txt   # cached full Radarr list, see SONARR_STRUCTURAL_AUDIT.md "How to regenerate this data"
curl -sL -G "http://radarr.home/api/v3/movie/lookup" --data-urlencode "term=<exact special title>" --data-urlencode "apikey=$RADARR_KEY" | jq '.[] | {title, year, tmdbId}'
```
If TMDB lookup returns a match — even under a *different* title than the Sonarr special — that's usually the same film (see Macross Plus "Movie Edition" → "Macross Plus: The Movie" case). If Radarr already has the file (`hasFile: true`), the Sonarr special is a false gap: unmonitor it, don't search for it.

**4. If TMDB/Radarr comes back completely empty, don't assume "doesn't exist" or "definitely missing" — look it up online.** A title with zero TMDB hits is often a historical alternate release name for content that *does* exist under a different title (see "Clash of the Bionoids" case — a censored US re-edit of a film Radarr already had). Use `WebSearch` with the special's exact title plus the franchise name; if a specific promising source turns up (forum post, wiki, TVDB episode page), follow up with `WebFetch` on that URL directly rather than re-searching — note that **Reddit blocks WebFetch directly**, so for Reddit results, either rely on the WebSearch snippet or fetch an alternate source (Wikipedia, wiki, TheTVDB) that surfaces the same information instead.

**5. Document the finding immediately, in `SONARR_STRUCTURAL_AUDIT.md`, with the source link** — don't just act on it and move on. Every research result exists so nobody (including a future session) has to re-derive it. Use whichever table/section fits: Movie audit (if it's a Radarr-copy or Radarr-covered case), Duplicate series (if it's a whole-series/season duplicate), or a new franchise-specific "niche specials" table (if it's genuinely non-core bonus content).

**6. Only actively search-and-grab for content that survived STEP 0 and steps 2-4 as genuinely real, story-relevant, and missing.** Don't spend search effort on confirmed bonus/promotional material unless the user explicitly asks for it. "Survived STEP 0" means: not already watched (jellystat), still monitored, actually aired, and not owned in the other app.

**6a. Grabbing is a hard stop until STEP 0 and steps 2-4 are done and stated out loud — no exceptions for the escape hatch.** Confirmed failure mode (2026-08-24, Gurren Lagann Parallel Works): grabbed the first plausible-looking search result (checked LQ blacklist + size sanity only) before doing the "what is this content actually" research step, then had to cancel two in-progress downloads once research showed it was non-story bonus content (Gainax music-video shorts) that never should have been actively chased in the first place. The escape hatch has no Custom Format scoring net catching a bad call the way a normal Sonarr/Radarr grab does — the workflow steps *are* the only gate, so treat each one as a checkpoint to stop at, not background knowledge to apply loosely. Concretely, for every escape-hatch grab: **(a) list every candidate release, not just the top structured-search hit** (a later/lower-ranked result can match the actual series structure — e.g. season-split — better than the first one), **(b) state what the content actually is, sourced, before grabbing**, **(c) only then add it to the download client.** Don't let "it's not on the blacklist and the size looks plausible" substitute for "I confirmed what this actually is."

**6a-i. "Size looks plausible" needs an actual bitrate sanity check, not just non-zero.** Confirmed failure mode (2026-08-29, Steins;Gate "Egoistic Poriomania" re-grab): grabbed a 1-seeder torrent because it was the same release that had imported cleanly once before, without re-checking its live seed count (already at 1, dropped to 0, `stalledDL`) or its file size against runtime (a 25-min 720p BD episode landed complete at 66MB — implausibly low bitrate, almost certainly broken/mislabeled). A release having worked before says nothing about whether it still has active seeds now, and "not rejected by Sonarr/Radarr's scoring" isn't the same as "the file is real." Before grabbing: check live seeders (torrent) or that the size is in a sane range for the runtime/resolution claimed (either protocol) — reject anything wildly undersized even if unrejected.

**6a-ii. NZB/usenet is the default protocol pick over torrent unless the torrent scores meaningfully higher.** Check Sonarr/Radarr's own `/release` cache first (`GET /api/v3/release?episodeId=`/`?movieId=`) — it returns both `customFormatScore` and `protocol` per candidate, so the comparison uses real numbers. Only fall through to a raw Prowlarr free-text search (`/api/v1/search`) when the app's own search finds nothing usable — that path has no score at all, just title/seeders/size, and both protocols get judged blind. In either case, group candidates by `protocol` and default to NZB (no seed-count risk, see 6a-i) unless the best torrent option is a genuinely better release (verified quality/format, not just top-of-list).

**6a-iii. For the manual-mapping override (`shouldOverride`), a release's own rejection text describes the title-parse, not its file contents — and the override's `episodeIds` must be checked against `hasFile`, not assumed from the pack's implied range.** Confirmed failure mode (2026-08-29, Gundam 0083 "Mayfly of Space"): a 1300-`customFormatScore` release was dismissed as irrelevant because its own rejection said `"Wrong season"`/`"Episode wasn't requested: 1x1-13"` — but that only describes Sonarr's *automated* season-1 title-parse. The actual torrent (checked via the client's file tree, not Sonarr/Prowlarr API JSON, which never exposes per-file contents) bundled the two genuinely-missing Season 0 specials in a subfolder alongside the full season. It was then re-grabbed and the override's `episodeIds` was set to the pack's full season range (13 episodes) without checking `hasFile` first — all 13 already had files, making that portion of the ~100GiB grab pure duplicate content, and the two actually-missing episodes weren't in `episodeIds` at all (so untracked by Sonarr's queue, needing Manual Import once downloaded). **Two checkpoints, every escape-hatch pack grab:** (a) before ruling a pack irrelevant OR accepting it as a match, check its real file list, not just the release title/rejection text; (b) before POSTing the override, run `GET /api/v3/episode/<id>` `hasFile` for every episode the pack's title/season implies, and set `episodeIds` to only the genuinely-missing ones (grab the whole pack for the bonus content if needed, but set already-owned files to "do not download" in the torrent client once downloading).

**6b. "Both sides own a file" is not harmless — it's wasted duplicate storage, and needs deduping, not just noting.** Confirmed failure mode (2026-08-24, Gurren Lagann + Blue Gender): the original doc recorded several movie/special duplicates as `covered, unmonitor optional` when both Sonarr and Radarr had `hasFile:true` — treating the redundant copy as low-priority cleanup rather than something to actually fix. A file genuinely stored twice on disk is real waste, not a cosmetic issue, especially given this repo's disk-crisis history (`ai/todo.md` #93). When a duplicate is confirmed (Radarr `hasFile:true` for the same content), **delete the Sonarr-side episode file and unmonitor it in the same pass** — don't just note it as optional for later.

**6c. Check `series.id`/`tvdbId` in a Manual Import scan result before trusting an empty rejections array, before overriding an auto-match.** An auto-match to a combined/multi-season series entry can be correct even when it looks surprising — verify what the target series actually represents before assuming a mismatch and overriding it (a 2026-08-24 misdiagnosis on this repo overrode a *correct* auto-match, treating normal multi-season combination as a bug; see `SONARR_STRUCTURAL_AUDIT.md`'s `.hack//Roots` entry for the full retraction).

**7. (moved to STEP 0 — see the top of this file.)** The maintainerr check used to live here, at
the bottom, *after* the grab step. That ordering is exactly what caused the Made in Abyss and
Attack on Titan recap-movie over-grabs, so it is now a hard gate at the start rather than a
footnote at the end. Its old heuristic (looking in `/mnt/Data/media/.recycle`) was additionally
pointing at a legacy path nothing writes to any more, so it always failed open toward grabbing.
Use Signals 1 and 2 in STEP 0 instead.
