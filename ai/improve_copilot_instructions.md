Working draft: improvements to .github/copilot-instructions.md

Goal
- Make the copilot instructions clearer, more actionable, and easier for maintainers to validate.

Proposed high-level changes
- Reorganize sections for clarity: Scope, Out-of-scope, Style & Conventions, PR Checklist, Branch/Commit Naming, When to Ask for Help.
- Shorten and make validation steps prescriptive (commands to run where possible).
- Add explicit "no secrets" enforcement and a suggested pattern for secrets (use .env + docs).

Concrete suggested replacement content (drop-in)

# GitHub Copilot / AI Assistant Instructions for homelab

Purpose
- Help contributors and AI assistants make safe, consistent, and testable changes to the homelab repository.
- Provide repository-specific guidance: where to make changes, how to validate them, and what to avoid.

Scope — where AI can safely help
- Documentation and READMEs: update, add or correct instructions in `README.md`, `docs/`, and service README files.
- Deployment and automation scripts: modify or improve scripts in `scripts/`, `automations/`, `deploy.sh`, and compose-based deployment helpers.
- Docker Compose and YAML configuration: propose changes in `*.yaml`, `compose.yml` and `compose.yaml` files (include validation steps).
- Monitoring and alerts: propose changes to monitoring files (Prometheus, Grafana) with validation notes.
- Tooling and helper utilities: small improvements to `scripts/`, `tools/`, or service-specific scripts (follow repo style).

Out-of-scope — DO NOT change without explicit human confirmation
- Secrets, credentials, API keys, or tokens in plaintext anywhere (especially `config_backups/`). Suggest use of environment variables or external secret stores.
- Large or risky infra changes that could cause production downtime (reconfiguring core proxies, removing services, changing exposed ports) without owner approval.
- Changes that require credential rotation, re-deploying critical services, or host reboots. Propose PR and request owner approval instead.

Style and conventions
- Shell scripts: Use `#!/usr/bin/env bash`, `set -euo pipefail` and prefer idempotent design. Run `shellcheck` before opening a PR.
- YAML / Docker Compose: Validate with `yamllint` and `docker compose -f <file> config`.
- Python: Use `black` for formatting and `ruff`/`flake8` for linting. Add tests where feasible.
- Documentation: Keep changes short and actionable; include a validation command when possible.

PR checklist (required for AI-proposed changes)
1. Validate yaml/compose files
  - `yamllint <file>`
  - `docker compose -f <file> config`
2. Validate shell scripts
  - `shellcheck <script>` or `bash -n <script>`
3. Validate Python changes
  - `python -m pytest` (targeted tests) or run linters: `ruff .` / `black --check .`
4. Security check
  - Ensure no secrets are added. If a secret is required, add `.env` instructions and do not commit secrets.
5. Documentation
  - Update related README or `CHANGELOG.md` for user-facing changes.
6. Coordination
  - If change requires downtime, mention it in the PR and get explicit owner approval.

Commit and branch naming
- Branches:
  - Feature: `feature/<short-description>`
  - Fix: `fix/<short-description>`
  - Hotfix: `hotfix/<short-description>`
- Commit messages: `<type>(<scope>): <short summary>`
  - Examples: `fix(scripts): handle missing MEDIA_PATH env var`, `chore(docs): update media README`

When to ask for help / approval
- Touching production service definitions, scheduled jobs, or monitoring rules.
- Changes requiring credential rotation or re-deploys.
- Adding new services or changing architecture.

Examples (good / bad)
- Good: small script improvements with validation commands; updating a Docker image tag and validating compose config.
- Bad: adding API keys or replacing a service's network config without approval.

Contact
- Primary repo owner: kero-66. Open an issue and assign the owner for major or risky changes.

Suggested follow-ups
- Add CI jobs for `yamllint`, `shellcheck`, and `docker compose -f <file> config` to catch issues automatically.

Rationale and notes
- This draft shortens language, formats validation steps as commands, and clarifies the exact circumstances that require human approval.

---

How to apply
- Review this draft, copy accepted sections into `.github/copilot-instructions.md`, and open a PR with the minimal changes and the validation commands used.

