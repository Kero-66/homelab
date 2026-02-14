# TrueNAS Media Stack Implementation Session - Feb 11, 2026

## Project Goal
Deploy a complete media server stack (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd, Bazarr, Jellyseerr, Jellystat, FlareSolverr, FileFlows, Recyclarr, Cleanuparr) on TrueNAS Scale 25.10.1 with **CRITICAL SECURITY REQUIREMENT**: All secrets must be managed through Infisical - NO credentials stored in `.env` files on disk or in TrueNAS database.

---

## System Configuration

### Hardware & Storage
- **TrueNAS Server**: 192.168.20.22 (Scale 25.10.1)
- **User**: kero66 (UID/GID 1000) - matches existing media stack user
- **Storage Pools**:
  - **Data pool**: 2x 8TB HDD mirror (`/mnt/Data`) - for media files
    - Datasets: `Data/media/movies`, `Data/media/tv`, `Data/media/music`, `Data/downloads/complete`, `Data/downloads/incomplete`
  - **Fast pool**: 2x 1TB NVMe mirror (`/mnt/Fast`) - for Docker configs/databases
    - Datasets: `Fast/docker/`, `Fast/ix-apps/`
- **NFS Shares**: Exported Data/media, Data/downloads, Fast/docker to 192.168.20.0/24
- **Docker**: Configured to use Fast pool at `/mnt/Fast/ix-apps`

### Workstation
- **OS**: Ubuntu
- **Tools**: Infisical CLI installed and configured
- **Infisical Project**: Configured with `dev` environment, secrets at path `/media`
- **TrueNAS API**: Admin API key stored in Infisical at `/TrueNAS/truenas_admin_api`

### Repository Structure
```
~/homelab/
├── media/
│   ├── compose.yaml          # Complete media stack (12+ services)
│   ├── .env.example          # Template (PUID=1000, PGID=1000)
│   └── scripts/              # Automation scripts
├── truenas/
│   ├── README.md
│   ├── HARDWARE_CONFIG.md    # Pool configuration documented
│   ├── SETUP_COMPLETE.md     # Progress tracking
│   ├── SESSION_2026-02-11.md # This document
│   └── scripts/              # TrueNAS automation scripts
└── docs/
    └── INFISICAL_GUIDE.md    # Secrets management reference
```

---

## What Was Completed This Session

### 1. ✅ TrueNAS Storage Setup (Previously Completed)
- Created and configured both ZFS pools
- Created all necessary datasets
- Configured NFS exports
- Set Docker to use Fast pool (job 3495 completed)

### 2. ✅ Initial Container Manager Research
Investigated Dockge, Portainer, and other options to determine if any had native integration with Infisical or external secret managers.

**Finding**: None have native secret management integration.

### 3. ✅ Infisical Agent Discovery
Found that Infisical has an **Agent** feature that could solve our problem:
- Daemon that runs alongside containers
- Fetches secrets from Infisical and writes them to files
- Supports templating (Go text/template)
- Auto-rotates secrets on configurable intervals
- Can trigger commands on secret changes
- Supports multiple auth methods (Universal Auth, K8s, AWS, Azure, GCP)

### 4. ✅ COMPREHENSIVE RESEARCH COMPLETED

Deep-dive research into three potential platforms to understand their secret management capabilities:

#### **A. Dockge Analysis** (from source code examination)
**Repository**: https://github.com/louislam/dockge

