#!/usr/bin/env bash
# Checks if current repo's ai-standards version matches the golden repo.
# Outputs a warning injected into the prompt context if outdated.

GOLDEN_REPO="/mnt/library/repos/ai-standards"
GOLDEN_VERSION_FILE="$GOLDEN_REPO/VERSION"
INSTRUCTIONS_FILE=".github/copilot-instructions.md"

git rev-parse --git-dir &>/dev/null || exit 0
[[ -f "$INSTRUCTIONS_FILE" ]] || exit 0
[[ -f "$GOLDEN_VERSION_FILE" ]] || exit 0

GOLDEN_VERSION=$(cat "$GOLDEN_VERSION_FILE" | tr -d '[:space:]')
REPO_VERSION=$(grep -o 'AI-STANDARDS-VERSION: [0-9.]*' "$INSTRUCTIONS_FILE" | head -1 | awk '{print $2}')
LAST_UPDATED=$(grep -o 'LAST-UPDATED: [0-9-]*' "$INSTRUCTIONS_FILE" | head -1 | awk '{print $2}')

[[ -z "$REPO_VERSION" ]] && exit 0
[[ "$REPO_VERSION" == "$GOLDEN_VERSION" ]] && exit 0

cat <<EOF
[AI-STANDARDS WARNING] This repo's AI standards are outdated.
  Repo version : $REPO_VERSION (last updated: ${LAST_UPDATED:-unknown})
  Golden repo  : $GOLDEN_VERSION ($GOLDEN_REPO)
  Action: Ask user if they want to update before proceeding.
EOF
