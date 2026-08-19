# Dockhand GitOps Setup Guide

**Goal**: Manage TrueNAS containers via git-based deployments using Dockhand

**Status**: ✅ Complete — all 13 stacks migrated 2026-08-19, auto-sync enabled daily @ 3am

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

### Step 2: Repository already registered

`homelab` is registered once as `repositoryId: 1` (confirmed live via `GET /api/git/repositories`) — SSH auth, credential id 1. This is a one-time setup; every stack references this same `repositoryId`, no need to re-add the repo per stack.

```bash
DOCKHAND_USER=$(infisical secrets get DOCKHAND_USER --env dev --path /TrueNAS --plain --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081)
DOCKHAND_PASS=$(infisical secrets get DOCKHAND_USER_PASSWORD --env dev --path /TrueNAS --plain --projectId "$INFISICAL_PROJECT_ID" --domain http://192.168.20.22:8081)
curl -s -c cookies.txt -X POST "http://192.168.20.22:30328/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$DOCKHAND_USER\",\"password\":\"$DOCKHAND_PASS\",\"provider\":\"local\"}"
curl -s -b cookies.txt "http://192.168.20.22:30328/api/git/repositories" | jq
```

**IMPORTANT — do not use `curl -c <file>` for the cookie jar.** That writes a live session credential to disk, even briefly. Capture it in memory instead — e.g. Python's `http.cookiejar` + `urllib.request.HTTPCookieProcessor`, or `curl -c -` (stdout) piped into a variable and fed back via process substitution.

### Step 3: Create a stack from git — the real API

The web UI has a "Source: Git Repository" option (`GitStackModal.svelte`), but the REST API is fully scriptable and this is the proven path (used for all 13 stacks):

**`POST /api/git/repositories`** — register a repo (one-time, already done for `homelab`):
```json
{"name": "homelab", "url": "https://github.com/<user>/homelab", "branch": "main", "credentialId": 1}
```

**`POST /api/git/stacks`** — create a git-linked stack:
```json
{
  "stackName": "homepage",
  "repositoryId": 1,
  "environmentId": 1,
  "composePath": "/truenas/stacks/homepage/compose.yaml",
  "autoUpdate": true,
  "autoUpdateSchedule": "daily",
  "autoUpdateCron": "0 3 * * *",
  "deployNow": true
}
```
Note `composePath` is a **single full path from repo root** (leading slash), not split into a directory + filename. Response is `{"jobId": "..."}` — poll `GET /api/jobs/<jobId>` for the deploy result.

**`PUT /api/git/stacks/{id}`** — update an existing git stack's config (autoUpdate, deployNow to trigger a sync now, composePath, etc).

**No conversion endpoint exists.** If a stack already exists as an `internal` stack (created via plain `POST /api/stacks`), `POST /api/git/stacks` rejects it with `409 Conflict` — confirmed by reading the actual validation code (`getStackSource()` checks across all stack types). The only path is `DELETE /api/stacks/<name>` (safe — only removes the container + Dockhand's record; bind-mounted host data is untouched unless `?volumes=true` is passed, and that only targets named volumes anyway) followed by the `POST /api/git/stacks` create above. This is exactly what was needed for `maintainerr`, which had been deployed ad-hoc outside the repo.

Full endpoint list discovered by reading Dockhand's source at `github.com/Finsys/dockhand` (`src/routes/api/git/{repositories,stacks}/+server.ts` etc) — there's no public OpenAPI spec yet (planned per upstream issue #814).

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

## Migration Path — Complete

All stacks are migrated (2026-08-19). For any *new* stack added to the repo going forward:

**1. Verify compose.yaml is ready**
```bash
cd truenas/stacks/<stack-name>
docker compose config  # Validates syntax
```

**2. Create the git stack via API** (see Step 3 above for full request shape):
```bash
curl -s -b cookies.txt -X POST "http://192.168.20.22:30328/api/git/stacks" \
  -H "Content-Type: application/json" \
  -d '{"stackName":"<stack-name>","repositoryId":1,"environmentId":1,"composePath":"/truenas/stacks/<stack-name>/compose.yaml","autoUpdate":true,"autoUpdateSchedule":"daily","autoUpdateCron":"0 3 * * *","deployNow":true}'
```
If a stack of that name already exists as `internal` (deployed ad-hoc, not via git), this returns `409 Conflict` — `DELETE /api/stacks/<name>` first, then retry.

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
### Create-stack request shape
```json
{
  "stackName": "<stack-name>",
  "repositoryId": 1,
  "environmentId": 1,
  "composePath": "/truenas/stacks/<stack-name>/compose.yaml",
  "autoUpdate": true,
  "autoUpdateSchedule": "daily",
  "autoUpdateCron": "0 3 * * *",
  "deployNow": true
}
```

### Current Status
- ✅ Dockhand deployed and accessible
- ✅ Git authentication configured (SSH deploy key)
- ✅ Keys stored in Infisical (never on disk)
- ✅ All 13 stacks migrated to git-sourced, `autoUpdate: true`, daily @ 3am (2026-08-19)

### Next Steps
- New stacks: follow "Migration Path" above (`POST /api/git/stacks`).
- Consider webhook-based sync instead of the daily cron for faster deploy turnaround, if desired.
