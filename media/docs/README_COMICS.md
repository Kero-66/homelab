**Quick Setup — Comics & Automation**

- **Create config directories** (already created in repo root):
  - `komga`, `kavita`, `ubooquity`, `mylar3`

- **Recommended .env**
  - Copy `./.env.sample` to `./.env` and update `PUID`, `PGID`, `TZ`, `DATA_DIR`, and ports if needed.

- **Start containers**

```bash
# start only the new services
docker compose -f media/compose.yaml up -d komga kavita ubooquity mylar3
```

- **Automating initial configuration (minimal manual interaction)**
  - The containers are configured to persist settings under `${CONFIG_DIR}` so once you finish web-based first-run setups (admin user, library paths), those settings persist.
  - To minimize manual setup:
    - Point each app's library/media path to a subfolder inside `${DATA_DIR}` (e.g. `/data/comics` or `/data/webtoons`). The compose mounts `${DATA_DIR}` into the containers at `/books` or `/data` depending on the app.
    - If you want fully automatic provisioning (create admin users, add libraries, add Mylar3 to Prowlarr), I can add an init script that calls the apps' HTTP APIs after they become healthy and provision the defaults. Tell me the exact admin account + desired library paths and I'll add it.

- **Integrating Mylar3 with Prowlarr and download clients**
  - Workflow we recommend:
    1. Configure your download client in Mylar3 (qBittorrent) using the container host/ports (or `qbittorrent:8080` if on same compose network). This allows Mylar3 to send downloads to your client.
    2. In Prowlarr, add Mylar3 as an "Application" (Settings → Apps) using the Mylar3 API URL and API key — this allows Prowlarr to push indexer configuration to Mylar3 and centralize indexer management.
    3. In Mylar3, enable Prowlarr as an indexer target if you prefer Mylar3 to query Prowlarr-managed indexers.

- **Next steps I can take for you (pick one or more)**
  - Add an init container/script to automatically:
    - create an admin user for Komga/Kavita/Mylar3
    - create a Komga library pointing at `/books/comics`
    - register Mylar3 in Prowlarr (and set API key in Mylar3)
  - Add Traefik labels / reverse proxy rules for secure external access.
  - Start the containers for you now and verify logs.

If you want me to automate provisioning, tell me the admin username/password (or specify "generate strong random"), desired library paths inside `${DATA_DIR}` (e.g. `/data/comics`), and whether you want me to register Mylar3 in Prowlarr automatically. I'll implement an init helper to call the APIs after services are healthy and add it to `media/compose.yaml`.

Official documentation and image references
- **Kavita (official docs)**: https://wiki.kavitareader.com/installation/docker/
  - **LinuxServer image (recommended)**: `lscr.io/linuxserver/kavita:latest` — see https://wiki.kavitareader.com/installation/docker/lsio/
  - **Docker Hub / GitHub images**: documented on the Kavita Docker page linked above.
- **Komga**: https://komga.org/docs/
- **Kavita GitHub**: https://github.com/Kareadita/Kavita
- **Ubooquity**: https://vaemendis.net/ubooquity/
- **Mylar3**: https://github.com/mylar3/mylar3

These links are saved here to help automated provisioning pick the correct container images and configuration paths.