AdGuard Home (networking)

This folder contains a simple Docker Compose to run AdGuard Home (DNS & adblocking).

Quick start

1) Copy and edit environment file:
   cp .env.sample .env
   # update CONFIG_DIR to where you want persistent config stored (absolute path recommended)

2) Create config directory (example):
   mkdir -p /mnt/wd_media/homelab-data/networking/adguard
   chown $PUID:$PGID /mnt/wd_media/homelab-data/networking/adguard

3) Bring the service up:
   docker compose --env-file /path/to/homelab/networking/.env -f /path/to/homelab/networking/compose.yaml up -d

Notes & recommendations

- DNS port (53) is privileged. If you already run other DNS services or containers, consider stopping them
  or changing ADGUARD_DNS_PORT in `.env` or running the container with `network_mode: "host"`.

- If you plan to expose the web UI publicly, put it behind your reverse proxy (SWAG/Traefik) and secure it with
  HTTPS + authentication.

Caddy (reverse proxy) 🔧

- This compose includes a `caddy` service that is intended to be the reverse proxy for services in this stack (for example, AdGuard's web UI). For local testing we've disabled automatic HTTPS and bound Caddy to `localhost` only (HTTP).

- `caddy` is attached to `servarrnetwork` so it can resolve and proxy to media services by name (e.g. `/jackett`, `/sonarr`, `/radarr`, `/prowlarr`).

- If/when you want to expose services publicly, set `CADDY_EMAIL` and `CADDY_DOMAINS` in `.env` and update the `Caddyfile` accordingly.

Start the stack (local testing):

```bash
docker compose --env-file /path/to/homelab/networking/.env -f /path/to/homelab/networking/compose.yaml up -d
```

Notes:
- For local testing keep Caddy set to `localhost` (no TLS), which avoids browser "not secure" warnings.
- Path-based proxies are available for common services (e.g., `http://localhost/sonarr` → Sonarr UI).

Configuration directory ✅

- By default this stack will use `networking/.config` for persistent configuration (set via `CONFIG_DIR` in the `.env` file). You can change that to an absolute path if you prefer.

Checking for a DNS service (port 53) on your desktop ⚠️

- Many desktops run a local resolver (systemd-resolved, NetworkManager) which will already be bound to port 53. To check:

  ```bash
  sudo ss -lunp | grep :53 || sudo lsof -i :53
  ```

- If port 53 is in use you have options:
  - Stop or disable the local resolver temporarily (not recommended on some systems).
  - Run AdGuard on a different host port (set `ADGUARD_DNS_PORT` to e.g. `5353`) and configure test clients accordingly.
  - Use `network_mode: "host"` for AdGuard to bind directly to host network (be careful with conflicts).

Local-only Caddy testing (no public domain) 🔒

- For internal testing, use the `localhost` site block in `Caddyfile` and bind the Caddy ports to loopback so it is not reachable externally. The compose file already binds Caddy to `127.0.0.1` by default.

- Example `Caddyfile` entry for local testing:

  ```text
  http://localhost {
    handle_path /health { respond "OK" 200 }
    reverse_proxy / adguardhome:3000
  }
  ```

- This avoids ACME/Let’s Encrypt altogether during tests and keeps traffic local to the host.

AdGuard configuration

- Complete the initial setup at `http://localhost:3000/install.html` to set admin credentials and preferences.
- After initial setup, copy the generated `AdGuardHome.yaml` into `networking/.config/adguard/conf/AdGuardHome.yaml` if you want to persist your configuration and avoid the installer next boot.
- See `ADGUARD_SETUP.md` in this folder for more notes and tips.

- Configuration files are persisted under `${CONFIG_DIR}/adguard` per the compose file.

Validation

- Open the web UI locally: http://<host>:${ADGUARD_HTTP_PORT}
- After initial setup, configure a client to use the DNS server at <host>:${ADGUARD_DNS_PORT}.
