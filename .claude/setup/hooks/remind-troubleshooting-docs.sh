#!/usr/bin/env bash
# Stop hook — if commands were logged this session and we're in a git repo,
# remind to document anything useful in .github/TROUBLESHOOTING.md

SESSION_LOG="/tmp/claude-session-commands-${PPID}.log"

[[ -f "$SESSION_LOG" ]] || exit 0

git rev-parse --git-dir &>/dev/null || { rm -f "$SESSION_LOG"; exit 0; }

COMMANDS=$(cat "$SESSION_LOG")
rm -f "$SESSION_LOG"

[[ -z "$COMMANDS" ]] && exit 0

TROUBLESHOOTING_FILE=".github/TROUBLESHOOTING.md"

echo ""
echo "─────────────────────────────────────────────"
echo " TROUBLESHOOTING DOC REMINDER"
echo "─────────────────────────────────────────────"
echo " Commands run this session that may be worth"
echo " documenting in $TROUBLESHOOTING_FILE:"
echo ""
echo "$COMMANDS" | while IFS= read -r cmd; do
  echo "  • $cmd"
done
echo ""
echo " If any solved a real problem, append to"
echo " $TROUBLESHOOTING_FILE with: what worked, why,"
echo " and any required env var placeholders."
echo "─────────────────────────────────────────────"
