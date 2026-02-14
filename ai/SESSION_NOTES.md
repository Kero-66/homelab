# Session Notes

This file captures active session context, decisions, and in-progress research to allow resuming work across sessions.

## Active Session: 2026-02-14 - Dockhand GitOps Setup

### 🚀 HANDOFF TO NEXT AGENT
**What's Ready**:
- ✅ Homepage labels added to all services (committed to git)
- ✅ Dockhand authentication working (see code snippet below)
- ✅ `.claude/INSTRUCTIONS.md` created (agent-agnostic documentation)
- ✅ DNS resolution fixed (AdGuard Home only)
- ✅ Documentation cleaned up (kero66 vs root)

**What's Pending**:
- ⏸️ Dockhand GitOps configuration (likely via web UI at http://192.168.20.22:30328/)
- ⏸️ Homepage stack deployment testing
- ⏸️ Original task: Tailscale migration (deferred for Dockhand focus)

**Quick Start for Next Agent**:
1. Read `.claude/INSTRUCTIONS.md` for patterns and gotchas
2. Access Dockhand: http://192.168.20.22:30328/ (credentials in Infisical)
3. Configure GitOps for Homepage stack following `truenas/DOCKHAND_GITOPS_GUIDE.md`

### Context
**Pivot**: Shifted from Tailscale migration to Dockhand GitOps implementation for managing TrueNAS containers.
- Dockhand already deployed at http://192.168.20.22:30328/
- Goal: Set up GitOps workflow with Homepage stack as test case
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

### Dockhand GitOps Setup (PARTIALLY COMPLETE)
**Goal**: Configure Dockhand for GitOps management of Homepage stack
**Progress**:
- Created DOCKHAND_GITOPS_GUIDE.md with complete setup procedures
- Accessed Dockhand API at http://192.168.20.22:30328/
- Found API endpoints: /api/health (working), /api/stacks (empty)
- Successfully authenticated to Dockhand API using cookie-based auth
- Infisical pattern: `infisical secrets get <NAME> --env dev --path /TrueNAS --plain`
- Dockhand credentials: DOCKHAND_USER and DOCKHAND_USER_PASSWORD in Infisical /TrueNAS path
**Authentication Working**:
```bash
DOCKHAND_USER=$(infisical secrets get DOCKHAND_USER --env dev --path /TrueNAS --plain 2>/dev/null)
DOCKHAND_PASSWORD=$(infisical secrets get DOCKHAND_USER_PASSWORD --env dev --path /TrueNAS --plain 2>/dev/null)
curl -X POST http://192.168.20.22:30328/api/auth/login -H "Content-Type: application/json" \
  -d "{\"username\":\"$DOCKHAND_USER\",\"password\":\"$DOCKHAND_PASSWORD\"}"
# Returns session cookie: dockhand_session=<token>
```
**Still Pending**:
- Configure GitOps settings in Dockhand (likely via web UI, not pure API)
- Set up git repository connection for Homepage stack
- Test GitOps auto-deployment workflow
**AI Performance Issues**: Multiple failures with jq (piping HTML to jq), not following established patterns, guessing instead of researching existing code
**Status**: Auth working, GitOps configuration pending - 2026-02-14

---

## Instructions for AI
1. **Start each session** by reading this file first
2. **Update this file** with key decisions, research findings, and blockers
3. **When blocked**, document the blocker here before ending session
4. **Link related items** to todo.md for tracking
5. **Clear completed sections** after items are fully resolved and documented elsewhere

---

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

