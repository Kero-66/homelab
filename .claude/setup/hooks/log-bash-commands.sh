#!/usr/bin/env bash
# PostToolUse hook — logs successful bash commands to a session temp file.
# Scrubs secrets before logging. Skips trivial/read-only commands.

SESSION_LOG="/tmp/claude-session-commands-${PPID}.log"

git rev-parse --git-dir &>/dev/null || exit 0

INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

EXIT_CODE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',{}).get('exit_code','1'))" 2>/dev/null)
[[ "$EXIT_CODE" == "0" ]] || exit 0

CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

SKIP_PATTERNS="^(ls |cat |head |tail |echo |grep |find |git log|git status|git diff|git show|git branch|pwd|which|type |wc |du |df |ps |top|htop)"
echo "$CMD" | grep -qE "$SKIP_PATTERNS" && exit 0

CMD=$(echo "$CMD" | sed \
  -e 's/Bearer [A-Za-z0-9._~+/-]\{8,\}/Bearer <REDACTED>/g' \
  -e 's/\(Authorization:[[:space:]]*\)[^\\"'\''[:space:]]*/\1<REDACTED>/g' \
  -e 's/\(--password[[:space:]=]\+\)[^\\"'\''[:space:]]*/\1<REDACTED>/g' \
  -e 's/\(--token[[:space:]=]\+\)[^\\"'\''[:space:]]*/\1<REDACTED>/g' \
  -e 's/\(--secret[[:space:]=]\+\)[^\\"'\''[:space:]]*/\1<REDACTED>/g' \
  -e 's/\(PASS\(WORD\)\?[[:space:]]*=[[:space:]]*\)[^\\"'\''[:space:];|&]*/\1<REDACTED>/gI' \
  -e 's/\(TOKEN[[:space:]]*=[[:space:]]*\)[^\\"'\''[:space:];|&]*/\1<REDACTED>/gI' \
  -e 's/\(SECRET[[:space:]]*=[[:space:]]*\)[^\\"'\''[:space:];|&]*/\1<REDACTED>/gI' \
  -e 's/\(API_KEY[[:space:]]*=[[:space:]]*\)[^\\"'\''[:space:];|&]*/\1<REDACTED>/gI' \
  -e 's/\(ACCESS_KEY[[:space:]]*=[[:space:]]*\)[^\\"'\''[:space:];|&]*/\1<REDACTED>/gI' \
  -e "s/\(infisical run\).*$/\1 <REDACTED>/g" \
)

[[ -z "$(echo "$CMD" | tr -d '[:space:]')" ]] && exit 0

echo "$CMD" >> "$SESSION_LOG"
exit 0
