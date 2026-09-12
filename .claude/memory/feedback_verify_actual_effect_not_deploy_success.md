---
name: feedback_verify_actual_effect_not_deploy_success
description: "A clean deploy + healthy container restart doesn't prove a config file change took effect — verify the actual mounted content on disk after any change to a stack whose mount pattern you haven't already confirmed works"
metadata:
  type: feedback
  originSessionId: 5d0e53a2-40b0-4cc4-9167-82561e850ee6
  modified: 2026-09-10T00:00:00.000Z
---

Spent a large chunk of a 2026-09-09/10 observability session chasing why a Loki retention fix
and a new Alloy scrape job "weren't working" after clean Dockhand deploys and healthy container
restarts — turned out `config.alloy`/`loki-config.yaml` were bind-mounted from a stale, absolute
host path that predated the stack's Dockhand git-sync migration and was never actually receiving
the git-synced content. Every deploy reported success; every restart came up healthy; the
container was just quietly running its old config the whole time.

**Why:** "deploy succeeded" and "container is healthy" only prove the *orchestration* worked, not
that the specific file content you intended to change is what's actually mounted. A stack that's
never had this specifically verified (i.e., you haven't already confirmed its compose.yaml mount
paths resolve to the git-synced source) can silently absorb edits forever.

**How to apply:** after any config-file (not just compose.yaml) change to a Dockhand/git-synced
stack, verify the *actual mounted content* — compare file mtimes between the live mount path and
the Dockhand-synced source (`stat -c '%Y %n'` on both), or `docker inspect --format
'{{range .Mounts}}...{{end}}'` to confirm the mount source, or just read the file at its real host
path — before trusting that a "successful" deploy did what you intended. This applies especially
to any stack where the compose.yaml wasn't written using the standard `./relative-path` pattern
(which resolves inside Dockhand's own git clone and is known-good) — an absolute
`/mnt/Fast/docker/...` path in a volume mount is a signal to double-check, not assume.
