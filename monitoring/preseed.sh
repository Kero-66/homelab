#!/usr/bin/env bash
set -euo pipefail

# Use credentials from environment (Infisical) or fallback
USERNAME="${BESZEL_USER:-admin}"
PASSWORD="${BESZEL_PASS:-homelab123PASSWORD}"

# Ensure password is at least 8 characters for Beszel
if [[ ${#PASSWORD} -lt 8 ]]; then
    PASSWORD="${PASSWORD}123"
fi

EMAIL="${USERNAME}@homelab.local"

echo "Preseeding Beszel Hub..."
docker exec beszel /beszel superuser upsert "$EMAIL" "$PASSWORD"

echo "------------------------------------------------"
echo "Preseed complete!"
echo "Beszel Hub Email: $EMAIL"
echo "Beszel Hub Password: $PASSWORD"
echo "Netdata Cloud login has been disabled via netdata.conf"
echo "------------------------------------------------"
