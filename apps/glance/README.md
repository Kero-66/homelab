# Glance - Self-Hosted Dashboard

## Location

Located at: `/mnt/library/repos/homelab/apps/glance`

## Quick Start

```bash
cd /mnt/library/repos/homelab/apps/glance
docker compose up -d
```

## Access

Open your browser and navigate to: http://localhost:8095

## Configuration

Edit `config/glance.yml` to customize your dashboard. Available widgets:
- **RSS** - Feed aggregation
- **Weather** - Weather display
- **Calendar** - Calendar events
- **Hacker News** - Tech news
- **Reddit** - Subreddit posts
- **Twitch** - Stream status
- **YouTube** - Channel videos
- **Markets** - Stock tracking
- **System** - Server stats
- **Uptime Status** - Service monitoring
- **Docker Containers** - Container status

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
```

## Data Locations

- Config: `./config`
- Assets: `./assets`
