# Machine Setup State

Track per-machine Claude Code setup status here.

## MacBook Air (primary) — updated 2026-06-01

| Item | State | Notes |
|------|-------|-------|
| `~/.claude/hooks/` | ✅ installed | 8 hook scripts active |
| `~/.claude/settings.json` | ✅ current | No UserPromptSubmit hook; Stop+PreCompact in global only |
| mempalace plugin | ✅ installed | Palace at `~/.mempalace/` |
| token-optimizer plugin | ✅ installed | Dashboard LaunchAgent on port 24842 |
| context7 plugin | ✅ installed | Official |
| github plugin | ✅ installed | Official |
| caveman plugin | ❌ removed | Replaced by MP caveman skill (npx install) |
| MP skills (npx) | ✅ installed | 9 skills: caveman, diagnose, grill-me, grill-with-docs, handoff, improve-codebase-architecture, prototype, review, write-a-skill |
| intent-layer skill | ✅ installed | git clone crafter-station/skills → `~/.agents/skills/intent-layer` → symlink to `~/.claude/skills/intent-layer` |
| mempalace CLI in PATH | ✅ | `~/Library/Python/3.9/bin` |
| Infisical CLI | ✅ | `infisical` available |
| Last `apply.sh` run | 2026-06-01 | Post token-optimizer cleanup session |

### Machine-specific notes
- Token optimizer dashboard LaunchAgent at `~/Library/LaunchAgents/` (port 24842)
- `statusLine` and `SessionEnd` hook use wrapper scripts (version-agnostic)
- Output caps: `BASH_MAX_OUTPUT_LENGTH=10000`, `MAX_MCP_OUTPUT_TOKENS=4000` (in global-settings.json)

### Key changes 2026-06-01 (intent-layer session)
- Moved `CLAUDE.md` from `.claude/CLAUDE.md` → repo root `CLAUDE.md` (required for detect_state.sh)
- Installed intent-layer skill: git clone crafter-station/skills → copy to `~/.agents/skills/intent-layer` → symlink to `~/.claude/skills/intent-layer`
- Created AGENTS.md child nodes: `truenas/`, `media/`, `media/scripts/`, `ai/`
- Added `SessionStart` hook → `mempalace wake-up` at session start

### Key changes 2026-06-01 (token-optimizer session)
- Removed `caveman@caveman` plugin, replaced with Matt Pocock caveman via npx
- Removed `UserPromptSubmit` hook (`check-ai-standards-version.sh` — Fedora path, no-op on Mac; todo#3 tracks future portable version)
- Removed duplicate Stop+PreCompact hooks from project settings (kept in global only)
- Archived 20 out-of-domain skills to `~/.claude/_backups/skills-archived-20260601/`
- Deleted `rules/troubleshooting.md` (content merged into CLAUDE.md Behavior Rules)
- Trimmed MEMORY.md feedback files (~480 tokens saved)

---

## PC / Workstation (secondary)

| Item | State | Notes |
|------|-------|-------|
| `~/.claude/hooks/` | ❌ not set up | Run `apply.sh` |
| `~/.claude/settings.json` | ❌ not set up | Run `apply.sh` |
| mempalace plugin | ❓ unknown | |
| token-optimizer plugin | ❓ unknown | |
| context7 plugin | ❓ unknown | |
| github plugin | ❓ unknown | |
| MP skills (npx) | ❓ unknown | Run install + prune (see below) |
| mempalace CLI in PATH | ❓ unknown | Linux: `~/.local/bin` |
| Infisical CLI | ❓ unknown | |
| Last `apply.sh` run | — | Never |

### Setup instructions
```bash
# 1. Clone / pull repo
git pull

# 2. Run setup (hooks + global settings)
bash .claude/setup/apply.sh

# 3. Install missing plugins in Claude Code (restart after)

# 4. Install skills
npx --yes skills@latest add mattpocock/skills --yes --global

# 5. Install intent-layer skill (npx does NOT work — clone manually)
git clone https://github.com/crafter-station/skills.git /tmp/cs-skills
cp -r /tmp/cs-skills/context-engineering/intent-layer ~/.agents/skills/intent-layer
ln -s ~/.agents/skills/intent-layer ~/.claude/skills/intent-layer
rm -rf /tmp/cs-skills

# 6. Prune extra skills — archive everything except:
#    caveman, diagnose, grill-me, grill-with-docs, handoff,
#    improve-codebase-architecture, prototype, review, write-a-skill
KEEP=(caveman diagnose grill-me grill-with-docs handoff improve-codebase-architecture prototype review write-a-skill)
ARCHIVE="$HOME/.claude/_backups/skills-pruned-$(date +%Y%m%d)"
mkdir -p "$ARCHIVE"
for d in ~/.agents/skills/*/; do
  name=$(basename "$d")
  if [[ ! " ${KEEP[*]} " =~ " $name " ]]; then
    mv "$d" "$ARCHIVE/"
    echo "archived: $name"
  fi
done

# 6. Update this table
```

### Linux PATH note
On Fedora/Linux, Python packages land in `~/.local/bin` not `~/Library/Python/3.9/bin`.
If `mempalace` not found after install, add to `~/.bashrc`:
```bash
export PATH="$PATH:$HOME/.local/bin"
```
