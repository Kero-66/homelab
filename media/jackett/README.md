# Jackett (media)

docker compose up -d
This folder holds the configuration, logs, and helper scripts for the Jackett service launched by the top-level `media/compose.yaml` file.

Quick start

1. Start Jackett through the shared stack:

```bash
cd media
docker compose up -d jackett
```

2. Open the Jackett UI: `http://<host>:9117` and configure indexers (search for `DMHY`, `Nyaa`, `Tangmen`, etc.).

3. After configuring indexers in Jackett, copy the Torznab feed URL for each indexer and add it into your running Prowlarr (Prowlarr → Indexers → + → Torznab).

Automation

- Use the repository script `../scripts/jackett_torznab_list.sh` to list Jackett Torznab URLs and optionally add them directly to Prowlarr using the API. See the script header for usage.

Notes

- Do not commit API keys or credentials. Configure private indexer credentials inside the Jackett UI.
- Jackett config/logs live inside `media/jackett/Jackett/` (the directory mounted as `/config` in the container).

Credentials
- Authentication is enforced by HTTP Basic Auth in the proxy; Jackett itself does not expose an admin password in `ServerConfig.json`. The credentials are centralized in `media/.config/.credentials` and used by the proxy (see `proxy/README.md`).
- If you need additional access controls, you can still set an admin password through the UI or directly edit `media/jackett/Jackett/ServerConfig.json`, but the default approach is proxy-level auth.

See the main `README.md` and `proxy/README.md` for more details.

2. Open the Jackett UI: `http://<host>:9117` and configure indexers (search for `DMHY`, `Nyaa`, `Tangmen`, etc.).

3. After configuring indexers in Jackett, copy the Torznab feed URL for each indexer and add it into your running Prowlarr (Prowlarr → Indexers → + → Torznab).

Automation

- Use the repository script `../scripts/jackett_torznab_list.sh` to list Jackett Torznab URLs and optionally add them directly to Prowlarr using the API. See script header for usage.

Notes

- Do not commit API keys or credentials. Configure private indexer credentials inside the Jackett UI.
- If a Jackett container is already running, `docker compose up -d` will reuse it.

Credentials

- Jackett does **not** store its own admin password in the config file. Instead, authentication is enforced at the proxy (NGINX Proxy Manager) using HTTP Basic Auth. The credentials are managed centrally in `media/.config/.credentials` and applied via the proxy's Access List (see `proxy/README.md`).
- If you want to enforce a separate admin password for Jackett, you may set it in the Jackett UI or in `/config/Jackett/ServerConfig.json`, but this is not recommended for unified setups.

**Credential Flow:**
1. User accesses Jackett via the proxy (e.g., `https://jackett.example.com`).
2. Proxy prompts for Basic Auth using the unified credentials.
3. Jackett does not prompt for a separate password.

See the main `README.md` and `proxy/README.md` for more details.
