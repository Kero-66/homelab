---
name: check_docs_before_acting_not_after
description: When the user says something is documented, or before any grab/action in a domain with a known workflow doc, check that doc FIRST — not after being corrected
metadata:
  type: feedback
---

When the user references "the documented process" (even without naming the file), or before taking
an action in a domain that has a known workflow doc (grabbing releases, escape-hatch searches,
etc.), grep/read the relevant doc BEFORE acting — not after acting wrong and getting corrected,
and not by writing a new ad-hoc memory note that duplicates what's already written down somewhere.

**Why:** 2026-08-29 session, closing media gaps: skipped `media/docs/SONARR_STRUCTURAL_AUDIT.md`'s
already-documented step 6a (list every candidate, state suitability out loud before grabbing) not
once but twice in the same session — grabbed a 1-seeder stalled torrent, then a fake 66MB release,
both without checking candidates or sanity-checking size/seeders first. When the user pointed out
a release looked wrong, the correct move (re-derive the rule, write fresh memory) was still the
*wrong* move, because the user had already said "there's a documented process for this" and it was
ignored in favor of inventing new rules from scratch. The user had to say it a third time, more
sharply, before the actual doc got checked. This is explicitly called out as an existing, known
failure mode — see [[feedback_check_docs_before_fixing]] (same root problem in a different domain:
permissions/ownership fixes) — this is not an isolated one-off, it is a pattern in how work in this
repo starts.

**Second confirmed instance, same session (2026-08-29):** treated "Codename: Robotech" as a
genuine missing-movie gap and ran the escape-hatch search on it without ever doing step 6a(b)
("state what the content actually is, sourced, before grabbing") — it's actually a 73-minute 1985
promotional recap compiling the first 12 TV episodes, not new content, and never should have been
searched for as a gap at all. User had to look it up externally and point this out. The doc's own
step 6a(b) exists specifically to catch this category of mistake (see the Gurren Lagann Parallel
Works precedent in the same doc) — it was skipped again, in the very next action after being
corrected on skipping step 6a itself.

**How to apply:**
- The moment the user says "this is documented," "there's a process for this," or similar — stop,
  find the doc (grep the repo, check `ai/AGENTS.md`'s docs index, check `media/AGENTS.md`, check
  the specific domain's `AGENTS.md`), and read it before responding, even if a plausible-sounding
  answer is already forming.
- Before any escape-hatch grab specifically: `media/docs/SONARR_STRUCTURAL_AUDIT.md` step 6 (and
  6a/6a-i/6a-ii) is the governing process — list every candidate, state what the content actually
  is, check size/seeder sanity, prefer NZB, only then grab.
- When a new "lesson" seems worth writing to memory, check first whether an existing doc already
  covers it (grep for the topic across `media/docs/`, `ai/PATTERNS.md`, the relevant `AGENTS.md`)
  before creating a new memory file — extend the existing doc instead of fragmenting the same rule
  across multiple files.
