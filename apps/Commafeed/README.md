# Commafeed - Self-Hosted RSS Reader

## Location

Located at: `/mnt/library/repos/homelab/apps/Commafeed`

## Quick Start

```bash
cd /mnt/library/repos/homelab/apps/Commafeed
docker compose up -d
```

## Access

Open your browser and navigate to: http://localhost:8082

## Default Credentials

- **Username:** admin
- **Password:** admin

**Important:** Change the default password after first login!

## Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Update to latest version
docker compose pull
docker compose up -d

# Restart service
docker compose restart commafeed
```

## Data Locations

- Database: `./data/db`
- Application data: `./data/commafeed`
