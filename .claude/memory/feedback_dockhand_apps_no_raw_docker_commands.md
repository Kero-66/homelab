---
name: feedback_dockhand_apps_no_raw_docker_commands
description: "For Dockhand-managed apps, use Dockhand's container API or docker compose from the compose file — never bare docker lifecycle commands, and never `docker run`/`docker exec -it` to spin up ad-hoc utility work on the TrueNAS host"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bf60f53f-96d8-4fc1-9d6b-d111d0212ec1
  modified: 2026-08-29T00:00:00.000Z
---

Even for one-off lifecycle fixes (e.g. restarting a container after fixing a permissions issue), Dockhand-managed apps must be restarted via Dockhand's own container API (`POST /api/containers/{id}/restart?env=1`, see PATTERNS.md "Dockhand API") or `docker compose -f /mnt/Fast/docker/<name>/compose.yaml restart` — not a bare `sudo docker restart <name>`.

**Why:** User caught this live (2026-08-18) right after I SSH'd in and ran `sudo docker restart maintainerr` directly to recover from a permissions crash-loop. This is the same anti-pattern CLAUDE.md already bans for midclt apps ("NEVER use `docker start/stop`" — use midclt instead) — it applies equally to Dockhand apps, just with Dockhand's API/compose as the correct layer instead of midclt. Bypassing the management layer even for "just a restart" defeats the reason the app is Dockhand-managed in the first place (state tracking, git-sync consistency).

**How to apply:** Whenever recovering/restarting/stopping a Dockhand-managed container (check `truenas/DOCKHAND_READINESS.md` for which stacks are Dockhand vs midclt), use the Dockhand API pattern from `ai/PATTERNS.md` → "Dockhand API (preferred over SSH for container lifecycle)", not raw `docker` commands over SSH — even for quick one-off fixes mid-troubleshooting.

**Extended 2026-08-29 — the gap this memory originally missed:** the rule above only covered *lifecycle* verbs against an *already-managed* container (restart/start/stop). It said nothing about `docker run` to spin up a brand-new, throwaway container on the TrueNAS host for an unrelated utility task — e.g. defaulting to `sudo docker run --rm caddy:latest caddy hash-password ...` over SSH just to generate a bcrypt hash for a Caddyfile edit. User caught this live: "yes because everything is managed via dockhand." `docker run` on that host creates a container Dockhand's inventory never sees, however briefly (`--rm` cleanup doesn't change that it happened) — it's the same violation in spirit as a raw lifecycle command, just against a container that doesn't exist yet instead of one that already does.

**How to apply (the actual decision rule):**
- **Never `docker run` a new container on the TrueNAS host** for a one-off utility task, regardless of `--rm`. If a CLI tool is needed for something unrelated to an app's own runtime (hashing, generating a config, testing), find or build the equivalent locally first (e.g. `htpasswd` was already installed locally and did the job `caddy hash-password` would have — checked with `which <tool>` before reaching for SSH/docker at all) — **default to local execution, only escalate to TrueNAS when the task is inherently host-specific** (reading a live config/log, checking disk state, something that must run where the data actually lives).
- `docker exec` into an **already-running, already-Dockhand-managed** container to invoke that container's own binary for a sanctioned, already-documented action (e.g. `docker exec caddy caddy reload` after an scp'd Caddyfile change, per CLAUDE.md's "Both systems" section) is a different, narrower, already-accepted pattern — it doesn't create or remove anything from Dockhand's inventory. Don't conflate "exec into an existing managed container for its own documented reload/signal action" with "run a brand-new container for an unrelated CLI utility." The first is fine; the second is the violation.
- Before reaching for SSH+docker at all, ask: does this need to run *on TrueNAS*, or does it just need *a binary* that happens to also exist in a TrueNAS-hosted container image? Only the former justifies SSH.
