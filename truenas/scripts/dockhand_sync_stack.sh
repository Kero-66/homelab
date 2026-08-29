#!/usr/bin/env bash
# Trigger an immediate Dockhand git-stack sync+deploy (bypassing the daily
# 3am autoUpdateCron) via PUT /api/git/stacks/{id} with deployNow:true.
#
# Usage: truenas/scripts/dockhand_sync_stack.sh <stack-name> [<stack-name> ...]
#
# Run from the workstation/laptop where the infisical CLI is installed and
# authenticated — infisical is NOT installed on TrueNAS itself.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <stack-name> [<stack-name> ...]" >&2
  exit 1
fi

INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
DH="http://192.168.20.22:30328"

_isec() {
  infisical secrets get "$1" --env dev --path "$2" --plain \
    --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 2>/dev/null
}

COOKIEJAR=$(mktemp)
trap 'rm -f "$COOKIEJAR"' EXIT

DH_USER=$(_isec DOCKHAND_USER /TrueNAS)
DH_PASS=$(_isec DOCKHAND_USER_PASSWORD /TrueNAS)

if [[ -z "$DH_USER" || -z "$DH_PASS" ]]; then
  echo "Failed to fetch Dockhand credentials from Infisical" >&2
  exit 1
fi

DH_USER="$DH_USER" DH_PASS="$DH_PASS" python3 -c \
  "import json,os; print(json.dumps({'username':os.environ['DH_USER'],'password':os.environ['DH_PASS']}))" \
  | curl -s -c "$COOKIEJAR" -X POST "$DH/api/auth/login" \
    -H "Content-Type: application/json" --data-binary @- > /dev/null

STACKS_JSON=$(curl -s -b "$COOKIEJAR" "$DH/api/git/stacks")

for name in "$@"; do
  id=$(STACKS_JSON="$STACKS_JSON" STACK_NAME="$name" python3 -c "
import os, json
d = json.loads(os.environ['STACKS_JSON'])
items = d if isinstance(d, list) else d.get('stacks', d.get('data', []))
for s in items:
    if (s.get('stackName') or s.get('name')) == os.environ['STACK_NAME']:
        print(s.get('id'))
        break
")
  if [[ -z "$id" ]]; then
    echo "Stack '$name' not found in Dockhand git stacks" >&2
    continue
  fi

  echo "Syncing '$name' (id=$id)..."
  resp=$(curl -s -b "$COOKIEJAR" -X PUT "$DH/api/git/stacks/$id" \
    -H "Content-Type: application/json" -d '{"deployNow": true}')
  echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  jobId:', d.get('jobId', d))"
done
