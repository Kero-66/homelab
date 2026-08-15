---
name: project_sonarr_radarr_movie_migration
description: Movies sitting as Sonarr TV specials that need copying into Radarr and are already unmonitored in Sonarr
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-15T02:19:52.260Z
---

Several movies exist as completed files under Sonarr TV series "Season 0 / Specials" instead of proper Radarr movie entries. Radarr already has matching monitored-but-missing entries for these — they just need the file copied over (Sonarr `/data/shows` and Radarr `/data/movies` are separate ZFS datasets, so this is a real copy, not a free hardlink, ~10-15GB total).

**Status as of 2026-08-08:** the 4 confirmed matches below have been **unmonitored in Sonarr** already (so Sonarr won't re-grab them), but the files have **NOT yet been copied into Radarr** — Radarr still shows them as missing/monitored.

| Radarr entry (still missing) | Source file location in Sonarr |
|---|---|
| Macross 7: The Galaxy Is Calling Me! (Radarr id 50) | series 67 (Macross 7), episode id 2934, episodeFileId 4199 |
| Macross Frontier: The False Songstress (Radarr id 55) | series 68 (Macross Frontier), episode id 2971, episodeFileId 3508 |
| Macross Frontier: The Wings of Farewell (Radarr id 56) | series 68 (Macross Frontier), episode id 2972, episodeFileId 3021 |
| The Super Dimension Fortress Macross: Flash Back 2012 (Radarr id 64) | series 70 (Macross), episode id 3080, episodeFileId 2906 |

**Why:** User is doing a broader library audit (2026-08-08) comparing Sonarr's 25 series-with-gaps against Radarr's 38 missing movies, and found a recurring pattern (first spotted with Macross Dynamite 7 / series 101, since deleted as a duplicate) — franchise movies get grabbed as TV "specials" instead of proper Radarr entries. [[project_media_gap_survey]] tracks the fuller survey.

**How to apply:** Next session, fetch the exact file paths via `GET /api/v3/episodefile/{id}` on the Sonarr side for the 4 episodeFileIds above, copy each into the corresponding Radarr movie's expected library path (use Radarr's manual import scan on a staged copy, same pattern used for the VOTOMS movies earlier this session), then verify `hasFile: true` in Radarr before considering this done.

Also still outstanding from the same audit — not yet cross-referenced:
- Two more Macross movies missing everywhere (not just Sonarr/Radarr split): Macross II: Lovers Again, Macross FB7: Listen to My Song!
- Franchises not yet checked for the same Sonarr-specials-vs-Radarr-movie overlap: Tekkaman Blade (4 Radarr movie entries missing, series 80 only 3/55 episodes), .hack (5 Radarr entries missing), Gundam/VOTOMS Die Graue Hexe, M.D. Geist
- Full Sonarr gap list (25 series) and Radarr gap list (38 movies) captured this session — re-derive via `GET /api/v3/series` filtered on `monitored && episodeCount > episodeFileCount`, and `GET /api/v3/movie` filtered on `monitored && !hasFile`, rather than trusting this snapshot as still accurate.

**Update 2026-08-15:** A much bigger, full-library version of this audit now lives in `media/docs/SONARR_STRUCTURAL_AUDIT.md` (durable repo doc, not memory) — every Season 0 special ≥60min runtime across all 67 Sonarr series with specials, cross-referenced against Radarr. Read that file for the current state; it supersedes the narrow Macross-only list above. It found several more series with the same pattern (Babylon 5, Gurren Lagann, Blue Gender, Goblin Slayer, Steins;Gate, .hack, Macross Frontier) — some already fully covered by Radarr (no action needed), some needing the same copy-Sonarr-file-to-Radarr treatment as the 4 originally found here, and some flagged as needing manual verification because automated fuzzy title-matching produced false positives on generic titles (Attack on Titan, Gundam, Jujutsu Kaisen, Macross Delta/Plus cluster).
