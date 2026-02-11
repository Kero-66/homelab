# TrueNAS Stacks

Deploy containerized services on TrueNAS Scale 25.10.1 using Custom Apps.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  TrueNAS Scale 25.10.1                                       │
│                                                              │
│  ┌──────────────────┐     writes .env     ┌───────────────┐ │
│  │ Infisical Agent   │ ──────────────────► │ /mnt/Fast/    │ │
│  │ (Custom App)      │     every 5min      │ docker/       │ │
│  └────────┬─────────┘                      │ jellyfin/.env │ │
│           │ fetches                         └───────┬───────┘ │
│           │ secrets                                 │         │
│           ▼                                         ▼         │
│  ┌──────────────────┐                   ┌──────────────────┐ │
│  │ Infisical Cloud   │                   │ Jellyfin Stack   │ │
│  │ (external)        │                   │ (Custom App)     │ │
│  └──────────────────┘                   │ reads env_file   │ │
│                                          └──────────────────┘ │
│                                                              │
│  Storage:                                                     │
│    /mnt/Fast (NVMe) → configs, databases                     │
│    /mnt/Data (HDD)  → media files                            │
└──────────────────────────────────────────────────────────────┘
```

## Stacks

| Stack | Services | Ports | Description |
|-------|----------|-------|-------------|
| [infisical-agent](infisical-agent/) | infisical-agent | none | Fetches secrets from Infisical, writes .env files |
| [jellyfin](jellyfin/) | jellyfin, jellyseerr, jellystat-db, jellystat | 8096, 5055, 3002 | Media server + requests + analytics |

## Prerequisites

1. **TrueNAS Storage** — Pools and datasets set up per [SETUP_COMPLETE.md](../SETUP_COMPLETE.md)
2. **Infisical** — Account with secrets at `/media` path in `dev` environment
3. **Machine Identity** — Created in Infisical for the agent (Universal Auth)

## Quick Start

### 1. Run the setup script (from your workstation)

```bash
cd /path/to/homelab
bash truenas/scripts/setup_agent.sh
```

This will:
- Fetch the TrueNAS API key from Infisical
- Prompt for Machine Identity credentials
- Copy all configs and compose files to TrueNAS
- Set restrictive permissions on credentials

### 2. Deploy the Infisical Agent (TrueNAS UI)

1. Go to **Apps → Discover → Custom App**
2. Set name: `infisical-agent`
3. Paste this YAML:
   ```yaml
   include:
     - /mnt/Fast/docker/infisical-agent/compose.yaml
   services: {}
   ```
4. Click **Save**
5. Wait for it to start — check logs to confirm it's polling

### 3. Deploy the Jellyfin Stack (TrueNAS UI)

1. Go to **Apps → Discover → Custom App**
2. Set name: `jellyfin`
3. Paste this YAML:
   ```yaml
   include:
     - /mnt/Fast/docker/jellyfin/compose.yaml
   services: {}
   ```
4. Click **Save**

### 4. Verify

- **Jellyfin**: http://192.168.20.22:8096
- **Jellyseerr**: http://192.168.20.22:5055
- **Jellystat**: http://192.168.20.22:3002

## Required Secrets in Infisical

These must exist at path `/media` in the `dev` environment:

| Key | Description | Example |
|-----|-------------|---------|
| `JELLYSTAT_DB_USER` | Postgres username | `postgres` |
| `JELLYSTAT_DB_PASS` | Postgres password | (generate a strong password) |
| `JELLYSTAT_JWT_SECRET` | JWT signing secret for Jellystat | (generate a random string) |

The Infisical Agent fetches **all** secrets from `/media` and writes them to `.env`.
Only the keys listed above are consumed by the Jellyfin stack.

### Ensure secrets exist

```bash
# From your workstation (must be logged into Infisical)
infisical secrets --env dev --path /media | grep JELLYSTAT
```

If missing, create them:
```bash
infisical secrets set JELLYSTAT_DB_USER=postgres --env dev --path /media
infisical secrets set JELLYSTAT_DB_PASS="$(openssl rand -base64 24)" --env dev --path /media
infisical secrets set JELLYSTAT_JWT_SECRET="$(openssl rand -base64 32)" --env dev --path /media
```

## TrueNAS Custom App Constraints

- TrueNAS 25.10 requires `services: {}` in the Custom App YAML
- The `include:` directive points to compose files on persistent datasets
- TrueNAS calls `docker compose up -d` internally — no way to wrap with CLI tools
- Root filesystem is wiped on TrueNAS updates — all data must live on pool datasets
- No persistent `apt install` — everything must be containerized

## Adding New Stacks

1. Create a new directory under `truenas/stacks/<name>/`
2. Add a `compose.yaml` with absolute paths to `/mnt/Fast/` or `/mnt/Data/`
3. If secrets are needed:
   - Create a template in `infisical-agent/<name>.tmpl`
   - Add a `templates:` entry in `infisical-agent/agent-config.yaml`
   - Redeploy the agent Custom App
4. Deploy as a new Custom App in TrueNAS UI

## Tailscale (Remote Access)

See [Tailscale Setup](#tailscale-setup) below for remote access to services.

### Tailscale Setup

TrueNAS Scale has a first-party Tailscale app in the App Store.

1. **Install Tailscale** from TrueNAS App Store:
   - Apps → Discover → search "Tailscale"
   - Install with default settings

2. **Authenticate**:
   - Check Tailscale app logs for the auth URL
   - Open the URL in your browser and approve the device
   - The TrueNAS machine gets a Tailscale IP (e.g., `100.x.y.z`)

3. **Access services remotely** using the Tailscale IP:
   - Jellyfin: `http://100.x.y.z:8096`
   - Jellyseerr: `http://100.x.y.z:5055`
   - Jellystat: `http://100.x.y.z:3002`

