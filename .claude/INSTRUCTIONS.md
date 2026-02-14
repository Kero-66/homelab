# AI Agent Instructions for Homelab Project

**IMPORTANT:** Read this file at the start of every session for quick reference.

## Start Every Session Here
1. **Read:** `ai/SESSION_NOTES.md` - Current work in progress
2. **Read:** `ai/todo.md` - Pending tasks
3. **Read:** This file - Quick facts and patterns

## Quick Reference
- **TrueNAS**: 192.168.20.22 (SSH as kero66) - **Version 25.10.1**
- **Workstation**: 192.168.20.66 (Fedora, cold spare) - SSH keys at `~/.ssh/id_ed25519*`
- **Pools**: `/mnt/Fast` (NVMe), `/mnt/Data` (HDD)
- **Configs**: `/mnt/Fast/docker/<service>/`
- **Media**: `/mnt/Data/media/{shows,movies,anime,music,tv,downloads}`
- **Downloads**: `/mnt/Data/downloads/{qbittorrent,sabnzbd,complete,incomplete}`
- **Dockhand**: http://192.168.20.22:30328/ (credentials in Infisical, API not well documented - use UI)

## Key Architecture Decisions
- **Security**: API-first approach, Infisical for infrastructure secrets, Bitwarden for personal passwords
- **Secrets management**: Infisical Agent renders `.env` → `/mnt/Fast/docker/{arr-stack,downloaders,jellyfin}/`
- **User access**: kero66 (UID 1000) for all daily ops, truenas_admin is break-glass only
- **TrueNAS deployment**: Web UI Custom Apps, NOT docker-compose CLI
- **Compose files in repo**: Reference/documentation only (except for updates)
- **Networking**: Cross-stack via explicit network joins (downloaders→arr-stack, jellyseerr→both)
- **DNS**: Router DHCP sends only 192.168.20.22 (AdGuard Home), no fallback (single point of failure accepted)

## Common Gotchas
- **ALWAYS check response type before piping to jq** - API endpoints may return HTML, not JSON
- **TrueNAS version**: 25.10.1 - don't discuss old versions (24.04/24.10) unless relevant
- Use `jq` not `python3 -m json.tool`
- SSH piped commands fail on TrueNAS → use separate steps
- Sonarr/Radarr cache health checks → trigger `CheckHealth` command via API
- qBittorrent doesn't create dirs at startup, only on first download
- `ix-*` networks are TrueNAS built-in, separate from compose networks
- **TrueNAS access**: Use kero66 user, NOT root. truenas_admin is break-glass only (can elevate to root if needed)
- **Infisical CLI pattern**: `infisical secrets get <NAME> --env dev --path /TrueNAS --plain 2>/dev/null`
- **Infisical environments**: Production secrets in `--env prod`, NOT default `dev`

## Critical Patterns
- **ALWAYS check existing setup** before creating files (see truenas/DEPLOYMENT_GUIDE.md)
- **Workstation → TrueNAS**: `.config/` → `/mnt/Fast/docker/<service>/`
- **Migration steps**: backup → mkdir → scp → chown 1000:1000 → deploy via Web UI
- **TrueNAS SSH**: `ssh kero66@192.168.20.22` for daily ops, NOT root
- **Infisical secrets**: Pattern is `infisical secrets get <SECRET> --env dev --path /TrueNAS --plain 2>/dev/null`

## For Detailed Documentation
- **Architecture**: `truenas/README.md`
- **Deployment**: `truenas/DEPLOYMENT_GUIDE.md`
- **Migration**: `truenas/MIGRATION_CHECKLIST.md`
- **Troubleshooting**: `.github/TROUBLESHOOTING.md`
- **Session work**: `ai/SESSION_NOTES.md`
- **Task tracking**: `ai/todo.md`
- **Doc structure**: `ai/DOCUMENTATION_STRUCTURE.md`

## Task Tracking (User Requirement)
- **Always use TodoWrite/TaskCreate** for multi-step current session work
- **Always add** long-term items to `ai/todo.md`
- See `ai/DOCUMENTATION_STRUCTURE.md` for full workflow

## AI Agent Behavior
- **DO THE WORK, don't ask user** - Set up SSH access, install tools, troubleshoot issues yourself
- **Research first, guess never** - Use existing patterns from codebase, check documentation
- **Verify before piping** - Check response types before using jq or other text processing
- **Follow established patterns** - Search codebase for existing examples (e.g., infisical usage)
- **Update documentation** - Keep `ai/SESSION_NOTES.md` current with decisions and blockers
- **Agent-agnostic** - All documentation should work for Claude, Copilot, or any AI tool
- **No passwords in output** - Use variables, redirect stderr, don't echo secrets
