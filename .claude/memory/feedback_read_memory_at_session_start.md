---
name: feedback_read_memory_at_session_start
description: "CLAUDE.md's 'Start Every Session' step 1 (read .claude/memory/MEMORY.md) must actually be done, not assumed — skipping it causes repeat violations of already-documented lessons"
metadata:
  type: feedback
---

On 2026-08-24, an entire session (Shoko deployment + fallout) repeated at least five already-documented mistakes in one sitting: raw `docker restart` on a Dockhand-managed container (already in `feedback_dockhand_apps_no_raw_docker_commands.md`), dumping a full API record containing a live secret (`AniDb.Password` from Shoko's `/Settings` — already the exact pattern in `feedback_never_dump_full_records_with_secret_fields.md`), defaulting to Python parsing over raw output when told directly not to (already in `feedback_use_apis.md`, which quotes the user saying almost the identical sentence in a past session), not checking response type before piping to `jq`/`python3 -c` (already a "Common Gotcha" in `MEMORY.md` itself), and guessing HTTP methods on unfamiliar APIs instead of checking the spec first.

**Why:** When asked directly, honest answer was that `.claude/memory/MEMORY.md` was never read at any point in the session — no `Read` tool call against it exists in the transcript. CLAUDE.md mandates this as literal step 1 of every session, before any other work. Skipping it meant re-deriving lessons the hard way — live, with real consequences (an AniDB password now needs rotating, a user's trust took real damage) — that were already sitting in the repo, written specifically to prevent this.

**How to apply:** At the start of every session in this repo, actually call `Read` on `.claude/memory/MEMORY.md` before touching any service, API, or file — not "I should already know this," not relying on general instincts. If a session runs long enough to compact or resume, re-check whether memory was actually read this session (not a prior one) before proceeding with any TrueNAS/API/service work. When corrected on something mid-session, the first move should be checking whether a memory entry on it already exists (grep `.claude/memory/` for the topic) before writing a new one from scratch — extending an existing entry with a new incident (as done for the secrets-dump one) is more honest than treating each violation as a first-time lesson.
