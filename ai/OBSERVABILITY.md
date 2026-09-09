# Observability Tracking

Findings from log/metric review via Grafana (Loki logs + Prometheus/cAdvisor metrics,
`grafana-alloy` stack, http://grafana.home). See `ai/PATTERNS.md` "Querying it back" for the
Loki datasource-proxy query pattern used to pull these.

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
- **Not yet done**: wiring this into the `grafana-alloy` Prometheus scrape config.
  Dockhand's Prometheus auth needs a bearer API token (session cookies don't work for
  scraping) — was investigating `POST /api/auth/tokens` (`src/routes/api/auth/tokens/+server.ts`)
  when this got deprioritized in favor of other items. Next step: generate a token (via
  the UI under Profile, or that API), store it in Infisical, add a
  `prometheus.scrape "dockhand"` block to `config.alloy` with `bearer_token_file` or
  inline `authorization.credentials`, target `http://192.168.20.22:30328/metrics`.

## Dockhand Auto-Update Config (2026-09-09)

`repullImages` was `false` on every git stack except where explicitly set — meaning the nightly
3am auto-update job only re-synced compose/config from git, it did **not** pull new `:latest`
images. Enabled `repullImages: true` on every `autoUpdate: true` stack still tracking `:latest`
(arr-stack, caddy, commafeed, downloaders, homepage, infisical, infisical-agent, jellyfin,
maintainerr, suggestarr, tailscale). Left untouched: version-pinned stacks (autobrr, fileflows,
grafana-alloy, recyclarr — pinned deliberately after past upgrade issues) and stacks with
`autoUpdate: false` (gamarr, shokoanime, signoz).
