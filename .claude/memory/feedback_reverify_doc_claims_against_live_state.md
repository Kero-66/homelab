---
name: feedback_reverify_doc_claims_against_live_state
description: "Doc rows marked done/resolved can be false — re-verify against live Sonarr/Radarr state before trusting them, and never call content 'bonus' without checking Radarr/TMDB and researching first"
metadata:
  type: feedback
---

Two compounding failures in one `.hack` Season 0 audit session (2026-08-31), both caught by the user, not by me:

1. **A prior session's `✅ Full Season 0 assessed` row in `SONARR_STRUCTURAL_AUDIT.md` was false on every specific claim it made** — it said G.U. Trilogy/Returner/Thanatos Report/"Let's Meet Offline" were "imported this session" and Parody Mode/Chim Chims/YuiYui were "deprioritized," but live Sonarr showed all of them still `hasFile:false`/`monitored:true`. I initially defended my own unrelated Liminality import by pointing at this stale doc row as if it were ground truth, instead of independently checking live state first.
2. **I started to write off "Online Jack" (9 short 2-4min Season 0 specials) as bonus content purely from runtime + title pattern**, without checking Radarr or actually researching what it was. The user called this out before I acted on it. It turned out to be real narrative content (an in-universe news-show tied into the .hack//G.U. game story), not a DVD extra.

**Why:** `ai/PATTERNS.md`/`SONARR_ACQUISITION_PROCESS.md` are the process; the audit doc's ✅/🟡/⚪ verdicts are a *cache* of that process's output, not the process itself. A cache can go stale — a doc row claiming an action was taken is not proof the action was taken. Separately, runtime is a *triage signal* (the process doc says this explicitly) for which pattern you're probably looking at, never a substitute for actually researching what unfamiliar content is before deciding it's bonus/non-story.

**How to apply:**
- Before trusting a doc's "✅ resolved" claim in an argument or as a basis for further action, re-pull live state (`hasFile`, `monitored`) for the specific episodes/movies in question — especially when the user is pushing back on something adjacent to that claim.
- Before marking anything `⚪`/deprioritized/bonus, do two checks minimum: (a) does Radarr/TMDB already have a matching entry — if `hasFile:true` there, it's a structural-flaw-#1 duplicate, not bonus, and needs unmonitoring, not dismissal; (b) an actual web search for what the content specifically is — short runtime alone is not evidence of "not story."
- When a whole Season 0 needs auditing, do it exhaustively (every item, not a spot-check) and check for structural flaw #2 in the reverse direction — a standalone Sonarr series can exist for content also filed under a combined series' Season 0 (confirmed this session: `.hack//Liminality` existed as series id 151 *and* as Season 0 specials of series 55 simultaneously).
