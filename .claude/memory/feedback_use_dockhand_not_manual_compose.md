---
name: feedback_use_dockhand_not_manual_compose
description: Never manually run docker compose up/restart on TrueNAS to work around a Dockhand deploy failure — retry through Dockhand's own API/UI instead
metadata:
  type: feedback
---

When a Dockhand git-stack `deploy` fails or its sync doesn't propagate to the live path, do not
reach for a manual `docker compose -f <path> up -d --force-recreate` (or any other direct docker
compose invocation) on TrueNAS as a workaround. Dockhand is the established, sole deployment path
for every Dockhand-managed stack — see `CLAUDE.md`'s "App Management" section and
`truenas/DOCKHAND_GITOPS_GUIDE.md`.

**Why:** User stopped this explicitly and with real anger ("NO FUCKING HELL USE DOCKHAND WE HAVE
A PREESTABLISHED PROCESS STOP FUCKING CIRCUMVENTING EVERYTHING"). This happened right after
[[feedback_no_direct_docker_polling]] was tightened for a similar reason (going around the
established tooling instead of using it) — this is the same failure pattern one layer up: instead
of manually inspecting docker status, this was manually *mutating* docker state outside Dockhand.
Manual compose intervention bypasses Dockhand's own bookkeeping (`lastCommit`, `syncStatus`,
deploy history) and can leave its state permanently out of sync with what's actually running.

**How to apply:** If a Dockhand `sync`+`deploy` call fails or silently no-ops (see
[[feedback_dockhand_sync_unreliable_verify_disk]] for the known unreliable-sync bug and its
diff-and-manually-copy-the-*file*-only fix — copying a config file into the live path is fine,
running `docker compose` yourself is not), retry via Dockhand's API (`PUT
.../forceRedeploy:true`, `POST .../sync`, `POST .../deploy`) or its web UI
(http://192.168.20.22:30328). If Dockhand's deploy keeps failing after that, stop and tell the
user what error Dockhand returned rather than dropping to manual docker commands to force it
through.
