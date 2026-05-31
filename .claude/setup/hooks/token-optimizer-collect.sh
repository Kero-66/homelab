#!/usr/bin/env bash
# SessionEnd hook — collect token-optimizer metrics.
# Finds measure.py in plugin cache regardless of version.
measure=$(find "$HOME/.claude/plugins/cache/alexgreensh-token-optimizer" \
  -name "measure.py" 2>/dev/null | sort -V | tail -1)
[[ -n "$measure" ]] && python3 "$measure" collect
