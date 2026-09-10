#!/usr/bin/env bash
# Prints the TrueNAS tailscale container's status (JSON) via the standard ssh-agent
# pattern - key goes straight from Infisical into the agent's memory, never to disk.
# See ai/PATTERNS.md "TrueNAS SSH" and .claude/skills/tailscale/SKILL.md for context.
set -euo pipefail

eval "$(ssh-agent -s)" > /dev/null
trap 'ssh-agent -k > /dev/null' EXIT

infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null

ssh kero66@192.168.20.22 "sudo docker exec tailscale tailscale --socket=/tmp/tailscaled.sock status --json"
