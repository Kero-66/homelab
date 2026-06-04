#!/usr/bin/env bash
export PATH="$PATH:$HOME/Library/Python/3.9/bin:$HOME/.local/bin"
if command -v mempalace &>/dev/null; then
  mempalace wake-up 2>/dev/null
fi
