#!/usr/bin/env bash
set -euo pipefail

# Updates the Tailscale binaries on JetKVM (armv7l embedded Linux).
#
# JetKVM's firmware ships no OS-level CA cert store, so `tailscale update`
# fails on-device with "x509: certificate signed by unknown authority"
# (see https://github.com/jetkvm/kvm/issues/1096, still open). This script
# downloads and verifies the release on the machine running it, then pushes
# the binaries over SSH — same approach the JetKVM community uses
# (see https://github.com/thinktankmachine/jetkvm-tailscale).
#
# Idempotent: does nothing if JetKVM is already on the latest stable version.
#
# Usage:
#   networking/scripts/jetkvm-tailscale-update.sh
#
# Env overrides:
#   JETKVM_IP   (default 192.168.20.15)
#   SSH_USER    (default root)

JETKVM_IP="${JETKVM_IP:-192.168.20.15}"
SSH_USER="${SSH_USER:-root}"
INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
INFISICAL_DOMAIN="http://192.168.20.22:8081"

SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=8)

TMPDIR_SAFE=$(mktemp -d)
chmod 700 "$TMPDIR_SAFE"
TMPKEY="$TMPDIR_SAFE/k"
cleanup() { rm -rf "$TMPDIR_SAFE"; }
trap cleanup EXIT

infisical secrets get JETKVM_SSH_PRIVATE_KEY --env dev --path /networking --plain \
  --projectId "$INFISICAL_PROJECT_ID" --domain "$INFISICAL_DOMAIN" 2>/dev/null > "$TMPKEY"
chmod 600 "$TMPKEY"

ssh_jetkvm() {
  ssh -i "$TMPKEY" "${SSH_OPTS[@]}" "${SSH_USER}@${JETKVM_IP}" "$@"
}

CURRENT_VERSION=$(ssh_jetkvm "/userdata/tailscale/tailscale version 2>&1 | head -1")
echo "JetKVM current tailscale version: $CURRENT_VERSION"

LATEST_VERSION=$(curl -sS "https://pkgs.tailscale.com/stable/?mode=json" | \
  grep '"TarballsVersion"' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

if [ -z "$LATEST_VERSION" ]; then
  echo "ERROR: could not determine latest stable version from pkgs.tailscale.com" >&2
  exit 1
fi
echo "Latest stable version: $LATEST_VERSION"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "Already up to date, nothing to do."
  exit 0
fi

TARBALL="tailscale_${LATEST_VERSION}_arm.tgz"
URL="https://pkgs.tailscale.com/stable/${TARBALL}"
SHA_URL="${URL}.sha256"

WORKDIR=$(mktemp -d)
curl -sS -o "$WORKDIR/$TARBALL" "$URL"
EXPECTED_SHA=$(curl -sS "$SHA_URL")
ACTUAL_SHA=$(shasum -a 256 "$WORKDIR/$TARBALL" | awk '{print $1}')
if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "ERROR: sha256 mismatch for $TARBALL (expected $EXPECTED_SHA, got $ACTUAL_SHA)" >&2
  rm -rf "$WORKDIR"
  exit 1
fi
echo "Downloaded and verified $TARBALL"

scp -i "$TMPKEY" "${SSH_OPTS[@]}" "$WORKDIR/$TARBALL" "${SSH_USER}@${JETKVM_IP}:/tmp/ts.tgz"
rm -rf "$WORKDIR"

ssh_jetkvm "
set -e
cd /tmp
tar xzf ts.tgz
/userdata/init.d/S22tailscale stop
sleep 2
cp /userdata/tailscale/tailscale /userdata/tailscale/tailscale.bak
cp /userdata/tailscale/tailscaled /userdata/tailscale/tailscaled.bak
cp tailscale_${LATEST_VERSION}_arm/tailscale /userdata/tailscale/tailscale
cp tailscale_${LATEST_VERSION}_arm/tailscaled /userdata/tailscale/tailscaled
chmod +x /userdata/tailscale/tailscale /userdata/tailscale/tailscaled
rm -rf /tmp/ts.tgz /tmp/tailscale_${LATEST_VERSION}_arm
/userdata/init.d/S22tailscale start
sleep 5
/userdata/tailscale/tailscale version | head -1
/userdata/tailscale/tailscale status
"

echo "JetKVM tailscale updated to ${LATEST_VERSION}."
echo "Previous binaries kept as tailscale.bak / tailscaled.bak on device for rollback."
