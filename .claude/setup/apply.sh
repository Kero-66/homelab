#!/usr/bin/env bash
# apply.sh — idempotent Claude Code setup for any machine.
# Run from repo root: bash .claude/setup/apply.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_DIR="$REPO_ROOT/.claude/setup"
HOOKS_SRC="$SETUP_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
SETTINGS_SRC="$SETUP_DIR/global-settings.json"
SETTINGS_DST="$HOME/.claude/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
info() { echo "  $*"; }

echo ""
echo "Claude Code — machine setup"
echo "==========================="
echo ""

# ── Hooks ────────────────────────────────────────────────────────────────────
mkdir -p "$HOOKS_DST"

for hook in "$HOOKS_SRC"/*.sh; do
  name=$(basename "$hook")
  dst="$HOOKS_DST/$name"
  cp "$hook" "$dst"
  chmod +x "$dst"
  ok "hook: $name"
done

# ── Global settings ───────────────────────────────────────────────────────────
if [[ -f "$SETTINGS_DST" ]]; then
  python3 - <<PYEOF
import json, sys

with open("$SETTINGS_SRC") as f:
    canonical = json.load(f)
with open("$SETTINGS_DST") as f:
    current = json.load(f)

# Canonical keys always win
merged = {**current, **canonical}

with open("$SETTINGS_DST", "w") as f:
    json.dump(merged, f, indent=2)
    f.write("\n")
print("merged")
PYEOF
  ok "global settings: merged $SETTINGS_DST"
else
  cp "$SETTINGS_SRC" "$SETTINGS_DST"
  ok "global settings: installed $SETTINGS_DST"
fi

# ── Skills (Matt Pocock suite via npx) ───────────────────────────────────────
echo ""
echo "Skills check:"

AGENTS_SKILLS="$HOME/.agents/skills"
REQUIRED_SKILLS=(caveman diagnose grill-me grill-with-docs handoff improve-codebase-architecture prototype review write-a-skill)
MISSING_SKILLS=()

for skill in "${REQUIRED_SKILLS[@]}"; do
  if [[ -d "$AGENTS_SKILLS/$skill" ]]; then
    ok "skill: $skill"
  else
    MISSING_SKILLS+=("$skill")
    warn "skill MISSING: $skill"
  fi
done

if [[ ${#MISSING_SKILLS[@]} -gt 0 ]]; then
  echo ""
  info "Install missing skills:"
  info "  npx --yes skills@latest add mattpocock/skills --yes --global"
  info ""
  info "Then archive out-of-domain skills (keep only the 9 above):"
  info "  See machines.md for the prune list"
fi

# ── intent-layer skill (crafter-station) ────────────────────────────────────
echo ""
echo "intent-layer skill check:"

INTENT_SRC="$HOME/.agents/skills/intent-layer"
INTENT_LINK="$HOME/.claude/skills/intent-layer"

if [[ -d "$INTENT_SRC" ]]; then
  ok "intent-layer source: $INTENT_SRC"
else
  warn "intent-layer MISSING — install with:"
  info "  git clone https://github.com/crafter-station/skills.git /tmp/cs-skills"
  info "  cp -r /tmp/cs-skills/context-engineering/intent-layer $INTENT_SRC"
  info "  rm -rf /tmp/cs-skills"
fi

if [[ -L "$INTENT_LINK" ]]; then
  ok "intent-layer symlink: $INTENT_LINK"
elif [[ -d "$INTENT_SRC" ]]; then
  mkdir -p "$(dirname "$INTENT_LINK")"
  ln -s "$INTENT_SRC" "$INTENT_LINK"
  ok "intent-layer symlink: created"
else
  warn "intent-layer symlink: skipped (source not installed)"
fi

# ── Plugin install reminders ──────────────────────────────────────────────────
echo ""
echo "Plugin check (manual install required if missing):"

PLUGIN_CACHE="$HOME/.claude/plugins/cache"

check_plugin() {
  local dir="$1" name="$2" install_cmd="$3"
  if [[ -d "$PLUGIN_CACHE/$dir" ]]; then
    ok "plugin: $name"
  else
    warn "plugin MISSING: $name"
    info "Install: $install_cmd"
  fi
}

check_plugin "mempalace/mempalace"              "mempalace"       "/install-plugin mempalace (in Claude Code)"
check_plugin "alexgreensh-token-optimizer"      "token-optimizer" "/install-plugin token-optimizer (in Claude Code)"
check_plugin "claude-plugins-official/context7" "context7"        "(official — install via Claude Code settings)"
check_plugin "claude-plugins-official/github"   "github"          "(official — install via Claude Code settings)"

# ── mempalace PATH ────────────────────────────────────────────────────────────
echo ""
if command -v mempalace &>/dev/null; then
  ok "mempalace CLI: $(which mempalace)"
else
  warn "mempalace CLI not in PATH"
  info "macOS: export PATH=\"\$PATH:\$HOME/Library/Python/3.9/bin\""
  info "Linux: export PATH=\"\$PATH:\$HOME/.local/bin\""
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Done. Restart Claude Code for hook/settings changes to take effect."
echo ""
echo "Next steps:"
echo "  1. Install any missing plugins/skills listed above"
echo "  2. After npx install, prune extra MP skills — keep only: ${REQUIRED_SKILLS[*]}"
echo "  3. If palace feels degraded: mempalace repair --mode from-sqlite --archive-existing --backup --yes"
echo "  4. Update .claude/setup/machines.md for this machine"
echo ""
