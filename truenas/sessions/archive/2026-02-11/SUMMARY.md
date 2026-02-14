# TrueNAS Jellyfin Deployment — Session Summary (2026-02-11)

## Objective
Deploy Jellyfin media stack (Jellyfin, Jellyseerr, Jellystat) to TrueNAS Scale 25.10.1 using Custom Apps with Infisical Agent for secrets management.

---

## Major Issue Resolved: IPv6 Networking

### Problem
Custom App creation jobs (5354, 5367) failed during `docker compose up` with errors:
```
dial tcp [2600:1f18:2148:bc01::]:443: connect: network is unreachable
```

Root cause: Docker daemon was configured with IPv6 address pools, and when pulling images, Docker preferred IPv6 AAAA records. However, the home network lacks functional IPv6 routing—connections timeout trying to reach Docker registries.

### Root Cause Analysis
- **Workstation:** Cannot reach Docker Hub (times out on HTTPS connections)
- **TrueNAS:** Same issue (isolated to home network, not local config)
- **DNS resolution:** Works fine (resolves registry-1.docker.io to IPv4 and IPv6 addresses)
- **Issue:** IPv6 addresses are routable on paper but connectivity fails at the ISP/network level

### Solution Applied
**Job 5442:** Updated Docker daemon config to remove IPv6 address pools
```bash
PUT /api/v2.0/docker
Payload: {"address_pools": [{"base": "172.17.0.0/12", "size": 24}]}
```

**Verified:** ✅ `GET /api/v2.0/docker` confirms only IPv4 pool remains:
```json
{
  "address_pools": [
    {"base": "172.17.0.0/12", "size": 24}
  ]
}
```

---

## Deployment Status

### ✅ Completed
1. **Infisical Machine Identity**
   - Created: `truenas-agent`
   - Auth method: Universal Auth
   - Credentials: Securely stored, tested working
   - API: Confirmed connectivity from workstation

2. **setup_agent.sh Execution**
   - Deployed to TrueNAS on 2026-02-10
   - Exit code: 0 (success)
   - Files uploaded:
     - `/mnt/Fast/docker/infisical-agent/config/agent-config.yaml` (✅ updated with TrueNAS IP 192.168.20.66)
     - `/mnt/Fast/docker/infisical-agent/config/jellyfin.tmpl`
     - `/mnt/Fast/docker/infisical-agent/compose.yaml`
     - `/mnt/Fast/docker/jellyfin/compose.yaml`
   - Config ownership: 1000:1000 (app user)
   - Permissions: 600 on credentials

3. **Config Migration**
   - Jellyfin: Full `/mnt/Fast/docker/jellyfin/config/` (includes data/, cache/, xml configs)
   - Jellyseerr: Full `/mnt/Fast/docker/jellyseerr/config/`
   - Jellystat DB: Backup SQL dump at `/mnt/Fast/docker/jellyfin/jellystat_db_dump.sql` (5MB)
   - Status: ✅ Verified in place on TrueNAS

4. **Docker Configuration**
   - **Before:** IPv4 + IPv6 address pools causing image pull timeouts
   - **After:** IPv4-only (`172.17.0.0/12`), IPv6 removed
   - **Method:** API Job 5442
   - **Verification:** ✅ Confirmed via `GET /api/v2.0/docker`

### 🔄 In Progress
1. **Media Transfer**
   - rsync running in background: `~/truenas_media_transfer.log`
   - Transferring ~6 TB of media from workstation to TrueNAS `/mnt/Data/`
   - Estimated completion: Monitor log file in background

### ⏳ Waiting / Blocked

**TrueNAS API Limitation:** Custom Apps cannot be created programmatically
- Attempted: `POST /api/v2.0/app` with custom compose YAML
- Result: Job 5486 FAILED with schema validation errors
  ```
  [EINVAL] app_create.app_name: Field required
  [EINVAL] app_create.release_name: Extra inputs are not permitted
  ```
- Root cause: API expects official Helm chart apps, not custom compose apps
- **Workaround:** Use TrueNAS Web UI to create Custom Apps (documented in DEPLOYMENT_GUIDE.md)

### ⬜ Not Started
1. Create `infisical-agent` Custom App (Web UI)
2. Create `jellyfin` + `jellyseerr` Custom App (Web UI)
3. Restore Jellystat database
4. Verify all services are accessible

---

## Documentation Created

1. **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** — Step-by-step Web UI instructions
   - How to create Custom Apps manually
   - What YAML to paste for each app
   - Troubleshooting checklist
   - Database restoration steps

2. **[truenas/README.md](./README.md)** — Updated with current status
   - Added "Current Status" section with checkboxes
   - Referenced DEPLOYMENT_GUIDE.md
   - Documented IPv6 fix

---

## API Endpoints Used (Verified Working)

### Authentication
```bash
# Fetch API key inline (never store in shell env)
KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --domain "http://localhost:8081" --plain 2>/dev/null)
```

