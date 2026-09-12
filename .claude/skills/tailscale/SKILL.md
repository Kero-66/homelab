---
name: tailscale
description: Manage this homelab's Tailscale mesh network — check tailnet/device status, deploy Tailscale to a new device, rotate/troubleshoot the auth key, reason about split-DNS and subnet-route config, and know what still requires the admin console UI. Use whenever the user mentions Tailscale, the tailnet, "over Tailscale" vs LAN, adding a device to remote access, or a tailscale container crash-loop.
---

# Tailscale

This homelab runs Tailscale as a subnet router so every `.home` service is reachable
identically from the LAN or remotely, with no port forwarding. This skill is the single place
that knows the real, verified operational details — read it before SSHing in or guessing at a
compose/env change. See `truenas/AGENTS.md` for the surrounding TrueNAS conventions (SSH,
Dockhand, secrets) this skill assumes.

## Current tailnet state

| Device | Role | Address | Notes |
|---|---|---|---|
| `truenas` | Subnet router | Tailscale IP `100.98.14.66`, advertises `192.168.20.0/24` | Container `tailscale` on TrueNAS (192.168.20.22) |
| JetKVM | Client | LAN `192.168.20.25` | Joined via `https://jetkvm.com/install-tailscale.sh -y`, own SSH key at Infisical `/networking/JETKVM_SSH_PRIVATE_KEY` |
| Workstation (192.168.20.66) | — | Not documented as joined | Verify with `tailscale status` on the box itself before assuming it's on the tailnet |

Split DNS: Tailscale admin console → DNS → custom nameserver `100.98.14.66` (AdGuard Home),
restricted to the `home` domain. This is *why* `http://jellyfin.home` etc. work the same over
Tailscale as on LAN — don't reinvent this with per-service Tailscale Serve/Funnel config.

## Where it's managed

**Dockhand-managed (git-synced), NOT midclt** — migrated 2026-08-15 (`truenas/DOCKHAND_READINESS.md`).
`truenas/TRUENAS_STATE.md` still lists it under midclt in one spot — that line is stale, trust
`CLAUDE.md`'s App Management section and `DOCKHAND_READINESS.md` instead.

**Live compose path has a trap**: it is
`/mnt/.ix-apps/app_mounts/dockhand/data/stacks/TrueNAS/tailscale/compose.yaml` — note the extra
`TrueNAS/` path segment. The git-repo mirror directory has other `tailscale/compose.yaml`-shaped
paths that are decoys, not the live one. If unsure which file is actually live:
```bash
docker inspect tailscale --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}'
```

**Update pattern** (standard Dockhand flow — see `ai/PATTERNS.md`):
```bash
scp truenas/stacks/tailscale/compose.yaml kero66@192.168.20.22:/mnt/Fast/docker/tailscale/compose.yaml
ssh kero66@192.168.20.22 "sudo cp /mnt/Fast/docker/tailscale/compose.yaml /mnt/.ix-apps/app_mounts/dockhand/data/stacks/TrueNAS/tailscale/compose.yaml && sudo docker compose -f /mnt/Fast/docker/tailscale/compose.yaml up -d --force-recreate"
```
`network_mode: host` + `cap_add: [NET_ADMIN, SYS_MODULE]` works fine under Dockhand — no special
handling needed beyond the standard force-recreate flow.

## Auth key

- Infisical secret: `TRUENAS_TAILSCALE_AUTH_KEY` at `/TrueNAS` — rendered by
  `truenas/stacks/infisical-agent/tailscale.tmpl` into `/mnt/Fast/docker/tailscale/.env` as
  `TS_AUTHKEY`. (The stale setup comment at the top of `truenas/stacks/tailscale/compose.yaml`
  still says `TAILSCALE_AUTHKEY` at `/TrueNAS/TAILSCALE_AUTHKEY` — that's leftover from before
  the tmpl was wired up; the tmpl + live `.env` is the source of truth.)
- **The reusable auth key has its own expiry, separate from the node's session key** — see
  `.claude/memory/incident_tailscale_authkey_expiry.md`. Tailscale defaults new keys to 90-day
  expiry. The node's own session key (~180 days) is what normally survives restarts, so an
  expired `TS_AUTHKEY` is invisible until something forces a fresh login (state loss, a
  force-recreate) — which can be weeks after it actually died.
  - Current key: expiry already disabled in the Tailscale admin console (fixed 2026-08-25).
  - **If a new key is ever generated for this node, disable its expiry too**, or this incident
    repeats on the next force-recreate.
