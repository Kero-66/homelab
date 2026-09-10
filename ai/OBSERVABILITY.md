# Observability Tracking

Findings from log/metric review via Grafana (Loki logs + Prometheus/cAdvisor metrics,
`grafana-alloy` stack, http://grafana.home). See `ai/PATTERNS.md` "Querying it back" for the
Loki datasource-proxy query pattern used to pull these.

## Host-level metrics added for Valheim prep (2026-09-10, staged — not yet deployed)

Prepped in the same cloud session as the Valheim server stack (no LAN access, nothing live —
see `ai/SESSION_NOTES.md`). Until now this stack only had **container-level** metrics
(cAdvisor) plus two whole-machine gauges (`machine_memory_bytes`, `machine_cpu_cores`) — no
real host CPU utilization, load average, or disk I/O at all. Added because Valheim is
expected to be the single heaviest CPU consumer on this host (an Intel N150 — fine on RAM,
weak on single-thread CPU), and because the user explicitly wants confirmation that neither
Valheim nor this monitoring stack ever touch the slow `Data` HDD pool.

- **`config.alloy`**: added `prometheus.exporter.unix "host"` (Alloy's node_exporter
  equivalent) + a `host_metrics` scrape job, reusing the `/rootproc`, `/sys`, `/rootfs` host
  bind mounts already present on the `alloy` service for cAdvisor's own needs — no new mounts
  needed. Component argument names (`procfs_path`/`sysfs_path`/`rootfs_path`) confirmed via
  Grafana's own component docs (web search — `grafana.com` itself is blocked by this
  session's egress proxy, `pkg.go.dev`'s mirrored source docs were used instead) rather than
  guessed from memory.
- **`config/provisioning/alerting/rules.yaml`**: new `Host Health` alert group — CPU >85%
  busy for 10m (`host-cpu-saturated`), available memory <10% for 10m
  (`host-memory-low`) — same file-provisioned pattern as the existing `Container Health`
  group, no notification channel configured (Alerting UI only, matches existing rules).
- **`config/provisioning/dashboards/json/host-resources.json`**: new dashboard — CPU busy %,
  load average, memory available, and (the actual point of this exercise) **disk I/O split
  into a "Fast pool" panel (nvme0n1/nvme2n1) and a "Data pool, should stay near-idle" panel
  (sda/sdb)**, plus filesystem-used-% by mountpoint for `/mnt/Fast`, `/mnt/Data`, `/`. Device
  → pool mapping per `truenas/HARDWARE_CONFIG.md`.

**Not yet verified live** (no LAN access this session): whether `prometheus.exporter.unix`
actually starts cleanly against the existing mounts, whether the filesystem collector's
default `mount_points_exclude` regex lets `/mnt/Fast`/`/mnt/Data` through as expected (it's
node_exporter's stock default, not overridden here — if either mountpoint doesn't show up,
check that first), and whether the new alert rules evaluate without error. `grafana-alloy` is
`autoUpdate: false` (version-pinned) — this needs an explicit Dockhand sync+deploy, not just a
git push, to take effect. Tracked in `ai/todo.md` #123.

## Known Issues (no action available from our side)

### jellyseerr/Seerr: intermittent 401 on internal self-fetch
- **First seen**: 2026-09-09 (predates that session — not caused by any change that day)
- **Symptom**: Seerr (`ghcr.io/seerr-team/seerr`, container `jellyseerr`) makes a server-side
  request to its own API (`GET http://localhost:5055/api/v1/movie/<tmdbId>`) and gets a 401 with
  `{"message": "cookie 'connect.sid' required"}`, followed by `Cannot write headers after they are
  sent to the client`.
- **Cause**: session-cookie timing race inside Seerr itself. Matches upstream GitHub issues
  seerr-team/seerr#2793 ("await session.save() before responding to prevent missing Set-Cookie
  header", closed/fixed) and #3024 (same error text, different trigger — OIDC preview branch, not
  our setup).
- **Why not fixed**: our instance is already on the latest release (checked via
  `GET /api/v1/status` → `commitsBehind: 0`, `updateAvailable: false`) — no version bump or config
  change available to apply. Appears intermittent/low-impact (requests seem to still complete).
- **Revisit**: if this starts blocking real requests (not just showing in logs), or if a future
  Seerr release changelog mentions a session/cookie fix beyond #2793.

## cAdvisor `container_health_state` caches at discovery (2026-09-10)

**Confirmed via direct test.** Restarting `grafana-alloy-alloy` immediately fixed 5 of 7
containers showing a stale `container_health_state == 0` (autobrr, gamarr, suggestarr,
`grafana-alloy-prometheus`, `grafana-alloy-grafana`) despite `docker inspect` confirming all
were genuinely `healthy` — some for 10+ minutes beforehand. The Prometheus samples were
fresh (current timestamps), so this wasn't a scrape/staleness issue — the *value* itself was
frozen.

