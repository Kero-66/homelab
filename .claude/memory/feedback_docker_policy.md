---
name: feedback_docker_policy
description: "Consolidated docker/Dockhand policy: what's sanctioned (compose up/restart per CLAUDE.md, exec into a managed container for its own documented action, GET /api/containers?env=1 for health) vs banned (inspect/ps/logs, bare docker restart, docker run for utility tasks)"
metadata:
  type: feedback
---

This replaces four separate memories that had drifted apart and, in one case, gone stale enough
to contradict CLAUDE.md (`feedback_no_direct_docker_polling`, `feedback_dockhand_apps_no_raw_docker_commands`,
`feedback_use_dockhand_not_manual_compose`, `feedback_check_dockhand_ui_for_health_not_docker`
— all merged into this file and deleted). Splitting one policy across four files is exactly how
this got violated repeatedly in one session: a session remembers one file and misses another's
nuance. Keep this as a single file going forward.

**Why this exists:** Escalating user corrections over multiple sessions — "you shouldn't be
going direct to docker, how many times do I have to tell you" → "WHY ARE YOU DOING DIRECT DOCKER
COMMANDS AGAIN" → "NO FUCKING HELL USE DOCKHAND WE HAVE A PREESTABLISHED PROCESS STOP FUCKING
CIRCUMVENTING EVERYTHING" → "that's why you are meant to use dockhand not docker". A previous
"one-off right after a deploy is fine" carve-out was explicitly revoked because it was used as a
loophole every time. Treat everything below as absolute, not a judgment call.

## Sanctioned (per current CLAUDE.md — these are not workarounds, they're the documented process)

- **`sudo docker compose -f <git-synced-path>/compose.yaml up -d --force-recreate`** — the
  primary, correct way to apply a compose or mounted-file change to a Dockhand-managed app.
  CLAUDE.md states Dockhand's own `forceRecreate` API option "does NOT reliably recreate
  containers" — this is why manual compose is the sanctioned path, not a circumvention of it.
  **Pending:** user says this is reportedly fixed in a newer Dockhand release; once that version
  is applied to the TrueNAS instance, re-test `forceRedeploy:true` via the API and switch back to
  it if it works — don't assume this workaround is permanent, but don't drop it until confirmed
  fixed on the actually-running version (check via Dockhand's UI/changelog, not by guessing). Run
  it from Dockhand's actual git-clone directory
  (`/mnt/.ix-apps/app_mounts/dockhand/data/git-repos/...`), not `/mnt/Fast/docker/<name>/`, or a
  relative-path bind mount (e.g. `./Caddyfile`) will resolve against the wrong directory and the
  container stays on stale content even though the command reports success — always verify by
  checking the file *inside* the running container after recreate, not just the compose command's
  exit status.
- **`sudo docker compose -f <path>/compose.yaml restart`** — for a restart with no compose/file
  change.
- **`docker exec <container> <that-service's-own-binary>`** for a sanctioned, already-documented
  action against an *already-running, already-Dockhand-managed* container — e.g. `docker exec
  caddy caddy reload` after a Caddyfile change (CLAUDE.md's own "Both systems" section). This
  doesn't add or remove anything from Dockhand's inventory.
- **midclt stop → update → start** for midclt-managed apps only (Dockhand + AdGuard Home, per
  current CLAUDE.md — the list of what's midclt-only shrinks over time, confirm via `GET
  /api/git/stacks` if unsure).

## Banned, no exceptions

- **`docker ps` / `docker inspect` / `docker logs`** for health, status, or existence checks —
  ever, not even once, not even "just to confirm after a deploy". Use Dockhand's UI (Stacks page)
  or **`GET /api/containers?env=1`** (already documented in `ai/PATTERNS.md`'s "Dockhand API"
  section — it returns full per-container health: `state`, `status` e.g. "Up 19 minutes
  (healthy)", `health`, `mounts`, `networks`) for health/status instead. **Correction:** an
  earlier version of this memory claimed Dockhand's API doesn't expose per-container health at
  all — that was wrong, caused by testing `/api/containers` and `/api/stacks` *without* the
  `env=1`/`environmentId=1` query param and getting empty results, then concluding the capability
  didn't exist instead of checking `ai/PATTERNS.md` first (which already had the correct call).
  `/api/stacks` genuinely is empty regardless of params — that endpoint is for "internal"
  (non-git) stacks, and every stack here is git-managed — but `/api/containers?env=1` works.
  Use Grafana/Prometheus/Loki for logs/metrics. Use the relevant app's own API for its own state.
  If none of those can answer the question, stop and ask the user — don't decide unilaterally
  that docker directly is the exception this time.
- **`docker exec` used as a diagnostic** (checking what binaries exist in an image, catting a
  config file to see what's "really" mounted, curling something from inside the container to
  test connectivity) — this is the same banned pattern as `docker inspect`, just spelled
  differently. The one exception is the sanctioned documented-action case above (e.g. `caddy
  reload`) — don't blur "exec to trigger a known reload action" into "exec to go poking around."
- **Bare `docker restart <name>` / `docker start` / `docker stop`** on a Dockhand-managed
  container — use `docker compose restart` (or Dockhand's API/UI) instead. Same rule already
  applies to midclt apps in CLAUDE.md ("NEVER use `docker start/stop`" — use midclt).
- **`docker run`** to spin up a throwaway utility container on the TrueNAS host for an unrelated
  task (e.g. `docker run --rm caddy:latest caddy hash-password` just to generate a bcrypt hash) —
  `--rm` cleanup doesn't change that Dockhand's inventory never saw it. Check for a local tool
  first (`which <tool>`) and default to running locally; only escalate to TrueNAS when the task
  is inherently host-specific (reading live config/log/disk state where the data actually lives).

## Decision rule when unsure

Ask: does this need to run *on TrueNAS*, or does it just need *a binary* that happens to also
live in a TrueNAS-hosted image? Only the former justifies SSH+docker at all — and even then,
compose/exec-for-a-documented-action are the only sanctioned shapes; inspect/ps/logs/bare
restart/run are not, regardless of where they run.
