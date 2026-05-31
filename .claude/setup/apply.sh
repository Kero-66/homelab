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
  # Merge: preserve machine-specific keys (theme, etc.), apply canonical keys
  # Strategy: canonical is authoritative for hooks/plugins/marketplaces/effortLevel
  # Machine keeps: any keys NOT in canonical (e.g. machine-specific statusLine overrides)
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

check_plugin "mempalace/mempalace"                   "mempalace"       "/install-plugin mempalace"
check_plugin "caveman/caveman"                       "caveman"         "/install-plugin caveman"
check_plugin "alexgreensh-token-optimizer"           "token-optimizer" "/install-plugin token-optimizer"
check_plugin "claude-plugins-official/context7"      "context7"        "(official — install via Claude Code settings)"
check_plugin "claude-plugins-official/github"        "github"          "(official — install via Claude Code settings)"

# ── mempalace PATH (macOS Python) ─────────────────────────────────────────────
echo ""
if command -v mempalace &>/dev/null; then
  ok "mempalace CLI: $(which mempalace)"
else
  warn "mempalace CLI not in PATH"
  info "Add to ~/.zshrc or ~/.bashrc:"
  info '  export PATH="$PATH:$HOME/Library/Python/3.9/bin"'
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Done. Restart Claude Code for hook changes to take effect."
echo ""
echo "Next steps:"
echo "  1. If any plugins were missing, install them in Claude Code"
echo "  2. Run 'mempalace repair --mode from-sqlite --archive-existing --backup --yes' if palace feels degraded"
echo "  3. Check .claude/setup/machines.md and add/update this machine's entry"
echo ""
