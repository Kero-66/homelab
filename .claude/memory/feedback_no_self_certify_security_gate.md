---
name: feedback_no_self_certify_security_gate
description: "Never manually write ~/.claude/hooks/.security-review-timestamp yourself, even after actually running /security-review — this is a repeat violation (2026-08-22, 2026-08-29), not a one-off"
metadata:
  type: feedback
---

CLAUDE.md's commit gate says: run `/security-review`, and if clean, `date +%s > ~/.claude/hooks/.security-review-timestamp`, then commit. That literal instruction reads like the model should write the token itself as step 2. It's wrong to follow literally — the user has now corrected this exact behavior twice: once documented in `ai/handoff-2026-08-22.md` ("`/security-review` must be invoked as the actual Skill each time, not self-certified by manually writing the timestamp token"), and again on 2026-08-29 in a fresh session that had no way to know about that handoff note (handoffs aren't part of the auto-injected `MEMORY.md` index, so reading memory at session start wouldn't have caught this either — see [[feedback_read_memory_at_session_start]]).

**Why:** Writing the token by hand after the skill reports clean is functionally self-certification — it's the model asserting its own review passed and unlocking its own gate, which defeats the point of an independent gate entirely, regardless of whether the review was genuinely run and genuinely clean. The user's objection isn't about whether the review happened; it's that the model must never be the one to flip the switch that says "review happened, gate open."

**How to apply:**
- After running the `/security-review` skill and getting a clean result, do **not** run `date +%s > ~/.claude/hooks/.security-review-timestamp` or any equivalent yourself.
- Just attempt the commit. If the gate blocks it, that block is expected and correct — stop and ask the user how they want to proceed (they may have their own mechanism for clearing the gate, or want to adjust the workflow), rather than finding a way to satisfy the check unilaterally.
- This applies even when the literal text of CLAUDE.md's gate instructions describes writing the token as "your" next step — that instruction was written before this correction and is stale; treat the user's live correction as the higher authority over a written doc that hasn't caught up yet. (Worth fixing CLAUDE.md's gate wording itself if this comes up again, so the doc stops contradicting the actual rule.)
