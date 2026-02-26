# Session Notes

This file captures active session context, decisions, and in-progress research to allow resuming work across sessions.

---

## Session 2026-02-26 - Tailscale + Caddy Remote Access (COMPLETED)

### What Was Done

Deployed Tailscale as subnet router on TrueNAS and configured Split DNS so all `.home` services work over Tailscale identically to LAN.

### Changes Made

1. **`truenas/stacks/infisical-agent/tailscale.tmpl`** — Fixed secret key name: `TAILSCALE_AUTHKEY` → `TRUENAS_TAILSCALE_AUTH_KEY` (matches actual Infisical secret)
2. **Tailscale deployed** via `midclt call -j app.create` (not Web UI, not REST API — see PATTERNS.md)
3. **Subnet routes approved** in Tailscale admin console for `192.168.20.0/24`
4. **Split DNS configured** in Tailscale admin → DNS → Custom nameserver: `100.98.14.66` restricted to domain `home`

### Key Facts

| Item | Value |
|------|-------|
| TrueNAS Tailscale IP | `100.98.14.66` |
| Hostname | `truenas` |
| Subnet advertised | `192.168.20.0/24` |
| Split DNS nameserver | `100.98.14.66` (AdGuard Home port 53) |
| Split DNS domain | `home` |
| Auth key secret | `TRUENAS_TAILSCALE_AUTH_KEY` at `/TrueNAS` in Infisical |
| State persisted | `/mnt/Fast/docker/tailscale` |

### How It Works

- Tailscale runs in host network mode (`network_mode: host`) — required for subnet routing
- When on Tailscale, DNS queries for `*.home` are routed to `100.98.14.66:53` (AdGuard) via Split DNS
- AdGuard resolves all `.home` entries to `192.168.20.22`
- Caddy on `192.168.20.22:80` proxies to the correct container
- Result: `http://jellyfin.home` works identically on LAN and over Tailscale

### Critical Discovery: midclt for App Creation

- **REST API** (`POST /api/v2.0/app`) cannot create Custom Apps — schema validation always fails
- **Web UI** is NOT required — use `midclt call -j app.create` via SSH instead
- See PATTERNS.md → "Create a new Custom App" for the exact command pattern

---

## Session 2026-02-18 - Jellyfin Playback Fix + VAAPI Hardware Transcoding (COMPLETED)

### What Was Done

**Problem**: Terminator (28GB Remux-1080p AVC DTS-HD MA 5.1) got stuck when playing in Jellyfin web client.

**Root Cause**: DTS-HD MA 5.1 is not supported by web browsers. Jellyfin was running in DirectStream mode (video passthrough, audio remux) but had no hardware transcoding configured. Without transcoding, the audio codec was incompatible with the client → stream stalled.

**Secondary issue**: Jellystat was permanently `unhealthy` due to a broken healthcheck (`curl` not installed in its container image).

---

### Diagnosis Steps

```bash
# SSH to TrueNAS using kero66 key from Infisical (secure pattern)
TMPDIR_SAFE=$(mktemp -d) && chmod 700 "$TMPDIR_SAFE" && TMPKEY="$TMPDIR_SAFE/k"
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS --plain 2>/dev/null > "$TMPKEY" && chmod 600 "$TMPKEY"
ssh -i "$TMPKEY" -o StrictHostKeyChecking=no kero66@192.168.20.22 "sudo docker logs jellyfin --tail 100 2>&1"
rm -rf "$TMPDIR_SAFE"

# Check DRI devices available on host and in container
ssh ... "ls /dev/dri/ && sudo docker exec jellyfin ls /dev/dri/"
# Result: card0 (GID 44/video), renderD128 (GID 107/render) present in both

# Check GPU vendor
ssh ... "sudo cat /sys/class/drm/card0/device/vendor"  # 0x8086 = Intel
ssh ... "sudo cat /sys/class/drm/card0/device/device"  # 0x46d4 = Alder Lake-N (N150)

# Check VA drivers in container
ssh ... "sudo docker exec jellyfin ls /usr/lib/x86_64-linux-gnu/dri/"
# Result: only nouveau/radeon — no Intel drivers on system path

# Find Intel iHD driver in jellyfin-ffmpeg bundle
ssh ... "sudo docker exec jellyfin find / -name '*iHD*' 2>/dev/null"
# Result: /usr/lib/jellyfin-ffmpeg/lib/dri/iHD_drv_video.so  ← key finding

# Verify Intel VAAPI works with correct driver path
ssh ... "sudo docker exec -e LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri -e LIBVA_DRIVER_NAME=iHD jellyfin /usr/lib/jellyfin-ffmpeg/vainfo"
# Result: Intel iHD driver 25.4.4, H264/HEVC/VP9 decode+encode — CONFIRMED WORKING

# Check render group GID
ssh ... "stat -c '%G %g' /dev/dri/renderD128"  # render 107
ssh ... "getent group render video"              # render:x:107: video:x:44:
```

