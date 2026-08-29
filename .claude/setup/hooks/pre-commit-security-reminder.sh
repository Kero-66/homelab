#!/usr/bin/env bash
# PreToolUse hook — blocks git commit unless a security review passed for
# THIS exact diff within the last 10 minutes.
#
# The token file holds two lines: a timestamp and sha256(git diff HEAD) as of
# when the review concluded clean. Both the freshness AND the hash must match
# what's about to be committed — a token from reviewing diff A can never
# clear a commit of diff B, even seconds later and even though A and B might
# overlap. This closes a real gap in the original timestamp-only design: a
# stale review could otherwise "cover" any commit made within its window,
# regardless of whether that commit's content was ever actually reviewed.
#
# Token is written only by .claude/skills/security-review-gate/scripts/write-token.sh,
# and only as that skill's own last step after a real review found nothing —
# see that skill and .claude/memory/feedback_no_self_certify_security_gate.md.

INPUT=$(cat)

TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

echo "$CMD" | grep -qE '^\s*git commit' || exit 0

REVIEW_FILE="$HOME/.claude/hooks/.security-review-timestamp"
MAX_AGE_SECONDS=600  # 10 minutes

if [[ -f "$REVIEW_FILE" ]]; then
  review_time=$(sed -n '1p' "$REVIEW_FILE" 2>/dev/null)
  reviewed_hash=$(sed -n '2p' "$REVIEW_FILE" 2>/dev/null)
  now=$(date +%s)
  age=$(( now - ${review_time:-0} ))
  current_hash=$(git diff HEAD 2>/dev/null | shasum -a 256 | awk '{print $1}')

  if [[ $age -le $MAX_AGE_SECONDS && -n "$reviewed_hash" && "$reviewed_hash" == "$current_hash" ]]; then
    rm -f "$REVIEW_FILE"
    exit 0
  fi
fi

cat <<'EOF'
{
  "decision": "block",
  "reason": "Security gate: no matching security review for this exact diff. Run the security-review-gate skill — if it finds nothing, it writes a diff-hash-bound token itself and the next commit attempt (of that same diff) will be allowed."
}
EOF
