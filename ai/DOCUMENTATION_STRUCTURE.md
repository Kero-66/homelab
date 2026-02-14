# Documentation Structure & AI Agent Guidelines

## Problem Statement
We need agent/AI-agnostic documentation that works for Claude Code, GitHub Copilot, and any future AI tools. Currently:
- `.claude/memory/MEMORY.md` duplicates content from repo docs
- `.github/copilot-instructions.md` has some overlap with ai/ folder
- Not clear where to put different types of documentation
- Need standardized workflow for tracking tasks

---

## Documentation Hierarchy (Where Things Go)

### 1. `.github/` - Development & Contribution Guidelines
**Purpose:** Instructions for developers and AI agents on HOW to work with this repo

**What goes here:**
- `copilot-instructions.md` - AI coding standards and patterns
- `TROUBLESHOOTING.md` - Common issues and solutions
- `memory.md` - Quick reference facts (IPs, paths, gotchas)
- CI/CD configs, PR templates, etc.

**Examples:**
- ✅ "Always use `jq` instead of `python -m json.tool`"
- ✅ "SSH piped commands fail on TrueNAS - use separate steps"
- ✅ "TrueNAS IP: 192.168.20.22"

### 2. `ai/` - AI Session Management & Planning
**Purpose:** Active work tracking, session continuity, research, and AI workflow

**What goes here:**
- `todo.md` - Task tracking (structured format)
- `SESSION_NOTES.md` - Active session context for cross-session continuity
- `reference.md` - External resources used during development
- `ideas.md` - Future enhancements and brainstorming
- `ai_behaviour.md` - How AI agents should behave in this repo

**Examples:**
- ✅ "Currently researching Tailscale userspace mode"
- ✅ "Session 2026-02-14: Working on frontend stack migration"
- ✅ "TODO: Migrate Infisical to TrueNAS"

### 3. `truenas/` - TrueNAS Deployment Documentation
**Purpose:** Everything related to TrueNAS deployment, migration, and operations

**What goes here:**
- `README.md` - Overview of TrueNAS setup
- `DEPLOYMENT_GUIDE.md` - How to deploy services
- `*_DEPLOYMENT.md` - Specific stack deployment guides
- `STATUS.md` - Current deployment state
- Migration guides, session summaries, hardware configs

**Examples:**
- ✅ "How to deploy Custom Apps via TrueNAS Web UI"
- ✅ "Arr stack migration checklist"
- ✅ "Infisical Agent configuration"

### 4. Root Documentation - Project Overview
**Purpose:** High-level project documentation for humans

**What goes here:**
- `README.md` - Project overview, quick start
- `MIGRATION_GUIDE.md` - Workstation → TrueNAS migration
- `BACKUP_README.md` - Backup strategy
- `CHANGELOG.md` - Major changes and releases

---

## `.claude/memory/MEMORY.md` Strategy

**Purpose:** Quick reference for Claude Code - should be < 200 lines (only first 200 load)

**What to include:**
- **Critical paths and IPs** (TrueNAS IP, key directories)
- **Key architecture decisions** (deploy via Web UI, not docker-compose)
- **Common gotchas** (SSH issues, tool preferences)
- **Links to detailed docs** (not full content)

**What NOT to include:**
- ❌ Full deployment procedures (link to truenas/ docs instead)
- ❌ Complete task lists (use ai/todo.md)
- ❌ Session-specific context (use ai/SESSION_NOTES.md)

**Example structure:**
```markdown
# Homelab Project Memory

## Quick Reference
- TrueNAS: 192.168.20.22 (SSH as root)
- Workstation: 192.168.20.66 (Fedora)
- Pools: /mnt/Fast (NVMe), /mnt/Data (HDD)

## Key Patterns
- Deploy via TrueNAS Web UI Custom Apps
- Compose files are REFERENCE, not deployed directly
- See: truenas/DEPLOYMENT_GUIDE.md

## Common Gotchas
- Don't use `python -m json.tool` → use `jq`
- See: .github/TROUBLESHOOTING.md for full list

## Active Work
- See: ai/SESSION_NOTES.md for current session context
- See: ai/todo.md for task tracking

## For more details:
- Architecture: truenas/README.md
- Deployment: truenas/DEPLOYMENT_GUIDE.md
- Troubleshooting: .github/TROUBLESHOOTING.md
```