---

### TrueNAS API - Verified Endpoints

```bash
TRUENAS_API_KEY=$(infisical secrets get truenas_admin_api --env dev --path /TrueNAS --plain 2>/dev/null)
BASE="https://192.168.20.22/api/v2.0"

# List all Custom Apps
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/app"

# Get app details
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/app/id/jellyfin"

# Get current app compose config (returns structured dict)
curl -sk -X POST -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
  -H "Content-Type: application/json" -d '"jellyfin"' \
  "${BASE}/app/config"

# Update app compose config (returns job ID)
curl -sk -X PUT -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"custom_compose_config": <compose_dict>}' \
  "${BASE}/app/id/jellyfin"
# NOTE: endpoint is /id/{id}, NOT /app/{id}

# Check job status
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/core/get_jobs?id=<JOB_ID>"

# User management
curl -sk -H "Authorization: Bearer ${TRUENAS_API_KEY}" "${BASE}/user?username=kero66"  # GET user (returns array)
curl -sk -X PUT -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
  -H "Content-Type: application/json" -d '{"sshpubkey": "..."}' \
  "${BASE}/user/id/72"  # NOTE: /id/ in path, kero66 ID = 72
```

**API Notes**:
- HTTP → HTTPS redirect (308) drops Authorization header → always use HTTPS
- `PUT /api/v2.0/user/{id}` returns 404 — must use `PUT /api/v2.0/user/id/{id}`
- App updates are async jobs; poll `/core/get_jobs?id=<JOB_ID>` for status

---

### Jellyfin API - Verified Endpoints

```bash
JF_API_KEY=$(infisical secrets get JELLYFIN_API_KEY --env dev --path / --plain 2>/dev/null)
# NOTE: Jellyfin key is at root path /, not /TrueNAS

# Get encoding config
curl -sf -H "X-Emby-Token: ${JF_API_KEY}" "http://192.168.20.22:8096/System/Configuration/encoding"

# Set encoding config (HTTP 204 on success)
curl -sf -X POST -H "X-Emby-Token: ${JF_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '<encoding_json>' \
  "http://192.168.20.22:8096/System/Configuration/encoding"
```

---

### Changes Made

#### 1. `truenas/stacks/jellyfin/compose.yaml`

