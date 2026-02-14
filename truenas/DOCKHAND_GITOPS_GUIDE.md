# Dockhand GitOps Setup Guide

**Goal**: Manage TrueNAS containers via git-based deployments using Dockhand

**Status**: Active - Homepage stack in progress

---

## Architecture Overview

```
GitHub Repo (homelab)
    ↓ (git webhook or polling)
Dockhand on TrueNAS
    ↓ (docker API)
TrueNAS Docker Containers
```

**Benefits:**
- ✅ Infrastructure as Code - All changes tracked in git
- ✅ Automated deployments - Push to git, auto-deploy
- ✅ Rollback capability - Git history = deployment history
- ✅ Security - Secrets via Infisical, no hardcoded values
- ✅ Multi-environment - Can replicate to other nodes later

---

## Prerequisites

### 1. Dockhand Access
- **Web UI**: http://192.168.20.22:30328/
- **Authentication**: Credentials stored in Infisical `/TrueNAS` path
  - `DOCKHAND_USER`
  - `DOCKHAND_USER_PASSWORD`
- **User**: kero66 (UID 1000)

### 2. Git Repository Structure

**Existing structure (no changes needed):**
```
homelab/
└── truenas/stacks/
    ├── homepage/
    │   └── compose.yaml
    ├── caddy/
    │   ├── compose.yaml
    │   └── Caddyfile
    ├── arr-stack/
    │   └── compose.yaml
    ├── jellyfin/
    │   └── compose.yaml
    └── ...
```

**Key Point**: Dockhand points directly at `truenas/stacks/<stack-name>/compose.yaml` - no symlinks or additional directory structure needed.

---

## Setup Steps

### Step 1: Configure Git Authentication

Deploy keys are stored in Infisical for security. To retrieve them:

```bash
# Retrieve private key (for Dockhand configuration)
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE --env dev --path /TrueNAS --plain

# Retrieve public key (already added to GitHub)
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PUBLIC --env dev --path /TrueNAS --plain
```

**GitHub Configuration:**
- Deploy key already added to: https://github.com/<username>/homelab/settings/keys
- Access: Read-only
- Key type: ed25519

### Step 2: Configure Repository in Dockhand

1. **Access Dockhand Web UI**
   - URL: http://192.168.20.22:30328/
   - Login with credentials from Infisical

2. **Add Git Repository** (if not already configured)
   - Navigate to: Settings → Git Integration → Add Repository
   - **Repository URL**: `git@github.com:<username>/homelab.git` (SSH) or `https://github.com/<username>/homelab.git` (HTTPS)
   - **Branch**: `main`
   - **Auth Method**: SSH Deploy Key (paste private key from Infisical)

### Step 3: Create Stack from Git

**Example: Homepage Stack**

1. **Create New Stack in Dockhand UI**
   - Name: `homepage`
   - Source: **Git Repository**
   - Repository: Select `homelab` repo
   - **Git Path**: `truenas/stacks/homepage`
   - **Compose File**: `compose.yaml`
   - **Sync Interval**: 60 seconds (or use webhook)

2. **Environment Variables**
   - Dockhand will use `env_file` directives from compose.yaml
   - Infisical Agent continues to render `.env` files to `/mnt/Fast/docker/<stack>/.env`
   - No additional configuration needed

3. **Networks**
   - External networks are referenced in compose.yaml
   - Ensure they exist before deploying:
     - `ix-jellyfin_default`
     - `ix-arr-stack_default`

4. **Deploy Stack**
   - Click "Deploy" or enable auto-sync
   - Dockhand pulls compose.yaml from git and deploys

### Step 4: Test GitOps Workflow

#### Test 1: Configuration Change (Non-breaking)
```bash
# 1. Make a comment change in compose.yaml
cd truenas/stacks/homepage
echo "# Test GitOps deployment - $(date)" >> compose.yaml

# 2. Commit and push
git add compose.yaml
git commit -m "test(homepage): verify GitOps auto-deployment"
git push origin main

# 3. Watch Dockhand UI or logs for sync
# Should see: "Stack 'homepage' synced from git"

# 4. Verify deployment
curl -I http://192.168.20.22:3000
# Should return HTTP 200
```

#### Test 2: Service Configuration Update
```bash
# 1. Update memory limit in compose.yaml
cd truenas/stacks/homepage
sed -i 's/mem_limit: 256m/mem_limit: 512m/' compose.yaml

# 2. Commit and push
git add compose.yaml
git commit -m "feat(homepage): increase memory limit to 512m"
git push origin main

# 3. Dockhand should:
#    - Detect change within 60 seconds
#    - Pull updated compose file
#    - Recreate container with new settings
#    - Health check passes
```

