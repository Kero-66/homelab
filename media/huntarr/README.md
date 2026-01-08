# Huntarr

This folder contains sample configuration and notes for integrating Huntarr into the media stack.

Quick enable and seed steps

1. Add API key placeholders to `media/.config/.credentials` (see `HUNTARR_API_KEY=`).
1. Optionally set `HUNTARR_PORT` and `IP_HUNTARR` in `media/.env` (defaults are provided).
1. Edit `media/compose.yaml`: find the `huntarr` service in the "Optional Services" block and set the `image:` to the container you prefer (recommended: `ghcr.io/plexguide/huntarr:latest`). Uncomment the block to enable the service.
1. Generate seed configs and API keys:

```bash
bash media/scripts/setup_seed_configs.sh
```

1. Initialize service config files (copies seeds into the repo folder for first-run):

```bash
bash media/scripts/init_configs.sh
```

1. Start Huntarr:

```bash
docker compose -f media/compose.yaml up -d huntarr
```

Where to put real credentials

- Replace the generated `HUNTARR_API_KEY` in `media/.config/.credentials` with your real key.
- Runtime config is stored under `${CONFIG_DIR}/huntarr` (by default `media/huntarr`).

Notes

- The compose template uses `${HUNTARR_PORT}` and `${IP_HUNTARR}` environment variables — set them in `media/.env` if you need custom values.
- If you want me to pick a specific image and enable/start the service for you, tell me which image to use and I'll uncomment and start it.
