<!--
	copilot-instructions.md
	Purpose: guidance for GitHub Copilot or AI assistants on how to propose and edit code in this repository.
	NOTES:
	 - Keep suggestions mindful of the homelab / production services in this repo.
	 - This file should be concise and actionable.
-->

# GitHub Copilot Instructions for homelab

## Purpose
- Help contributors and AI assistants make safe, consistent, and testable changes to the homelab repository.
- Provide repository-specific direction so we minimize rework, avoid rerunning commands unnecessarily, and cut down on repeated experimentation when the answer is already available.

## Key principles
- READ THE DOCUMENTATION before assuming anything; use MCP or other docs listed below and cite the source in ai/reference.md.
- USE THE API FIRST when investigating or changing infrastructure; rely on service APIs before manual terminal exploration.
- WORK EFFICIENTLY: reuse recorded commands/results, double-check prior logs before rerunning validations, and surface any repeated effort in your summary so maintainers can trust you revisited the right state.
- IF YOU ASK A CLARIFYING QUESTION AND IT GOES UNANSWERED, add it as an **open** item to ai/todo.md with context and a suggested next step, then restrict yourself to safe, reversible work.
- LOG any newly discovered working API call or troubleshooting command in `.github/TROUBLESHOOTING.md` with sanitized placeholders and enough context so future troubleshooters can reuse it.

## Source of truth (consult before guessing)
- [README.md](../README.md)
- [networking/README.md](../networking/README.md)
- [networking/.config/caddy/Caddyfile](../networking/.config/caddy/Caddyfile)
- [monitoring/README.md](../monitoring/README.md)
- [monitoring/compose.yaml](../monitoring/compose.yaml)
- [media/README.md](../media/README.md)
- [media/compose.yaml](../media/compose.yaml)
- [homeassistant/README.md](../homeassistant/README.md)
- Record any additional external resources you consult in ai/reference.md, even if they come from MCP or other docs.

## Scope — where AI can safely help
- Documentation and READMEs (including service-specific READMEs and docs/*).
- Deployment and automation scripts under scripts/, automations/, deploy.sh, and related compose helpers.
- Docker Compose or YAML configuration files; always include the validation commands (yamllint, docker compose config) that you used in your summary.
- Monitoring and alert files (Prometheus rules, Grafana provisioning); note any alert owner impact and include validation steps.
- Tooling/helper utilities (scripts/, tools/, service helpers) with repo-standard style and linting.

## Service Specific Rules

### Recyclarr
- **API Keys:** Never hardcode. Use `!secret` tags referencing `secrets.yml`.
- **Profiles:** Map Trash Guides custom formats manually to existing profiles: `Anime (1080p)`, `Standard (1080p)`, and `Ultra-HD (4K)`. Do NOT use quality-profile templates that create new profiles.
- **Anime Audio:** Penalize English-only dubs with a score of `-10000` on the "Dubs Only" custom format to prioritize Japanese/Original audio.
- **Warnings:** Ignore Recyclarr warnings about "missing profile definitions" for template-default names (e.g., "Remux-1080p - Anime") to maintain official template compatibility.
- **Naming:** Use `WEBDL-1080p` and `WEBDL-2160p` style naming for quality targets in Recyclarr mapping.

## Out-of-scope — ask a human before touching
- Secrets, credentials, API keys, tokens, or anything that would live in config_backups/. 
- Large or risky infra changes (core proxy rewrites, service removals, new ports) that could cause downtime, unless an explicit owner approves.
- Work that requires rotating credentials, redeploying critical services, or rebooting hosts; open an issue or request direct owner coordination instead.

## Secrets handling
- Never insert real secrets in the repo; use `.sample` placeholders and describe where real values belong in documentation.
- Store credentials in Infisical and reference the relevant secret path (for example, `/media`, `/monitoring`, `/homepage`) in docs/README updates instead of copying secrets.
- Document the vault/secret manager expectation for each change when a new secret would be required.

## Style and conventions
- Shell: use `#!/usr/bin/env bash`, `set -euo pipefail`, prefer idempotent designs, and run `shellcheck` before claiming the script is ready.
- YAML / Docker Compose: run `yamllint <file>` and `docker compose -f <file> config` (include `compose -f` target in your summary) for every modified compose file.
- Python: format with `black` and lint with `ruff`/`flake8`; include new tests when feasible.
- Documentation: keep prose concise, add a short example or command to validate the doc change, and cite the relevant README.

## Efficiency checklist for AI-proposed work
1. Validate yaml/compose files
   - `yamllint <file>`
   - `docker compose -f <file> config`
2. Validate shell scripts
   - `shellcheck <script>` or `bash -n <script>`
3. Validate Python changes
   - `python -m pytest <target>` or run `ruff .` and `black --check .`
4. Security check
   - confirm no secrets were added; document required secret sources in docs or `.env.sample`.
5. Documentation follow-up
   - update user-facing README/CHANGELOG entries when behavior changes.
6. Coordination note
   - mention any needed downtime or owner approvals; cite the owner (kero-66) when responsibilities are handed off.

## Branching and commits
- Branch names: `feature/<short-description>`, `fix/<short-description>`, `hotfix/<short-description>`.
- Commit messages: `<type>(<scope>): <short summary>` (e.g., `fix(scripts): handle missing MEDIA_PATH env var`, `chore(docs): refresh media README`).

## When to ask for help or approval
- Touching production service definitions, scheduled jobs, or monitoring/alerting rules.
- Changes that require credential rotations, redeploys, or architectural shifts (new services, new networks).
- Any work that cannot be validated without owner coordination or that could cause downtime.

## Examples
- Good: tweak a deployment script, run `shellcheck`, and document the command in the summary.
- Good: bump an image tag in a compose file, run `yamllint` + `docker compose -f <file> config`, and describe the validation output.
- Bad: adding API keys to config_backups/ or altering a proxy config without human signoff.

## Contact
- Primary repo owner: kero-66. Open an issue or mention them on the PR for any major or risky change.

