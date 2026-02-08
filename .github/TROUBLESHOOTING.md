# Troubleshooting Guide (sanitised)

This file documents safe, repeatable troubleshooting commands for the homelab project.
Do NOT put real credentials in this file — use placeholders and reference your local, gitignored `.env` files or Infisical paths.

## Principles
- Never commit secrets. Store secrets in Infisical and inject at runtime.
- Infisical CLI requires a project ID for `infisical run`. Set `INFISICAL_PROJECT_ID` or pass `--projectId` to avoid the “projectSlug or workspaceId” error.
- Prefer adding defensive defaults in compose files (e.g., `${VAR:-default}`) to avoid parse-time errors.

## Recording successful fixes
- When you discover a reliable API call or troubleshooting command, add it here with sanitized paths/credentials and a short explanation so the next person can reuse it.
- Reference the gitignored credentials file for any service-specific secrets instead of copying them into this document.

## Common commands (sanitised)

### Validate merged compose config (Infisical injection)

Run from the project root:

```bash
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /media --projectId <PROJECT_ID> -- \
  docker compose -f media/compose.yaml -f apps/homepage/compose.yaml config
```

### Start homepage (Infisical injection)

```bash
cd apps/homepage
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose --profile homepage -f /mnt/library/repos/homelab/apps/homepage/compose.yaml up -d
```

### Stop homepage (Infisical injection)

```bash
cd apps/homepage
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose --profile homepage -f /mnt/library/repos/homelab/apps/homepage/compose.yaml down
```

### Start media stack (Infisical injection)

```bash
cd media
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /media --projectId <PROJECT_ID> -- \
  docker compose --profile media -f /mnt/library/repos/homelab/media/compose.yaml up -d
```

### Stop media stack (Infisical injection)

```bash
cd media
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /media --projectId <PROJECT_ID> -- \
  docker compose --profile media -f /mnt/library/repos/homelab/media/compose.yaml down
```

### View logs for services

```bash
# Media services (qbittorrent, jackett)
docker compose -f media/compose.yaml logs qbittorrent jackett --tail=200

# Homepage logs (Infisical injection for environment variables)
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose -f media/compose.yaml -f apps/homepage/compose.yaml logs homepage --tail=200
```

### Exec into a service to inspect config (as root)

```bash
docker compose -f media/compose.yaml exec --user root qbittorrent sh -c "ls -la /config && sed -n '1,200p' /config/qBittorrent/qBittorrent.conf"
```

### Unban homepage host in qBittorrent (preferred: use API where available)

1. Stop homepage to avoid repeated failed attempts.
2. Log in to qBittorrent and unban or restart qbittorrent.

```bash
# Stop homepage
INFISICAL_PROJECT_ID=<PROJECT_ID> \
infisical run --env dev --path /homepage --projectId <PROJECT_ID> -- \
  docker compose -f media/compose.yaml -f apps/homepage/compose.yaml stop homepage

### Sync Homepage secrets from stack paths

If Homepage is missing API keys from other stacks, mirror them into `/homepage`:

```bash
INFISICAL_PROJECT_ID=<PROJECT_ID> \
bash security/infisical/sync_homepage_secrets.sh
```

# Restart qbittorrent service to clear temporary bans
docker compose -f media/compose.yaml restart qbittorrent

# Alternatively, use the qBittorrent API (login + unban)
# curl -c /tmp/qb-cookies -X POST -d "username=USER&password=PASS" http://localhost:8080/api/v2/auth/login
# curl -b /tmp/qb-cookies "http://localhost:8080/api/v2/commands/unbanHosts?hosts=172.39.0.21"
```

## Notes about assistant memory
- The assistant stores a private, non-repo memory entry with a sanitized list of commands to avoid repeating trial-and-error in future sessions.

## Want this in a PR?
- Adds this file to `.github/`
- Adds a short README note pointing to it
