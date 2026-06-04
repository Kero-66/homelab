# Installed Skills

Canonical record of Claude Code skills installed in this homelab setup, their source repos, install methods, and review workflows.

## Active Skills

### Matt Pocock Suite
- **Source**: https://github.com/mattpocock/skills
- **Install**: `npx --yes skills@latest add mattpocock/skills --yes --global`
- **Location**: `~/.agents/skills/` (symlinked to `~/.claude/skills/`)
- **Skills kept**: caveman, diagnose, grill-me, grill-with-docs, handoff, improve-codebase-architecture, prototype, review, write-a-skill
- **Post-install**: prune extras — see `.claude/setup/machines.md` for prune script

### intent-layer (crafter-station)
- **Source**: https://github.com/crafter-station/skills
- **Install**: `git clone https://github.com/crafter-station/skills.git /tmp/cs-skills && cp -r /tmp/cs-skills/context-engineering/intent-layer ~/.agents/skills/intent-layer && ln -s ~/.agents/skills/intent-layer ~/.claude/skills/intent-layer`
- **Note**: `npx skills add crafter-station/skills --skill intent-layer -g` does NOT work — not in published package
- **Review workflow**: see below

### token-optimizer (alexgreensh)
- **Source**: https://github.com/alexgreensh/token-optimizer (via Claude plugin marketplace)
- **Install**: `/install-plugin token-optimizer` in Claude Code
- **Review workflow**: see below

---

## Review Workflows

### token-optimizer — when to re-run
Trigger a full `/token-optimizer` audit when:
- Adding new hooks, plugins, or skills
- CLAUDE.md grows significantly
- Context quality score drops below 60 for multiple sessions
- After any major repo restructure

Phases: Audit (6 parallel agents) → Synthesis → Dashboard → Implement → Verify (`python3 $MEASURE_PY report`)

### intent-layer — when to re-run
Trigger `/intent-layer` maintenance when:
- A directory grows past 20k tokens (new stacks, major new scripts)
- A new major subsystem is added to the repo
- An AGENTS.md feels stale or wrong after working in that area
- Running `bash ~/.agents/skills/intent-layer/scripts/detect_state.sh .` returns `partial`

Maintenance mode options:
- **Audit nodes** — review existing AGENTS.md files against capture protocol
- **Find candidates** — re-measure token counts, identify new nodes needed
- **Both**

Current nodes (created 2026-06-01):
| File | Tokens | Purpose |
|------|--------|---------|
| `truenas/AGENTS.md` | — | TrueNAS app lifecycle, SSH, midclt |
| `media/AGENTS.md` | ~94k | Media stack reference, Bazarr invariants |
| `media/scripts/AGENTS.md` | ~50k | Config automation scripts |
| `ai/AGENTS.md` | ~42k | Claude Code ops, PATTERNS.md, memory workflow |

---

## Skill Install Checklist (new machine)
1. `npx --yes skills@latest add mattpocock/skills --yes --global` → prune to 9 (see machines.md)
2. Clone crafter-station/skills → copy intent-layer → symlink (see above)
3. `/reload-skills` in Claude Code
4. Verify: skills list should include `intent-layer`, `caveman`, `diagnose`, etc.
