# Infisical Secrets Management

This document explains how to use Infisical to manage secrets in the homelab project.

---

## Quick Reference

### Basic Commands

```bash
# List all folders in Infisical
infisical secrets folders get --env dev --path /

# Export secrets from a specific folder (JSON format)
infisical export --env dev --path /TrueNAS --format json

# Get a single secret value (plain text)
infisical secrets get TRUENAS_ADMIN --env dev --path /TrueNAS --plain

# Set a secret
infisical secrets set KEY=VALUE --env dev --path /TrueNAS

# Run a command with secrets injected as environment variables
infisical run --env dev --path /media -- docker compose up -d
```

---

## Project Structure

### Infisical Configuration

- **Project ID**: `5086c25c-310d-4cfb-9e2c-24d1fa92c152`
- **Config File**: `.infisical.json` (in repo root)
- **Default Environment**: `dev`

### Secret Folders

| Folder | Path | Purpose |
|--------|------|---------|
| `automations` | `/automations` | n8n, automation workflows |
| `homepage` | `/homepage` | Homepage dashboard credentials |
| `media` | `/media` | Jellyfin, Sonarr, Radarr, etc. |
| `monitoring` | `/monitoring` | Grafana, Prometheus |
| `networking` | `/networking` | Network services |
| `proxy` | `/proxy` | Nginx Proxy Manager |
| `TrueNAS` | `/TrueNAS` | TrueNAS admin credentials |

---

## TrueNAS Secrets

### Available Secrets

```bash
# Export all TrueNAS secrets
infisical export --env dev --path /TrueNAS --format json
```

**Current secrets:**
- `truenas_admin_api` - TrueNAS API key (66 chars) **[PREFERRED]**
- `truenas_admin` - TrueNAS root/admin password (fallback)

### Getting TrueNAS Credentials

#### Preferred: Using API Key

```bash
# Get API key (plain text)
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain)

# Use in script
TRUENAS_IP="192.168.20.22"

# Test API access with API key (recommended)
curl -H "Authorization: Bearer $TRUENAS_API_KEY" \
  -H "Content-Type: application/json" \
  "http://$TRUENAS_IP/api/v2.0/system/info"
```

#### Alternative: Using Password

```bash
# Get admin password (plain text)
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

# Use in script
TRUENAS_USER="root"

# Test API access with password
curl -u "$TRUENAS_USER:$TRUENAS_PASSWORD" \
  -H "Content-Type: application/json" \
  "http://$TRUENAS_IP/api/v2.0/system/info"
```

### Adding New TrueNAS Secrets

```bash
# Set TrueNAS IP
infisical secrets set TRUENAS_IP=10.0.0.50 --env dev --path /TrueNAS

# Set API key (if using API key instead of password)
infisical secrets set TRUENAS_API_KEY=your-api-key --env dev --path /TrueNAS

# Set SSH key path
infisical secrets set TRUENAS_SSH_KEY_PATH=/path/to/key --env dev --path /TrueNAS
```

---

## Using Secrets in Scripts

### Pattern 1: Export and Source

```bash
#!/usr/bin/env bash
# Export secrets to temporary env file
infisical export --env dev --path /TrueNAS --format dotenv > /tmp/truenas.env

# Source the file
source /tmp/truenas.env

# Use the variables
echo "Admin password: $truenas_admin"

# Clean up
rm /tmp/truenas.env
```

### Pattern 2: Direct Inline Retrieval

```bash
#!/usr/bin/env bash
# Get secret directly in script
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

# Use it
curl -u "root:$TRUENAS_PASSWORD" http://truenas.local/api/v2.0/system/info
```

### Pattern 3: Infisical Run (Best for Docker)

```bash
# Run docker compose with secrets injected
infisical run --env dev --path /media -- docker compose up -d

# Run any command with secrets
infisical run --env dev --path /TrueNAS -- bash ./setup_script.sh
```

---

## TrueNAS API Access

### API Documentation

- **TrueNAS Scale API**: `http://<truenas-ip>/api/docs`
- **API Version**: v2.0
- **API Endpoint**: `http://<truenas-ip>/api/v2.0/`

### Authentication Methods

#### Method 1: Basic Auth (Username/Password)

