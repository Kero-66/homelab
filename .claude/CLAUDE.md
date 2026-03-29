# Claude Code Instructions — Homelab Project

## Start Every Session
1. Read `.claude/memory/MEMORY.md` — accumulated feedback, gotchas, service-specific decisions
2. Read `ai/SESSION_NOTES.md` — current work in progress
3. Read `ai/todo.md` — pending tasks
4. Before any command, check `ai/PATTERNS.md` — verified copy-paste commands

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
```bash
TMPDIR_SAFE=$(mktemp -d) && chmod 700 "$TMPDIR_SAFE" && TMPKEY="$TMPDIR_SAFE/k"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null > "$TMPKEY" && chmod 600 "$TMPKEY"
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no kero66@192.168.20.22 "your command here"
rm -rf "$TMPDIR_SAFE"
```
- kero66 cannot access Docker socket directly — use `sudo docker ...`
- kero66 UID on TrueNAS: **72**
- API key: `truenas_admin_api` (env dev, path /TrueNAS)
- API requires HTTPS — http returns 308 that drops auth header

## TrueNAS App Management — CRITICAL
- **NEVER use REST API to update compose** — breaks running containers with port conflicts
- **Update compose**: `midclt app.stop` → `midclt app.update` → `midclt app.start`
- **New app**: `midclt app.create` with `custom_compose_config_string` (string, not dict)
- **Caddyfile changes**: `scp` to live location → `docker exec caddy caddy reload` (no app restart)
- **Port conflicts**: check `ss -tlnp` before assigning ports — TrueNAS nginx owns 80, 443, 8082
- **NEVER store secrets in /tmp with predictable names** — use `mktemp -d` + cleanup immediately

## Common Gotchas
- **ALWAYS check response type before piping to jq** — APIs may return HTML not JSON
- Use `jq` not `python3 -m json.tool`
- SSH piped commands fail on TrueNAS — use separate steps
- `ix-*` networks are TrueNAS built-in, separate from compose networks
- Sonarr/Radarr cache health checks — trigger `CheckHealth` command via API
- qBittorrent doesn't create dirs at startup, only on first download

## Behavior Rules
- **Check logs first** — `sudo docker logs <container> --tail 30` before forming any hypothesis about a broken service. See `.claude/rules/troubleshooting.md`.
- **DO THE WORK** — set up SSH, install tools, troubleshoot yourself. Don't ask user to run commands.
- **Research first, guess never** — read existing working apps before attempting anything new. Replicate patterns, never invent.
- **NO /tmp for working files** — stage files in repo, SCP to TrueNAS. `/tmp` is for secrets only (mktemp -d, cleanup immediately).
- **Repo is source of truth** — all persistent knowledge lives in this repo. `.claude/` travels with it.
- **No secrets in output** — use variables, redirect stderr, never echo secrets.
- **ALWAYS check existing setup** before creating new files.

## Task Tracking
- Use TodoWrite for multi-step current session work
- Add long-term items to `ai/todo.md`
- See `ai/DOCUMENTATION_STRUCTURE.md` for full workflow

## Documentation Index
- `ai/PATTERNS.md` — verified commands (check before trial-and-error)
- `truenas/README.md` — architecture
- `truenas/DEPLOYMENT_GUIDE.md` — deployment
- `.github/TROUBLESHOOTING.md` — troubleshooting
- `ai/SESSION_NOTES.md` — current session
- `ai/todo.md` — task backlog
