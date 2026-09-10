#!/usr/bin/env bash
# Loads SSH keys into a fresh in-memory agent for this container's lifetime
# (never written to disk - same principle as the ssh-agent pattern in
# ai/PATTERNS.md "TrueNAS SSH"), then starts Claude Code Remote Control in
# server mode as the container's long-running process.
#
# Deliberately does NOT use `set -e`: a failed key load must not crash the
# whole container and drop into a restart loop - it should just start Remote
# Control anyway so the rest of it is usable, and let SSH/git commands fail
# individually later (debuggable interactively, same as a workstation with
# an expired key would behave).
set -uo pipefail

SSH_AUTH_SOCK_PATH="/root/.ssh-agent.sock"
rm -f "$SSH_AUTH_SOCK_PATH"
eval "$(ssh-agent -a "$SSH_AUTH_SOCK_PATH" -s)" > /dev/null
export SSH_AUTH_SOCK="$SSH_AUTH_SOCK_PATH"

INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
INFISICAL_DOMAIN="http://192.168.20.22:8081"

load_key() {
  infisical secrets get "$1" --env dev --path /TrueNAS \
    --projectId "$INFISICAL_PROJECT_ID" --domain "$INFISICAL_DOMAIN" --plain 2>/dev/null \
    | ssh-add - 2>/dev/null \
    || echo "warning: could not load '$1' from Infisical - is 'infisical login' still valid inside this container? SSH/git push will fail until this is fixed." >&2
}

load_key kero66_ssh_key
load_key CLAUDE_WORKSTATION_GIT_SSH_PRIVATE_KEY

mkdir -p /root/workspace
cd /root/workspace/homelab 2>/dev/null || cd /root/workspace 2>/dev/null || cd /root

exec claude remote-control --name claude-workstation
