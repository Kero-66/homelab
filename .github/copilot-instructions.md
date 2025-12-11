<!--
	copilot-instructions.md
	Purpose: guidance for GitHub Copilot or AI assistants on how to propose and edit code in this repository.
	NOTES:
	 - Keep suggestions mindful of the homelab / production services in this repo.
	 - This file should be concise and actionable.
-->

# GitHub Copilot / AI Assistant Instructions for homelab

✅ Purpose

- Help contributors and AI assistants make safe, consistent, and testable changes to the homelab repository.
- Provide repository-specific guidance: where to make changes, how to validate them, and what to avoid.

---

## Scope — where AI can safely help

- Documentation and READMEs: update, add or correct instructions in `README.md`, `docs/`, and service README files (e.g. `media/README.md`, `homeassistant/README.md`).
- Deployment and automation scripts: modify or improve scripts in `scripts/`, `automations/`, `deploy.sh`, and `compose`-based deployment helpers.
- Docker Compose and YAML configuration: propose changes in `*.yaml`, `compose.yml` and `compose.yaml` files, or `images/` small updates (image tags and metadata updates are OK with validation steps).
- Monitoring and alerts: propose changes to `monitoring/` files including Prometheus, Grafana dashboards (but include validation steps and confirm alerts scope).
- Tooling and helper utilities: small improvements to `scripts/`, `tools/`, or service-specific scripts (maintain existing style and linting).

## Out-of-scope — do NOT make these changes without explicit human confirmation

- Secrets, credentials, API keys, or tokens: never add or modify values in `config_backups/` or anywhere that would store secrets in plaintext. If a secret needs to be managed, propose using environment variables and an external secrets manager.
- Large or risky infrastructure changes that could cause production downtime (remove or reconfigure services such as `homeassistant`, `jellyfin`, `prowlarr`, `radarr`, `sonarr`, `updating core proxies` etc.) without explicit owner approval.
- Changes requiring credential rotation, re-deploying critical services, or rebooting hosts. Suggest the change in a PR and mention the operational steps and owner approval required.

---

## Style and conventions

- Shell scripts
	- Use POSIX-ish bash: include `#!/usr/bin/env bash` and set `set -euo pipefail` where appropriate.
	- Prefer idempotent scripts and document assumptions in the script header.
	- Run `shellcheck` on changes to existing or new `.sh` files and follow linter suggestions where possible.

- YAML / Docker Compose
	- Validate YAML syntax with `yamllint` and `docker compose -f <file> config` when editing compose files.
	- Keep service definitions minimal and documented in the respective folder README when adding or altering services.

- Python
	- Use `black` or the repository's already used formatting tooling. Run `ruff` or `flake8` for linting.
	- Add unit tests where feasible and include instructions for running them in the updated README.

- Documentation
	- Use clear, short, and actionable changes. Include a small example or command to validate the change locally where possible.

---

## Suggested PR checklist for changes proposed by AI

Before opening a PR, or when PRs include AI-proposed changes, ensure the following:

1. Validate yaml/compose files:
	 - `yamllint` on modified YAML files
	 - `docker compose -f path/to/compose.yaml config` for all modified compose files
2. Validate shell scripts:
	 - `shellcheck` (or at least `bash -n` and a simple smoke test)
3. Validate Python changes (if present):
	 - `python -m pytest` for related tests, or at least run a quick linter like `ruff` / `flake8`.
4. Security checks:
	 - Ensure no secrets are added. If a secret is required, use `.env` (ignored in the repo) and document where to populate it.
5. Documentation and changelog:
	 - Update related README or `CHANGELOG.md` when adding or changing functionality that affects users or operations.
6. Coordination and downtime:
	 - If changes require downtime or re-deploys, mention this in the PR and get explicit approval from the repo owner or the on-call maintainer.

---

## Commit and branch naming suggestions

- Branches
	- Feature branches: `feature/<short-description>`
	- Fix branches: `fix/<short-description>`
	- Hotfix/urgent: `hotfix/<short-description>`

- Commit messages (conventional and clear)
	- Format: `<type>(<scope>): <short summary>`
	- Examples: `fix(scripts): handle missing MEDIA_PATH env var`, `chore(docs): update README media section`

---

## When to ask for help or confirmation

- Ask a human maintainer in a PR or an issue when making changes that:
	- touch production service definitions, scheduled jobs, or monitoring/alerting rules.
	- require credential or key rotation.
	- change architecture (e.g., adding a new VM, exposing new ports, changing proxies).
	- introduce a brand new service or automation for which there are no tests.

---

## Examples (what to do / what NOT to do)

- Good
	- Small performance improvement to a script and update README with `how-to-run` instructions.
	- Update a Docker image version and validate via `docker compose -f ... config`.
	- Add a new lint rule and update CI instructions for the repository.

- Bad
	- Adding API keys or exposing SSH keys in `images/` or `config_backups/`.
	- Replacing a service's network configuration without owner confirmation.

---

## Contact and owners

- Primary repo owner: `kero-66` (maintainer). If you need to escalate or coordinate, open an issue describing the change and assign the owner.

---

💡 Tip: When in doubt, propose a minimal and reversible change in a PR, include validation instructions, and request maintainers' approval.

---

Thank you for helping to keep this homelab repository safe and reliable. If you'd like, I can also add CI job suggestions (shellcheck, yamllint, docker compose validation) to help enforce these rules automatically.