**Key Findings**:
- **NO secret management**: Only supports plain text `.env` files
- **NO plugin system**: Monolithic architecture with no extension points
- **NO hooks**: Fixed lifecycle, no pre/post deployment hooks
- **File structure**: `/opt/stacks/<stack>/.env` per stack, optional `/opt/stacks/global.env`
- **Execution model**: Direct `docker compose` CLI calls (not Docker API)
- **Security issue**: Active command injection vulnerability (PR #917)
- **Community demand**: Feature request #370 has 26 upvotes for native secrets management

**Architecture**:
```
User → Dockge Web UI → Node.js Backend → docker compose CLI
                                       ↓
                                   Plain .env files
```

**Conclusion**: Cannot support external secret managers without major refactoring.

---

#### **B. Portainer CE Analysis** (from docs and source)
**Repository**: https://github.com/portainer/portainer

**Key Findings**:
- **Docker Swarm only**: Native secrets only work with Swarm mode (not standalone Docker)
- **NO external integrations**: No support for Vault, AWS Secrets Manager, Azure Key Vault
- **NO plugin system**: Closed architecture, no extension points
- **Storage**: Environment variables stored in plaintext in Portainer's internal database
- **NO hooks/webhooks** for secret injection (webhooks only trigger redeployments, not secret management)
- **UI masking**: Hides secret values in UI but doesn't encrypt in database

**Architecture**:
```
User → Portainer Web UI → Portainer API → Portainer Database (plaintext)
                                        → Docker API
```

**Community approach**: Users manage secrets completely outside Portainer using:
- Manual Docker secrets (Swarm only)
- External secret injection scripts
- Pre-deployment hooks outside Portainer

**Conclusion**: Portainer CE has no secret management for standalone Docker deployments.

---

#### **C. TrueNAS SCALE Analysis** (from middleware source)
**Repository**: https://github.com/truenas/middleware

**Key Findings**:
- **NO secret management**: Environment variables stored in plaintext in SQLite database
- **NO encryption**: Configuration stored as JSON blobs without encryption
- **NO external integrations**: No Vault, AWS Secrets Manager, Azure Key Vault support
- **UI masking only**: `private: true` flag only hides values in UI (doesn't encrypt in storage)

**Storage locations**:
- Main database: `/data/freenas-v1.db` (SQLite)
- K8s manifests: `/mnt/.ix-apps/k3s/manifests/`
- Helm values: `/mnt/.ix-apps/releases/<app-name>/values.yaml`

**Architecture**:
```
User → TrueNAS Web UI → Middleware API → SQLite Database (plaintext)
                                      → K3s/Helm → Container
```

**Community workarounds**:
- Manual Kubernetes secrets (still stored in etcd unencrypted by default)
- ACL-protected files on datasets
- Init containers that fetch secrets at runtime
- External secret operators (requires Kubernetes expertise)

**Conclusion**: TrueNAS Custom Apps have no secret management; secrets stored in plaintext database.

---

### Research Summary: No Platform Has Native Secret Management

| Platform | Secret Storage | External Integration | Plugin System | Hooks/Webhooks |
|----------|---------------|---------------------|---------------|----------------|
| **Dockge** | Plaintext `.env` files | ❌ None | ❌ None | ❌ None |
| **Portainer CE** | Plaintext DB | ❌ None | ❌ None | ⚠️ Redeployment only |
| **TrueNAS** | Plaintext SQLite | ❌ None | ❌ None | ❌ None |

**Critical Finding**: ALL three platforms store secrets in plaintext without encryption or external secret manager support.

---

## The Infisical Agent Solution

Since no container manager has native secret management, we explored the **Infisical Agent** as an external solution.

### How Infisical Agent Works

```
┌─────────────────────┐
│  Infisical Agent    │ ◄── Authenticates with Infisical Cloud
│  (runs as container │     Polls for secrets every 60s (configurable)
│   or systemd)       │     Writes rendered template to disk
└──────────┬──────────┘
           │
           ▼ (writes files)
    ┌──────────────────┐
    │ /mnt/Fast/docker/│
    │   media/.env     │ ◄── Agent writes secrets here
    └────────┬─────────┘
             │
             ▼ (mounts volume)
┌────────────────────────┐
│  Media Stack Container │
│  (Jellyfin, Sonarr,    │ ◄── Reads .env file like normal
│   Radarr, etc.)        │
└────────────────────────┘
```

### Agent Features
- ✅ **Authentication**: Universal Auth (client-id/secret), K8s, AWS IAM, Azure, GCP
- ✅ **Templating**: Go text/template syntax for flexible secret rendering
- ✅ **Auto-rotation**: Polls Infisical at configurable intervals (default 60s)
- ✅ **Command execution**: Can restart containers when secrets change
- ✅ **Platform agnostic**: Works with ANY container manager (Dockge, Portainer, TrueNAS, plain Docker)

### Agent Configuration Example

**Agent Config** (`/opt/infisical-agent/config.yaml`):
```yaml
infisical:
  address: "https://app.infisical.com"

auth:
  type: "universal-auth"
  config:
    client-id: "/opt/infisical-agent/client-id"
    client-secret: "/opt/infisical-agent/client-secret"
    remove_client_secret_on_read: true

templates:
  - source-path: /opt/infisical-agent/templates/media-stack.tmpl
    destination-path: /mnt/Fast/docker/media/.env
    config:
      polling-interval: 60s
      execute:
        command: "docker compose -f /mnt/Fast/docker/media/compose.yaml restart"
        timeout: 120
```

**Template File** (`/opt/infisical-agent/templates/media-stack.tmpl`):
```go
{{- with secret "YOUR-PROJECT-ID" "dev" "/media" `{"recursive": true, "expandSecretReferences": true}` }}
{{- range . }}
{{ .Key }}={{ .Value }}
{{- end }}
{{- end }}
```

**Agent Docker Compose** (`/mnt/Fast/docker/infisical-agent/compose.yaml`):
```yaml
services:
  infisical-agent:
    image: infisical/cli:latest
    container_name: infisical-agent
    restart: unless-stopped
    command: agent --config /config/agent-config.yaml
    volumes:
      - /opt/infisical-agent/config.yaml:/config/agent-config.yaml:ro
      - /opt/infisical-agent/templates:/config/templates:ro
      - /opt/infisical-agent/client-id:/config/client-id:ro
      - /opt/infisical-agent/client-secret:/config/client-secret:ro
      - /mnt/Fast/docker:/output
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### Benefits of Infisical Agent Approach
✅ **No TrueNAS database storage**: Secrets never touch TrueNAS/Portainer/Dockge databases
✅ **Automatic rotation**: Agent polls every 60s and updates secrets
✅ **Container restart on change**: Can automatically restart containers when secrets rotate
✅ **Platform agnostic**: Works with ANY container manager (or no manager at all)
✅ **Transparent to apps**: Containers just read `.env` files normally
✅ **Centralized management**: All secrets managed in Infisical dashboard

### Trade-offs of Infisical Agent Approach
⚠️ **Secrets on disk**: `.env` files exist on disk at `/mnt/Fast/docker/media/.env`
  - Mitigations: root-only readable (600 permissions), ephemeral (auto-rotated), not in git
⚠️ **Additional complexity**: One more service to manage (the agent itself)
⚠️ **Agent must stay running**: If agent fails, secrets won't rotate (but containers keep running with last known secrets)

---

## Current Status: At a Decision Point

**We have NOT started implementation yet.**

We are at a critical decision point that needs your input:

### Decision 1: Accept Infisical Agent Approach?

**Question**: Is it acceptable for secrets to exist on disk in agent-written `.env` files?

**Context**:
- Files are root-only readable (600 permissions)
- Files auto-rotate every 60s
- Files are NOT committed to git
- This is the ONLY solution that keeps secrets out of TrueNAS/Portainer/Dockge databases

**Options**:
- ✅ **Accept this approach**: Proceed with Infisical Agent implementation
- ❌ **Reject this approach**: Explore other alternatives (see below)

### Decision 2: Alternative Approaches (If Agent Rejected)

If Infisical Agent approach is not acceptable, alternatives include:

#### Option A: Manual Secret Injection Scripts
- Write bash scripts that fetch from Infisical and inject into containers
- Run as cron jobs or systemd timers
- **Pros**: More control over secret handling
- **Cons**: More maintenance, no auto-restart, manual implementation

#### Option B: Kubernetes + External Secrets Operator
- Convert TrueNAS to use Kubernetes (it already runs K3s underneath)
- Deploy External Secrets Operator
- Use Kubernetes secrets (still base64, not encrypted by default)
- **Pros**: Industry-standard approach
- **Cons**: Much more complex, requires K8s expertise, secrets still on disk in etcd

#### Option C: Accept Plaintext Storage in Container Manager
- Store secrets in Dockge/Portainer/TrueNAS databases
- Accept that secrets are plaintext
- Rely on TrueNAS OS-level security (file permissions, network isolation)
- **Pros**: Simplest approach, no additional tooling
- **Cons**: Violates your security requirement

#### Option D: Hashicorp Vault Agent (Similar to Infisical Agent)
- Use Vault instead of Infisical
- Same architecture as Infisical Agent (writes files to disk)
- **Pros**: More mature, more enterprise features
- **Cons**: More complex setup, requires Vault server, same trade-off (secrets on disk)

### Decision 3: Which Container Manager? (If Proceeding with Agent)

If we proceed with Infisical Agent, we still need to choose a container manager:

| Manager | Pros | Cons |
|---------|------|------|
| **Dockge** | Simple UI, easy stack management, 10K+ installs | Command injection vulnerability, no plugin system |
| **Portainer CE** | Full-featured, 10K+ installs, active development | Heavier resource usage, more complex UI |
| **TrueNAS Custom App** | Native to TrueNAS, integrated UI | Less flexible, UI can be clunky, harder to debug |
| **Plain Docker Compose** | No extra tool, most direct control | No web UI, manual management |

---

## Proposed Implementation Steps (If Proceeding)

**These steps are NOT executed yet - awaiting your decision.**

### Phase 1: Infisical Machine Identity Setup
1. Log into Infisical dashboard
2. Navigate to your project → Settings → Machine Identities
3. Create new Universal Auth identity: `truenas-media-stack-agent`
4. Set permissions: Read access to `/media` path in `dev` environment
5. Generate client-id and client-secret
6. Securely transfer credentials to TrueNAS

### Phase 2: Deploy Infisical Agent on TrueNAS
1. SSH to TrueNAS as root
2. Create directory structure:
   ```bash
   mkdir -p /opt/infisical-agent/templates
   mkdir -p /mnt/Fast/docker/infisical-agent
   ```
3. Create agent configuration files (config.yaml, template, credentials)
4. Create agent Docker Compose file
5. Deploy agent: `docker compose up -d`
6. Verify agent logs: `docker logs infisical-agent`

### Phase 3: Adapt Media Stack Compose File
1. Update `~/homelab/media/compose.yaml` with TrueNAS paths:
   - Change config dirs: `.` → `/mnt/Fast/docker/<service>`
   - Change data dirs: `/data` → `/mnt/Data`
   - Add `env_file: /mnt/Fast/docker/media/.env` to all services
2. Test locally on workstation first (dry-run)
3. Copy to TrueNAS: `/mnt/Fast/docker/media/compose.yaml`

### Phase 4: Choose and Deploy Container Manager
**Option 4a - Dockge**:
1. Deploy Dockge as TrueNAS Custom App or Docker container
2. Point Dockge to `/mnt/Fast/docker` for stacks
3. Import media stack compose file
4. Deploy through Dockge UI

**Option 4b - Portainer**:
1. Deploy Portainer CE as TrueNAS Custom App
2. Connect to local Docker socket
3. Create stack from media compose file
4. Deploy through Portainer UI

**Option 4c - TrueNAS Custom App**:
1. Create Custom App through TrueNAS UI
2. Manually configure each service (tedious)
3. Deploy through TrueNAS

**Option 4d - Plain Docker**:
1. SSH to TrueNAS
2. `cd /mnt/Fast/docker/media && docker compose up -d`
3. Manage via CLI

### Phase 5: Verify and Test
1. Check all containers are running: `docker ps`
2. Verify services are accessible (Jellyfin web UI, etc.)
3. Test secret rotation:
   - Change a secret in Infisical
   - Wait 60s (polling interval)
   - Verify `.env` file updated
   - Verify containers restarted
4. Check container logs for errors

### Phase 6: Install Tailscale (Optional)
1. Install Tailscale app from TrueNAS Apps
2. Authenticate with Tailscale account
3. Configure Jellyfin for remote access

---

## Files That Need Creation (For Implementation)

### On TrueNAS Server

1. **`/opt/infisical-agent/config.yaml`** - Agent configuration
2. **`/opt/infisical-agent/templates/media-stack.tmpl`** - Secret template
3. **`/opt/infisical-agent/client-id`** - Machine identity client ID
4. **`/opt/infisical-agent/client-secret`** - Machine identity client secret
5. **`/mnt/Fast/docker/infisical-agent/compose.yaml`** - Agent deployment
6. **`/mnt/Fast/docker/media/compose.yaml`** - Adapted media stack (copied from workstation)

### On Workstation (Modified)

1. **`~/homelab/media/compose.yaml`** - Update paths for TrueNAS deployment
2. **`~/homelab/truenas/infisical-agent/`** - Store agent configs for reference

---

## Critical Security Requirements (Non-Negotiable)

1. ❌ **NO secrets in `.env` files** committed to git
2. ❌ **NO credentials stored in TrueNAS database**
3. ✅ **All secrets must come from Infisical**
4. ✅ **Secrets should auto-rotate**
5. ⚠️ **Open question**: Are agent-written `.env` files on disk acceptable?

---

## Open Questions for Tomorrow

### 1. **Security Trade-off Decision**
   - Is Infisical Agent approach (secrets on disk) acceptable?
   - Or should we explore alternative approaches?

### 2. **Container Manager Choice**
   - Dockge (simple, UI-focused)?
   - Portainer (full-featured)?
   - TrueNAS Custom App (native)?
   - Plain Docker Compose (no UI)?

### 3. **Deployment Strategy**
   - Deploy as single compose file or split by function?
   - Use Docker networks for service isolation?

### 4. **Secret Rotation Testing**
   - How to safely test secret rotation without breaking services?
   - Fallback strategy if agent fails?

---

## Key Resources

- **Infisical Agent Docs**: https://infisical.com/docs/integrations/platforms/infisical-agent
- **Infisical Agent GitHub**: https://github.com/Infisical/infisical (see `cli/` directory)
- **Techno Tim's TrueNAS Docker Guide**: https://technotim.com/posts/truenas-docker-pro/
- **Dockge GitHub**: https://github.com/louislam/dockge
- **Portainer Docs**: https://docs.portainer.io/
- **TrueNAS SCALE Apps**: https://apps.truenas.com
- **Current Media Stack**: `~/homelab/media/compose.yaml` (12+ services, LinuxServer.io images)

---

## Research Notes

### Infisical Agent Technical Details

**Authentication Methods**:
- Universal Auth: client-id + client-secret (recommended for our use case)
- Kubernetes Auth: Service account tokens
- AWS IAM Auth: IAM roles
- Azure Auth: Managed identities
- GCP Auth: Service accounts

**Template Syntax** (Go text/template):
```go
# Fetch all secrets from a path
{{- with secret "project-id" "env" "/path" `{"recursive": true}` }}
{{- range . }}
{{ .Key }}={{ .Value }}
{{- end }}
{{- end }}

# Fetch specific secret
{{ secret "project-id" "env" "/path/SECRET_NAME" }}

# Conditional rendering
{{- if eq .Key "DATABASE_URL" }}
DB_URL={{ .Value }}
{{- end }}
```

**Command Execution**:
- Runs after template is written
- Has configurable timeout (default 60s)
- Can be used to restart containers, reload configs, etc.
- Stdout/stderr logged by agent

**Error Handling**:
- Agent retries on network failures (exponential backoff)
- If template rendering fails, previous file is NOT overwritten
- If command execution fails, agent logs error but continues polling

### TrueNAS Docker Setup Details

**Docker Storage Location**: `/mnt/Fast/ix-apps/`
- Docker root: `/mnt/Fast/ix-apps/docker`
- Docker data: `/mnt/Fast/ix-apps/docker/data`
- Docker volumes: `/mnt/Fast/ix-apps/docker/volumes`

**Verification Commands**:
```bash
# Check Docker root
docker info | grep "Docker Root Dir"

# Check if job completed
midclt call core.get_jobs | jq '.[] | select(.id == 3495)'

# Check datasets
zfs list | grep -E "Fast|Data"
```

### Media Stack Services Breakdown

| Service | Purpose | Port | Config Location |
|---------|---------|------|----------------|
| Jellyfin | Media server | 8096 | `/mnt/Fast/docker/jellyfin` |
| Sonarr | TV show management | 8989 | `/mnt/Fast/docker/sonarr` |
| Radarr | Movie management | 7878 | `/mnt/Fast/docker/radarr` |
| Prowlarr | Indexer manager | 9696 | `/mnt/Fast/docker/prowlarr` |
| qBittorrent | Torrent client | 8080 | `/mnt/Fast/docker/qbittorrent` |
| SABnzbd | Usenet client | 8081 | `/mnt/Fast/docker/sabnzbd` |
| Bazarr | Subtitle management | 6767 | `/mnt/Fast/docker/bazarr` |
| Jellyseerr | Request management | 5055 | `/mnt/Fast/docker/jellyseerr` |
| Jellystat | Statistics | 3000 | `/mnt/Fast/docker/jellystat` |
| FlareSolverr | Cloudflare bypass | 8191 | `/mnt/Fast/docker/flaresolverr` |
| FileFlows | File processing | 5000 | `/mnt/Fast/docker/fileflows` |
| Recyclarr | Radarr/Sonarr config sync | N/A | `/mnt/Fast/docker/recyclarr` |
| Cleanuparr | Media cleanup | N/A | `/mnt/Fast/docker/cleanuparr` |

**Network Architecture**:
```
┌──────────────────────────────────────────────────────┐
│                    Docker Network                     │
│                                                        │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │ Jellyfin │◄───│ Sonarr   │◄───│ Prowlarr │       │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘       │
│       │               │                 │             │
│       │          ┌────▼─────┐    ┌─────▼──────┐     │
│       │          │ Radarr   │    │qBittorrent │     │
│       │          └──────────┘    └────────────┘     │
│       │                                              │
│  ┌────▼──────┐    ┌──────────┐    ┌──────────┐     │
│  │Jellyseerr │    │  Bazarr  │    │ SABnzbd  │     │
│  └───────────┘    └──────────┘    └──────────┘     │
└──────────────────────────────────────────────────────┘
            │                    │
            ▼                    ▼
    /mnt/Data/media      /mnt/Data/downloads
```

---

## Session Conclusion

**Status**: Research and analysis phase complete. NO implementation started.

**Key Findings**:
- No container manager has native secret management
- Infisical Agent is viable solution but requires secrets on disk
- Decision needed before proceeding with implementation

**Next Session Actions**:
1. Review this document
2. Make decision on security trade-off
3. Choose container manager
4. Proceed with implementation (if decisions made)

**Recommended Pre-Reading**:
- Infisical Agent docs: https://infisical.com/docs/integrations/platforms/infisical-agent
- Review `~/homelab/media/compose.yaml` to understand current stack
- Review `~/homelab/truenas/HARDWARE_CONFIG.md` for storage layout

---

## Session Metadata

- **Date**: February 11, 2026
- **Duration**: ~2 hours
- **Phase**: Research and analysis
- **Next Phase**: Decision and implementation
- **Blocker**: Security trade-off decision needed
