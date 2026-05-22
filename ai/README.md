# AI / Claude Code Resources

Config, hooks, and setup scripts for Claude Code across machines.

## New Machine Setup

```bash
bash ai/laptop-setup.sh
```

Requires: `claude` CLI installed and authenticated, `git` available.

What it does:
1. Adds plugin marketplaces (caveman, mempalace)
2. Installs plugins: context7, github, caveman, mempalace
3. Copies hooks from `ai/hooks/` → `~/.claude/hooks/`
4. Installs `ai/settings.json` → `~/.claude/settings.json` (skips if exists)
5. Clones `Kero-66/skills` fork → `~/repos/skills` and links all skills to `~/.claude/skills`

## Files

| File | Purpose |
|------|---------|
| `laptop-setup.sh` | One-shot new machine setup |
| `settings.json` | Claude Code settings (hooks, plugins, theme) — source of truth |
| `hooks/` | Hook scripts installed to `~/.claude/hooks/` |
| `PATTERNS.md` | Verified copy-paste commands for SSH, Infisical, TrueNAS |
| `SESSION_NOTES.md` | Current work in progress |
| `todo.md` | Task backlog |
| `DOCUMENTATION_STRUCTURE.md` | Doc workflow reference |
| `ai_behaviour.md` | Claude behaviour guidelines |
| `reference.md` | Quick reference links |

## Skills

Skills live in `~/repos/skills` (fork of mattpocock/skills).
Linked to `~/.claude/skills` — available as `/skill-name` in Claude Code.

Key skills installed:
- `/diagnose` — disciplined debug loop
- `/grill-me` / `/grill-with-docs` — grilling sessions before coding
- `/zoom-out` — broader codebase context
- `/handoff` — compact conversation into handoff doc
- `/write-a-skill` — scaffold new skills

Run `/setup-matt-pocock-skills` once per repo before using `/to-issues`, `/triage`, `/diagnose`.

## settings.json

`ai/settings.json` is the canonical settings file. If `~/.claude/settings.json` already exists on a machine, merge manually — don't overwrite. Diff against `ai/settings.json` to see what's missing.

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `check-ai-standards-version.sh` | UserPromptSubmit | Warns if AI docs are stale |
| `pre-commit-security-reminder.sh` | PreToolUse | Security check before commits |
| `log-bash-commands.sh` | PostToolUse | Logs bash commands run |
| `remind-troubleshooting-docs.sh` | Stop | Prompts to update troubleshooting docs |
| `mempalace-stop.sh` | Stop | Syncs memories to MemPalace |
| `mempalace-precompact.sh` | PreCompact | Saves context before compaction |

## Prompt Engineering

- `prompting_resources.md` — curated links
- `copilot-instructions-template.md` — template for GitHub Copilot instructions
- `improve_copilot_instructions.md` — working draft for `.github/copilot-instructions.md`
