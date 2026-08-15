# Dockhand Migration Readiness Audit
_Assessed: 2026-05-31, refreshed 2026-08-15_

## Status: Proceeding

Migration decision is settled — moving all remaining apps to Dockhand. `comicarr` (previously listed as already-migrated) was removed and replaced by `suggestarr` (commit `fbcecec`, 2026-08). `autobrr` and `suggestarr` remain Dockhand-managed. `infisical` (self-hosted secrets server) was separately migrated to Dockhand for unrelated reasons (commit `9e64e8a`) — not part of this plan, doesn't affect the order below.

`arr-stack`, `downloaders`, and `jellyfin` keep their current multi-container grouping post-migration — not splitting into one-service-per-stack. Docker compose already supports per-service restart/recreate, so Dockhand removes the midclt constraint (whole-app-only restart) that motivated bundling in the first place; splitting further would only multiply cross-stack network wiring (the exact bug class fixed below) for no added lifecycle benefit.

**2026-08-15: pre-created `arr-stack_default`, `downloaders_default`, `jellyfin_default` as real docker networks ahead of any stack migrating**, so dependent stacks (`suggestarr`, and `arr-stack`'s own cross-reference to jellyfin) can point at final network names immediately instead of needing a redeploy after the owning stack migrates. `arr-stack/compose.yaml`, `downloaders/compose.yaml`, `jellyfin/compose.yaml` now declare all their networks as `external: true` (network already exists, not created by compose). `suggestarr/compose.yaml` now points directly at `jellyfin_default`.

**Action still pending**: `suggestarr` is live and currently attached to `ix-jellyfin_default` — its compose file was updated but not yet redeployed. Redeploy with `sudo docker compose -f .../suggestarr/compose.yaml up -d --force-recreate` to actually move it onto `jellyfin_default`.

---

## Per-Stack Status

| Stack | Dockhand Status | Notes |
|-------|----------------|-------|
| autobrr | ✅ Already on Dockhand | Running as Dockhand-managed container |
| suggestarr | ✅ Already on Dockhand | Replaced comicarr 2026-08; compose now points at jellyfin_default (pre-created) — pending redeploy to pick it up, still live on ix-jellyfin_default |
| infisical-agent | ✅ Migrated 2026-08-15 | Dockhand-managed, healthy, re-rendered .env for all 6 dependent stacks. Deleted via `midclt app.delete` (not `app.stop`) to free the container name first. |
| adguard-home | 🔄 Ready, deferred to last | No env_file, no external networks — but highest blast radius (sole DNS, no fallback). Deliberately pushed to the end of the order until the pattern's proven elsewhere. |
| tailscale | ✅ Migrated 2026-08-15 | Dockhand-managed via GitOps sync (deployed under `stacks/TrueNAS/tailscale/`, mirroring the git repo path — not a manual paste). Resumed existing identity (100.98.14.66), healthy, connected to DERP. Deleted via `midclt app.delete`. Fixed a pre-existing `/mnt/Fast/docker/tailscale` directory permission bug along the way (missing group/other execute bit blocked Dockhand's UID 568 from reading `.env`) — see `HOWTO_MIGRATE_ADGUARD_TAILSCALE.md`. |
| arr-stack | 🔄 Ready | Owns `arr-stack_default`; others depend on it |
| downloaders | 🔄 Ready | Owns `downloaders_default`; needs arr-stack_default |
| jellyfin | ✅ Migrated 2026-08-15 | 4 containers (jellyfin, jellyseerr, jellystat, jellystat-db), all healthy. Fixed a real bug before deploying: 3 of 4 services had no explicit `networks:`, would've fallen back to compose's implicit default network and collided with our pre-created `jellyfin_default` (same name, no compose ownership labels). Added explicit `networks:` to all 4 services. Deleted via `midclt app.delete`. |
| caddy | 🔄 Ready | Needs arr-stack_default + jellyfin_default |
| homepage | 🔄 Ready | Needs arr-stack_default + jellyfin_default |
| commafeed | 🔄 Ready | Standalone (internal network only) |
| fileflows | 🔄 Ready | Standalone (no external networks, no env_file) |

---

## Required Deployment Order

Dockhand stacks must be deployed in this sequence due to network and secret dependencies:

```
0. (done) pre-create arr-stack_default, downloaders_default, jellyfin_default as real docker networks
1. (done 2026-08-15) infisical-agent      ← renders .env files for all other stacks
2. (done 2026-08-15) tailscale            ← remote access
3. arr-stack            ← joins arr-stack_default + jellyfin_default (both pre-created, external)
4. downloaders          ← joins downloaders_default + arr-stack_default (both pre-created, external)
5. (done 2026-08-15) jellyfin  ← joins jellyfin_default + arr-stack_default (both pre-created, external)
6. caddy                ← reverse proxy; needs arr-stack_default + jellyfin_default
7. homepage             ← dashboard; needs arr-stack_default + jellyfin_default
8. suggestarr           ← redeploy only (already on Dockhand) to pick up jellyfin_default instead of ix-jellyfin_default
9. commafeed            ← standalone
10. fileflows           ← standalone
11. adguard-home        ← DEFERRED TO LAST, deliberately: highest blast radius (no fallback DNS, whole
                           LAN affected), moved to the end until the migration pattern is proven on
                           everything else. Decided 2026-08-15.
```

Since all three shared networks are pre-created, steps 3–5 can now run in any order relative to each other — no more strict "owning stack must go first" requirement. Only the infisical-agent → everything-else and arr-stack/downloaders/jellyfin → caddy/homepage/suggestarr orderings still matter (secrets and network membership, respectively).

---

## Fixes Applied

| File | Fix |
|------|-----|
| `arr-stack/compose.yaml` | recyclarr healthcheck: `ps aux \| grep recyclarr` → `pgrep -f recyclarr` (old form always passed because grep matched itself) |

---

## Key Architecture Notes

- **env_file paths** are absolute TrueNAS paths (`/mnt/Fast/docker/<stack>/.env`) — Dockhand deploys directly on the host so these resolve correctly
- **Plain networks pre-created**: `arr-stack_default`, `downloaders_default`, `jellyfin_default` exist now (2026-08-15), ahead of migration — old `ix-*` equivalents still exist too and remain in use by the still-midclt-managed apps until each one migrates; safe to remove the `ix-*` versions once nothing joins them
- **External networks**: each stack declares its own network and joins others as `external: true`; deployment order above ensures owning stack is up first
- **pg_isready healthchecks**: `-U <user>` flag is not required for connectivity checks — pg_isready tests server availability, not authentication
- **tailscale**: `network_mode: host` + `cap_add: [NET_ADMIN, SYS_MODULE]` — works with Dockhand, no special handling needed
- **caddy**: runs as `user: 1000:1000`, currently healthy — image handles port binding as non-root
- **Cross-container breakage on cutover (found live 2026-08-15, jellyfin migration)**: migrating jellyfin off `ix-jellyfin_default` broke `caddy`, `homepage`, and `suggestarr` — all three were still attached to `ix-jellyfin_default` and reach `jellyfin` by container name, so they got `no such host` / 502s the moment jellyfin left that network. Fixed live with `docker network connect jellyfin_default <container>` (no restart, fully reversible) for all three. **Before cutting over any remaining stack, run `docker network inspect ix-<stack>_default` first and check every container still attached — not just what that stack's own compose file declares** — and `docker network connect <new>_default <container>` any of them proactively, before deploying, not after something breaks.
- **Implicit-network gotcha — check every remaining stack before deploying**: any service with no explicit `networks:` falls back to compose's own auto-created default network, which collides in name (but not ownership labels) with our pre-created `arr-stack_default`/`downloaders_default`/`jellyfin_default`. Found and fixed in `jellyfin/compose.yaml` (3 of 4 services) and `arr-stack/compose.yaml` (4 of 7 services had none at all; the other 3 used the ambiguous literal `default` instead of the actual network name). `downloaders/compose.yaml` already had this right. **Check `caddy`, `homepage`, `commafeed`, `fileflows` for the same pattern before deploying each.**
