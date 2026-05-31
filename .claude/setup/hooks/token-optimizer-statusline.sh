#!/usr/bin/env bash
# statusLine hook — token-optimizer status bar.
# Finds statusline.js in plugin cache regardless of version.
statusline=$(find "$HOME/.claude/plugins/cache/alexgreensh-token-optimizer" \
  -name "statusline.js" 2>/dev/null | sort -V | tail -1)
[[ -n "$statusline" ]] && node "$statusline"
