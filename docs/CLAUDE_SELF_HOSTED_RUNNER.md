# Claude Code Self-Hosted Runner — Setup

## Why

Claude Code on web/mobile runs in an Anthropic-managed cloud VM with no route into the home LAN — it can't reach TrueNAS (`192.168.20.22`), Infisical, or anything else on `192.168.20.0/24`, even over Tailscale, because Tailscale on your phone/laptop doesn't extend into that VM's network namespace. Sessions started from web/mobile against infra tasks (Bazarr, midclt, SSH to TrueNAS) hit a dead end for this reason.

A **self-hosted environment** fixes this: a runner process on a box that's actually on the LAN (the workstation, `192.168.20.66`) picks up the session and executes it there, with real access to the network, Infisical CLI, and SSH keys already on that host.

## Prerequisite check — do this first

Self-hosted environments are a **Team/Enterprise-plan beta feature**, gated behind an org Owner toggle. Before doing anything else:

1. Confirm the Claude account is on a Team or Enterprise plan (not Pro/Max) — self-hosted environments aren't available otherwise.
2. An Owner must enable **Allow self-hosted environments** on the [Cloud environments admin page](https://claude.ai/admin-settings/cloud-environments). The **New** button for creating an environment doesn't appear until this is on.
3. A GitHub connection must exist for the org so the repo is pickable from the environment picker.

If the account is Pro/Max, stop here — this path isn't available; infra tasks stay a local-CLI-only workflow until/unless the plan changes.

## Setup

### 1. Prep the workstation (192.168.20.66, Fedora)

- Install Claude Code **v2.1.224+** (any standard method — see `claude update` if already installed, or reinstall from the `latest` channel).
- Confirm Git 2.24+.
- Sign in: `claude auth login` (must be an account holding the Owner role, or someone with Owner hands you the environment secret from step 2).
- Verify the runner subcommand exists:
  ```bash
  claude self-hosted-runner --help
  ```
  If this prints generic `claude --help` instead of runner flags (`--environment-secret-file`, etc.), the version is too old — update first.

### 2. Guided setup (recommended)

```bash
claude self-hosted-runner setup
```

This is an interactive Claude Code session that creates the environment in the admin UI, starts a local runner, verifies registration, and writes `./runner-setup/CHEAT-SHEET.md`. Run it directly on the workstation.

### 3. Manual setup (if guided setup isn't usable)

**Create the environment** — [Cloud environments admin page](https://claude.ai/admin-settings/cloud-environments) → Self-hosted environments → **New** → name it (e.g. `homelab-workstation`) → **Create**. On the next step, **Copy environment key** — shown once, expires in 365 days. Note the `ccpool_...` ID shown in the environment's detail dialog.

**Store the secret on the workstation:**
```bash
sudo mkdir -p /etc/claude
(umask 077 && sudo tee /etc/claude/environment-secret > /dev/null)
# paste the secret, press Enter, then Ctrl-D
```

**Start the runner:**
```bash
claude self-hosted-runner \
  --environment-secret-file /etc/claude/environment-secret \
  --base-dir /home/kero66/claude-runner-workspace
```
(`--base-dir` must exist or be creatable by the runner user — it holds per-session checkouts.)

**Verify**: back on the [Cloud environments admin page](https://claude.ai/admin-settings/cloud-environments), status flips from "No runners deployed" to "Healthy" within seconds.

### 4. Route a session to it

Start a session at claude.ai/code (or the mobile app) and pick the new environment from the environment picker — self-hosted environments appear alongside the Anthropic-hosted ones. The runner clones with whatever git credentials the workstation already has, so a repo the workstation can already clone (or a public one) works without extra setup.

## Caveats specific to this homelab

- **Runner exits when idle** — the quickstart runner is not persistent; it exits once its sessions finish. For this to be reliably usable from mobile, it needs to run under something that restarts it (systemd unit, cron `@reboot`, or a simple restart loop) on the workstation. Not set up yet — do this before relying on it for on-the-go infra fixes.
- **Git credentials** — the runner clones with whatever creds already exist on the workstation. If the workstation doesn't already have push access configured for `kero-66/homelab` / `kero-66/skills`, sessions routed here can pull but not push — set that up (existing SSH deploy keys or `gh auth login`) before depending on this for real fixes.
- **Secrets** — this gives the runner host (and therefore any Claude session routed to it) the same LAN/Infisical access as the workstation user. Treat the environment secret (`/etc/claude/environment-secret`) like any other credential — it's what lets a cloud-issued session execute locally.
- **Not a replacement for local CLI** — for anything security-sensitive or high-blast-radius (TrueNAS app lifecycle, Infisical writes), running Claude Code directly on the workstation terminal is still simpler than routing a web/mobile session through it. The runner mainly buys you "fix this from my phone" for routine stuff.

## References

- https://code.claude.com/docs/en/self-hosted-environments-quickstart — this walkthrough
- https://code.claude.com/docs/en/self-hosted-environments-deploy — production hardening, egress control, git credential options, running under systemd/Kubernetes
- https://code.claude.com/docs/en/self-hosted-environments — concepts, runner lifecycle
