#!/usr/bin/env bash
# Authenticate infisical CLI using machine identity stored in Bitwarden.
# Prompts for Bitwarden master password (or Touch ID if desktop integration is enabled).
#
# Usage:
#   eval "$(scripts/infisical-auth.sh)"   # auth + export INFISICAL_PROJECT_ID in current shell
#   scripts/infisical-auth.sh             # auth only (INFISICAL_PROJECT_ID not exported)
#
# One-time Bitwarden item setup (do this manually in Bitwarden):
#   Name:     Infisical Homelab Machine Identity
#   Username: <infisical machine identity client-id>
#   Password: <infisical machine identity client-secret>
#   Custom field (text): project-id = <infisical project id>
#
# One-time CLI setup on a new machine:
#   bw login    (only needed once)

set -euo pipefail

INFISICAL_DOMAIN="http://192.168.20.66:8081"
BW_ITEM_NAME="Infisical Homelab Machine Identity"

# Check bw is logged in
BW_STATUS=$(bw status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unauthenticated'))" 2>/dev/null || echo "unauthenticated")

if [[ "$BW_STATUS" == "unauthenticated" ]]; then
  echo "Bitwarden CLI is not logged in. Run: bw login" >&2
  exit 1
fi

# Unlock vault (prompts for password or biometrics)
BW_SESSION=$(bw unlock --raw)

if [[ -z "$BW_SESSION" ]]; then
  echo "Bitwarden unlock failed." >&2
  exit 1
fi

# Retrieve all fields from the Bitwarden item
BW_ITEM=$(bw get item "$BW_ITEM_NAME" --session "$BW_SESSION" 2>/dev/null)

CLIENT_ID=$(echo "$BW_ITEM" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['login']['username'])" 2>/dev/null)
CLIENT_SECRET=$(echo "$BW_ITEM" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['login']['password'])" 2>/dev/null)
PROJECT_ID=$(echo "$BW_ITEM" | python3 -c "
import sys, json
d = json.load(sys.stdin)
fields = d.get('fields') or []
match = next((f['value'] for f in fields if f.get('name') == 'project-id'), '')
print(match)
" 2>/dev/null)

if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  echo "Could not find '$BW_ITEM_NAME' in Bitwarden vault." >&2
  exit 1
fi

infisical login \
  --method=universal-auth \
  --client-id="$CLIENT_ID" \
  --client-secret="$CLIENT_SECRET" \
  --domain="$INFISICAL_DOMAIN" \
  --silent >/dev/null

echo "infisical authenticated" >&2

# Output project ID export so caller can eval this script
if [[ -n "$PROJECT_ID" ]]; then
  echo "export INFISICAL_PROJECT_ID='$PROJECT_ID'"
fi
