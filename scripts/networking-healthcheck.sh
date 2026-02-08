#!/usr/bin/env bash
set -euo pipefail

# Quick health check for networking stack
BASE=http://localhost
SERVICES=("/health" "/jackett" "/sonarr" "/radarr" "/prowlarr" "/jellyfin" "/qbittorrent" "/homepage")

echo "Checking networking services on ${BASE}"
failed=0
for p in "${SERVICES[@]}"; do
  echo -n " - ${p}... "
  if curl -fsS -o /dev/null "${BASE}${p}" ; then
    echo OK
  else
    echo FAIL
    failed=1
  fi
done

if [ "$failed" -eq 0 ]; then
  echo "All checks OK"
  exit 0
else
  echo "Some checks failed"
  exit 2
fi
