#!/usr/bin/env bash
export PATH="$PATH:$HOME/Library/Python/3.9/bin"
hook=$(find "$HOME/.claude/plugins/cache/mempalace/mempalace" -name "mempal-precompact-hook.sh" 2>/dev/null | sort -V | tail -1)
[[ -n "$hook" ]] && bash "$hook"