---

## Task Tracking Workflow

### When to use TaskCreate (Claude Code ephemeral tasks)
Use for **current session work** that won't persist across sessions:
- ✅ Multi-step tasks in the current session
- ✅ Complex work that needs progress tracking NOW
- ✅ Breaking down a larger task into subtasks

**Characteristics:**
- Tasks disappear after session ends
- Good for "working memory"
- Shown in Claude Code UI

### When to use ai/todo.md (Persistent tracking)
Use for **work that persists across sessions**:
- ✅ Long-term tasks and goals
- ✅ Items that need to be remembered weeks later
- ✅ Decisions that were made
- ✅ Follow-up work identified during a session

**Format (structured for parsing):**
```
ID | title | description | created_by | created_at | status | related_files

Example:
64 | migrate_caddy_to_truenas | Deploy Caddy reverse proxy on TrueNAS with HTTPS support | Claude | 2026-02-14 | in_progress | truenas/stacks/caddy/
```

### Recommended Workflow
1. **Start of session:**
   - Read `ai/SESSION_NOTES.md` to see what was being worked on
   - Read `ai/todo.md` to see pending tasks
   - Create TaskCreate items for work you'll do THIS session

2. **During session:**
   - Use TaskUpdate to track progress on ephemeral tasks
   - Add findings/decisions to `ai/SESSION_NOTES.md`

3. **End of session:**
   - Add any unfinished work to `ai/todo.md` with status=open
   - Update `ai/SESSION_NOTES.md` with current blockers/status
   - TaskCreate items will automatically disappear

---

## Standard Operating Procedures

### For AI Agents (Claude, Copilot, etc.)

#### Starting a New Session
1. Read `ai/SESSION_NOTES.md` first
2. Read `ai/todo.md` for pending tasks
3. Check `.github/memory.md` for quick facts
4. Ask user what to work on

#### During Work
1. **Always use TaskCreate** for multi-step work in current session
2. **Update ai/SESSION_NOTES.md** with key findings/research
3. **Add to ai/todo.md** when identifying new long-term work
4. **Reference existing docs** instead of duplicating

#### Ending a Session
1. Update `ai/SESSION_NOTES.md` with current status
2. Add unfinished work to `ai/todo.md`
3. Mark completed todo.md items as `completed`

### For Humans

#### Adding New Documentation
- Global facts → `.github/memory.md`
- TrueNAS specific → `truenas/*.md`
- Task tracking → `ai/todo.md`
- Active research → `ai/SESSION_NOTES.md`

---

## Migration Plan

### Phase 1: Cleanup .claude/memory/MEMORY.md ✅ (Task #1)
1. Keep only critical quick reference items
2. Add links to detailed documentation
3. Remove duplicated content
4. Keep under 200 lines

### Phase 2: Consolidate .github docs
1. Review `.github/memory.md` vs `.github/copilot-instructions.md`
2. Ensure no overlap with `ai/` folder
3. Clear separation: .github = HOW to work, ai/ = WHAT to work on

### Phase 3: Establish todo.md workflow (Task #4)
1. Create guidelines for when to use TaskCreate vs todo.md
2. Document workflow in this file
3. Train AI agents to follow this pattern

---

## TL;DR for AI Agents

**Start here every session:**
```bash
1. Read ai/SESSION_NOTES.md  # What were we doing?
2. Read ai/todo.md           # What needs to be done?
3. Read .github/memory.md    # Quick facts (IPs, paths)
```

**During work:**
- Use TaskCreate for current session tasks
- Add discoveries to ai/SESSION_NOTES.md
- Add long-term work to ai/todo.md

**Reference, don't duplicate:**
- Deployment procedures → truenas/DEPLOYMENT_GUIDE.md
- Architecture → truenas/README.md
- Troubleshooting → .github/TROUBLESHOOTING.md
