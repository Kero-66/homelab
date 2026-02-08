#!/usr/bin/env bash
# security/infisical/preseed.sh
# Purpose: Programmatically bootstrap the Infisical instance with an admin account.

set -euo pipefail

# 1. Load credentials
CRED_FILE="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CRED_FILE" ]; then
    echo "Error: Credentials file not found at $CRED_FILE"
    exit 1
fi

# We use the generic USERNAME (treating it as prefix for email) and PASSWORD
# Infisical requires an email, so we'll construct one if not explicitly set.
# Mapping: USERNAME=kero66 -> kero66@homelab.local
EMAIL=$(grep '^USERNAME=' "$CRED_FILE" | cut -d'=' -f2)
PASSWORD=$(grep '^PASSWORD=' "$CRED_FILE" | cut -d'=' -f2)

if [[ "$EMAIL" != *"@"* ]]; then
    EMAIL="${EMAIL}@homelab.local"
fi

ORG_NAME="Homelab"
DOMAIN="http://localhost:8081"

echo "Bootstrapping Infisical admin account: $EMAIL"

# 2. Run bootstrap command via docker exec
# Using --ignore-if-bootstrapped to ensure idempotency
docker exec infisical-backend infisical bootstrap \
    --email "$EMAIL" \
    --password "$PASSWORD" \
    --organization "$ORG_NAME" \
    --domain "$DOMAIN" \
    --ignore-if-bootstrapped \
    --silent

echo "Infisical preseed complete."
