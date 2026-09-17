#!/bin/sh
# Reruns build_playlist.py for every manual-watch-order franchise on a fixed
# interval. See ./scripts/README.md's "Status" table -- this list must match
# its "Manual" rows exactly.
#
# Still deliberately NOT a glob over /scripts/*.json: the list is the explicit
# record of what we intend to publish, and a stray/experimental JSON dropped in
# the directory should not silently start creating playlists in Jellyfin.
#
# macross.json was previously excluded here because SmartLists owned Macross and
# running both would have produced duplicate playlists. SmartLists were retired
# 2026-09-18 (we prefer researched, version-controlled orders over external
# lists that can silently drift), so it is now enabled. Note it defines TWO
# variants (release_order and chronological_order) and therefore creates two
# playlists -- intentional: the community disagrees on where Macross Zero goes,
# so both are published rather than picking one.
#
# robotech.json is kept listed even though its library content has been removed
# (watched, then cleaned up by maintainerr). build_playlist.py logs
# "skipped entirely: ... (nothing resolved yet)" and moves on, so it costs one
# harmless log line per sweep and self-heals if the content is ever re-acquired.
set -eu

FRANCHISES="trigun.json votoms.json hack.json steinsgate.json robotech.json tekkaman.json gundam_uc.json macross.json broken_blade.json"
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
