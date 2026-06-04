# Claude Code Instructions — Homelab Project

## Start Every Session
1. Read `.claude/memory/MEMORY.md` — accumulated feedback, gotchas, service-specific decisions
2. Read `ai/SESSION_NOTES.md` — current work in progress
3. Read `ai/todo.md` — pending tasks
4. Before any command, check `ai/PATTERNS.md` — verified copy-paste commands
5. Run `mempalace wake-up` — load memory palace context (past decisions, known failures, session history)

## Infrastructure Quick Reference
- **TrueNAS**: 192.168.20.22 (SSH as kero66) — Version 25.10.1
- **Workstation**: 192.168.20.66 (Fedora, cold spare)
- **JetKVM**: 192.168.20.25 — SSH as root@, key in Infisical `/networking/JETKVM_SSH_PRIVATE_KEY`
- **Pools**: `/mnt/Fast` (NVMe), `/mnt/Data` (HDD)
- **Configs**: `/mnt/Fast/docker/<service>/`
- **Media**: `/mnt/Data/media/{shows,movies,anime,music,tv,downloads}`
- **Downloads**: `/mnt/Data/downloads/{qbittorrent,sabnzbd,complete,incomplete}`

## Architecture
- **Secrets**: Infisical for infrastructure secrets, Bitwarden for personal passwords
- **Infisical Agent**: renders `.env` → `/mnt/Fast/docker/{arr-stack,downloaders,jellyfin,homepage}/`
- **User access**: kero66 (UID 1000) for all daily ops — truenas_admin is break-glass only
- **TrueNAS deployment**: `midclt` via SSH — NOT docker-compose CLI, NOT REST API for compose updates
- **Compose files in repo**: reference/documentation only (except when pushing updates)
- **Networking**: cross-stack via explicit network joins
- **DNS**: AdGuard Home (192.168.20.22) only, no fallback

## Infisical
- **ALL secrets are `--env dev`** — no prod environment exists
- **NEVER run `infisical secrets` without targeting a specific key** — table output exposes all secrets in cleartext
- **Correct pattern**: `infisical secrets get <KEY> --env dev --path /TrueNAS --plain 2>/dev/null`

## TrueNAS SSH — Secure Pattern
**Use ssh-agent pattern from `ai/PATTERNS.md` — ALWAYS check before running SSH commands.**
- kero66 cannot access Docker socket directly — use `sudo docker ...`
- kero66 UID on TrueNAS: **72**
- API key: `truenas_admin_api` (env dev, path /TrueNAS)
- API requires HTTPS — http returns 308 that drops auth header

## TrueNAS App Management — CRITICAL
- **NEVER use REST API to update compose** — breaks running containers with port conflicts
- **Update compose**: `sudo midclt call -j app.stop` → `app.update` → `app.start`
- **New app**: `midclt app.create` with `custom_compose_config_string` (string, not dict)
- **Caddyfile changes**: `scp` to live location → `docker exec caddy caddy reload` (no app restart)
- **Port conflicts**: check `ss -tlnp` before assigning ports — TrueNAS nginx owns 80, 443, 8082
- **NEVER store secrets in /tmp with predictable names** — use `mktemp -d` + cleanup immediately
- **midclt REQUIRES sudo** — without `sudo`, calls silently fail as `.UNAUTHENTICATED` (audit log shows it)
- **NEVER use `docker start/stop`** — use midclt to manage app lifecycle, not docker commands directly
- **Multi-service stacks**: midclt has no per-container restart — stop/start restarts the whole app

## Common Gotchas
- **ALWAYS check response type before piping to jq** — APIs may return HTML not JSON
- Use `jq` not `python3 -m json.tool`
- SSH piped commands fail on TrueNAS — use separate steps
- `ix-*` networks are TrueNAS built-in, separate from compose networks
- Sonarr/Radarr cache health checks — trigger `CheckHealth` command via API
- qBittorrent doesn't create dirs at startup, only on first download

