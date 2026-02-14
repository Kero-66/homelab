# TrueNAS Migration Checklist

**CRITICAL**: Follow this checklist for ALL service migrations to avoid configuration errors and data loss.

## Pre-Migration Research Phase

### ✅ Step 1: Identify Existing Configuration
- [ ] Find existing compose file in repo (`apps/`, `networking/`, `media/`)
- [ ] Check if service is currently running on workstation: `docker ps | grep <service>`
- [ ] Inspect current container mounts: `docker inspect <service> | jq '.[].Mounts'`
- [ ] List current data directories: `ls -la <service-dir>/`

### ✅ Step 2: Review Similar Migrations
- [ ] Check `truenas/scripts/` for existing migration scripts
- [ ] Review completed migrations in `ai/todo.md` (look for "✅ COMPLETED" TrueNAS tasks)
- [ ] Read `truenas/DEPLOYMENT_GUIDE.md` for deployment patterns
- [ ] Check `.github/TROUBLESHOOTING.md` for known issues

### ✅ Step 3: Document Current State
- [ ] Screenshot or note current service configuration
- [ ] List all environment variables needed: `cat <service>/.env`
- [ ] Identify secrets that need Infisical templates
- [ ] Check which networks the service uses

## Migration Execution Phase

### ✅ Step 4: Create Backup
```bash
# Create timestamped backup
BACKUP_FILE="$HOME/<service>_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
cd /mnt/library/repos/homelab
tar czf "$BACKUP_FILE" <service-dir>/
ls -lh "$BACKUP_FILE"  # Verify backup created
```

### ✅ Step 5: Prepare TrueNAS
```bash
# Create service directory
ssh kero66@192.168.20.22 "mkdir -p /mnt/Fast/docker/<service>"

# If service needs database
ssh kero66@192.168.20.22 "mkdir -p /mnt/Fast/databases/<service>"
```

### ✅ Step 6: Migrate Configuration
```bash
# Copy entire config directory
scp -r <service-dir>/* kero66@192.168.20.22:/mnt/Fast/docker/<service>/

# Verify files copied
ssh kero66@192.168.20.22 "ls -la /mnt/Fast/docker/<service>/"

# Fix ownership (containers run as UID 1000)
ssh kero66@192.168.20.22 "chown -R 1000:1000 /mnt/Fast/docker/<service>"
```

### ✅ Step 7: Prepare Secrets (if needed)
- [ ] Create Infisical template in `truenas/stacks/infisical-agent/<service>.tmpl`
- [ ] Add secrets to Infisical at path `/media` or appropriate path
- [ ] Update `agent-config.yaml` to reference new template
- [ ] Test template rendering: Check `/mnt/Fast/docker/<service>/.env` after agent restart

### ✅ Step 8: Create TrueNAS Compose File
- [ ] Create `truenas/stacks/<service>/compose.yaml`
- [ ] Use **absolute paths**: `/mnt/Fast/docker/<service>/`
- [ ] Reference env file if using Infisical: `env_file: /mnt/Fast/docker/<service>/.env`
- [ ] Add to external networks if needed: `ix-jellyfin_default`, `ix-arr-stack_default`
- [ ] Set proper health check (use `wget` not `curl` for Alpine images)
- [ ] Document storage layout, secrets, and first-time setup in compose file comments

### ✅ Step 9: Deploy via TrueNAS Web UI
```
1. Open TrueNAS Web UI: https://192.168.20.22
2. Apps → Discover → Custom App
3. Release Name: <service>
4. Version: 1.0.0
5. Paste compose YAML from truenas/stacks/<service>/compose.yaml
6. Click Install
7. Wait for deployment (check Apps → Installed)
```

### ✅ Step 10: Verify Deployment
```bash
# Check container status
ssh kero66@192.168.20.22 "docker ps | grep <service>"

# Check logs
ssh kero66@192.168.20.22 "docker logs <service> --tail 50"

# Test service endpoint
curl http://192.168.20.22:<port>/

# Check health status
ssh kero66@192.168.20.22 "docker inspect <service> | jq -r '.[0].State.Health.Status'"
```

### ✅ Step 11: Update Documentation
- [ ] Mark task as completed in `ai/todo.md`
- [ ] Add working commands to `.github/TROUBLESHOOTING.md`
- [ ] Update `ai/reference.md` if using external documentation
- [ ] Update MEMORY.md if new patterns discovered

## Post-Migration Cleanup

### ✅ Step 12: Stop Workstation Service (Optional)
```bash
# Stop service on workstation
docker stop <service>

# Optionally remove container (config remains in repo)
docker rm <service>
```

### ✅ Step 13: Update Client Configurations
- [ ] Update Homepage to use new IP/service name
- [ ] Update any hard-coded `localhost` references
- [ ] Update Caddy reverse proxy if needed
- [ ] Test from other devices on network

## Common Mistakes to Avoid

### ❌ DON'T:
- Create new configs from scratch without checking existing setup
- Use relative paths in TrueNAS compose files
- Forget to set ownership to 1000:1000
- Skip the backup step
- Use `curl` in health checks (use `wget` instead)
- Edit files directly on TrueNAS without updating repo
- Assume service uses same paths as documentation (check actual container)

### ✅ DO:
- Follow the pattern from previous successful migrations
- Check `docker inspect` output for actual mount points
- Create backups before every migration
- Test health checks work before deploying
- Document any deviations from standard setup
- Update repo compose files to match TrueNAS deployment

## Migration Templates

See existing examples:
- **Simple service**: `truenas/stacks/tailscale/compose.yaml`
- **With database**: `truenas/stacks/jellyfin/compose.yaml`
- **Multi-service stack**: `truenas/stacks/arr-stack/compose.yaml`
- **With Infisical**: `truenas/stacks/infisical-agent/jellyfin.tmpl`

## Rollback Procedure

If migration fails:

```bash
# 1. Stop service on TrueNAS
ssh kero66@192.168.20.22 "docker stop <service>"

# 2. Restore backup on workstation
cd /mnt/library/repos/homelab
tar xzf "$BACKUP_FILE"

# 3. Restart service on workstation
docker compose -f <service>/compose.yaml up -d

# 4. Remove incomplete TrueNAS deployment
# Via TrueNAS Web UI: Apps → <service> → Delete
```

## Getting Help

If stuck, check:
1. `ai/todo.md` - Recent completed migrations
2. `.github/TROUBLESHOOTING.md` - Known issues and solutions
3. `truenas/DEPLOYMENT_GUIDE.md` - Step-by-step deployment instructions
4. TrueNAS logs: Apps → <service> → Logs
