---
name: security-review-gate
description: Run a security review of pending git changes and automatically clear this repo's commit gate if none are found; surface any findings for user review instead of proceeding. Use before any commit in this repo, in place of the bundled /security-review.
---

# Security Review Gate

Replaces the bundled `/security-review` for commits in this repo. The purpose of the gate is to
let clean changes proceed automatically, while anything found gets surfaced to the user for
review and direction — never silently fixed, skipped, or waved through.

The commit-gate hook (`.claude/setup/hooks/pre-commit-security-reminder.sh`, deployed to
`~/.claude/hooks/`) requires a token file containing a timestamp **and** a sha256 of `git diff
HEAD`, both matching what's about to be committed. **The model must never write that token file
itself outside of step 3 below** — see `.claude/memory/feedback_no_self_certify_security_gate.md`.
Writing it as this skill's own final, conditional step is different from that: it's a fixed
procedure the user already reviewed and approved, not an on-the-fly decision to self-certify.

## Quick start

Run this skill instead of typing `/security-review` when about to commit in this repo.

## Workflow

1. **Review.** Gather `git status`, `git diff HEAD` (staged + unstaged), and recent commit log for
   style. Launch a sub-task (Agent tool, general-purpose) to identify vulnerabilities newly
   introduced by the diff — input validation, auth/authz, secrets management (including
   credentials in process argv/logs), injection/code execution, data exposure. Then launch a
   parallel filtering sub-task per candidate to rule out false positives (no DOS/rate-limiting, no
   "secrets stored on disk" if otherwise secured, no documentation-only, no theoretical/low-impact)
   — keep only findings scored 8/10+ confidence.

2. **Findings found → stop.** Report them to the user (file, line, severity, category,
   description, exploit scenario, fix). Do not write the token. Wait for the user's direction —
   don't fix anything unprompted.

3. **Zero findings → clear the gate.** Run:
   ```bash
   bash .claude/skills/security-review-gate/scripts/write-token.sh
   ```
   Report its output (the hash prefix) to the user, then proceed to commit.

4. **Token is single-diff, single-use.** It's bound to the exact diff reviewed — any edit,
   staging, or unstaging before the commit invalidates it (by design). Re-run this skill if what's
   being committed changes after review.
