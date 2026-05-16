#!/usr/bin/env bash
hook=$(find "$HOME/.claude/plugins/cache/mempalace/mempalace" -name "mempal-precompact-hook.sh" 2>/dev/null | sort -V | tail -1)
[[ -n "$hook" ]] && bash "$hook"