- Rotation procedure:
  ```bash
  infisical secrets set TRUENAS_TAILSCALE_AUTH_KEY <new-key> --env dev --path /TrueNAS
  # infisical-agent re-renders .env within ~5min on its own polling interval, or force it:
  ssh kero66@192.168.20.22 "sudo docker restart infisical-agent"
  ssh kero66@192.168.20.22 "sudo docker compose -f /mnt/Fast/docker/tailscale/compose.yaml up -d --force-recreate"
  ```
  Plain `docker compose restart` does **not** pick up an env file change or clear stale auth
  state — must be `--force-recreate`.

## Checking status

Use the standard ssh-agent pattern (never a temp key file — see `ai/PATTERNS.md` "TrueNAS SSH"):
```bash
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null | ssh-add - 2>/dev/null
ssh kero66@192.168.20.22 "sudo docker exec tailscale tailscale --socket=/tmp/tailscaled.sock status --json"
ssh-agent -k > /dev/null
```
Or use `scripts/status.sh` in this skill's directory, which wraps the same pattern.

Look for `"BackendState": "Running"` (this is also the container's own healthcheck). A
`Backend state: Running` line in `docker logs tailscale` confirms the same thing without a
docker exec.

## Deploying Tailscale to a new device

Generalized from how JetKVM was joined (see `ai/SESSION_NOTES.md` 2026-02-26 entry):

1. Install Tailscale using whatever method fits the device (vendor install script, package
   manager, or the official install — `curl -fsSL https://tailscale.com/install.sh | sh` on a
   generic Linux box).
2. Authenticate with the reusable key from Infisical: `tailscale up --authkey=<TRUENAS_TAILSCALE_AUTH_KEY> --ssh` (add flags like `--advertise-routes` only if this device should itself be a subnet router — most new devices shouldn't be).
3. Confirm it shows up in the Tailscale admin console (https://login.tailscale.com/admin/machines) under the expected name, and that DNS resolves for it if relevant.
4. If it should be reachable as `http://<name>.home`: add a block to `truenas/stacks/caddy/Caddyfile` proxying to its LAN or Tailscale IP (by IP, not container name — it's not a Docker container on this host), scp to the live Caddyfile location, `docker exec caddy caddy reload`. Then add an AdGuard DNS rewrite for `<name>.home` → 192.168.20.22 (same pattern as every other `.home` entry).
5. Store any device-specific credentials (SSH keys, etc.) in Infisical, not in this repo — see JetKVM's `/networking/JETKVM_SSH_PRIVATE_KEY` for the pattern.

## Troubleshooting

**Container crash-loops with `invalid key: API key does not exist` or `tailscale up failed:
exit status 1`** — check the auth key's expiry in the admin console **first**, before assuming
DNS or network is the cause. A `context canceled` error talking to `controlplane.tailscale.com`
in the logs looks DNS-related but is frequently a red herring for this exact failure — the real
tell is the `invalid key` message. See the incident memory file above for the full writeup.

**A `.home` domain works on LAN but not over Tailscale (or vice versa)**: check split DNS is
still configured in the Tailscale admin console (DNS → nameserver `100.98.14.66` restricted to
`home`) — this is external admin-console state, not anything in this repo, and can be reset by
account-level changes outside our control.

**A device shows as "new" after a redeploy instead of keeping its existing identity/IP**: the
state volume didn't mount (for TrueNAS: `/mnt/Fast/docker/tailscale`) — stop and investigate
before approving what looks like a new device's subnet route.

**Newly advertised or changed subnet routes don't propagate**: routes require manual approval
in the admin console (Machines → the device → Subnet routes → Approve) — there's no established
API/automation for this in this repo yet.

## What's not automatable here

No API token/automation pattern is established in this repo for the Tailscale admin console
itself — auth key generation/expiry toggling, subnet route approval, ACL edits, and adding
external collaborators/logins all require the web UI
(https://login.tailscale.com/admin). Don't invent a `curl`-based approach for these without
checking Tailscale's actual API docs first and getting it working end-to-end — the same
research-first rule as everything else in this repo.
