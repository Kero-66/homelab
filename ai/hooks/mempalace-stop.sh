#!/usr/bin/env bash
hook=$(find "$HOME/.claude/plugins/cache/mempalace/mempalace" -name "mempal-stop-hook.sh" 2>/dev/null | sort -V | tail -1)
[[ -n "$hook" ]] && bash "$hook"