#### Test 3: Rollback
```bash
# If deployment fails, rollback via git
git revert HEAD
git push origin main

# Dockhand should auto-deploy previous working version
```

---

## Security Considerations

### 1. Git Repository Access

**Deploy Key (Configured)**
- ✅ SSH deploy key already generated and stored in Infisical
- ✅ Public key added to GitHub repository (read-only access)
- ✅ Private key stored at: `/TrueNAS/DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE`

**To retrieve keys:**
```bash
# Private key (for Dockhand config)
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE --env dev --path /TrueNAS --plain

# Public key (for reference)
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PUBLIC --env dev --path /TrueNAS --plain
```

**Security Notes:**
- Read-only access prevents accidental pushes from Dockhand
- Keys never stored in git or on disk (Infisical-managed only)
- Deploy key scoped to single repository

### 2. Secrets Management

**Architecture:**
```
Infisical (Secret Store)
    ↓ (Infisical Agent on TrueNAS)
/mnt/Fast/docker/<stack>/.env
    ↑ (env_file directive)
Docker Compose
```

**Important Rules:**
- ✅ `.env` files are NEVER committed to git (in `.gitignore`)
- ✅ `compose.yaml` references `.env` via `env_file` directive
- ✅ Infisical Agent runs on TrueNAS, renders secrets on-demand
- ✅ Dockhand pulls compose.yaml from git, uses existing `.env` files

**Example from compose.yaml:**
```yaml
services:
  homepage:
    env_file:
      - /mnt/Fast/docker/homepage/.env  # Generated by Infisical Agent
```

### 3. Webhook Security

If using webhooks instead of polling:
```yaml
# GitHub webhook configuration
URL: https://dockhand.home/api/webhooks/github
Secret: <stored in Infisical>
Events: push (to main branch only)
```

---

## Monitoring & Validation

### Dockhand Logs
```bash
# SSH to TrueNAS
ssh kero66@192.168.20.22

# View Dockhand container logs
docker logs -f <dockhand-container-name>

# Expected output on sync:
# [GitOps] Syncing repository: homelab
# [GitOps] Detected changes in: truenas/stacks/homepage
# [GitOps] Deploying stack: homepage
# [GitOps] Stack 'homepage' deployed successfully
```

### Stack Health
```bash
# Check Homepage container status
curl -I http://192.168.20.22:3000
# Should return HTTP 200

# Check Homepage container
docker ps | grep homepage

# View Homepage logs
docker logs homepage
```

### Git Sync Status
- **Dockhand UI**: Dashboard shows last sync time, commit hash, sync status
- **Expected**: Sync within 60 seconds of push (or instant with webhooks)
- **Alert**: If sync fails, check Dockhand logs and git authentication

---

## Troubleshooting

### Issue: Dockhand Can't Access Git Repo

**Symptom**: "Authentication failed" or "Permission denied" in Dockhand logs

**Solution**:
```bash
# 1. Verify deploy key is configured in Dockhand
# Check Dockhand UI → Settings → Git Integration

# 2. Retrieve private key from Infisical
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE --env dev --path /TrueNAS --plain

# 3. Verify public key is added to GitHub
# GitHub → Repo Settings → Deploy keys
# Should show: "dockhand@truenas" with read-only access

# 4. Test from TrueNAS (if needed)
ssh kero66@192.168.20.22
# Verify git clone works with deploy key
```

### Issue: Compose File Not Found

**Symptom**: "No such file: compose.yaml" in Dockhand logs

**Solution**:
```bash
# Verify path configuration in Dockhand stack settings
# Git Path should be: truenas/stacks/<stack-name>
# Compose File should be: compose.yaml

# Test git clone manually
git clone git@github.com:<username>/homelab.git /tmp/test
ls -la /tmp/test/truenas/stacks/homepage/compose.yaml
# Should exist
```

### Issue: Container Won't Start After GitOps Deploy

**Symptom**: Container exits immediately after Dockhand deployment

**Solution**:
```bash
# 1. Check Dockhand logs for detailed error
ssh kero66@192.168.20.22
docker logs <dockhand-container> | tail -50

# 2. Verify volumes are accessible
ls -la /mnt/Fast/docker/homepage/

# 3. Check .env file exists (Infisical Agent)
ls -la /mnt/Fast/docker/homepage/.env
cat /mnt/Fast/docker/homepage/.env | wc -l
# Should have secrets rendered

# 4. Manually test compose file
cd /path/to/cloned/repo/truenas/stacks/homepage
docker compose config  # Validates syntax without deploying
```

