---
name: feedback_dockhand_git_stack_file_only_changes_need_force_recreate
description: "Dockhand git-stack sync+deploy does not pick up changes to a bind-mounted file (e.g. Caddyfile) unless compose.yaml itself also changed — must force-recreate against Dockhand's synced compose file"
metadata:
  type: feedback
---

For a Dockhand git-stack whose compose.yaml bind-mounts a config file with a relative path
(e.g. caddy's `./Caddyfile:/etc/caddy/Caddyfile:ro`, resolved against Dockhand's own git clone
directory), running `POST /api/git/stacks/<id>/sync` then `POST /api/git/stacks/<id>/deploy` is
**not sufficient** when only that mounted file changed and compose.yaml itself did not.

**Why:** `sync` correctly pulls the new file into Dockhand's git clone
(`/mnt/.ix-apps/app_mounts/dockhand/data/git-repos/TrueNAS/<stack>/...`). But `deploy` runs
`docker compose up -d` under the hood, which diffs the compose config — since compose.yaml is
unchanged, compose sees nothing to do and reports `"Container <name> Running"` (no recreate). The
running container's bind mount is still attached to the *old* file inode (git checkout replaces
files via unlink+create, not in-place edit), so the container keeps serving stale content
indefinitely even though `sync` succeeded and `deploy` reported success. Confirmed live
2026-08-29: updated `truenas/stacks/caddy/Caddyfile` to add a new reverse-proxy block, sync+deploy
both reported success, but `docker exec caddy grep <newblock> /etc/caddy/Caddyfile` still failed
and Caddy's automatic-HTTPS fallback silently 308-redirected the new unmatched hostname to
`https://`, which looked like a browser problem but wasn't.

**How to apply:** After a `sync`+`deploy` for a config-file-only change, verify the actual running
container's file content (`docker exec <name> cat/grep <path>`) — don't trust job "success" status
alone. If stale, SSH in and run
`docker compose -p <stack> -f <git-clone-dir>/truenas/stacks/<stack>/compose.yaml up -d --force-recreate`
directly against Dockhand's own synced compose file (same file Dockhand itself used — this isn't
bypassing Dockhand's inventory, since project name and compose file both match what Dockhand
already deployed). See [[feedback_dockhand_apps_no_raw_docker_commands]] for why raw
`docker restart` is still wrong here — recreate via compose, not a bare lifecycle command.
