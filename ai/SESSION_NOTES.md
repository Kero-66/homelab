# Session Notes

This file captures active session context, decisions, and in-progress research to allow resuming work across sessions.

## Active Session: 2026-02-14 - Tailscale & Frontend Stack Migration

### Context
Working on migrating remaining services to TrueNAS, specifically:
- Tailscale (for external access)
- Caddy (reverse proxy)
- AdGuard Home (DNS)

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

---

## Instructions for AI
1. **Start each session** by reading this file first
2. **Update this file** with key decisions, research findings, and blockers
3. **When blocked**, document the blocker here before ending session
4. **Link related items** to todo.md for tracking
5. **Clear completed sections** after items are fully resolved and documented elsewhere

---

## Previous Sessions Archive

### Session 2026-02-12: Arr Stack Migration Complete
- Successfully deployed arr-stack, downloaders, and Jellyfin to TrueNAS
- Fixed Prowlarr URL issues, recycle bin permissions
- Documented fixes in TROUBLESHOOTING.md
- See todo.md items 48-58 for details

