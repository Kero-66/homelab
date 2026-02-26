# External references used by Copilot

Sources consulted for external service configuration and APIs.

## Infisical CLI & Docker usage (2026-01-17)
- https://github.com/infisical/infisical/blob/main/docs/documentation/getting-started/cli.mdx
- https://github.com/infisical/infisical/blob/main/docs/documentation/getting-started/docker.mdx
- https://github.com/infisical/infisical/blob/main/docs/integrations/platforms/docker-pass-envs.mdx
- Notes: `infisical run` injects secrets into the process environment; alternative is `infisical export --format=dotenv` piped to Docker `--env-file` (single-line values only).

## Prowlarr API docs (recorded)

- URL: https://prowlarr.com/docs/api/
- OpenAPI JSON (use for programmatic generation): https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/src/Prowlarr.Api.V1/openapi.json
- Notes (2025-12-23): Prowlarr exposes a v1 API under `/api/v1` (server base often http://localhost:9696). Key resource groups include:
  - `indexer` (list, test, categories), `search` (POST/GET search endpoints), `health`, `history`, `downloadclient`, `notification`, `system`/`task` and `tag`.
  - Use the OpenAPI JSON above to discover exact request/response schemas and supported query parameters (recommended when building scripts).

Recording rationale:
- Save this doc here so automation/scripts use the canonical OpenAPI JSON rather than ad-hoc one-liners that cause repeated shell quoting mistakes.

## SABnzbd Configuration (2026-01-08)
- **inet_exposure**: Must be set to `0` (or `1` with caution) to allow full UI access via reverse proxy (Caddy). `2` (API only) blocks the browser UI.
- **host_whitelist**: Ensure Docker subnets (`172.16.0.0/12`) and `localhost` are included to prevent "External internet access denied" errors when proxied.
- **local_ranges**: Should include local network subnets to allow cross-container API communication without strict authentication blocks.

## Usenet Binary Providers (2026-01-08)
- **Easynews**: Binary Usenet provider verified working.
  - Port: 563 (SSL) / 119 (Non-SSL)
  - Host: news.easynews.com
  - Connection limit: 20 recommended.
  - Testing: Verified first-byte flow and full 6.2MB/s download using DrunkenSlug as indexer and SABnzbd as client.

## Jellyseerr API Integration
- **API Version**: v1
- **Discovery**: Access via browser at `/settings/about` or `/api/v1/status` (requires header `X-Api-Key`).
- **Authorization**: Requires `X-Api-Key` header with a valid API key. Fixed 403 error on Homepage dashboard by ensuring this key is mapped via `HOMEPAGE_VAR_JELLYSEERR_API_KEY`.

## Homelab Automation - Homepage & Media Stack Sync
- **Script**: `apps/homepage/scripts/generate_env_from_media.sh`
- **Function**: Automatically extracts API keys from `config.xml`, `sabnzbd.ini`, and `config.yaml`. It also pulls all `IP_*` variables from `media/.env` and credentials from `media/.config/.credentials`.
- **Dependency**: Run this script before starting the homepage container to ensure all variables are populated for Compose interpolation.
- **SABnzbd Fix**: Automated hardening in the script sets `inet_exposure = 0` and configures `host_whitelist` and `local_ranges` to allow access from Caddy and other containers.

## Cleanuparr API Documentation (2026-01-08)

- **Base URL**: `http://localhost:11011/api`
- **Authentication**: Header `X-Api-Key` required.
- **Key Endpoints**:
  - `GET /configuration/general`: Retrieve systemic settings (Dry Run, logging, timeouts).
  - `PUT /configuration/general`: Update systemic settings. Field `dryRun: false` to enable live mode.
  - `GET /configuration/queue_cleaner`: Retrieve queue cleaning rules (Stalled, Failed Import, Slow).
  - `PUT /configuration/queue_cleaner`: Update cleaning rules.
    - Path `failedImport.enabled: true` and `failedImport.maxStrikes: 3` handles "Invalid season or episode" errors.
    - Path `stallRules` array handles stalled downloads.
  - `POST /jobs/{jobName}/trigger`: Manually trigger a background task (e.g., `QueueCleaner`, `MalwareBlocker`).
  - `GET /jobs`: List all available jobs and their schedules.
- **Notes**: Does NOT use `/v1/` prefix in the REST path. Accessing `/v1/` returns the Angular frontend HTML.

## Bazarr API Documentation (2026-01-08)
- **Base URL**: http://localhost:6767/bazarr/api
- **Swagger UI/JSON**: http://localhost:6767/bazarr/api/swagger.json
- **Authorization**: Requires header `X-API-KEY` with value `{{BAZARR_API_KEY}}`.
- **Key Resource Groups**:
  - `system/status`: Environment info and versions.
  - `system/health`: List current health issues.
  - `system/languages/profiles`: List or update subtitle language profiles (Anime/Standard).
  - `series`: Sync or list series metadata (link to Sonarr).
  - `movies`: Sync or list movie metadata (link to Radarr).
  - `episodes/wanted`: List missing subtitles for episodes.
  - `system/tasks`: Run manual syncs (`update_series`, `update_movies`).
- **Notes**: Bazarr uses a flat schema for many endpoints. If an endpoint returns the SPA HTML instead of JSON, check the base URL prefix (`/bazarr`) and ensure the trailing slash is omitted unless required by the Swagger spec.

## Beszel Hub & Agent (2026-01-09)
- **Documentation**: [https://beszel.dev/](https://beszel.dev/)
- **Auto-Provisioning**: Use `USER_EMAIL` and `USER_PASSWORD` env vars for the Hub to bypass the setup screen.
- **Agent Communication**: In a Docker bridge network, set `extra_hosts` with `host.docker.internal:host-gateway` on the Hub to allow it to reach the Agent running in `network_mode: host`.
- **Registration**: System records can be managed via PocketBase API at `/api/collections/systems/records`.

## JetKVM Tailscale Setup (2026-02-26)

- **Device IP**: 192.168.20.25 (LAN), **Tailscale IP**: see Tailscale admin console
- **SSH user**: `root` (key-based only, Developer Mode must be enabled)
- **Web UI**: Password-only (no username). Login endpoint: `POST /auth/login-local` with `{"password":"..."}` → sets `auth` cookie (7-day TTL).
- **Infisical secrets** (env `dev`, path `/networking`):
  - `JETKVM_PW` — web UI password
  - `JETKVM_SSH_PUBLIC_KEY` — Ed25519 public key installed on device
  - `JETKVM_SSH_PRIVATE_KEY` — Ed25519 private key for SSH automation
- **Tailscale auth key used**: `TRUENAS_TAILSCALE_AUTH_KEY` (env `dev`, path `/TrueNAS`)
- **Install method**: Official script `https://jetkvm.com/install-tailscale.sh` with `-y` flag (skips TTY prompt):
  ```bash
  eval $(ssh-agent -s) > /dev/null
  infisical secrets get JETKVM_SSH_PRIVATE_KEY --env dev --path /networking --plain | ssh-add - 2>/dev/null
  TS_AUTH_KEY=$(infisical secrets get TRUENAS_TAILSCALE_AUTH_KEY --env dev --path /TrueNAS --plain)
  curl -fsSL https://jetkvm.com/install-tailscale.sh | sh -s -- -y 192.168.20.25 -- --authkey="$TS_AUTH_KEY"
  ssh-agent -k > /dev/null
  ```
- **Known warnings** (harmless on BusyBox): `socket: protocol not supported`, `getting OS base config is not supported`, DNS config errors. Tailscale connectivity works fine despite these.
- **JetKVM REST API**: No Tailscale endpoints — install is SSH-only. See [JetKVM docs](https://jetkvm.com/docs/advanced-usage/developing) for Developer Mode instructions.

## TrueNAS Scale Custom App Management (2026-02-12)
- **Documentation**:
  - [Custom App Screens | TrueNAS Documentation Hub](https://www.truenas.com/docs/scale/25.10/scaleuireference/apps/installcustomappscreens/)
  - [Installing Custom Apps | TrueNAS Apps Market](https://apps.truenas.com/managing-apps/installing-custom-apps/)
  - [API Reference | TrueNAS Documentation Hub](https://www.truenas.com/docs/scale/api/)
- **Community Tools**:
  - [truenas-scale-custom-app-control](https://github.com/meyayl/truenas-scale-custom-app-control) - Wrapper for app management API
- **Compose File Location**: Custom Apps store rendered compose files at:
  - `/mnt/.ix-apps/app_configs/<APP_NAME>/versions/<VERSION>/templates/rendered/docker-compose.yaml`
- **Update Method**: Can be updated directly via SSH + docker compose:
  ```bash
  # Upload updated compose
  scp compose.yaml root@TRUENAS:/mnt/.ix-apps/app_configs/APP/versions/1.0.0/templates/rendered/docker-compose.yaml

  # Recreate containers (uses TrueNAS project name: ix-APP_NAME)
  ssh root@TRUENAS 'docker compose -p ix-APP_NAME -f /path/to/compose.yaml up -d'
  ```
- **Notes**:
  - TrueNAS 25.10 REST API cannot create Custom Apps — use `midclt call -j app.create` via SSH (see PATTERNS.md)
  - midclt tool can query apps: `midclt call app.query`, `midclt call app.get_instance APP_NAME`
  - Docker networks created by TrueNAS use `ix-APP_NAME_default` naming convention
