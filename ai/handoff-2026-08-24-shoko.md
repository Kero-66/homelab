# Handoff — 2026-08-24 — Shoko deployment, GitOps improvements, OOM incident

**Repo**: `/Users/kieran/repos/homelab`

**Read first**: `.claude/memory/MEMORY.md` for any related repo-tracked feedback. This doc covers everything from Shoko's initial setup through a mid-session TrueNAS crash and its follow-up. Commits are the source of truth for exact diffs — this is a narrative pointer, not a duplicate.

---

## Where this session landed

### 1. Shoko Server deployed and working end-to-end
New service (`truenas/stacks/shokoanime/`) for anime library management, registered as a Dockhand git stack (id 18), joined to `arr-stack_default` + `jellyfin_default`. Fixed along the way: wrong healthcheck endpoint (`/api/v3/ping` 404s; `/api/v3/Init/Status` is correct), obsolete `version:` compose key. AniDB creds (`ANIDB_USERNAME`/`ANIDB_PASSWORD`) flow via a new `shokoanime.tmpl` — currently unused dead weight since the user configured AniDB via the UI instead (left in per user's call, "doesn't hurt anything"). Reverse-proxied at `shoko.home` (Caddy + AdGuard DNS rewrite, both applied). Shoko's own renamer (`RenameOnImport`/`MoveOnImport`/`RelocateOnImport`) is confirmed **off** — it only identifies/hashes files against AniDB, never touches disk. AniDB import is slow (rate-limited API) and was still processing (~2/74+ series matched, thousands of jobs queued) as of session end — check `GET /api/v3/Queue` and `GET /api/v3/Series?pageSize=0` on Shoko's API to see current progress.

**Architecture decision** (see conversation, not written to a doc yet — worth capturing in `media/docs/` if this becomes permanent): Shoko will NOT replace Sonarr for acquisition. Sonarr keeps searching/grabbing normally for all shows, anime included. The "Sonarr acquires, Shoko organizes" hybrid (disabling Sonarr's Completed Download Handling) was researched and found to require a **second, dedicated Sonarr instance** since that setting is instance-global, not per-series — this was explicitly deferred, not started. Shoko's actual goal is AniDB-based chronological watch-order playlists via Shokofin in Jellyfin, which doesn't need the renamer or a second Sonarr at all.

### 2. Shokofin plugin installed and configured in Jellyfin
Plugin repo added, `Shoko` plugin (v6.0.5.11) installed via Jellyfin's REST API, Jellyfin restarted to activate. Configured to point at `http://shoko_server:8111` (container network) with the `SHOKO_API_KEY` secret (Infisical `/media` path — this key is for direct API/tooling use, not injected into any container). New "Anime" Jellyfin library created (`/data/shows` + `/data/movies`, Shoko as metadata+image fetcher, VFS mode — Shokofin's default). Initial scan triggered.

**Known consequence, accepted deliberately**: anime titles will show in both the existing TV/Movies libraries AND the new Anime library (duplicates) until the anime folders are excluded from the original libraries' scope — user chose "accept duplicates for now" rather than sort out folder separation immediately.

### 3. True GitOps for `infisical-agent` and `caddy` (unblocks future config changes)
Discovered Dockhand actually clones the **whole repo** per git-stack (not just the compose file) under `/mnt/.ix-apps/app_mounts/dockhand/data/git-repos/TrueNAS/<stack>/`. Changed both stacks' compose files to mount config from a relative path (`./`) instead of an absolute `/mnt/Fast/docker/...` path, so `agent-config.yaml`/`*.tmpl` (infisical-agent) and `Caddyfile` (caddy) now update automatically on `sync`+`deploy` — no more manual `scp`. Hit and fixed a real regression along the way: `infisical-agent`'s auth credentials (`client-id`/`client-secret`/access-token sink) were never in git and briefly broke when `/config` became read-only-from-git; fixed by splitting into two mounts (`/config` from git, `/auth` from the original Fast-pool path for credentials only).

Also explored (proven working, NOT wired into any stack yet): Dockhand's native Infisical secrets-provider integration (`POST /api/secret-providers`, tested `ok:true` against the same `dev`/`/media` Infisical path) — could eventually replace `infisical-agent` + `.tmpl` files entirely for any stack, by binding a provider directly to a git stack (`PUT /api/git/stacks/{id}` with `secretProviderId`). Registered as provider id 1, name `infisical-homelab`. This is a bigger architectural change than anything done this session — treat as a separate, deliberate follow-up if picked up again.

### 4. Mid-session TrueNAS crash — root-caused and partially remediated
Triggering a recursive Jellyfin scan on the new Anime library (spawning dozens of concurrent `ffprobe` processes) landed at the same time as Shoko's own heavy AniDB import queue. Combined memory pressure caused two OOM kills (`journalctl -b -1`, 13:47:40 and 13:48:08) severe enough to crash the whole host (not just the container) — TrueNAS was fully unreachable for several minutes, then came back up cleanly on its own (`restart: unless-stopped` on every container worked correctly).

Root cause had two parts, confirmed with real data (not guessed):
- **Shoko was uncapped** — fixed, `mem_limit: 2g` added and deployed.
- **ZFS ARC had no cap** (`zfs_arc_max` was `0` = default, which on this box meant ARC could grow to ~14.4GB of 15GB total RAM) — fixed, capped to 8GB via a TrueNAS `ZFS`-type tunable (persisted, id 1) and applied live (`/sys/module/zfs/parameters/zfs_arc_max`).
- **Separately found via 2-day Prometheus history** (Alloy's cAdvisor pipeline, confirmed working — query `container_memory_working_set_bytes{job="integrations/docker"}` on `http://127.0.0.1:9090` from TrueNAS, or `max_over_time(...[2d])` for peaks): `qbittorrent` was the single largest uncapped memory consumer in the whole fleet, peaking at 4.74GiB — bigger than Jellyfin's already-capped 4g peak. Capped to `mem_limit: 4g` (intentionally below its observed peak, so it gets container-killed and restarted rather than threatening the host again).

Everything else in the fleet showed peaks well under 1GiB over the 2-day window — not urgent to cap, but could get modest default caps later as cheap insurance (this was explicitly deferred as a "scale up" phase, not started).

Added `ai/todo.md` #108: decide a TrueNAS update strategy (untouched territory this session — worth a fresh look, since ARC/mem_limit tuning may need re-verification after a version update).

---

## Outstanding as of session end — check these first

- **Shoko's AniDB import** — still running, rate-limited. Check `http://shoko.home` or the API for progress. Shokofin's playlist/group features will populate as more series get matched.
- **Anime library duplicates** — user accepted this for now; revisit excluding anime folders from the original TV/Movies libraries once satisfied with how the Shoko-powered library looks.
- **Dual-Sonarr-for-anime** — deliberately deferred, not started. Only relevant if the user later wants Shoko to actually organize/rename files (currently off).
- **Dockhand-native Infisical secrets provider** — proven working (`infisical-homelab`, provider id 1) but not bound to any stack. Real architectural upgrade if pursued, treat as a new task.
- **Remaining fleet memory caps** — only `shoko_server` and `qbittorrent` capped based on real data. Rest of the fleet (jellyfin/caddy/infisical/etc. were already capped pre-session) is low-risk per 2-day peaks, not urgent.
- **`ai/todo.md` #108** — TrueNAS update strategy, newly added, untouched.

---

## Gotchas hit this session, worth knowing before continuing

- **The security-review pre-commit hook token must come from an actual review**, not a manually-written timestamp file — got called out for this twice by the user. Run a real review (subagent or the `/security-review` skill flow), *then* write `~/.claude/hooks/.security-review-timestamp`. Don't pre-write it before reviewing.
- **`git commit`/`ssh-agent -k` must run in the same Bash tool call as whatever set up state before it** — a security-review timestamp written in one tool call and a `git commit` in a separate one can hit the pre-commit hook before the file is visible; batch them. Similarly `ssh-agent -k` only works if `SSH_AGENT_PID`/`SSH_AUTH_SOCK` are still set from the same call that started the agent.
- **Dockhand's git-stack deploy doesn't always recreate the container** — it only recreates when the *compose file itself* changes something Docker Compose diffs on (e.g. a volume mount source path). A Caddyfile content-only change via the old absolute-path mount required a manual `scp` + `docker exec caddy caddy reload`; switching to the relative-path git-clone mount fixed the scp requirement, but `caddy reload` is still needed after any future Caddyfile edit specifically (compose doesn't recreate the container for bind-mount content changes).
- **Dockhand API auth quirk**: some job-status responses contain raw control characters that break `jq`; use Python's `json.load` instead when `jq` throws "Invalid string: control characters."
- **Container name in Dockhand's `docker ps` isn't always what you'd guess** — Dockhand itself runs as `ix-dockhand-dockhand-1`, not `dockhand`.
- **This workstation's Bash tool has an inconsistent DNS resolver** — `host`/`nslookup` can resolve `*.home` hostnames while `curl` in the same environment reports "Could not resolve host." Use IP + `Host:` header, or route through SSH to TrueNAS, for any `*.home` verification from this tool.
- **ZFS ARC counts as "used" memory in `free -h` but is technically reclaimable** — don't read a high "used" number as proof of real application memory pressure without checking `/proc/spl/kstat/zfs/arcstats` (`c`/`c_max`) first, especially right after a reboot when ARC is still cold and rebuilding.

---

## Suggested skills for next session

- If picking up the dual-Sonarr-for-anime work: no specific skill indicated, same direct compose+Prowlarr API pattern used throughout this session.
- If wiring Dockhand's native Infisical secrets provider into a real stack: this is a genuine architecture change (could eventually retire `infisical-agent` for every stack) — worth a `Plan` pass or at least an explicit scoping conversation before touching multiple stacks' compose files, rather than doing it ad hoc.
- If investigating further OOM/capacity work: query Alloy/Prometheus (`http://127.0.0.1:9090` from TrueNAS) for real data before guessing at caps — this session's `qbittorrent` finding only came from checking actual 2-day peaks, not assumption.