```bash
TRUENAS_IP="10.0.0.50"
TRUENAS_USER="root"
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

# Make API request
curl -u "$TRUENAS_USER:$TRUENAS_PASSWORD" \
  -H "Content-Type: application/json" \
  "http://$TRUENAS_IP/api/v2.0/system/info"
```

#### Method 2: API Key (Recommended for Scripts)

1. **Create API Key in TrueNAS UI**:
   - Navigate to: System Settings → API Keys
   - Click "Add API Key"
   - Name: `homelab-automation`
   - Copy the generated key

2. **Store in Infisical**:
   ```bash
   infisical secrets set TRUENAS_API_KEY=your-generated-key --env dev --path /TrueNAS
   ```

3. **Use API Key**:
   ```bash
   TRUENAS_API_KEY=$(infisical secrets get TRUENAS_API_KEY --env dev --path /TrueNAS --plain)
   
   curl -H "Authorization: Bearer $TRUENAS_API_KEY" \
     -H "Content-Type: application/json" \
     "http://$TRUENAS_IP/api/v2.0/system/info"
   ```

### Common API Endpoints

```bash
# Get system info
GET /api/v2.0/system/info

# List pools
GET /api/v2.0/pool

# List datasets
GET /api/v2.0/pool/dataset

# List disks
GET /api/v2.0/disk

# List shares (SMB)
GET /api/v2.0/sharing/smb

# List shares (NFS)
GET /api/v2.0/sharing/nfs

# Get services status
GET /api/v2.0/service
```

### Example: Get TrueNAS System Info

```bash
#!/usr/bin/env bash
# truenas/scripts/get_system_info.sh

set -euo pipefail

# Load TrueNAS credentials from Infisical
TRUENAS_IP="10.0.0.50"  # Or from Infisical
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

# Query system info
curl -s -u "root:$TRUENAS_PASSWORD" \
  -H "Content-Type: application/json" \
  "http://$TRUENAS_IP/api/v2.0/system/info" | jq .

# Get pool status
echo -e "\n=== Pools ==="
curl -s -u "root:$TRUENAS_PASSWORD" \
  "http://$TRUENAS_IP/api/v2.0/pool" | jq '.[] | {name, status, healthy}'

# Get disk info
echo -e "\n=== Disks ==="
curl -s -u "root:$TRUENAS_PASSWORD" \
  "http://$TRUENAS_IP/api/v2.0/disk" | jq '.[] | {name, model, size, pool}'
```

---

## Media Stack Secrets

### Available Secrets in /media

Common secrets used by the media stack:

```bash
# List all media secrets
infisical export --env dev --path /media --format json | jq -r '.[] | .key'
```

**Expected secrets:**
- `JELLYFIN_API_KEY`
- `SONARR_API_KEY`
- `RADARR_API_KEY`
- `LIDARR_API_KEY`
- `PROWLARR_API_KEY`
- `BAZARR_API_KEY`
- `JELLYSEERR_API_KEY`
- `QBITTORRENT_USER`
- `QBITTORRENT_PASS`
- `USERNAME` - Default admin username
- `PASSWORD` - Default admin password

### Using Media Secrets in Docker Compose

The `media/deploy.sh` script automatically uses Infisical:

```bash
cd media

# This automatically uses Infisical to inject secrets
./deploy.sh --full

# Manual docker compose with Infisical
infisical run --env dev --path /media -- docker compose up -d
```

---

## Best Practices

### 1. Never Hardcode Secrets

**DON'T:**
```bash
TRUENAS_PASSWORD="Stopforgetting890"  # Bad!
```

**DO:**
```bash
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)
```

### 2. Use Appropriate Paths

Organize secrets by service:
- `/TrueNAS` - TrueNAS credentials
- `/media` - Media stack (Jellyfin, *arr apps)
- `/monitoring` - Grafana, Prometheus
- `/proxy` - Nginx Proxy Manager

### 3. Clean Up Temporary Files

If you export secrets to files:

```bash
# Export to temp file
infisical export --env dev --path /TrueNAS --format dotenv > /tmp/secrets.env

# Use it
source /tmp/secrets.env

# ALWAYS clean up
rm /tmp/secrets.env
```

