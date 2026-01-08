# Homepage (gethomepage)

This folder contains a minimal scaffold to run the Homepage dashboard locally.

Files:
- `docker-compose.yml` - runs the `gethomepage/homepage` container and mounts `./config`.
- `config.yml.sample` - example configuration. Copy to `config/config.yml` and edit.

Quick start:

1. Copy the sample config and edit:

```bash
mkdir -p apps/homepage/config
cp apps/homepage/config.yml.sample apps/homepage/config/config.yml
# edit apps/homepage/config/config.yml to suit
```

2. Start with Docker Compose (from repo root):

```bash
cd apps/homepage
# uses `compose.yaml` in this folder; override image/port with env vars
HOMEPAGE_IMAGE=your/image:tag HOMEPAGE_PORT=3000 docker compose up -d
```

Networking: Ensure the container can reach your media services by attaching to the same Docker network (the media stack uses `servarrnetwork`). You can override the network name with `SERVARR_NETWORK_NAME` when running:

```bash
HOMEPAGE_IMAGE=your/image:tag SERVARR_NETWORK_NAME=servarrnetwork HOMEPAGE_PORT=3000 docker compose up -d
```

Or simply copy the environment defaults from `.env.sample`:

```bash
cp .env.sample .env
docker compose up -d
```

3. Open http://localhost:3000

Notes:
- The image and port are configurable via the `HOMEPAGE_IMAGE` and `HOMEPAGE_PORT` environment variables.
- Use a different image or tag by setting `HOMEPAGE_IMAGE` (example above).
- If you want this deployed via your main `docker compose` setup, I can add the service into `media/compose.yaml` or your preferred compose file.

Environment & API keys
----------------------
- This compose references `../../media/.env` to reuse API keys and network settings from the media stack. Ensure `apps/homepage/.env` and `media/.env` exist and contain the required variables before starting the container.
- Important variables often present in `media/.env` (examples): `SONARR_API_KEY`, `RADARR_API_KEY`, `PROWLARR_API_KEY`, `JELLYFIN_API_KEY`, `PROWLARR_API_KEY`, `QBITTORRENT_USER`, `QBITTORRENT_PASS`, `NZBGET_USER`, `NZBGET_PASS`.

Run `scripts/generate_env_from_media.sh` to populate `apps/homepage/.env` from the media service config files (Radarr, Prowlarr, Sonarr) for local testing — this avoids hardcoding secrets. Do NOT commit the generated `.env` file to git (it's ignored by default).
- You must set `HOMEPAGE_ALLOWED_HOSTS` to include the host:port you will use (for example `localhost:3001`) to avoid host header validation errors.
- If the container needs to write `settings.yaml` on first run, ensure `./config` is mounted writable (do not use read-only mounts for the `config` folder).

Example quick env setup (from `apps/homepage`):

```bash
# copy media env if you want to reuse keys
cp ../../media/.env ./media.env
cp .env.sample .env
# edit .env and media.env to add any missing API keys or credentials
docker compose up -d
```

If you'd like, I can add a small checklist to `README.md` or a health-check script to validate the internal network reachability of the media services.
