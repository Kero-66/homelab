# Handoff — 2026-08-22 — Sonarr/Radarr gap-audit continuation, Manual Import backlog

**Repo**: `/Users/kieran/repos/homelab`
**Commits this session**: `68c0af6` through `a9157f7` (`git log --oneline 68c0af6^..a9157f7`) — six commits, see their messages for full detail, not duplicated here. All touch `media/docs/SONARR_STRUCTURAL_AUDIT.md` and `ai/todo.md`.

Note: `ai/handoff-2026-08-22.md` (no suffix) is a **different, unrelated session** from earlier today (observability stack trial evaluation) — don't confuse the two.

---

## Where this session actually landed

This picked up the 2026-08-20 handoff's Sonarr/Radarr gap-fixing work. **Read `media/docs/SONARR_STRUCTURAL_AUDIT.md` in full before continuing** — every finding below is already written there in detail; this doc is a pointer, not a duplicate.

### Full audit is now complete — every gap has been triaged
- Ruled out Prowlarr category/tag scoping as a cause of zero-result searches (checked at both the Applications and per-indexer Sonarr/Radarr layers — both clean).
- Discovered the **real** cause: Sonarr's structured `SeasonSearch`/`SeriesSearch` cannot match complete-series/season "batch" releases that lack `S0XE0X`-style naming (often in Japanese/Chinese). The documented **Prowlarr free-text escape hatch** (see `ai/PATTERNS.md`) finds these immediately. Confirmed across 7+ franchises this session — treat this as a proven pattern, not a one-off, for any future "zero results" gap.
- Ran a full-library sweep (109 Sonarr series, diffed `episodeFileCount`/`episodeCount`) — found two series never touched by any prior audit: **Broken Blade** (was wrongly modeled as a 12-episode show; it's actually 6 theatrical films — moved to Radarr) and **RWBY** (grabbed after catching a wrong-show match on the first query — "RWBY" alone matches an unrelated Japanese spinoff, "Ice Queendom").
- Ran a full-library Season 0 sweep (77 series with any Season 0 content, 92 monitored+missing items) — every series now individually triaged at least once. Found Monogatari's `Koyomimonogatari` (12 legit short stories, genuine gap, grabbed) and cleaned up 3 leftover duplicate Sonarr specials for already-owned Kizumonogatari Radarr movies.
- Two items closed per explicit user decision, not a search problem: Fallout "A Special LIVE Report from Galaxy News" and BSG "The Miniseries" — both already `monitored:false`, left as-is, not added to Radarr.

**Bottom line: nothing is un-investigated anymore.** What's NOT done is landing everything that was found — see the Manual Import backlog below.

### New standing rule adopted this session — apply going forward
Before treating any escape-hatch grab as resolved, check the release's group name against Sonarr's live `Anime LQ Groups`/`Anime Raws` Custom Formats (`GET /api/v3/customformat`, filter by name). This caught `Moozzi2` (Tekkaman Blade box) as blacklisted — kept anyway since no clean alternative had live seeders (user's explicit call: "if there are no other options, we just grab the best we can... don't just drop it"), but flagged in the doc for a future re-grab. Radarr's own automated scoring separately auto-rejected the one candidate release for Broken Blade (BR-DISK, no-release-group) — left genuinely open rather than force a bad grab there, since that one still has an automated path that might land something clean later.

---

## Manual Import backlog — the actual next task

**3 of 9+ grabs are done**: `.hack//G.U. Returner`, `.hack//Versus: The Thanatos Report`, `.hack//Legend of the Twilight: Let's Meet Offline` — imported via Radarr's Manual Import API, confirmed `hasFile:true`.

**Still downloading as of end of session** (check qBittorrent categories `tv-sonarr` / `radarr` for current progress — no login needed beyond the standard `QBITTORRENT_USER`/`QBITTORRENT_PASS` pattern, see below):
- Robotech (Sonarr 74) Season 2 Southern Cross + Season 3 Mospeada
- Zoids Chaotic Century (Sonarr 112)
- Maison Ikkoku (Sonarr 144) — only needed for eps 22-26, rest already owned, de-dupe on import
- `.hack//G.U. Trilogy` (Radarr 36)
- Tekkaman Blade TV+OVA BD-BOX (Radarr 68-71, possibly 72 — **not confirmed whether the box includes "Virgin Memory"**, check once extracted)
- RWBY Volume 1-6 (Sonarr 139, Season 1 only)
- Koyomimonogatari (Sonarr 42, Season 0)

**Import pattern** (same one used for the 3 already done — works for both Sonarr and Radarr, swap the base URL/API key):
```bash
# 1. Scan the download folder
curl -sL -G "http://radarr.home/api/v3/manualimport" \
  --data-urlencode "folder=/data/downloads/qbittorrent/completed" \
  --data-urlencode "filterExistingFiles=true" \
  --data-urlencode "apikey=$RADARR_KEY" | jq '.[] | {path, movie: .movie.title, rejections}'
# 2. For anything Radarr/Sonarr auto-matched (movie/series not null), stage the file object as-is.
#    For anything "Unknown Movie"/"Unknown Series", set .movieId (Radarr) or .seriesId+.episodeIds (Sonarr) manually before staging.
# 3. POST the staged files array
curl -sL -X POST "http://radarr.home/api/v3/command?apikey=$RADARR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"ManualImport","files":[...],"importMode":"move"}'
# 4. Verify: GET /api/v3/movie/<id> or /api/v3/episode/<id>, check hasFile:true
```
For Sonarr the endpoint is the same shape at `http://sonarr.home/api/v3/manualimport` — I did not use it this session (all completed downloads happened to be Radarr-side), so the exact field names for series/episode mapping are undocumented here; check Sonarr's own manualimport response shape before assuming it matches Radarr's.

## Known still-genuinely-open gaps (not a Manual Import problem)
- **Broken Blade** (Radarr 185-190) — no clean release exists at all yet. Re-run the escape hatch periodically.
- **Tekkaman Blade II "Virgin Memory"** — unclear if it's in the grabbed Moozzi2 box; check once extracted, may still need a separate search.
- **Moozzi2 (Tekkaman Blade)** — known LQ-group release, kept as best-available. Re-check for a cleaner source later.

## Security incident this session, already resolved — don't re-trigger
The live Prowlarr API key was briefly printed in cleartext (embedded in a release's `downloadUrl`/`magnetUrl` fields returned by Prowlarr's own `/search` endpoint) while using the escape hatch. **Already rotated and verified working** (Prowlarr config + Infisical both updated, confirmed via both `X-Api-Key` header and `?apikey=` query param). Memory updated: `.claude/memory/feedback_never_dump_full_records_with_secret_fields.md` now explicitly covers Prowlarr's `/search` endpoint, not just Sonarr/Radarr release/history records. **When extracting a release's download URL for a grab, always pull the specific field into a shell variable with a targeted `jq -r`, never a broad `select`+dump that could print the whole record.**

Also fixed a stale `ai/PATTERNS.md` entry: `QBITTORRENT_USER`/`QBITTORRENT_PASS` are at Infisical path `/media`, not `/TrueNAS` as previously documented.

## Suggested skills for next session
- No specific investigation skill needed to finish the Manual Import backlog — it's direct, repetitive API work following the pattern documented above.
- If Broken Blade or Tekkaman Blade's Virgin Memory turn into a longer hunt (private tracker signup, alternate acquisition path), no skill strongly indicated — same manual API-driven workflow as the rest of this doc.
- If a new large-scale audit angle opens up (e.g., a similar full-library sweep for Radarr movies rather than Sonarr series), consider `Plan` first given how much ground the two full-library sweeps this session covered — worth scoping before diving in.
