#!/bin/sh
# Reruns build_playlist.py for every manual-watch-order franchise on a fixed
# interval. See media/scripts/watch_orders/README.md's "Status" table -- this
# list must match its "Manual" rows exactly. Deliberately NOT a glob over
# /scripts/*.json: that directory also holds JSONs superseded by the
# SmartLists path (e.g. macross.json), and re-running one of those would
# create a duplicate playlist alongside the live SmartList-managed one.
set -eu

FRANCHISES="trigun.json votoms.json hack.json steinsgate.json robotech.json tekkaman.json gundam_uc.json"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-86400}"

while true; do
  echo "$(date -Iseconds) watch-orders-runner: starting sweep"
  for name in $FRANCHISES; do
    f="/scripts/$name"
    if [ ! -f "$f" ]; then
      echo "$(date -Iseconds) watch-orders-runner: SKIP $name -- file not found (list in entrypoint.sh vs README out of sync?)"
      continue
    fi
    echo "$(date -Iseconds) watch-orders-runner: building $name"
    # build_playlist.py exits 0 and builds a partial playlist for entries
    # still missing content -- a nonzero exit here is a real bug (bad JSON,
    # missing JELLYFIN_KEY), not "still downloading", and is worth noticing.
    if ! python3 /scripts/build_playlist.py "$f"; then
      echo "$(date -Iseconds) watch-orders-runner: FAILED $name (see error above) -- will retry next sweep"
    fi
  done
  echo "$(date -Iseconds) watch-orders-runner: sweep complete, sleeping ${INTERVAL_SECONDS}s"
  sleep "$INTERVAL_SECONDS"
done
