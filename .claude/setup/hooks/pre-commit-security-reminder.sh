#!/usr/bin/env bash
# PreToolUse hook — blocks git commit unless /security-review ran clean within 10 minutes.
# Bypass requires a timestamped review file, not a simple flag.

INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

echo "$CMD" | grep -qE '^\s*git commit' || exit 0

REVIEW_FILE="$HOME/.claude/hooks/.security-review-timestamp"
MAX_AGE_SECONDS=600  # 10 minutes

if [[ -f "$REVIEW_FILE" ]]; then
  review_time=$(cat "$REVIEW_FILE" 2>/dev/null)
  now=$(date +%s)
  age=$(( now - review_time ))
  if [[ $age -le $MAX_AGE_SECONDS ]]; then
    rm -f "$REVIEW_FILE"
    exit 0
  fi
fi

cat <<'EOF'
{
  "decision": "block",
  "reason": "Security gate: /security-review must be run and pass before each commit. Run /security-review now — if it comes back clean, it will write a timestamp token and the next commit attempt will be allowed (within 10 minutes)."
}
EOF
