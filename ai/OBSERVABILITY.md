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

## Dockhand Auto-Update Config (2026-09-09)

`repullImages` was `false` on every git stack except where explicitly set — meaning the nightly
3am auto-update job only re-synced compose/config from git, it did **not** pull new `:latest`
images. Enabled `repullImages: true` on every `autoUpdate: true` stack still tracking `:latest`
(arr-stack, caddy, commafeed, downloaders, homepage, infisical, infisical-agent, jellyfin,
maintainerr, suggestarr, tailscale). Left untouched: version-pinned stacks (autobrr, fileflows,
grafana-alloy, recyclarr — pinned deliberately after past upgrade issues) and stacks with
`autoUpdate: false` (gamarr, shokoanime, signoz).