**Jellyfin service**:
- Added `LIBVA_DRIVERS_PATH=/usr/lib/jellyfin-ffmpeg/lib/dri` (points libva to jellyfin-ffmpeg's bundled iHD driver)
- Added `LIBVA_DRIVER_NAME=iHD` (selects Intel iHD over default i965)
- Added `group_add: ["107", "44"]` (render + video group GIDs for `/dev/dri` access after privilege drop)
- Increased `mem_limit: 2g → 4g` (transcoding headroom)

**Jellystat healthcheck**:
- Changed from `curl` (not installed) → `wget 127.0.0.1:3000/` (using 127.0.0.1 avoids IPv6 ::1 connection attempt)

#### 2. Jellyfin encoding config (applied via API)

```json
{
  "HardwareAccelerationType": "vaapi",
  "VaapiDevice": "/dev/dri/renderD128",
  "EnableHardwareEncoding": true,
  "EnableDecodingColorDepth10Hevc": true,
  "EnableDecodingColorDepth10Vp9": true,
  "EnableTonemapping": true,
  "HardwareDecodingCodecs": ["h264", "hevc", "vp8", "vp9", "av1"]
}
```

---

### Infisical Secret Locations (dev env)

| Secret | Path | Notes |
|--------|------|-------|
| `kero66_ssh_key` | `/TrueNAS` | Private key for SSH to TrueNAS as kero66 |
| `truenas_admin_api` | `/TrueNAS` | TrueNAS REST API key |
| `JELLYFIN_API_KEY` | `/` (root) | Jellyfin API key |
| `JELLYFIN_USERNAME` | `/` (root) | `kero66` |
| `JELLYSTAT_API_KEY` | `/` (root) | Jellystat API key |

---

### Security Incident (Self-Inflicted)

**Incident**: During session, attempted to test TrueNAS API PUT with `{"sshpubkey": "test"}` which succeeded and overwrote kero66's authorized SSH key.

**Resolution**: Restored immediately by:
1. Retrieving private key from Infisical
2. Deriving public key with `ssh-keygen -y -f <key_file>`
3. Restoring via `PUT /api/v2.0/user/id/72` with correct public key

**Lesson**: Never test write endpoints with dummy data on production users. Always use dry-run or read-only operations first.

---

### Intel N150 VAAPI Summary

| Item | Value |
|------|-------|
| GPU vendor/device | 0x8086 / 0x46d4 (Intel Alder Lake-N) |
| Driver | iHD 25.4.4 (bundled in jellyfin-ffmpeg) |
| Driver path in container | `/usr/lib/jellyfin-ffmpeg/lib/dri/iHD_drv_video.so` |
| Render device | `/dev/dri/renderD128` |
| render group GID | 107 |
| video group GID | 44 |
| Supported decode | H264, HEVC, VP8, VP9, AV1 |
| Supported encode | H264, HEVC |

---

## Active Session: 2026-02-14 - Homepage Deployment via Dockhand

### 🚀 HANDOFF TO NEXT AGENT
**Current Blocker**: Homepage deployment requires Infisical Agent .env file
- Homepage compose references: `/mnt/Fast/docker/homepage/.env`
- Infisical Agent should generate this via template: `truenas/stacks/infisical-agent/homepage.tmpl`
- **Action needed**: Verify Infisical Agent is running and generating .env files

**What's Ready**:
- ✅ Homepage labels added to all services (committed to git)
- ✅ Dockhand authentication working (credentials in Infisical)
- ✅ SSH deploy keys configured in Dockhand UI
- ✅ Git repository configured in Dockhand UI (user confirmed)
- ✅ Infisical Agent config files exist in repo (agent-config.yaml, homepage.tmpl)
- ✅ SSH keys exist on workstation (~/.ssh/id_ed25519)

**What's Blocked**:
- ❌ SSH access from workstation to TrueNAS (publickey auth not configured)
- ❌ Homepage deployment (missing .env file from Infisical Agent)
- ❌ Dockhand API documentation (not publicly available, difficult to use programmatically)

**What's Pending**:
- ⏸️ Set up SSH key on TrueNAS for workstation access
- ⏸️ Verify Infisical Agent is deployed and running
- ⏸️ Verify /mnt/Fast/docker/homepage/ directory exists
- ⏸️ Verify .env file is being generated by agent
- ⏸️ Deploy Homepage stack via Dockhand
- ⏸️ Test GitOps auto-deployment workflow
- ⏸️ Original task: Tailscale migration (deferred)

**Quick Start for Next Agent**:
1. Set up SSH access: Copy workstation public key to TrueNAS authorized_keys
2. Verify Infisical Agent: `docker ps | grep infisical`
3. Check .env generation: `ls -la /mnt/Fast/docker/homepage/.env`
4. Deploy Homepage via Dockhand UI (API not practical)

### Context
**Current Task**: Deploy Homepage stack via Dockhand GitOps workflow
- User attempted to deploy Homepage via Dockhand UI
- Deployment blocked: missing `/mnt/Fast/docker/homepage/.env` file
- Root cause: Infisical Agent may not be running or not generating .env files
- Secondary issue: SSH access from workstation to TrueNAS not configured

**Previous Context**:
- Shifted from Tailscale migration to Dockhand GitOps implementation
- Dockhand already deployed at http://192.168.20.22:30328/
- Homepage migrated but missing auto-discovery labels (fixed)

### Key Problem: Tailscale without host network mode
**Issue**: Tailscale traditionally requires `network_mode: host` to function properly, but this:
- Breaks container isolation
- Prevents using Docker networks for service discovery
- Goes against Docker best practices

**Research/Attempts**:
1. Current implementation uses `network_mode: host` (line 30 in compose.yaml)
2. This breaks container isolation and Docker networking
3. Need alternative approach

**Current Status**:
- Investigating Tailscale userspace networking mode
- Exploring whether subnet routing works in bridge mode
- Goal: Allow Tailscale container to route traffic TO other containers without host mode

**Possible Solutions**: (See `truenas/TAILSCALE_HOST_MODE_ALTERNATIVES.md` for full details)
A) **Userspace networking** (`TS_USERSPACE=true`) - ⭐ RECOMMENDED FIRST
B) **Tailscale Serve/Funnel** - Share specific ports, not entire subnet
C) **macvlan** - Give container its own IP on LAN (e.g., 192.168.20.200)
D) **Keep host mode** - Accept the trade-off if alternatives don't work

