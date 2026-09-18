# Observability Tracking

Findings from log/metric review via Grafana (Loki logs + Prometheus/cAdvisor metrics,
`grafana-alloy` stack, http://grafana.home). See `ai/PATTERNS.md` "Querying it back" for the
Loki datasource-proxy query pattern used to pull these.

## Observability coverage audit (2026-09-18)

Full audit of what is actually collected vs what is running, prompted by a crash-looping
container that a casual check had missed. Method and verified numbers:

- **Metrics coverage is complete.** All 37 running containers (per Dockhand
  `/api/containers?env=1`) appear in cAdvisor's `container_memory_working_set_bytes`. All 5
  scrape targets are `up`: `cadvisor-standalone`, `integrations/node_exporter`,
  `integrations/smartctl`, `prometheus.scrape.dockhand`, `prometheus`.
- **Log coverage had a real hole — fixed this session.** 6 of 37 running containers had
  **zero** log lines in Loki over 30 days. `loki.process "docker_logs"` used
  `stage.drop { expression = "(alloy|grafana|loki)" }` — an *unanchored substring* match.
  Every container in this stack is named `grafana-alloy-*`, so it also silently dropped
  `grafana-alloy-cadvisor`, `-prometheus` and `-smartctl-exporter`, which were plainly
  meant to be kept. This already cost real diagnostic ability: the 2026-09-11 cAdvisor CPU
  investigation (below) had to fall back to reading `docker logs` directly precisely
  because Loki had never held a single cAdvisor line. Fixed by anchoring to
  `^grafana-alloy-(alloy|grafana|loki)$`. `infisical-db` and `qbittorrent` also looked
  silent in a 24h window but are simply low-volume — they do log.
- **No filesystem-space alert existed — added this session.** The `Disk Health` group
  covered SMART status, reallocated/pending sectors, temperature and pool-online state,
  but nothing fired when a pool merely filled up, which is the most likely way this box
  actually breaks. Found `/mnt/Data/Servarr` at **94% used (420GB free of 6.49TB)** with
  nothing watching it. Added `filesystem-space-low` (>90% for 15m, warning).
- **Memory is overcommitted 2.1x with no swap.** Sum of container `mem_limit` values is
  **32.8GB on a 15.4GB host**, `SwapTotal` is **0**. Actual container working set is ~7.4GB
  and ZFS ARC ~1.4GB (of an 8GB `arc_c_max`), so ARC is *not* the reason available memory
  looks low — the pressure is genuine. `Host memory available low` was observed firing
  during this audit at 6% available. Limits are caps rather than reservations so the
  overcommit is not inherently fatal, but it means there is no headroom if several
  containers peak together, and nothing can spill to swap.
- **History depth is shorter than retention implies.** Prometheus is configured
  `--storage.tsdb.retention.time=30d` and Loki `retention_period: 720h`, but host metrics
  only go back ~3-6 days (node_exporter was deployed recently) and cAdvisor series resolve
  at 14d but not 30d. Don't assume a 30-day lookback will return data.

### The structural gap: nothing alerts on logs

**All 14 alert queries target Prometheus. Zero target Loki.** Loki has no `ruler` block in
`loki-config.yaml`, so it cannot evaluate log-based rules at all (this is also the cause of
the cosmetic "Loki Error badge" entry further down). Consequence: any failure that exists
*only* as a log line is invisible to alerting — Dockhand deploy failures, the 43 registry
`toomanyrequests` rate-limit hits seen over 7 days, jellyseerr/infisical auth failures, and
*arr import failures. This is the real reason a human watching Dockhand's UI saw problems
that a metrics-only check reported as all-clear. Closing it means either configuring Loki's
ruler or adding Grafana-managed rules backed by the Loki datasource.

### An alert that fires on phantom data (fixed 2026-09-18)

**Correction to an earlier draft of this entry**, which claimed the rule "cannot fire"
because "all 37 series read 1". That was wrong — it came from checking only that nothing
read `0` *at that moment* and over-reading a stale note. The real value distribution is
exactly as designed: **5 containers at `-1`** (no healthcheck), **32 at `1`** (healthy),
matching Dockhand's own view (5 none / 32 healthy) precisely. The metric encodes the three
states correctly.

The actual defect is the opposite of "never fires" — it fires on **phantom values**.
cAdvisor samples a container's Docker health once at discovery and never refreshes it (the
2026-09-10 entry below), so containers recreated by a deploy stick at their discovery-time
value until `grafana-alloy-alloy` itself restarts. Measured over 7d: `count(container_health_state == 0)`
sat at **21-22 containers simultaneously from 2026-09-10 to 2026-09-13, then dropped to 1
all at once**. Unrelated containers do not fail and recover in lockstep — those were stale
cached zeros. Per-container totals show the same fingerprint: twelve unrelated containers
each with exactly 1341 "unhealthy" minutes, three more with exactly 1197.

