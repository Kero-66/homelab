# Dockhand Migration Readiness Audit
_Assessed: 2026-05-31_

## Status: Ready

All stacks are ready for Dockhand migration. Network names were cleaned in commit `3d98525` (ix-* → plain compose names). autobrr and comicarr are already running via Dockhand.

---

## Per-Stack Status

| Stack | Dockhand Status | Notes |
|-------|----------------|-------|
| autobrr | ✅ Already on Dockhand | Running as Dockhand-managed container |
| comicarr | ✅ Already on Dockhand | Running as Dockhand-managed container |
| infisical-agent | 🔄 Migrate first | Must be deployed before any stack with env_file |
| adguard-home | 🔄 Ready | No env_file, no external networks |
| tailscale | 🔄 Ready | network_mode: host — Dockhand handles this fine |
| arr-stack | 🔄 Ready | Owns `arr-stack_default`; others depend on it |
| downloaders | 🔄 Ready | Owns `downloaders_default`; needs arr-stack_default |
| jellyfin | 🔄 Ready | Owns `jellyfin_default`; needs arr-stack_default |
| caddy | 🔄 Ready | Needs arr-stack_default + jellyfin_default |
| homepage | 🔄 Ready | Needs arr-stack_default + jellyfin_default |
| commafeed | 🔄 Ready | Standalone (internal network only) |
| fileflows | 🔄 Ready | Standalone (no external networks, no env_file) |

---

## Required Deployment Order

Dockhand stacks must be deployed in this sequence due to network and secret dependencies:

```
1. infisical-agent      ← renders .env files for all other stacks
2. adguard-home         ← DNS (critical infrastructure)
3. tailscale            ← remote access
4. arr-stack            ← creates arr-stack_default network
5. downloaders          ← creates downloaders_default; needs arr-stack_default
6. jellyfin             ← creates jellyfin_default; needs arr-stack_default
7. caddy                ← reverse proxy; needs arr-stack_default + jellyfin_default
8. homepage             ← dashboard; needs arr-stack_default + jellyfin_default
9. autobrr              ← already deployed; needs arr-stack_default + downloaders_default
10. comicarr            ← already deployed; needs downloaders_default
11. commafeed           ← standalone
12. fileflows           ← standalone
```

**Critical**: arr-stack must be deployed before downloaders, jellyfin, caddy, homepage, and autobrr — it owns the `arr-stack_default` network that all cross-stack containers join.

---

## Fixes Applied

| File | Fix |
|------|-----|
| `arr-stack/compose.yaml` | recyclarr healthcheck: `ps aux \| grep recyclarr` → `pgrep -f recyclarr` (old form always passed because grep matched itself) |

---

## Key Architecture Notes

- **env_file paths** are absolute TrueNAS paths (`/mnt/Fast/docker/<stack>/.env`) — Dockhand deploys directly on the host so these resolve correctly
- **No ix-* networks** remain — all renamed to `arr-stack_default`, `downloaders_default`, `jellyfin_default`
- **External networks**: each stack declares its own network and joins others as `external: true`; deployment order above ensures owning stack is up first
- **pg_isready healthchecks**: `-U <user>` flag is not required for connectivity checks — pg_isready tests server availability, not authentication
- **tailscale**: `network_mode: host` + `cap_add: [NET_ADMIN, SYS_MODULE]` — works with Dockhand, no special handling needed
- **caddy**: runs as `user: 1000:1000`, currently healthy — image handles port binding as non-root
