# Dockhand Migration Readiness Audit
_Assessed: 2026-05-31, refreshed 2026-08-15_

## Status: Proceeding

**`dockhand` itself stays on midclt, permanently — not a migration target.** It's infrastructure-for-the-infrastructure: deleting the midclt `dockhand` app to redeploy it "through Dockhand" would kill the only thing serving the API that could bring it back — a bootstrapping problem, not something to work around. If it's ever moved, it has to be a manual SSH + `docker compose` operation done completely outside its own API, equivalent to a fresh install, not a migration step in this plan.

Migration decision is settled — moving all remaining apps to Dockhand. `comicarr` (previously listed as already-migrated) was removed and replaced by `suggestarr` (commit `fbcecec`, 2026-08). `autobrr` and `suggestarr` remain Dockhand-managed. `infisical` (self-hosted secrets server) was separately migrated to Dockhand for unrelated reasons (commit `9e64e8a`) — not part of this plan, doesn't affect the order below.

`arr-stack`, `downloaders`, and `jellyfin` keep their current multi-container grouping post-migration — not splitting into one-service-per-stack. Docker compose already supports per-service restart/recreate, so Dockhand removes the midclt constraint (whole-app-only restart) that motivated bundling in the first place; splitting further would only multiply cross-stack network wiring (the exact bug class fixed below) for no added lifecycle benefit.

