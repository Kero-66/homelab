#!/usr/bin/env bash
# =============================================================================
# laptop-setup.sh — Claude Code setup for a new machine
# =============================================================================
# Run once after cloning the repo on a new device.
# Installs Claude Code plugins and copies hooks + settings from this repo.
#
# Usage:
#   bash ai/laptop-setup.sh
#
# Requirements: claude CLI installed and authenticated
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

echo "=== Claude Code setup ==="

# ---------------------------------------------------------------------------
# Marketplaces
# ---------------------------------------------------------------------------
echo ""
echo "Adding plugin marketplaces..."
claude plugin marketplace add caveman github:JuliusBrussee/caveman 2>/dev/null || echo "  caveman already added"
claude plugin marketplace add mempalace github:milla-jovovich/mempalace 2>/dev/null || echo "  mempalace already added"

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
echo ""
echo "Installing plugins..."
claude plugin install context7@claude-plugins-official
claude plugin install github@claude-plugins-official
claude plugin install caveman@caveman
claude plugin install mempalace@mempalace

# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------
echo ""
echo "Copying hooks..."
mkdir -p "$HOOKS_DIR"
cp "$REPO_ROOT/ai/hooks/"*.sh "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*.sh
echo "  Hooks installed to $HOOKS_DIR"

# ---------------------------------------------------------------------------
# settings.json
# ---------------------------------------------------------------------------
echo ""
if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
  echo "settings.json already exists — skipping (merge manually if needed)"
  echo "  Reference: $REPO_ROOT/ai/settings.json"
else
  cp "$REPO_ROOT/ai/settings.json" "$CLAUDE_DIR/settings.json"
  echo "  settings.json installed"
fi

echo ""
echo "Done. Restart Claude Code to pick up all changes."
