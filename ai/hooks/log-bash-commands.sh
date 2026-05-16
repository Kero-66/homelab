#!/usr/bin/env bash
# PostToolUse hook — logs successful bash commands to a session temp file.
# Scrubs secrets before logging. Skips trivial/read-only commands.

SESSION_LOG="/tmp/claude-session-commands-${PPID}.log"

# Only run inside a git repo
git rev-parse --git-dir &>/dev/null || exit 0

# Read PostToolUse JSON from stdin
INPUT=$(cat)

# Only care about Bash tool
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

# Only log successful calls (exit_code 0)
EXIT_CODE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',{}).get('exit_code','1'))" 2>/dev/null)
[[ "$EXIT_CODE" == "0" ]] || exit 0

# Extract command
CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# Skip trivial/read-only commands not worth documenting
SKIP_PATTERNS="^(ls |cat |head |tail |echo |grep |find |git log|git status|git diff|git show|git branch|pwd|which|type |wc |du |df |ps |top|htop)"
echo "$CMD" | grep -qE "$SKIP_PATTERNS" && exit 0

# Scrub secrets — replace values that look like tokens/keys/passwords
# Covers: Bearer tokens, API keys, passwords, long hex/base64 strings in assignments
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

# Skip if scrubbing left nothing meaningful
[[ -z "$(echo "$CMD" | tr -d '[:space:]')" ]] && exit 0

echo "$CMD" >> "$SESSION_LOG"
exit 0
