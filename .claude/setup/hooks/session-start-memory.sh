#!/usr/bin/env bash
# SessionStart hook: injects repo-tracked memory into context automatically,
# since CLAUDE.md's "read these files" instruction is not self-enforcing.
set -euo pipefail

REPO_DIR="${CLAUDE_PROJECT_DIR:-/Users/kieran/repos/homelab}"
MEMORY_FILE="$REPO_DIR/.claude/memory/MEMORY.md"
PATTERNS_FILE="$REPO_DIR/ai/PATTERNS.md"
TODO_FILE="$REPO_DIR/ai/todo.md"
SESSION_NOTES="$REPO_DIR/ai/SESSION_NOTES.md"

if [[ -f "$MEMORY_FILE" ]]; then
  echo "=== .claude/memory/MEMORY.md (full, auto-injected) ==="
  cat "$MEMORY_FILE"
  echo
fi

if [[ -f "$PATTERNS_FILE" ]]; then
  echo "=== ai/PATTERNS.md (too large to auto-inject in full — headings index below) ==="
  grep -n '^#' "$PATTERNS_FILE" || true
  echo "Grep this file for the relevant section before guessing at a command. Do not trial-and-error an API — check here or the service's own spec first."
  echo
fi

if [[ -f "$TODO_FILE" ]]; then
  echo "=== ai/todo.md (too large to auto-inject in full — open item count below) ==="
  grep -c '^[0-9]' "$TODO_FILE" || true
  echo "open-numbered items. Read the file directly if picking up backlog work."
  echo
fi

if [[ -f "$SESSION_NOTES" ]]; then
  echo "=== ai/SESSION_NOTES.md exists — read it directly for in-progress work context ==="
fi