So `Container healthcheck failing` was a multi-day false-positive generator after every
deploy. Fixed by repointing it at `dockhand_containers_health{health="unhealthy"}`, which
reads Docker's live health state. Verified before switching that Dockhand genuinely emits
all three label values (`healthy`, `starting`, `unhealthy` all present within 7d) and that
its healthy count tracks reality (ranged 21-33 over the same window) — i.e. it is a real
signal, not another metric that can only ever report one value.

Tradeoff accepted: the Dockhand metric is an environment-wide aggregate with **no
per-container label**, so the alert says *how many* are unhealthy, not *which*. Identify the
container via Dockhand's UI or `GET /api/containers?env=1`. Nothing we currently scrape
exports per-container health that is both live and correct.

### Known collection boundary: stdout only

Loki collects container **stdout/stderr** via `loki.source.docker`. The *arr apps write
their real application logs to `config/logs/*.txt` inside their config dirs, not to stdout —
which is why a Sonarr error search over 6h returns only a handful of stdout lines while the
app's own log file is far more detailed. Log coverage being "complete" means every container's
stdout is captured, not that every app's internal log is searchable in Grafana.

**Method note — how the earlier miss happened.** A 6-hour Loki window and the
*current-state* APIs (`/api/git/stacks` `syncStatus`, `/api/alertmanager/.../v2/alerts`)
all returned clean while a container was actively OOM-crash-looping. Snapshot endpoints
only show what is wrong *right now*; an alert that fires and clears between checks leaves
no trace there. Query the underlying counters over a wide window instead — see
`ai/PATTERNS.md` "Checking for issues".

## Host-level metrics added for Valheim prep (2026-09-10 — DEPLOYED, verified live 2026-09-18)

**Status corrected 2026-09-18**: this entry previously said "staged — not yet deployed".
It has since been deployed — `integrations/node_exporter` is `up`, and `node_memory_*`,
`node_filesystem_*`, `node_zfs_*` all return data. The open questions it listed are
answered: the exporter starts cleanly against the existing mounts, and `/mnt/Fast` and
`/mnt/Data` mountpoints do come through the filesystem collector's default excludes.

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

**Stale claim corrected 2026-09-18**: the paragraph below says `grafana-alloy` is
`autoUpdate: false` (version-pinned) and needs an explicit Dockhand sync+deploy. Live check
via `GET /api/git/stacks` shows `autoUpdate=true, forceRedeploy=true, repullImages=true` —
it picks changes up on the daily sync like every other stack. (The `Dockhand Auto-Update
Config` section further down also lists grafana-alloy as version-pinned; same correction
applies.) Trigger a sync explicitly if you need a change applied before the next daily run.

**Not yet verified live** (no LAN access at the time this was written): whether `prometheus.exporter.unix`
actually starts cleanly against the existing mounts, whether the filesystem collector's
default `mount_points_exclude` regex lets `/mnt/Fast`/`/mnt/Data` through as expected (it's
node_exporter's stock default, not overridden here — if either mountpoint doesn't show up,
check that first), and whether the new alert rules evaluate without error. `grafana-alloy` is
`autoUpdate: false` (version-pinned) — this needs an explicit Dockhand sync+deploy, not just a
git push, to take effect. Tracked in `ai/todo.md` #123.

## cadvisor + jellyfin/IntroSkipper CPU spikes (2026-09-11, resolved/mitigated)

`container_cpu_usage_seconds_total` (via the new standalone cadvisor sidecar, see the
`container_health_state` entry below) showed `grafana-alloy-cadvisor` and `jellyfin` together
consuming ~75% of the host's 4 cores sustained.

- **cadvisor (~1.56 cores, resolved)**: default `enable_metrics` set includes `disk`/`diskIO`,
  whose `fsHandler` does a recursive filesystem `du` + inode-count scan per container every
  housekeeping cycle. Confirmed via `docker logs` taking 2-3.5s per scan across ~38 containers,
  plus repeated errors scanning stale overlay2 dirs for already-removed containers. Fixed:
  narrowed to `--enable_metrics=cpu,memory,oom_event` (exactly what `container-rightsizing.json`
  queries) — dropped to ~4% CPU immediately after redeploy. `container_health_state` is
  unaffected (separate Docker-inspect code path, not gated by this flag).