### Issue: External Networks Not Found

**Symptom**: "network ix-jellyfin_default not found"

**Solution**:
```bash
# Verify networks exist
docker network ls | grep ix-

# If missing, ensure other stacks are deployed first
# Networks are created by TrueNAS when deploying apps
```

---

## Migration Path for Other Stacks

Once Homepage GitOps is working, migrate other stacks in priority order:

### Priority Order:
1. 🔄 **Homepage** (in progress - test case)
2. **Caddy** (critical infrastructure, simple compose)
3. **AdGuard Home** (DNS - test with simple network config)
4. **Jellyfin** (single stack, well-tested)
5. **Arr-stack** (complex - multiple services in one compose)
6. **Downloaders** (depends on arr-stack network)
7. **Tailscale** (network complexity, test last)

### Migration Steps per Stack:

**1. Verify compose.yaml is ready**
```bash
cd truenas/stacks/<stack-name>
docker compose config  # Validates syntax
```

**2. Create stack in Dockhand UI**
- Name: `<stack-name>`
- Source: Git Repository
- Repository: `homelab`
- Git Path: `truenas/stacks/<stack-name>`
- Compose File: `compose.yaml`
- Sync: 60 seconds or webhook

**3. Test deployment**
```bash
# Make a test comment change
echo "# Dockhand GitOps enabled - $(date)" >> compose.yaml
git add compose.yaml
git commit -m "feat(<stack>): enable Dockhand GitOps"
git push

# Verify in Dockhand UI or logs
ssh kero66@192.168.20.22
docker logs <dockhand-container> | tail -20
```

**4. Verify functionality**
- Check service health endpoints
- Verify external networks work
- Test dependent services

---

## Future Enhancements

### 1. Multi-Environment Support
When deploying to additional nodes (compute node, backup server):
- Create separate git paths: `truenas/stacks/`, `compute/stacks/`
- Configure multiple Dockhand instances pointing to respective paths
- Share compose files, environment-specific `.env` via Infisical

### 2. Pre-Deploy Validation (GitHub Actions)
Add CI pipeline to validate compose files before deployment:
```yaml
# .github/workflows/validate-compose.yml
name: Validate Compose Files
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate compose files
        run: |
          for f in truenas/stacks/*/compose.yaml; do
            docker compose -f "$f" config --quiet
          done
```

### 3. Automated Testing
- Health check validation post-deployment
- Integration tests (API endpoints, service connectivity)
- Automated rollback on failed health checks

### 4. Notifications
- Webhook to Discord/Slack on deployment success/failure
- Email alerts for critical stacks (Caddy, AdGuard)
- Prometheus metrics for deployment tracking (success rate, duration)

---

## Reference Links

- [Dockhand Documentation](https://dockhand.pro/)
- [Dockhand GitOps Features](https://www.virtualizationhowto.com/2026/01/why-dockhand-is-one-of-the-best-docker-management-tools-for-secure-operations/)
- [TrueNAS Custom Apps](https://www.truenas.com/docs/truenasapps/usingcustomapp/)

---

## Quick Reference

### Key Information
- **Dockhand UI**: http://192.168.20.22:30328/
- **Credentials**: `infisical secrets --env dev --path /TrueNAS` → `DOCKHAND_USER` / `DOCKHAND_USER_PASSWORD`
- **Git Repo**: `git@github.com:<username>/homelab.git`
- **Deploy Key**: Stored in Infisical at `/TrueNAS/DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE`

### Stack Configuration Template
```yaml
Name: <stack-name>
Source: Git Repository
Repository: homelab
Git Path: truenas/stacks/<stack-name>
Compose File: compose.yaml
Sync Interval: 60 seconds
```

### Current Status
- ✅ Dockhand deployed and accessible
- ✅ Git authentication configured (SSH deploy key)
- ✅ Keys stored in Infisical (never on disk)
- 🔄 Homepage stack - ready for configuration in UI
- ⏸️ Other stacks - pending Homepage success

### Next Steps
1. Access Dockhand UI (http://192.168.20.22:30328/)
2. Configure git repository connection
3. Create Homepage stack from git
4. Test GitOps workflow with test commit
5. Migrate other stacks following priority order
