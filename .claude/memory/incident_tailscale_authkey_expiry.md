---
name: incident-tailscale-authkey-expiry
description: TrueNAS tailscale container crash-loop from expired reusable auth key, not node key expiry — diagnosis and fix
metadata:
  type: project
---

2026-08-25: TrueNAS `tailscale` container crash-looped with `invalid key: API key does not exist` after being force-recreated. Root cause: the reusable auth key stored in Infisical (`/TrueNAS` path, rendered into `/mnt/Fast/docker/tailscale/.env` as `TS_AUTHKEY`) had its own expiry (Tailscale defaults new auth keys to 90 days) — separate from the node's own session key (~180 days, stored in the container's state dir and normally reused across restarts without touching `TS_AUTHKEY` at all). A container recreate forced a fresh login, which then hit the expired auth key.

**Why:** Tailscale auth keys created without explicitly disabling expiry silently die after 90 days. Since this key is only touched on a forced re-auth (state loss, force-recreate), the failure is invisible until the next recreate — which can be weeks/months after the key expired.

**Fix applied**: key expiry disabled for the truenas auth key in the Tailscale admin console (https://login.tailscale.com/admin/settings/keys). No further action needed unless a *new* key is generated for this node — if so, disable expiry on it too.

**How to apply:** If `tailscale` container crash-loops with `invalid key: API key does not exist` or `tailscale up failed: exit status 1`, check the auth key's expiry status in the Tailscale admin console before assuming DNS/network is the cause (DNS-looking `context canceled` errors on `controlplane.tailscale.com` can be a red herring — the actual failure only shows up as `invalid key`, not a DNS error).

**Fix procedure** (if key expires again on a different node): generate new key with expiry disabled → set in Infisical (`infisical secrets set TS_AUTHKEY <key> --env dev --path /TrueNAS`) → `docker restart infisical-agent` to re-render `.env` → `docker compose -f /mnt/.ix-apps/app_mounts/dockhand/data/stacks/TrueNAS/tailscale/compose.yaml up -d --force-recreate` (plain `restart` does NOT pick up an env file change or clear stale auth state — must force-recreate).

Also noted: Tailscale's compose file lives under Dockhand's actual live path `/mnt/.ix-apps/app_mounts/dockhand/data/stacks/TrueNAS/tailscale/compose.yaml`, not `/mnt/.ix-apps/app_mounts/dockhand/data/stacks/tailscale/` as the naming pattern for other apps might suggest — the git-repos mirror directory also has many decoy `tailscale/compose.yaml`-shaped paths that are NOT the live one. Confirm via `docker inspect <container> --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}'` if unsure.