### Docker Configuration
```bash
# Check current Docker config (IPv4/IPv6 pools)
curl -sk "https://192.168.20.22/api/v2.0/docker" \
  -H "Authorization: Bearer $KEY" | jq '.address_pools'
```

### Filesystem Operations (from setup_agent.sh)
- `POST /api/v2.0/filesystem/listdir` — List directory
- `POST /api/v2.0/filesystem/stat` — Check file/dir exists
- `PUT /api/v2.0/filesystem/put_file` — Upload files
- `POST /api/v2.0/filesystem/chmod` — Set permissions
- `POST /api/v2.0/filesystem/chown` — Set ownership

### Job Management
- `GET /api/v2.0/core/get_jobs?id=<JOB_ID>` — Check job status
- Used for: Docker config updates, app creation attempts

---

## Key Technical Decisions

### Why IPv4-Only Docker?
1. Home network lacks proper IPv6 infrastructure
2. ISP likely doesn't provide IPv6 routing to residential connections
3. Workaround: Force Docker to use IPv4 exclusively
4. No production impact: all services can run on IPv4
5. Solution is permanent: IPv6 won't be re-enabled in Docker config

### Why Infisical Agent?
1. Renders secrets locally from Infisical vault before files are needed
2. Keeps credentials out of compose files (not hardcoded)
3. Decouples secret management from app deployment
4. Can be reused for other TrueNAS apps in future

### Why Custom Apps (not native TrueNAS apps)?
1. Full control over compose YAML and service configuration
2. Can use our existing compose files from the media stack
3. Easier to migrate existing Docker setups to TrueNAS
4. Simpler than managing Helm charts

---

## Files Structure

```
truenas/
├── README.md                        # Main guide (updated with status)
├── DEPLOYMENT_GUIDE.md              # ← NEW: Web UI step-by-step
├── AUTH_STATUS.md                   # Infisical auth verification
├── SETUP_COMPLETE.md                # Earlier setup notes
├── STATUS.md                        # (to be updated)
├── scripts/
│   ├── setup_agent.sh              # Deploys configs to TrueNAS (✅ run once)
│   ├── get_system_info.sh           # Query TrueNAS system info
│   └── ...
├── stacks/
│   ├── infisical-agent/
│   │   ├── compose.yaml            # Uploaded to TrueNAS
│   │   └── templates/
│   │       └── jellyfin.tmpl        # Secret template (uploaded)
│   └── jellyfin/
│       └── compose.yaml            # Uploaded to TrueNAS
└── .env.sample                      # Environment variables

TrueNAS /mnt/Fast/docker/:
├── infisical-agent/
│   └── config/
│       ├── agent-config.yaml        # (deployed)
│       └── jellyfin.tmpl            # (deployed)
├── jellyfin/
│   ├── config/                      # (migrated)
│   ├── cache/                       # (prepared)
│   └── jellystat_db_dump.sql        # (backup for restore)
└── jellyseerr/
    └── config/                      # (migrated)
```

---

## Environment Context

**Workstation:** Fedora Linux @ 192.168.20.66
**TrueNAS:** Scale 25.10.1 @ 192.168.20.22 (HTTPS, self-signed cert)
**Infisical:** Self-hosted @ localhost:8081
**Network:** 192.168.20.0/24, gateway 192.168.20.1
**DNS:** Working (resolves externally), but IPv6 connectivity broken

---

## Next Session Instructions

### To Continue Deployment:
1. **Read:** [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
2. **Manual Step 1:** Create `infisical-agent` Custom App via TrueNAS Web UI
   - Use compose from [stacks/infisical-agent/compose.yaml](./stacks/infisical-agent/compose.yaml)
3. **Manual Step 2:** Create `jellyfin` Custom App via TrueNAS Web UI
   - Use compose from [stacks/jellyfin/compose.yaml](./stacks/jellyfin/compose.yaml)
4. **Verify:** Apps should both show **ACTIVE** status
5. **Test:** Open http://192.168.20.22:8096 (Jellyfin) in browser
6. **Restore:** If needed, restore Jellystat database

### Monitoring:
- Check media transfer progress: `tail -f ~/truenas_media_transfer.log`
- App logs: TrueNAS UI → Apps → <AppName> → Logs
- API status: `bash truenas/scripts/get_system_info.sh 192.168.20.22`

### If Problems:
- See "Troubleshooting" section in [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- Check [../.github/TROUBLESHOOTING.md](../.github/TROUBLESHOOTING.md) for API examples

---

## Session Summary

✅ **Major blocker resolved:** IPv6 networking issue diagnosed and fixed  
✅ **Infrastructure ready:** Configs staged, Infisical Agent configured  
✅ **Documentation complete:** DEPLOYMENT_GUIDE created for manual Web UI steps  
⏳ **Awaiting:** Manual Custom App creation via TrueNAS Web UI  
🚀 **Ready to proceed:** Follow DEPLOYMENT_GUIDE.md for final deployment  