**Testing Strategy:**
1. Try userspace mode first (simplest, most secure)
2. If subnet routing fails, try macvlan
3. Last resort: accept host mode with documented trade-offs

**Documentation Created:**
- `truenas/TAILSCALE_HOST_MODE_ALTERNATIVES.md` - Full research and implementation guides
- `ai/SESSION_NOTES.md` - This file (session continuity)
- `ai/DOCUMENTATION_STRUCTURE.md` - Documentation hierarchy and AI workflow guidelines

### Claude Code Interface Investigation (RESOLVED)
**Discovery**: User was running Claude Code CLI in VSCode terminal, assuming it had VSCode integration
**Reality**:
- CLI = Standalone tool, no VSCode integration, no access to VSCode MCP servers
- Extension (chat panel) = Integrated with VSCode, may have MCP access
**VSCode MCP Servers Found**:
- Context7 (mcp.config.usrlocal.context7)
- Upstash Context7 (upstash.context7-mcp)
- Pylance (ms-python.vscode-pylance)
- GitHub Copilot MCP
**Decision**: User switching to VSCode chat panel to test MCP integration
**Status**: User testing chat panel (item #72 in todo.md)

### Caddy HTTPS Issue (RESOLVED)
**Problem**: Port 443 was removed from Caddy compose.yaml, causing HTTPS warnings
**Root cause**: Unknown - may have been accidental removal during conflict resolution
**Solution**: Restored ports 443/tcp and 443/udp to Caddy compose.yaml
**Fixed**: 2026-02-14

### AdGuard Home Port Conflict (RESOLVED)
**Change**: DoH port changed from 443 → 4443 to avoid conflict with Caddy
**Reason**: Caddy needs 443 for automatic HTTPS certificate management
**Fixed**: 2026-02-14

### DNS Resolution Issue - systemd-resolved (RESOLVED)
**Problem**: Linux clients couldn't resolve `.home` domains (e.g., `jellyfin.home`)
**Root Cause**: systemd-resolved was preferring Cloudflare DNS (1.1.1.1) over AdGuard Home (192.168.20.22) when both were configured via DHCP
- DHCP sent both DNS servers: Primary=192.168.20.22, Secondary=1.1.1.1
- systemd-resolved treated them as alternatives, not primary/fallback
- Chose Cloudflare for queries, which doesn't know about `.home` domains
**Solution**: Removed secondary DNS (1.1.1.1) from router DHCP configuration
- Router now only sends 192.168.20.22 (AdGuard Home) via DHCP
- AdGuard Home uses 1.1.1.1 as upstream, maintaining internet DNS fallback
**Trade-off Accepted**: Single point of failure - if AdGuard goes down, DNS fails network-wide
**Alternative**: Deploy second AdGuard Home instance on workstation (192.168.20.66) for HA
**Fixed**: 2026-02-14

### Documentation Cleanup (COMPLETED)
**Issue**: Documentation was using `root@192.168.20.22` instead of `kero66@192.168.20.22`
**Action**: Audited and updated 81 instances across all truenas/ documentation
**Principle**: kero66 (UID 1000) is standard user for all daily operations
- truenas_admin is break-glass account only
- API-first approach for infrastructure
- Infisical for infrastructure secrets, Bitwarden for personal passwords
**Updated**: MEMORY.md, ARR_DEPLOYMENT.md, FRONTEND_STACK_DEPLOYMENT.md, and 8 other docs
**Completed**: 2026-02-14

### Homepage Auto-Discovery Labels (COMPLETED)
**Problem**: Homepage dashboard not auto-discovering migrated services
**Root Cause**: Docker labels missing from compose files after migration
**Solution**: Added homepage.* labels to 9 services across 3 stacks:
- arr-stack: Sonarr, Radarr, Prowlarr, Bazarr
- downloaders: qBittorrent, SABnzbd
- jellyfin: Jellyfin, Jellyseerr, Jellystat
**Labels Added**: homepage.group, homepage.name, homepage.icon, homepage.href, homepage.description, homepage.widget.*
**Status**: Committed to git, ready for deployment testing
**Completed**: 2026-02-14

### Agent-Agnostic Documentation Structure (COMPLETED)
**Issue**: AI documentation was in global Claude directory, not in repo
**Problem**: Not version controlled, not accessible to other AI agents (Copilot, etc.)
**Solution**: Created `.claude/INSTRUCTIONS.md` in repository
- Contains all quick reference, patterns, gotchas, and architecture decisions
- Version controlled and agent-agnostic
- Replaces reliance on global `~/.claude/memory/MEMORY.md`
**Files Created**:
- `.claude/INSTRUCTIONS.md` - Main AI agent instructions (in repo, version controlled)
**Completed**: 2026-02-14

### Dockhand GitOps Setup (IN PROGRESS - UPDATED 2026-02-14)
**Goal**: Configure Dockhand for GitOps management of Homepage stack

**Completed This Session**:
- ✅ SSH deploy keys generated and stored in Infisical
  - Private key: `/TrueNAS/DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE`
  - Public key: `/TrueNAS/DOCKHAND_GITHUB_DEPLOY_KEY_PUBLIC`
  - Keys removed from local system after storing in Infisical
  - Public key added to GitHub (read-only access)
  - Private key configured in Dockhand UI
- ✅ **Architecture Decision**: Simplified approach - NO `deployments/` directory
  - Dockhand points directly at `truenas/stacks/<stack>/compose.yaml`
  - No symlinks needed (avoids cross-platform issues, reduces complexity)
  - Single source of truth for compose files
  - Existing `truenas/stacks/` structure used as-is
- ✅ DOCKHAND_GITOPS_GUIDE.md completely rewritten
  - Removed symlink/deployments approach
  - Updated all examples to use Homepage
  - Documented simpler configuration
  - Added Quick Reference section

**Key Decision - Direct Path Structure (2026-02-14)**:
```
REJECTED APPROACH (overly complex):
homelab/
├── deployments/truenas/homepage/
│   └── docker-compose.yaml → ../../../truenas/stacks/homepage/compose.yaml (symlink)
└── truenas/stacks/homepage/compose.yaml

APPROVED APPROACH (simple & clean):
homelab/
└── truenas/stacks/homepage/compose.yaml  ← Dockhand points here directly
```

**Rationale for Simpler Approach**:
1. Dockhand accepts any git path - no mandatory structure
2. Symlinks add complexity without benefit
3. Windows compatibility issues with git symlinks
4. Single source of truth is easier to maintain
5. No duplicate directory structure to manage

**Authentication Patterns Established**:
```bash
# Dockhand credentials
DOCKHAND_USER=$(infisical secrets get DOCKHAND_USER --env dev --path /TrueNAS --plain 2>/dev/null)
DOCKHAND_PASSWORD=$(infisical secrets get DOCKHAND_USER_PASSWORD --env dev --path /TrueNAS --plain 2>/dev/null)

# Deploy key retrieval
infisical secrets get DOCKHAND_GITHUB_DEPLOY_KEY_PRIVATE --env dev --path /TrueNAS --plain
```

**Still Pending**:
- Configure git repository in Dockhand UI (Settings → Git Integration)
- Create Homepage stack pointing to `truenas/stacks/homepage`
- Test GitOps auto-deployment workflow with test commit
- Verify Infisical Agent .env files work with GitOps deployments

**Status**: Ready for UI configuration - all prerequisites complete

---

## Instructions for AI
1. **Start each session** by reading this file first
2. **Update this file** with key decisions, research findings, and blockers
3. **When blocked**, document the blocker here before ending session
4. **Link related items** to todo.md for tracking
5. **Clear completed sections** after items are fully resolved and documented elsewhere

---

### Session 2026-02-14 Afternoon - Homepage Deployment Attempt

**Goal**: Deploy Homepage via Dockhand GitOps

**Discovery - TrueNAS Version**:
- System running: **TrueNAS Scale 25.10.1** (found in truenas/HARDWARE_CONFIG.md)
- AI agent was discussing old versions (24.04 Dragonfish, 24.10 Electric Eel)
- **Lesson**: Always verify current software versions before providing advice
- **Action**: Added TrueNAS version to MEMORY.md

**Deployment Blocker**:
- Homepage deployment requires `.env` file at `/mnt/Fast/docker/homepage/.env`
- File should be auto-generated by Infisical Agent from `homepage.tmpl`
- Unknown if Infisical Agent is deployed/running on TrueNAS
- Cannot verify without SSH access to TrueNAS

**Technical Challenges**:
1. **SSH Access**: Workstation has SSH keys but not authorized on TrueNAS
2. **Dockhand API**: No public documentation, difficult to use programmatically
   - Attempted to create stack via API: `/api/stacks` endpoint exists but unclear parameters
   - API returned "Compose file content is required" - may not support git-based creation via API
   - Conclusion: Use Dockhand UI for stack management, API not practical
3. **Remote Troubleshooting**: Cannot diagnose Infisical Agent status without TrueNAS access

**Next Steps**:
1. Configure SSH access from workstation to TrueNAS
2. Verify Infisical Agent deployment status
3. Ensure .env files are being generated
4. Deploy Homepage via Dockhand UI

---

## Lessons Learned (AI Performance Issues)

### Session 2026-02-14 - Critical Failures
**Issue**: AI agent repeatedly failed to follow established patterns and documentation
**Examples**:
1. **Infisical CLI usage**: Tried multiple wrong approaches (wrong environment, wrong path, export commands) despite established pattern existing in codebase: `infisical secrets get <NAME> --env dev --path /TrueNAS --plain`
2. **jq failures**: Repeatedly piped HTML responses to jq without checking response type first, causing parse errors
3. **Research vs guessing**: Guessed at solutions instead of searching existing code for patterns (e.g., Grep for "infisical secrets get")
4. **Documentation location**: Updated global `~/.claude/memory/` instead of repo's `.claude/` folder, missing agent-agnostic requirement

**Root Cause**: Not following DOCUMENTATION_STRUCTURE.md workflow:
- Should have searched codebase for existing patterns FIRST
- Should have verified response types before piping to tools
- Should have read established documentation before attempting new approaches

**Corrective Actions**:
- Created `.claude/INSTRUCTIONS.md` with "Research first, guess never" principle
- Added "Always verify response type before piping to jq" to Common Gotchas
- Documented Infisical CLI pattern explicitly in Critical Patterns section

**For Future AI Agents**:
- READ `.claude/INSTRUCTIONS.md` at session start
- SEARCH codebase with Grep/Glob before attempting new patterns
- VERIFY tool inputs/outputs before chaining commands
- DOCUMENT failures in SESSION_NOTES.md for future learning

---

## Previous Sessions Archive

### Session 2026-02-12: Arr Stack Migration Complete
- Successfully deployed arr-stack, downloaders, and Jellyfin to TrueNAS
- Fixed Prowlarr URL issues, recycle bin permissions
- Documented fixes in TROUBLESHOOTING.md
- See todo.md items 48-58 for details

