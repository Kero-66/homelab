# AI / Claude Code Operations

## Purpose
Owns all Claude Code configuration, verified commands, session tracking, task backlog, and AI setup scripts. Does NOT own infrastructure config (that's `.claude/`) or service-specific knowledge (that's `truenas/` or `media/`).

## Entry Points
- `PATTERNS.md` - **READ FIRST before writing any SSH, Infisical, or TrueNAS command**
- `SESSION_NOTES.md` - Current work in progress
- `todo.md` - Full task backlog with IDs
- `handoff-YYYY-MM-DD.md` - Session handoffs (append to today's file, never overwrite)

## Contracts & Invariants
- `PATTERNS.md` is the ONLY trusted source for SSH, Infisical, and midclt commands — never write from memory or CLAUDE.md snippets
- Handoff files live at `ai/handoff-YYYY-MM-DD.md` — always `ls ai/handoff*.md` before writing; append if today's file exists
- All feedback/decisions go to `.claude/memory/` in the repo — NEVER to `~/.claude/projects/` (local-only, doesn't travel)
- Update `.claude/memory/MEMORY.md` index whenever adding a new memory file

## Patterns
- New todo: append to `ai/todo.md` with sequential ID, created_by, created_at, status=open
- Completed todos: move to `ai/COMPLETED.md`
- Memory files: frontmatter with name/description/metadata.type + body with **Why:** and **How to apply:**
- Machine setup: `.claude/setup/apply.sh` (idempotent, run on any new machine)

## Anti-patterns
- DO NOT write memory to `~/.claude/projects/` — repo `.claude/memory/` only
- DO NOT write handoff to `/tmp` or OS temp dir — `ai/handoff-YYYY-MM-DD.md` only
- DO NOT use `ai/laptop-setup.sh` — superseded by `.claude/setup/apply.sh`
- DO NOT reference `ai/settings.json` — superseded by `.claude/setup/global-settings.json`

## Related Context
- `.claude/CLAUDE.md` - Root instructions, behavior rules, commit security gate
- `.claude/memory/MEMORY.md` - Accumulated feedback and gotchas
- `.claude/setup/` - Machine setup (apply.sh, global-settings.json, machines.md)
