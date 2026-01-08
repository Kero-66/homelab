# CleanupArr

This folder contains sample configuration and notes for integrating CleanupArr into the media stack.

Quick enable and seed steps

1. Add API key placeholders to `media/.config/.credentials` (see `CLEANUPARR_API_KEY=`).
1. Optionally set `CLEANUPARR_PORT` and `IP_CLEANUPARR` in `media/.env` (defaults are provided).
1. Edit `media/compose.yaml`: find the `cleanuparr` service in the "Optional Services" block and set the `image:` to the container you prefer (recommended: `ghcr.io/cleanuparr/cleanuparr:latest`). Uncomment the block to enable the service.
1. Generate seed configs and API keys:

```bash
bash media/scripts/setup_seed_configs.sh
```

1. Initialize service config files (copies seeds into the repo folder for first-run):

```bash
bash media/scripts/init_configs.sh
```

1. Start CleanupArr:

```bash
docker compose -f media/compose.yaml up -d cleanuparr
```

Where to put real credentials

- Replace the generated `CLEANUPARR_API_KEY` in `media/.config/.credentials` with your real key.
- Runtime config is stored under `${CONFIG_DIR}/cleanuparr` (by default `media/cleanuparr`).

Notes

- The compose template uses `${CLEANUPARR_PORT}` and `${IP_CLEANUPARR}` environment variables — set them in `media/.env` if you need custom values.
- If you want me to pick a specific image and enable/start the service for you, tell me which image to use and I'll uncomment and start it.