**2026-08-15: pre-created `arr-stack_default`, `downloaders_default`, `jellyfin_default` as real docker networks ahead of any stack migrating**, so dependent stacks (`suggestarr`, and `arr-stack`'s own cross-reference to jellyfin) can point at final network names immediately instead of needing a redeploy after the owning stack migrates. `arr-stack/compose.yaml`, `downloaders/compose.yaml`, `jellyfin/compose.yaml` now declare all their networks as `external: true` (network already exists, not created by compose). `suggestarr/compose.yaml` now points directly at `jellyfin_default`.

**Resolved 2026-08-15**: `suggestarr`'s pending redeploy (was stuck on `ix-jellyfin_default`) happened as part of converting it to a git-synced stack — confirmed on `jellyfin_default` now.

---

## Per-Stack Status

| Stack | Dockhand Status | Notes |
|-------|----------------|-------|
| autobrr | ✅ Git-synced 2026-08-15 | Was already Dockhand-managed (orphaned file copy); now a proper git stack via `/api/git/stacks`, `autoUpdate: false` |
| suggestarr | ✅ Git-synced 2026-08-15 | Redeploy via git-sync finally picked up the `jellyfin_default` fix (was still live on `ix-jellyfin_default` before this) — confirmed correctly on `jellyfin_default` only now, reachability verified. `autoUpdate: false` |
| infisical | ✅ Git-synced 2026-08-15 | Self-hosted secrets server, was orphaned file copy; now git-synced, `autoUpdate: false` |
| infisical-agent | ✅ Migrated 2026-08-15 | Deleted via `midclt app.delete`, git-synced via `/api/git/stacks`. `autoUpdate: true` (non-critical, low blast radius) |
| adguard-home | 🔄 Ready, deferred to last | No env_file, no external networks — but highest blast radius (sole DNS, no fallback). Will be created with `autoUpdate: false`. |
| tailscale | ✅ Migrated 2026-08-15 | Git-synced via Dockhand's UI. `autoUpdate: false` (critical — remote access) |
| arr-stack | 🔄 Ready | Owns `arr-stack_default`; others depend on it |
| downloaders | 🔄 Ready | Owns `downloaders_default`; needs arr-stack_default |
| jellyfin | ✅ Migrated 2026-08-15 | 4 containers, all healthy, git-synced via `/api/git/stacks`. `autoUpdate: true` (non-critical) |
| caddy | 🔄 Ready | Needs arr-stack_default + jellyfin_default. Will be created with `autoUpdate: false` (critical — reverse proxy for everything). |
| homepage | ✅ Migrated 2026-08-15 | Deleted via `midclt app.delete`, git-synced, `autoUpdate: false`. No implicit-network risk (single service, explicit `networks:` already). Direct `IP:3000` access returns 400 (Next.js `HOMEPAGE_ALLOWED_HOSTS` host validation, pre-existing/expected) — verified working via `http://homepage.home` through Caddy instead. |
| commafeed | ✅ Migrated 2026-08-15 | Deleted via `midclt app.delete`, git-synced, `autoUpdate: false`. No external networks at all — no implicit-network collision risk. |
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
7. (done 2026-08-15) homepage  ← dashboard; needs arr-stack_default + jellyfin_default
8. (done 2026-08-15) suggestarr — git-synced, redeploy picked up jellyfin_default
9. (done 2026-08-15) commafeed — standalone
10. fileflows           ← standalone
11. (done 2026-08-15) autobrr, infisical — git-linked (were already Dockhand-managed, orphaned file copies)
12. adguard-home        ← DEFERRED TO LAST, deliberately: highest blast radius (no fallback DNS, whole
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
- **Verified git-sync API sequence (2026-08-15, infisical-agent + jellyfin)** — use this for every remaining stack instead of manual scp+docker compose:
  1. Auth: `POST /api/auth/login` with `DOCKHAND_USER`/`DOCKHAND_USER_PASSWORD` (Infisical `/TrueNAS`), cookie-jar session — pattern already in `ai/PATTERNS.md`
  2. Create: `POST /api/git/stacks` — body `{"stackName": "<name>", "repositoryId": 1, "environmentId": 1, "composePath": "/truenas/stacks/<name>/compose.yaml", "autoUpdate": false}` (repositoryId 1 = the `homelab` repo, already registered)
  3. Sync: `POST /api/git/stacks/<id>/sync` — pulls the compose file from git; check `commit` in the response matches what you expect pushed
  4. Deploy: `POST /api/git/stacks/<id>/deploy` — returns `{"jobId": "..."}`; this is a **different endpoint from `/api/stacks/<name>/deploy`**, which is for file-based (non-git) stacks and returns `"Stack compose file location not configured"` if used on a git stack
  5. Poll: `GET /api/jobs/<jobId>` until `status != "running"`; check `result.success`
  6. Verify live: this correctly **recreates existing containers in place** (matched by `container_name` + compose project name) rather than creating duplicates — confirmed for both a 1-container and a 4-container stack. Still worth a `docker ps`/health check after, same as any deploy.
  - `autoUpdate: false` means no continuous background sync — each stack needs `sync`+`deploy` called again after future pushes, or flip `autoUpdate`/`autoUpdateCron` on if continuous sync is wanted.
  - **2026-08-15: user enabled `autoUpdate: true` (daily, `0 3 * * *`) on all three git stacks, then revised the policy**: critical/hard-to-recover infra stays `autoUpdate: false`, manual `sync`+`deploy` only — `tailscale` (remote access), `adguard-home` once migrated (sole DNS, no fallback), and `caddy` once migrated (reverse proxy for every other service — a bad auto-deploy takes down access to everything behind it, same asymmetric-risk logic as tailscale). Non-critical stacks (`infisical-agent`, `jellyfin`) keep `autoUpdate: true`. Apply this same split to every remaining stack: default to `autoUpdate: false` at creation, only enable it where an unattended bad deploy has low/recoverable blast radius. Only redeploys a stack if that stack's specific compose file changed (confirmed via `sync`'s `updated` field), not on every unrelated repo commit.
- **Implicit-network gotcha, corrected/expanded 2026-08-15**: any service with no explicit `networks:`, OR with a `networks:` list that includes the literal string `default`, falls back to (or additionally joins) compose's own auto-created implicit default network (named `<project-name>_default`). Two distinct consequences depending on whether that name collides with a pre-created external network:
  - **Hard failure** when the compose project name itself matches a pre-created network name — e.g. project `downloaders` + pre-created `downloaders_default`. Confirmed live: `downloaders`' deploy failed outright with `network downloaders_default exists but was not created by compose... incorrect label`. Same class of collision applies to `arr-stack` (project `arr-stack` + `arr-stack_default`).
  - **Silent harmless junk network** when there's no name collision — e.g. `homepage`, `autobrr`, `caddy` (none owns a network matching their own project name). Confirmed live: `homepage` and `autobrr` had already been deployed with a stray `- default` entry; both got an extra unused `<name>_default` network alongside the correct explicit ones, but reachability was unaffected — verified `homepage → jellyfin` still worked.
  - **I incorrectly cleared `downloaders/compose.yaml` as "already correct" earlier** — I'd only grepped for the *presence* of a `networks:` key per service, not checked its actual values. Both `qbittorrent` and `sabnzbd` had `- default` instead of `- downloaders_default`. Lesson: presence of the key is not sufficient, always check the literal network names listed.
  - Fixed: `downloaders/compose.yaml` (both services), `homepage/compose.yaml`, `autobrr/compose.yaml`, `caddy/compose.yaml` (pre-emptive, not yet deployed). All compose files in `truenas/stacks/` now verified clean via `grep -rn "^\s*- default\s*$" */compose.yaml` (must return nothing).
  - **Before deploying `fileflows`**: already checked, has no `networks:` section at all and no external network references — genuinely safe, not just unchecked.
