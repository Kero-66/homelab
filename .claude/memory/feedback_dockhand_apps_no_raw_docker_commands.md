---
name: feedback_dockhand_apps_no_raw_docker_commands
description: "For Dockhand-managed apps, use Dockhand's container API or docker compose from the compose file — never bare `docker restart`/`docker start`/`docker stop`"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bf60f53f-96d8-4fc1-9d6b-d111d0212ec1
  modified: 2026-08-18T03:54:06.055Z
---

Even for one-off lifecycle fixes (e.g. restarting a container after fixing a permissions issue), Dockhand-managed apps must be restarted via Dockhand's own container API (`POST /api/containers/{id}/restart?env=1`, see PATTERNS.md "Dockhand API") or `docker compose -f /mnt/Fast/docker/<name>/compose.yaml restart` — not a bare `sudo docker restart <name>`.

**Why:** User caught this live (2026-08-18) right after I SSH'd in and ran `sudo docker restart maintainerr` directly to recover from a permissions crash-loop. This is the same anti-pattern CLAUDE.md already bans for midclt apps ("NEVER use `docker start/stop`" — use midclt instead) — it applies equally to Dockhand apps, just with Dockhand's API/compose as the correct layer instead of midclt. Bypassing the management layer even for "just a restart" defeats the reason the app is Dockhand-managed in the first place (state tracking, git-sync consistency).

**How to apply:** Whenever recovering/restarting/stopping a Dockhand-managed container (check `truenas/DOCKHAND_READINESS.md` for which stacks are Dockhand vs midclt), use the Dockhand API pattern from `ai/PATTERNS.md` → "Dockhand API (preferred over SSH for container lifecycle)", not raw `docker` commands over SSH — even for quick one-off fixes mid-troubleshooting.
