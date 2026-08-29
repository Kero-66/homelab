#!/usr/bin/env bash
# Writes the commit-gate token — binds a timestamp to a hash of the exact
# diff just reviewed, so the gate can't be satisfied by reviewing one diff
# and committing another. Only ever run this as the last step of the
# security-review-gate skill, after a real review found zero issues — never
# run it standalone or based on a summary of results. See SKILL.md and
# .claude/memory/feedback_no_self_certify_security_gate.md for why this
# distinction matters.
set -euo pipefail

REVIEW_FILE="$HOME/.claude/hooks/.security-review-timestamp"
DIFF_HASH=$(git diff HEAD | shasum -a 256 | awk '{print $1}')
TIMESTAMP=$(date +%s)

printf '%s\n%s\n' "$TIMESTAMP" "$DIFF_HASH" > "$REVIEW_FILE"
echo "Token written for diff hash ${DIFF_HASH:0:12}... at $(date -r "$TIMESTAMP" 2>/dev/null || date -d "@$TIMESTAMP")"
