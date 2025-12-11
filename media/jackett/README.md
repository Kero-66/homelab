# Jackett (media)

This folder contains the Docker Compose to run Jackett as part of the `media/` services group.

Quick start

1. Start Jackett from the `media/jackett` folder:

```bash
cd media/jackett
docker compose up -d
```

2. Open the Jackett UI: `http://<host>:9117` and configure indexers (search for `DMHY`, `Nyaa`, `Tangmen`, etc.).

3. After configuring indexers in Jackett, copy the Torznab feed URL for each indexer and add it into your running Prowlarr (Prowlarr → Indexers → + → Torznab).

Automation

- Use the repository script `./scripts/jackett_torznab_list.sh` to list Jackett Torznab URLs and optionally add them directly to Prowlarr using the API. See script header for usage.

Notes

- Do not commit API keys or credentials. Configure private indexer credentials inside the Jackett UI.
- If a Jackett container is already running, `docker compose up -d` will reuse it.

Credentials

- Jackett will pick up the central media credentials file when started from this folder. The deployment uses `media/.config/.credentials` (gitignored) to store the global username/password used across Arr apps. Ensure you've created that file (see `media/deploy.sh` and `media/docs/DEPLOYMENT_CHECKLIST.md`).
- When the reverse proxy (NGINX Proxy Manager / SWAG) is configured, it should apply the same Basic auth to Jackett as to the other services. If you want Jackett to enforce its own admin credentials, update the Jackett UI or populate `/config/Jackett/ServerConfig.json` inside the mounted config directory.