## Behavior Rules
- **DO THE WORK** — set up SSH, install tools, troubleshoot yourself. Don't ask user to run commands.
- **Research first, guess never** — read existing working apps before attempting anything new. Replicate patterns, never invent.
- **NO /tmp for working files** — stage files in repo, SCP to TrueNAS. `/tmp` is for secrets only (mktemp -d, cleanup immediately).
- **Repo is source of truth** — all persistent knowledge lives in this repo. `.claude/` travels with it.
- **No secrets in output** — use variables, redirect stderr, never echo secrets.
- **ALWAYS check existing setup** before creating new files.
- **Broken service? Check logs first** — `sudo docker logs <container> --tail 30` before ANY hypothesis. Never assume networking; the cause is always visible in logs.
- **Be concise** — no filler, no trailing summaries, no restating what was just done. Direct answers only.
- **Memory lives in the repo** — write all new feedback/decisions to `.claude/memory/` and update `.claude/memory/MEMORY.md`. Never write to `~/.claude/projects/` (local-only, doesn't travel with repo).

## Service Migrations
See `.claude/docs/migrations.md`

## Recyclarr
See `.claude/docs/recyclarr.md`

## Code Standards
- **Shell**: `#!/usr/bin/env bash`, `set -euo pipefail`, idempotent designs, run `shellcheck` before committing
- **YAML/Compose**: validate with `yamllint <file>` and `docker compose -f <file> config`
- **Commits**: `<type>(<scope>): <short summary>` — e.g. `fix(autobrr): correct feed_type for AnimeTosho`

## Commit Security Gate — REQUIRED
Before EVERY commit:
1. Run `/security-review` on staged changes
2. If clean: `date +%s > ~/.claude/hooks/.security-review-timestamp`
3. Then commit — hook reads timestamp, allows if within 10 minutes, deletes token
4. If hook blocks: security review is stale or missing — repeat from step 1

## Task Tracking
- Use TodoWrite for multi-step current session work
- Add long-term items to `ai/todo.md`
- See `ai/DOCUMENTATION_STRUCTURE.md` for full workflow

## Compact Instructions
If context is compacted, preserve these critical facts:
- TrueNAS SSH: use ssh-agent pattern from `ai/PATTERNS.md` (NOT temp-file pattern)
- `midclt REQUIRES sudo` — without sudo, calls silently fail as `.UNAUTHENTICATED`
- NEVER use REST API to update compose — use midclt stop→update→start
- Infisical: ALL secrets are `--env dev`, NEVER run `infisical secrets` without targeting a key
- Check logs first: `sudo docker logs <container> --tail 30` before any hypothesis
- EVERY commit: run `/security-review` → if clean: `date +%s > ~/.claude/hooks/.security-review-timestamp` → then commit

## Intent Layer

**Before modifying code in a subdirectory, read its AGENTS.md first** to understand local patterns and invariants.

- **TrueNAS infrastructure**: `truenas/AGENTS.md` — app lifecycle, SSH, midclt, secrets, ports
- **Media stack**: `media/AGENTS.md` — arr apps, Bazarr invariants, API patterns
- **Media scripts**: `media/scripts/AGENTS.md` — configuration automation scripts
- **AI/Claude ops**: `ai/AGENTS.md` — PATTERNS.md, handoffs, memory, todo workflow

### Global Invariants
- Check logs first before any hypothesis: `sudo docker logs <container> --tail 30`
- All secrets are `--env dev` in Infisical — no prod environment exists
- `midclt` requires `sudo` — without it, calls silently fail as `.UNAUTHENTICATED`
- Never use REST API to update compose — midclt stop→update→start only
- Memory lives in the repo: `.claude/memory/` not `~/.claude/projects/`

## Documentation Index
- `ai/PATTERNS.md` — verified commands (check before trial-and-error)
- `truenas/README.md` — architecture
- `truenas/DEPLOYMENT_GUIDE.md` — deployment
- `.github/TROUBLESHOOTING.md` — troubleshooting
- `ai/SESSION_NOTES.md` — current session
- `ai/todo.md` — task backlog