### 4. Use `infisical run` for Docker

Instead of manually exporting:

```bash
# Best practice
infisical run --env dev --path /media -- docker compose up -d

# Instead of
export JELLYFIN_API_KEY=$(infisical secrets get ...)
docker compose up -d
```

### 5. Restrict Secret Access

- Use separate environments (`dev`, `prod`) if needed
- Use path-based organization
- Don't put all secrets at root `/`

---

## Troubleshooting

### "Error: unknown flag: --projectId"

Some commands don't need `--projectId` (it's stored in `.infisical.json`):

```bash
# Don't use --projectId for most commands
infisical secrets folders get --env dev --path /

# Only needed for machine identity / service token auth
```

### "Secret not found"

Check the correct path:

```bash
# List folders first
infisical secrets folders get --env dev --path /

# Use exact folder name (case-sensitive!)
infisical export --env dev --path /TrueNAS --format json  # Correct
infisical export --env dev --path /truenas --format json  # Wrong (lowercase)
```

### Empty Output

If `infisical export` returns empty, check authentication:

```bash
# Login if needed
infisical login

# Verify project ID
cat .infisical.json

# Try listing folders
infisical secrets folders get --env dev --path /
```

---

## Reference: Complete Command List

### Secrets Management

```bash
# Get single secret (plain text)
infisical secrets get SECRET_NAME --env dev --path /folder --plain

# Get secret with metadata
infisical secrets get SECRET_NAME --env dev --path /folder

# Set a secret
infisical secrets set KEY=VALUE --env dev --path /folder

# Delete a secret
infisical secrets delete SECRET_NAME --env dev --path /folder

# Export all secrets (JSON)
infisical export --env dev --path /folder --format json

# Export all secrets (dotenv)
infisical export --env dev --path /folder --format dotenv

# Export all secrets recursively
infisical export --env dev --path / --format json --recursive
```

### Folder Management

```bash
# List folders
infisical secrets folders get --env dev --path /

# Create folder
infisical secrets folders create --name newfolder --env dev --path /

# Delete folder
infisical secrets folders delete --name folder --env dev --path /
```

### Running Commands

```bash
# Run command with secrets injected
infisical run --env dev --path /folder -- command args

# Run with multiple paths (if needed)
infisical run --env dev --path /folder1 -- command

# Silent mode (no info messages)
infisical run --env dev --path /folder --silent -- command
```

---

## Examples for Common Tasks

### Example 1: TrueNAS Pool Status Script

```bash
#!/usr/bin/env bash
# truenas/scripts/check_pools.sh

TRUENAS_IP="${TRUENAS_IP:-10.0.0.50}"
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

echo "Checking TrueNAS pools at $TRUENAS_IP..."

curl -s -u "root:$TRUENAS_PASSWORD" \
  "http://$TRUENAS_IP/api/v2.0/pool" | jq '.[] | {
    name,
    status,
    healthy,
    topology: .topology.data[0].type,
    path
  }'
```

### Example 2: Automated Dataset Creation

```bash
#!/usr/bin/env bash
# truenas/scripts/create_dataset.sh

set -euo pipefail

TRUENAS_IP="${1:-10.0.0.50}"
DATASET_NAME="${2:-bulk/test}"
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

echo "Creating dataset: $DATASET_NAME"

curl -s -u "root:$TRUENAS_PASSWORD" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$DATASET_NAME\",
    \"type\": \"FILESYSTEM\",
    \"compression\": \"LZ4\",
    \"atime\": false
  }" \
  "http://$TRUENAS_IP/api/v2.0/pool/dataset"
```

### Example 3: Docker Compose with Secrets

```bash
#!/usr/bin/env bash
# Start media stack with secrets from Infisical

cd /mnt/fast/docker/homelab/media

# Inject secrets and start services
infisical run --env dev --path /media -- docker compose --profile jellyfin up -d

# Check status
docker compose ps
```

---

## Additional Notes

- **Infisical CLI version**: Check with `infisical --version`
- **Web UI**: Access at `http://localhost:8080` (if running locally)
- **Documentation**: https://infisical.com/docs/cli/overview
- **Project ID**: Stored in `.infisical.json` in repo root

---

*Last updated: 2026-02-11*