**Root cause**: cAdvisor appears to capture a container's Docker `Health.Status` once at
discovery/stats-collection start and never refreshes it as the container's health transitions
over its lifetime. Every affected container had been recreated (new container ID, part of
tonight's various compose changes) *after* `grafana-alloy-alloy` last started — so cAdvisor
discovered each one while its healthcheck was still in `starting` (or, for gamarr/suggestarr/
autobrr, before any healthcheck existed at all) and never re-checked once Docker's own status
moved to `healthy`.

**Practical implication**: after adding or changing a `healthcheck:` on any service, restart
`grafana-alloy-alloy` afterward to get accurate `container_health_state` data — don't just
wait, it will stay stale indefinitely until cAdvisor itself restarts.

`loki` and `alloy` remain permanently unable to have a Docker healthcheck at all regardless of
this — their images have no shell/curl/wget to run one (separate, already-documented below in
the healthcheck-additions section of git history — see commit `9d355d7`). Their
`container-unhealthy` alert firing forever is expected, not a bug.

## Known Issues (no action available from our side)

### Grafana: cosmetic "Loki" error badge on Alerting > Alert rules
- **First seen**: 2026-09-09
- **Symptom**: the Alert rules page shows a red "Error" badge on a data-source-managed
  "Loki" rule group. Cosmetic only — doesn't affect the Grafana-managed rules under
  "Homelab Alerts", which evaluate and fire normally.
- **Cause**: Loki has no `ruler` component configured (see `loki-config.yaml`), so its
  native alert-rules API 404s. Grafana's Alert rules page queries every configured
  datasource's native rules API by default and surfaces the 404 as an error.
- **Attempted fix**: set `jsonData.manageAlerts: false` on the Loki datasource
  (`truenas/stacks/grafana-alloy/compose.yaml`, commit `18d1243`) — this is supposed to
  tell Grafana not to query that datasource's native rules at all. Confirmed the setting
  is correctly written to the rendered `ds.yaml` on disk, but the live datasource API
  response still shows `jsonData: {}` after a Grafana restart — the setting isn't taking
  effect for reasons not yet root-caused. Grafana 13.1.0 didn't log the classic
  `provisioning.datasources` reconciliation step at all on restart (newer versions may
  have moved datasource provisioning under a different "provisioning.grafana.app"
  apiserver code path), which is as far as this was traced before deciding it wasn't
  worth further time on a cosmetic-only issue.
- **Revisit**: if this bothers you enough to chase further, or if a Grafana upgrade
  changes provisioning behavior. The `manageAlerts: false` config stays in place either
  way — harmless, and correct intent if it ever starts working.

## Resolved Issues (for reference — root cause + fix)

- **homepage Jellyfin widget 404 loop** (2026-09-09): Jellyfin 12.0.0 dropped the legacy `/emby/*`
  compat API; homepage's widget needed `version: 2` in `services.yaml`. Also surfaced a Dockhand
  deploy permission bug (`config/` dir ownership fighting between Dockhand's `apps` UID and
  homepage's own `PUID=1000` writes) — fixed with `chgrp apps` + `chmod 2775` (setgid) so both UIDs
  keep write access.
- **Jellyfin Trakt plugin failing** (2026-09-09): plugin v31 (rewritten for Trakt's changed API)
  was installed but stuck in `Restart`-pending status while Jellyfin kept running the superseded
  v30 build. Fixed with a Jellyfin container restart.
- **Caddy retrying ACME cert for truenas.home forever** (2026-09-09): vhost was missing the
  `http://` scheme prefix every other `.home` vhost has, so Caddy treated it as needing a real
  public TLS cert for an internal-only hostname. Fixed by adding the prefix.
- **jellyseerr avatar-cache EACCES** (2026-09-09): 11 files/dirs under
  `/mnt/Fast/docker/jellyseerr/config` were still `root:root`, leftover from before the
  Jellyseerr→Seerr migration. Reowned to `kero66`. (Note: `config/logs/jellyseerr.log` itself gets
  recreated as `root` by the container's own startup process each time — cosmetic, not causing
  errors, left as-is.)

## Container Memory Rightsizing (2026-09-09)

Reviewed 7-day peak `container_memory_working_set_bytes` (cAdvisor via Prometheus) against
`mem_limit` for every container. Full pass committed in `22b1d05` — see that commit message for
the complete before/after table. Highlights:
- `qbittorrent` was at 98% of its 4g limit (real OOM risk) → raised to 6g
- Several previously-uncapped containers (arr-stack services, autobrr, tailscale, gamarr,
  maintainerr, jellyseerr/jellystat/jellystat-db, the grafana-alloy stack itself) got a `mem_limit`
  for the first time, sized ~1.5-2x observed peak
- `jellyfin`, `shokoanime`, `fileflows`, and the infisical/commafeed DBs were over-provisioned and
  shrunk toward observed usage
- Applied via the nightly Dockhand auto-update job (`repullImages` now enabled on all
  `:latest`-tracking stacks — see below), not deployed manually. **Revisit in a few days** to
  confirm no container is getting OOM-killed under its new limit, especially jellyfin and the
  shrunk databases.

## config.alloy / loki-config.yaml mount paths never applied (2026-09-09, resolved)

Both files were bind-mounted from an absolute `/mnt/Fast/docker/grafana-alloy/config/`
path that predated this stack's Dockhand git-sync migration, per a compose.yaml comment
claiming Dockhand's git-stack API "only tracks compose.yaml, not sibling config files" —
requiring a manual `scp` before each deploy. That claim was wrong (or became wrong):
`config/provisioning/` in this same compose file already proved git-sync applies every
tracked file. Nobody ran the manual scp step during tonight's session, so **the earlier
Loki retention fix (commit `e93cf4b`) and the first attempt at the Dockhand metrics scrape
job (`fad1af9`) silently never took effect** despite clean deploys and healthy container
restarts — both configs kept running their old versions the whole time. Caught by
comparing file mtimes between the live mount and the Dockhand-synced copy. Fixed in
`eb06f18` by switching both to relative paths (`./config.alloy`, `./loki-config.yaml`),
matching the already-correct `config/provisioning/` pattern. Verified after the fix:
`retention_period: 720h` present in the actually-mounted file, and
`prometheus.scrape.dockhand` shows healthy in Alloy's component list with
`dockhand_containers_count` genuinely flowing into Prometheus.

**Lesson**: a "successful deploy" and a "healthy container" don't prove a config file
change took effect — verify the *actual mounted content* (via file mtimes, `docker
inspect --format '{{.Mounts}}'`, or reading the file at its real host path) after any
change to a stack whose compose.yaml doesn't already prove its mount pattern works.

## Dockhand Metrics (2026-09-09, in progress)

Dockhand has a Prometheus `/metrics` endpoint (source: `src/routes/metrics/+server.ts`,
gated by `EXPORT_METRICS=true`) — was 404ing because (a) `EXPORT_METRICS` wasn't set, and
(b) our installed Dockhand catalog version (1.1.10 / image `v1.0.45`) predated the
feature anyway.

- Set `EXPORT_METRICS=true` via `dockhand.additional_envs` on the TrueNAS catalog app
  config (`PUT /api/v2.0/app/id/dockhand` with a `values` wrapper — see `ai/PATTERNS.md`
  "Update Dockhand catalog app config"). **First attempt failed** with
  `Mount path [/mnt/Fast] already used for another volume mount` — this exposed a
  **pre-existing bug**: `storage.additional_storage` already had two entries both mapping
  to container path `/mnt/Fast` (one from host `/mnt/Fast`, one from host
  `/mnt/Fast/docker`), unrelated to the env var change. Fixed by resending the full
  config with the duplicate removed and the env var added — succeeded.
- Upgraded Dockhand 1.1.10 → 1.1.30 (`v1.0.46`) via the TrueNAS Apps UI, which is what
  actually shipped the `/metrics` route. Confirmed working: `GET /metrics` (bearer token
  or session auth) returns real Prometheus exposition data — `dockhand_containers_health`,
  `dockhand_container_restarts_total`, `dockhand_updates_available`,
  `dockhand_vulnerabilities`, `dockhand_env_up`, plus internals (jobs, scheduler, DB size).
  This is meaningfully richer than cAdvisor's `container_health_state` (which turned out
  to just indicate "a healthcheck is configured", not actual pass/fail — not useful for
  alerting).
- **Done**: wired into `grafana-alloy`'s Prometheus scrape config (commit `fad1af9`, fixed
  to actually take effect in `eb06f18` — see the mount-path issue above). API token
  created via `POST /api/auth/tokens` (id 2, `grafana-alloy-prometheus-scrape-2`), stored
  as `DOCKHAND_METRICS_TOKEN` in Infisical `/TrueNAS`, rendered into `grafana-alloy/.env`
  by infisical-agent, read by a new `prometheus.scrape "dockhand"` block in `config.alloy`
  via `sys.env(...)` (not bare `env()` — verified against Alloy's actual stdlib docs).
  Confirmed live: `dockhand_containers_count` etc. flowing into Prometheus.
  A `scrape-target-down` alert rule (`up < 1`) now also covers this + the cAdvisor job —
  the monitoring pipeline failing silently would otherwise show as every other alert just
  going quiet instead of firing.

## Dockhand Auto-Update Config (2026-09-09)

`repullImages` was `false` on every git stack except where explicitly set — meaning the nightly
3am auto-update job only re-synced compose/config from git, it did **not** pull new `:latest`
images. Enabled `repullImages: true` on every `autoUpdate: true` stack still tracking `:latest`
(arr-stack, caddy, commafeed, downloaders, homepage, infisical, infisical-agent, jellyfin,
maintainerr, suggestarr, tailscale). Left untouched: version-pinned stacks (autobrr, fileflows,
grafana-alloy, recyclarr — pinned deliberately after past upgrade issues) and stacks with
`autoUpdate: false` (gamarr, shokoanime, signoz).
