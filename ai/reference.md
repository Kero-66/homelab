# External references used by Copilot

Sources consulted when investigating NZBGet and public NNTP providers:

- Eternal September (news.eternal-september.org) — public/text-only NNTP server (registration required).
  - https://eternal-september.org/

- Usenet (Wikipedia) — general background and provider list references (Astraweb, Easynews, Giganews, Supernews).
  - https://en.wikipedia.org/wiki/Usenet

- AIOE (public NNTP project) — historical/public text NNTP resource (site fetch attempted).
  - https://aioe.org/

Notes:
- Eternal-September explicitly states it provides text-only newsgroups (no binaries). This is relevant when configuring NZBGet (which downloads binaries) — text-only servers cannot satisfy binary NZB downloads.
- For reliable binary downloads you typically need a commercial Usenet provider (trial accounts are often available).

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
