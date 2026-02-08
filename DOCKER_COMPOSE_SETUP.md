# Docker Compose Environment Configuration - Setup Complete

## Overview

Your homelab Docker Compose configuration has been successfully reorganized following Docker best practices. This document explains the structure and how to use it.

## Architecture

### Directory Structure

```
homelab/
├── .env                          # Global defaults (included in all stacks)
│                                 # TZ, PUID, PGID, CONFIG_DIR, DATA_DIR, RESTART_POLICY
├── .infisical.json               # Infisical project configuration
├── media/
│   ├── compose.yaml
│   ├── .env                       # Includes global defaults + media-specific config
├── monitoring/
│   ├── compose.yaml
│   ├── .env                       # Includes global defaults + monitoring-specific config
├── networking/
│   ├── compose.yaml
│   ├── .env                       # Includes global defaults + networking-specific config
└── apps/homepage/
    ├── compose.yaml
    ├── .env                       # Includes global defaults + homepage config
```

## Key Principles

### 1. **Global `.env` File**
- Located at root: `homelab/.env`
- Contains common settings used across all stacks:
  - `TZ` - Timezone
  - `PUID` / `PGID` - User/Group IDs for file permissions
  - `CONFIG_DIR` - Where service configs are stored
  - `DATA_DIR` - Where media files are stored
  - `RESTART_POLICY` - Container restart behavior
  - `ENABLE_LOCALTIME_MOUNT` - Optional for containers

### 2. **Stack-Specific `.env` Files**
- Each stack (media, monitoring, networking, homepage) has its own `.env`
- These include:
  - A copy of global defaults (for standalone use)
  - Stack-specific configuration (ports, IPs, service URLs)
- Can override global defaults if needed

### 3. **Secret Management with Infisical**
- All secrets (API keys, passwords, database credentials) are managed by **Infisical**.
- Secrets are NOT stored in files.
- The Infisical CLI injects secrets directly into the Docker Compose process at runtime.
- **Unified Credential Source**: All secrets originate from the Infisical `homelab` project.

### 4. **Homepage Integration**
- Homepage automatically receives all injected secrets.
- No cross-referencing of `.credentials` files is needed.

## Security

- ✅ No secrets are stored in the repository (even in gitignored files).
- ✅ Centralized secret management with Infisical.
- ✅ CLI injection prevents secrets from ever touching the disk in plaintext.
- ✅ Supports environment-specific secrets and now loads them from the dev environment by default.

## Usage

### ⚠️ CRITICAL: Always Use Infisical

**Every** Docker Compose command that starts or restarts containers MUST be run through Infisical. Containers like Beszel, Netdata, and others require secrets (API keys, passwords) that are only available at runtime via Infisical injection.

**NEVER run plain `docker compose` commands** for stacks that have secrets. If you do, containers will start without their required environment variables and will fail or malfunction.

```bash
# ❌ WRONG - Will fail (secrets not injected)
cd /mnt/library/repos/homelab/monitoring
docker compose up -d

# ✅ CORRECT - Infisical injects secrets
cd /mnt/library/repos/homelab/monitoring
infisical run --env dev --path /monitoring -- docker compose up -d

# ✅ CORRECT - Also works from root
cd /mnt/library/repos/homelab
infisical run --env dev --path /monitoring -- docker compose -f monitoring/compose.yaml up -d
```

### Running a Stack (with Infisical)

Use the Infisical CLI to inject secrets. Because your login shell already exports `INFISICAL_PROJECT_ID`, you do not need to pass `--projectId`; the commands below will target the dev workspace automatically.

```bash
# Media stack
cd /mnt/library/repos/homelab
infisical run --env dev --path /media -- docker compose -f media/compose.yaml --profile media up -d

# Monitoring stack
cd /mnt/library/repos/homelab
infisical run --env dev --path /monitoring -- docker compose -f monitoring/compose.yaml up -d

# Homepage (run after syncing secrets below)
cd /mnt/library/repos/homelab
infisical run --env dev --path /homepage -- docker compose -f apps/homepage/compose.yaml --profile homepage up -d
```

Before starting the homepage profile, mirror the media/monitoring secrets under `/homepage` so it can inject every API key/credential. Run `security/infisical/sync_homepage_secrets.sh` via Infisical:

```bash
cd /mnt/library/repos/homelab
infisical run --env dev --path /homepage -- bash security/infisical/sync_homepage_secrets.sh
```

> **Note**: Automated deployment scripts like `media/deploy.sh` will automatically detect Infisical and use it if available.

No special flags or wrapper scripts needed! Everything is auto-loaded.

### Restarting Containers

When restarting any container in a stack, **always use Infisical**:

```bash
# ✅ Correct way to restart
infisical run --env dev --path /monitoring -- docker compose restart beszel

# ✅ Or restart the entire stack
infisical run --env dev --path /monitoring -- docker compose restart

# ✅ Pull latest images and restart
infisical run --env dev --path /monitoring -- docker compose pull && infisical run --env dev --path /monitoring -- docker compose up -d
```

### Common Commands

```bash
# View logs (Infisical not required for read-only operations)
docker compose logs -f beszel

# Check container status
docker compose ps

# Validate compose file
docker compose config

# View resolved configuration (secrets won't show)
infisical run --env dev --path /monitoring -- docker compose config

# Stop containers (Infisical not strictly required, but safe to use)
infisical run --env dev --path /monitoring -- docker compose down
```

To see the resolved composition (after env interpolation):

```bash
cd media
docker compose config | less
```

### Environment Variable Precedence

When docker compose loads variables for a stack:

1. Process Environment (passed in by `infisical run`) - **HIGHEST PRECEDENCE**
2. Stack's `.env` file (local defaults/static config)
3. Container environment variables block in `compose.yaml`

## Maintenance

### Updating Global Settings

If you need to change `TZ`, `PUID`, `PGID`, `DATA_DIR`, etc.:

1. Update `homelab/.env`
2. Update the corresponding values in each stack's `.env` (if mapped)
3. Restart affected containers

### Adding New Credentials

When adding a new secret:

1. Add the secret to the **Infisical** "homelab" project via the Web UI (http://infisical.localhost) or CLI.
2. Reference the secret in your `compose.yaml` using `${SECRET_NAME}`.
3. Restart the stack using `infisical run --env dev -- docker compose up -d`.

### Running Scripts

Internal scripts that require API keys (like Sonarr/Radarr cleanup scripts) should be run via Infisical to ensure they have access to the secrets:

```bash
infisical run --env dev -- bash scripts/sonarr_trash_apply.sh
```

### Backing Up Secrets

To back up all Infisical secrets to an encrypted or local file:

```bash
infisical export --env dev > homelab-secrets-backup.env
```

## Status

- ✅ No legacy `.credentials` files exist on disk.
- ✅ Secrets are injected directly from memory into the container runtime.
- ✅ Stacks are portable and require Infisical access to deploy.
- ✅ All deployment scripts (`deploy.sh`) are Infisical-aware.

## Verification

All compose files have been tested and verified to:
- ✅ Load global variables without warnings
- ✅ Load stack-specific configuration
- ✅ Load credentials for containers (no interpolation warnings)
- ✅ Support Docker Compose `config` command
- ✅ Work from stack directory without special flags

Ready to use!
