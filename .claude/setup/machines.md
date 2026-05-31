# Machine Setup State

Track per-machine Claude Code setup status here.

## MacBook Air (primary)

| Item | State | Notes |
|------|-------|-------|
| `~/.claude/hooks/` | ✅ installed | All 8 hooks active |
| `~/.claude/settings.json` | ✅ current | SessionEnd, PostToolUse scoped to Bash |
| mempalace plugin | ✅ installed | Palace at `~/.mempalace/` |
| caveman plugin | ✅ installed | |
| token-optimizer plugin | ✅ installed | v5.8.4, dashboard LaunchAgent installed |
| context7 plugin | ✅ installed | Official |
| github plugin | ✅ installed | Official |
| mempalace CLI in PATH | ✅ | `~/Library/Python/3.9/bin` |
| Infisical CLI | ✅ | `infisical` available |
| Last `apply.sh` run | — | (pre-dates apply.sh creation) |

### Machine-specific notes
- Token optimizer dashboard LaunchAgent at `~/Library/LaunchAgents/` (port 24842)
- statusLine and SessionEnd hook use wrapper scripts (version-agnostic)

---

## PC / Workstation (secondary)

| Item | State | Notes |
|------|-------|-------|
| `~/.claude/hooks/` | ❌ not set up | Run `apply.sh` |
| `~/.claude/settings.json` | ❌ not set up | Run `apply.sh` |
| mempalace plugin | ❓ unknown | |
| caveman plugin | ❓ unknown | |
| token-optimizer plugin | ❓ unknown | |
| context7 plugin | ❓ unknown | |
| github plugin | ❓ unknown | |
| mempalace CLI in PATH | ❓ unknown | May differ on Linux (no `Library/Python/3.9`) |
| Infisical CLI | ❓ unknown | |
| Last `apply.sh` run | — | Never |

### Setup instructions
```bash
# 1. Clone / pull repo
git pull

# 2. Run setup
bash .claude/setup/apply.sh

# 3. Install missing plugins in Claude Code, then restart

# 4. Update this table
```

### Linux PATH note
On Fedora/Linux, Python packages land in `~/.local/bin` not `~/Library/Python/3.9/bin`.
`apply.sh` checks `which mempalace` — if missing, add to `~/.bashrc`:
```bash
export PATH="$PATH:$HOME/.local/bin"
```
