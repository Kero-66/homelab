#!/usr/bin/env bash
# PreToolUse hook — intercepts git commit commands and reminds to run /security-review.

INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

# Only trigger on git commit (not git commit --amend checks or git log etc)
echo "$CMD" | grep -qE '^\s*git commit' || exit 0

# Output as JSON block to inject into context
cat <<'EOF'
{
  "decision": "block",
  "reason": "Security check: before committing, run /security-review to scan for hardcoded secrets, credentials, or sensitive data in the staged changes. If you've already reviewed and it's clean, tell me to proceed."
}
EOF
