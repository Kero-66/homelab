# TrueNAS Infrastructure

## Purpose
Owns all deployment, configuration, and operation of the homelab on TrueNAS Scale 25.10.1 (192.168.20.22). Does NOT own media library content or AI tooling config.

## Entry Points
- `DEPLOYMENT_GUIDE.md` - How to deploy new stacks
- `DOCKHAND_READINESS.md` - Per-stack deployment order and current status
- `stacks/` - One directory per app/stack with compose.yaml
- `scripts/` - Operational scripts (deploy, backup, health checks)

## Contracts & Invariants

**App lifecycle — never bypass:**
- Update compose: `sudo midclt call -j app.stop` → `app.update` → `app.start`
- `midclt` ALWAYS requires `sudo` — without it, calls silently fail as `.UNAUTHENTICATED`
- NEVER use REST API `PUT /app/id/{name}` to update compose — breaks containers with port conflicts
- NEVER use `docker start/stop` — use midclt for all app lifecycle management
- Multi-service stacks (arr-stack, downloaders): midclt has no per-container restart — stop/start restarts entire app

**SSH:**
- User: `kero66` (UID 72 on TrueNAS), NOT truenas_admin (break-glass only)
- kero66 cannot access Docker socket directly — use `sudo docker ...`
- ALWAYS get SSH command from `ai/PATTERNS.md` "TrueNAS SSH" section — never write from memory
- API requires HTTPS — http returns 308 that silently drops auth header

**Ports:**
- TrueNAS nginx owns 80, 443, 8082 — always check `ss -tlnp` before assigning ports
- Caddyfile updates: scp to live location → `docker exec caddy caddy reload` (no app restart needed)

**Secrets:**
- ALL secrets are `--env dev` — no prod environment exists
- NEVER run `infisical secrets` without targeting a specific key (table output exposes all in cleartext)
- NEVER store secrets in `/tmp` with predictable names — use `mktemp -d` + cleanup immediately

## Patterns
- New app: `midclt app.create` with `custom_compose_config_string` (compose as string, not dict)
- Configs live at `/mnt/Fast/docker/<service>/` on TrueNAS
- Networks: cross-stack via explicit joins; `ix-*` networks are TrueNAS built-in, separate from compose networks
- kero66 filesystem UID on TrueNAS: **1000** (verified live 2026-08-15 via `id kero66`). Not to be confused with kero66's TrueNAS **API** user record id (**72**, used in REST calls like `PUT /api/v2.0/user/id/72`) — different namespace, both correct.

## Anti-patterns
- DO NOT use REST API to update compose — midclt only
- DO NOT pipe SSH commands — use separate steps (TrueNAS SSH piped commands fail)
- DO NOT pipe API responses to `jq` without first checking the response isn't HTML
- DO NOT assume networking is the cause of a broken service — check logs first: `sudo docker logs <container> --tail 30`
- DO NOT `docker run` a new throwaway container on this host for an unrelated utility task (hashing, testing, one-off CLI work), even with `--rm` — Dockhand's inventory never sees it, same violation as a raw lifecycle command against a managed app. Check for a local equivalent (`which <tool>`) before reaching for SSH+docker at all. `docker exec` into an *already-running* Dockhand-managed container to invoke its own documented action (e.g. `docker exec caddy caddy reload`) is fine — that's a different, narrower, already-accepted pattern. See `.claude/memory/feedback_dockhand_apps_no_raw_docker_commands.md`.

## Related Context
- `ai/PATTERNS.md` - Verified SSH/Infisical/midclt commands (check before trial-and-error)
- `truenas/DOCKHAND_READINESS.md` - Current per-stack deployment state
- `.claude/memory/MEMORY.md` - TrueNAS API patterns, AdGuard, Dockhand verified details
