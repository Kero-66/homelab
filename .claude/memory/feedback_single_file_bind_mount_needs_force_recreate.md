---
name: feedback-single-file-bind-mount-needs-force-recreate
description: A Dockhand git sync never lands a change to a single-file bind mount, even with forceRedeploy true — and a 200 from a reload endpoint does not mean the new content was read
metadata:
  type: feedback
---

A Dockhand git sync updates the file on disk but the container keeps the OLD inode when the mount
is a *single file* (`./config.alloy:/etc/alloy/config.alloy`), because git checkout replaces files
by rename. This holds even on a stack with `forceRedeploy: true` — `grafana-alloy` (stack id 17),
confirmed live 2026-09-18. Directory mounts are unaffected.

**Why:** the docs said the `scp` + force-recreate dance was "no longer required" after the upstream
Dockhand fix, and `forceRedeploy: true` looked like sufficient proof the change would land. It
wasn't. Worse, Alloy's `POST /-/reload` returned **HTTP 200** while re-reading the stale inode, so
every signal said "deployed" while the running config was unchanged — 20 minutes were spent
debugging a regex that was never loaded.

**How to apply:** for any config change to a file-mounted (not directory-mounted) path, run
`sudo docker compose -f compose.yaml up -d --force-recreate <service>` from the git-clone path
after the sync, and verify the *behaviour* changed — never a reload endpoint's status code. See
CLAUDE.md "Caveat 2" under Dockhand-managed apps, and [[feedback-reverify-doc-claims-against-live-state]].