4. **Optional — MagicDNS**: If enabled in your Tailscale admin console, access via hostname:
   - `http://truenas:8096` (or whatever your TrueNAS machine name is)

5. **Jellyfin client apps**: Configure the server URL to your Tailscale IP for remote streaming.

> **Note**: Tailscale provides encrypted point-to-point connections. No port forwarding or reverse proxy needed for remote access.

## File Layout on TrueNAS

```
/mnt/Fast/
├── docker/
│   ├── infisical-agent/
│   │   ├── compose.yaml
│   │   └── config/
│   │       ├── agent-config.yaml
│   │       ├── jellyfin.tmpl
│   │       ├── client-id         (600, root-only)
│   │       ├── client-secret     (600, root-only)
│   │       └── access-token      (written by agent)
│   ├── jellyfin/
│   │   ├── compose.yaml
│   │   ├── .env                  (written by agent)
│   │   ├── config/               (Jellyfin server config)
│   │   └── jellystat-backup/
│   └── jellyseerr/
│       └── config/
├── databases/
│   └── jellystat/
│       └── postgres/
│
/mnt/Data/
└── media/
    ├── movies/
    ├── shows/
    └── music/
```

## Troubleshooting

### Agent not writing .env
- Check agent logs in TrueNAS Apps UI
- Verify Machine Identity credentials are valid
- Ensure Infisical is reachable: `curl -sf https://app.infisical.com/api/status`

### Jellystat can't connect to database
- Confirm `.env` exists: SSH to TrueNAS and check `/mnt/Fast/docker/jellyfin/.env`
- Ensure agent is running and has written the file before starting the Jellyfin stack

### Jellyfin no hardware acceleration
- Verify `/dev/dri` exists on TrueNAS: `ls -la /dev/dri`
- The Beelink Mini S Pro has Intel QuickSync — should work out of the box
- Check Jellyfin dashboard → Playback → Hardware Acceleration → select "Intel QSV"

### Permission issues
- All media/config directories should be owned by `1000:1000` (kero66)
- Database directories should also be `1000:1000`
- Agent config directory is `root:root` (700) for credential protection
