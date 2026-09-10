# Claude Code Remote Control — Setup

## Why

Claude Code on web/mobile runs in an Anthropic-managed cloud VM with no route into the home
LAN — it can't reach TrueNAS (`192.168.20.22`), Infisical, or anything else on
`192.168.20.0/24`, even over Tailscale, because Tailscale on your phone/laptop doesn't extend
into that VM's network namespace (confirmed live: a `/dev/tcp` connect to `192.168.20.22:22`
from such a session times out, and every network-access level a cloud environment can be set
to — including "Full, any domain" — is HTTP(S)-only through Anthropic's own proxy; there is no
raw-socket egress option at any setting). Sessions started from web/mobile against infra tasks
(Bazarr, midclt, SSH to TrueNAS) hit a dead end for this reason.

**This account is on the Pro plan.** Anthropic's *self-hosted environments* feature — which
this doc previously described — would fix the above too, but it's a Team/Enterprise-only public
beta with no path to enable it on Pro. That entire approach (a self-hosted runner registered
against a `ccpool_...` cloud environment, Anthropic's runner-image/hardening guidance, etc.) is
**not available on this plan** and shouldn't be attempted. If the account ever moves to
Team/Enterprise, revisit `https://code.claude.com/docs/en/self-hosted-environments`.

## The actual fix on Pro: Remote Control

[Remote Control](https://code.claude.com/docs/en/remote-control) is a different, unrelated
feature — available on **Pro, Max, Team, and Enterprise** — and it solves the same problem more
simply: it connects claude.ai/code or the mobile app to a normal, local `claude` CLI process.
Execution and filesystem access stay on whatever machine runs that process; the web/mobile
client is just a window into it. No inbound ports are ever opened (outbound HTTPS only), so
there's nothing to expose and no port-forwarding to configure.

The process just needs to be (a) logged in and (b) kept running somewhere with real access to
the LAN. `truenas/stacks/claude-workstation/` provides that: a small always-on Docker container
on TrueNAS itself, built and deployed like any other Dockhand-managed stack in this repo. See
that stack's `compose.yaml` for the full design rationale (why its own bridge network, why the
whole home directory is persisted, why it doesn't touch `docker.sock`).

Running it as a container on TrueNAS (rather than on the workstation, `192.168.20.66`) was a
deliberate choice: the workstation is a "cold spare" per `CLAUDE.md` — likely off most of the
time — while TrueNAS is the one thing in this homelab that's always on. A Remote Control
process only exists while its host process is running, so putting it on the box that's actually
guaranteed to be up is what makes "fix this from my phone" reliable.

## One-time setup (interactive — cannot be done from a cloud/remote session)

Everything below needs a human at a real terminal (SSH to TrueNAS, or `docker exec -it`) — none
of it is automatable, and none of it can be done by a Claude session that doesn't already have
the LAN access this setup exists to provide. Chicken-and-egg by nature; do this once, by hand.

1. **Generate a dedicated git deploy key** — not `kero66_ssh_key`, a new one scoped to just
   this purpose (`ssh-keygen -t ed25519 -C claude-workstation`). Add its **public** half as a
   deploy key with **write** access on both `kero-66/homelab` and `kero-66/skills` (GitHub →
   repo → Settings → Deploy keys → Add deploy key, per repo — the same key can be added to
   both). Store the **private** half in Infisical at `/TrueNAS` as
   `CLAUDE_WORKSTATION_GIT_SSH_PRIVATE_KEY`. Deliberately separate from Dockhand's own
   (read-only) deploy key — independently revocable, and this is the only thing that uses it.

2. **Deploy the stack** via Dockhand git-sync (see `truenas/DEPLOYMENT_GUIDE.md` →
   "claude-workstation" section for the exact API call) — it will start, fail to log in (nothing
   is authenticated yet), and just sit there retrying under its restart policy. That's expected.

3. **Attach and authenticate:**
   ```bash
   ssh kero66@192.168.20.22 "sudo docker exec -it claude-workstation bash"
   ```

4. **Log in to Infisical** (this is a personal login — your own Infisical password, not a
   machine identity):
   ```bash
   infisical login -i --domain http://192.168.20.22:8081 --email <your-infisical-email>
   ```

5. **Load the SSH keys into the running agent** (entrypoint.sh already started one at a fixed
   socket path so `docker exec` sessions can reuse it):
   ```bash
   export SSH_AUTH_SOCK=/root/.ssh-agent.sock
   INFISICAL_PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
   infisical secrets get kero66_ssh_key --env dev --path /TrueNAS \
     --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 --plain 2>/dev/null | ssh-add -
   infisical secrets get CLAUDE_WORKSTATION_GIT_SSH_PRIVATE_KEY --env dev --path /TrueNAS \
     --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081 --plain 2>/dev/null | ssh-add -
   ```
   (If this is a fresh container that already restarted at least once *after* step 4, the keys
   may already be loaded automatically by `entrypoint.sh` — check with `ssh-add -l` first.)

6. **Clone the repo(s):**
   ```bash
   mkdir -p /root/workspace && cd /root/workspace
   git clone git@github.com:kero-66/homelab.git
   git clone git@github.com:kero-66/skills.git
   ```

7. **Log in to Claude Code** (prints a URL — open it in any device's browser, it doesn't need
   to be a browser on this container):
   ```bash
   claude auth login
   ```

8. **Accept the workspace-trust dialog** (one-time per project directory):
   ```bash
   cd /root/workspace/homelab && claude
   # accept the trust prompt, then exit (Ctrl-C or /exit)
   ```

9. **Accept the Remote Control confirmation** (also one-time):
   ```bash
   claude remote-control
   # answer 'y' to "Enable Remote Control? (y/n)", confirm it connects, then Ctrl-C
   ```

10. **Exit the shell.** The container's restart policy takes over from here — every future
    restart runs `entrypoint.sh`'s `claude remote-control` directly, non-interactively, and it
    will already recognize everything accepted above because it's all on the persisted
    `/root` volume.

11. **Connect from your phone or claude.ai/code**: the session will appear in your session list
    (named `claude-workstation`) once step 9 has run at least once.

## Caveats specific to this homelab

- **The container must actually be running** for a phone/web session to reach it — same
  fundamental constraint Remote Control has anywhere ("local process must keep running," per
  Anthropic's docs). Unlike the old self-hosted-runner plan, this isn't dependent on the
  workstation being powered on — it's on TrueNAS, which is always up — but a `docker stop`,
  TrueNAS reboot, or Dockhand redeploy still takes it offline until the container comes back
  (which `restart: unless-stopped` handles automatically).
- **Git credentials** — deliberately not baked into the image; loaded at runtime from Infisical
  via a dedicated deploy key (step 1 above), never a broadly-scoped personal token.
- **Resource sharing** — no fixed CPU/memory reservation (unlike Anthropic's self-hosted-runner
  sizing guidance, which doesn't apply here), but whatever task you actually give it competes
  for the same N150 CPU cores as Valheim and every other Dockhand stack while it's working. See
  `ai/OBSERVABILITY.md`'s host-resources dashboard if this ever needs investigating.
- **Not a replacement for local CLI** — for anything security-sensitive or high-blast-radius
  (TrueNAS app lifecycle, Infisical writes), running Claude Code directly at a terminal you're
  physically at is still simpler and more auditable than routing a phone session through this
  container. This mainly buys "fix this from my phone" for routine stuff.

## References

- https://code.claude.com/docs/en/remote-control — Remote Control (the feature this setup uses)
- https://code.claude.com/docs/en/cloud-environments — why a cloud/web session can't reach the
  LAN at any network-access setting (see "Access levels")
- https://code.claude.com/docs/en/self-hosted-environments — the Team/Enterprise-only feature
  this repo is **not** using; kept for reference in case the plan ever changes
- `truenas/stacks/claude-workstation/` — the actual Dockerfile, entrypoint, and compose.yaml
