# AI behaviour policy (recorded)

## Purpose

- Record explicit AI behaviour expectations for the repo in an easily discoverable file. This complements `.github/copilot-instructions.md` and `ai/improve_copilot_instructions.md`.

## Rules

### 1) Unanswered questions -> `ai/todo.md`

- If the AI asks a clarifying question and the user does not answer (or indicates "defer"), the AI MUST append the question as an `open` item to `ai/todo.md` with: a concise title, the question, context (files read), suggested next step, and timestamp.
- The AI should then continue only with safe, non-destructive tasks (creating sample files, docs, or proposals) and avoid making irreversible changes.

### 2) External sources -> `ai/reference.md`

- When using external documentation, the AI must append a short reference entry to `ai/reference.md` with the URL and a 1-line reason for use.

### 3) Secrets

- The AI must never populate real secrets. Use Infisical for secret storage and document required paths (for example, `/media`, `/monitoring`, `/homepage`).
  
### 6) Command logging

- After every successful troubleshooting or API command, append a sanitized entry to `.github/TROUBLESHOOTING.md` with what worked, why, and any required env vars placeholders.
- Infisical CLI requires a project ID for `infisical run`. Document `INFISICAL_PROJECT_ID` or `--projectId` in troubleshooting notes to avoid the “projectSlug or workspaceId” error.

### 4) Documentation & API First

- Before attempting to modify configuration files or databases directly, the AI MUST attempt to retrieve the official API documentation or Swagger specification from the running service (e.g., `/swagger.json`, `/api/v1/status`).
- Use the API for service status reviews and configuration changes whenever possible to ensure consistency and avoid schema corruption.
- Record canonical API endpoints and Swagger URLs in `ai/reference.md` once discovered.

### 7) Service Migrations - Research Before Action

- **CRITICAL**: Before migrating ANY service to TrueNAS or creating new configurations, the AI MUST:
  1. Check for existing compose files in the repo (`apps/`, `networking/`, `media/`, `truenas/stacks/`)
  2. Review `docker inspect <service>` output on workstation to understand current mounts
  3. Examine completed migrations in `ai/todo.md` and `truenas/scripts/` for patterns
  4. Read `truenas/MIGRATION_CHECKLIST.md` and follow ALL steps
  5. Never create configs from scratch if existing setup can be migrated
- **Path Conventions**:
  - Workstation uses relative paths (`.config/`, `config/`)
  - TrueNAS uses absolute paths: `/mnt/Fast/docker/<service>/` for ALL data
  - Compose files in repo are REFERENCE - deployment uses TrueNAS Web UI
- **Documentation Requirements**:
  - Create migration script in `truenas/scripts/migrate_<stack>.sh` following existing patterns
  - Update `~/.claude/memory/MEMORY.md` with lessons learned
  - Add working commands to `.github/TROUBLESHOOTING.md`
  - Mark tasks complete in `ai/todo.md` with file references

### 5) Tone & behaviour

- Be concise and direct. Avoid apologies or unnecessary flattery.
- Ask concise clarifying questions when needed.
- If the AI cannot answer, say so and record the sources it consulted.

## Implementation note

- Admins/maintainers should periodically triage `ai/todo.md` and `ai/reference.md` to convert open items into issues or PRs.