- **jellyfin (~1.43 cores, mitigated not resolved)**: the IntroSkipper plugin was mid-batch-scan
  across the library (`ScanIntroduction`/`ScanCredits`/`ScanRecap`/`ScanPreview`/
  `ScanCommercial` all enabled), spawning ffmpeg blackframe/blackdetect/entropy analysis
  processes. `MaxParallelism: 2` was already set, but `ProcessThreads: 0` let each of those 2
  parallel ffmpeg instances use unlimited threads, oversubscribing the 4-core host. Set
  `ProcessThreads: 2` via the plugin's own config API
  (`POST /Plugins/<id>/Configuration`, plugin id `c83d86bba1e04c35a113e2101cf4ee6b`) so 2
  parallel items × 2 threads matches the core count instead of exceeding it. This is a one-time
  library backlog scan, not a standing config problem — it'll taper off as it completes; revisit
  if it recurs on every future library scan.
  - **Noted in passing, not yet cleaned up**: two IntroSkipper plugin versions
    (`12.0.3.0` and `12.0.4.0`) are both installed under the same plugin id — a stale leftover
    from an upgrade. Not the CPU cause, but worth removing the old version's directory
    (`/mnt/Fast/docker/jellyfin/config/data/plugins/Intro Skipper_12.0.3.0/`) at some point.
  - **Follow-up identified 2026-09-12, not yet applied — `--housekeeping_interval` was never
    set, so cAdvisor was (and still is) running its internal collection loop at the default
    **1s**, independent of and 10x faster than the `cadvisor_standalone` Prometheus job's actual
    10s scrape interval (`config.alloy`). The `disk`/`diskIO` fsHandler walk wasn't inherently
    unaffordable — it was being *attempted* every 1s when a single full sweep across ~38
    containers already took 2-3.5s, so cycles were queuing on top of each other. A documented
    real-world case (akashrajpurohit.com, "Optimizing cAdvisor for Lower CPU Usage") got a 65%
    CPU cut from `--housekeeping_interval=10s` alone, no metrics disabled. Setting this flag
    (matching our scrape interval) is very plausibly enough on its own to make `disk`/`diskIO`
    affordable again without permanently giving up per-container disk usage — untested here,
    would need to be re-added and watched the same way the original spike was diagnosed
    (`container_cpu_usage_seconds_total` via cadvisor-standalone) before trusting it. User
    decided to document rather than apply for now — see `ai/todo.md`.
  - **Why cAdvisor is the heavier option in the first place**: it was built at Google as
    Kubernetes' per-container telemetry backend for real-time scheduling/autoscaling decisions,
    which is why its default housekeeping loop is 1s regardless of scrape frequency. Docker's
    own stats API (what Dockhand's per-container UI reads) was built for humans glancing at a
    dashboard — it only streams the cheap cgroup `blkio` I/O-throughput counters live, and
    computes actual disk *usage* on-demand rather than in a continuous background loop.
    Dockhand's `/metrics` Prometheus endpoint (scraped separately, see the Dockhand Metrics
    entry below) is a third, distinct thing again — environment-wide aggregates only
    (`dockhand_containers_health{health="healthy"} 33`), no per-container label at all;
    confirmed live against the raw endpoint 2026-09-12. Three different data sources, three
    different cost/granularity tradeoffs, not one API with three views onto it.

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
`autoUpdate: false` (gamarr, shokoanime). (SigNoz, also `autoUpdate: false`, was torn down
2026-09-12 — see `ai/todo.md` #114.)

## Log level detection — Serilog / ANSI formats (2026-09-18)

Loki's built-in level discovery only recognises the full level word (`[Info]`, `[INFO]`,
`"level":"debug"`). Containers using Serilog's three-letter codes (`[INF]`/`[WRN]`/`[DBG]` —
sportarr, cleanuparr, jellyfin) or ANSI-coloured levels (jellyseerr) all landed on
`detected_level="unknown"`, which made Grafana's level filtering and colouring useless for them.

Fix: two `stage.match` blocks in `truenas/stacks/grafana-alloy/config.alloy` that regex the level
token and write it as **structured metadata** (`detected_level`), never a label — a label would
multiply stream count by container × level. Each block is guarded by a **line filter** in the
selector, not just a container matcher: a non-matching line entering the block would get an empty
`detected_level` stamped on it, which suppresses Loki's own detection for the formats it already
handles correctly (sonarr, radarr, prowlarr, fileflows, autobrr, caddy, infisical).

Verified after deploy: sportarr `info`/`warn`, jellyfin `debug`, jellyseerr `debug`; autobrr,
caddy, fileflows, infisical, prowlarr unchanged.

Still `unknown` on purpose — no level token in the format at all: infisical-redis (`*`/`#`/`-`),
commafeed-db + jellystat-db (postgres), tailscale, valheim, and jellyfin's stack-trace
continuation lines (`   at Foo.Bar(...)`), which are separate log lines and would need multiline
joining to inherit the level of the line above.

**Two traps hit while landing this**, both worth remembering:
1. The match stage's `|~` pattern **must be a double-quoted LogQL string**. A LogQL backtick raw
   string is valid LogQL but this parser rejects it (`unexpected IDENTIFIER, expecting STRING`),
   and Alloy then refuses its initial config load entirely — the container crash-looped and log
   ingestion stopped until it was corrected. Write it as an Alloy raw string containing a
   double-quoted LogQL string.
2. `config.alloy` is a **single-file bind mount**, so a Dockhand git sync updates the file on disk
   without the container seeing it (old inode), and `POST /-/reload` returns 200 against the stale
   content. See CLAUDE.md's Dockhand "Caveat 2" — force-recreate and verify behaviour, not status.
