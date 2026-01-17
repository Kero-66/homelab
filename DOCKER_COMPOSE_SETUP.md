# Docker Compose Environment Configuration - Setup Complete

## Overview

Your homelab Docker Compose configuration has been successfully reorganized following Docker best practices. This document explains the structure and how to use it.

## Architecture

### Directory Structure

```
homelab/
├── .env                          # Global defaults (included in all stacks)
│                                 # TZ, PUID, PGID, CONFIG_DIR, DATA_DIR, RESTART_POLICY
├── .credentials                  # (Empty - for future global credentials if needed)
├── media/
│   ├── compose.yaml
│   ├── .env                       # Includes global defaults + media-specific config
│   └── .credentials               # Media API keys and secrets
├── monitoring/
│   ├── compose.yaml
│   ├── .env                       # Includes global defaults + monitoring-specific config
│   └── .credentials               # Monitoring passwords
├── networking/
│   ├── compose.yaml
│   ├── .env                       # Includes global defaults + networking-specific config
│   └── .credentials               # Networking passwords
└── apps/homepage/
    ├── compose.yaml
    ├── .env                       # Includes global defaults + homepage config
    └── .credentials               # References all API keys from other stacks
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
- **Only credentials are NOT in .env files**

### 3. **Stack-Specific `.credentials` Files**
- Secrets are kept separate from configuration
- Each stack has only the credentials it needs:
  - `media/.credentials` - API keys for *arr apps, download clients
  - `monitoring/.credentials` - Beszel passwords
  - `networking/.credentials` - AdGuard admin credentials
  - `apps/homepage/.credentials` - All API keys from other stacks

### 4. **Homepage Special Case**
- Homepage loads credentials from ALL stacks:
  - `../../media/.credentials`
  - `../../monitoring/.credentials`
  - `../../networking/.credentials`
- This allows the dashboard to access all services without duplication

## Security

- ✅ All `.env` and `.credentials` files are in `.gitignore`
- ✅ No secrets are committed to the repository
- ✅ Each stack has least-privilege access (only its own credentials)
- ✅ Global variables prevent duplication
- ✅ Credentials can be easily rotated per-stack

## Usage

### Running a Stack

Simply navigate to the stack directory and use normal docker compose commands:

```bash
# Media stack
cd media
docker compose up -d

# Monitoring stack
cd monitoring
docker compose up -d

# Networking stack
cd networking
docker compose up -d

# Homepage
cd apps/homepage
docker compose up -d
```

No special flags or wrapper scripts needed! Everything is auto-loaded.

### Viewing Configuration

To see the resolved composition (after env interpolation):

```bash
cd media
docker compose config | less
```

### Environment Variable Precedence

When docker compose loads variables for a stack:

1. Stack's `.env` file (includes global defaults + overrides)
2. Stack's `.credentials` file
3. Other stacks' `.credentials` (for homepage only)
4. Container environment variables (can further override)

## Maintenance

### Updating Global Settings

If you need to change `TZ`, `PUID`, `PGID`, `DATA_DIR`, etc.:

1. Update `homelab/.env`
2. Update the corresponding values in each stack's `.env`
3. Restart affected containers

This ensures all stacks have consistent global settings.

### Adding New Credentials

When adding a new service:

1. Add its API key/password to the appropriate stack's `.credentials` file
2. If homepage needs it, also add to `apps/homepage/.credentials`
3. Reference in compose.yaml with `${VAR_NAME}`

### Backing Up Credentials

All sensitive files are in `.gitignore`. To back up:

```bash
tar czf homelab-credentials-backup.tar.gz \
  .env \
  media/.credentials \
  monitoring/.credentials \
  networking/.credentials \
  apps/homepage/.credentials
```

Store securely (not in git).

## Files Changed

- Created: `/homelab/.env` - Global configuration
- Created: `/media/.credentials`, `/monitoring/.credentials`, `/networking/.credentials`, `/apps/homepage/.credentials`
- Updated: All stack `.env` files to include global defaults
- Updated: All `compose.yaml` files to properly load `.env` and `.credentials`
- Updated: `.gitignore` to ignore credential files at stack level

## Verification

All compose files have been tested and verified to:
- ✅ Load global variables without warnings
- ✅ Load stack-specific configuration
- ✅ Load credentials for containers (no interpolation warnings)
- ✅ Support Docker Compose `config` command
- ✅ Work from stack directory without special flags

Ready to use!
