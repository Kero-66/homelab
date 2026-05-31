# GitHub Copilot Instructions Template

Use this template when creating or refreshing `.github/copilot-instructions.md` in other repositories. Replace the placeholder text under each heading with project-specific guidance so Copilot-powered agents behave consistently across teams.

## Core Directives
- NEVER APOLOGIZE (adjust or remove if your org prefers different tone)
- ALWAYS CHECK DOCUMENTATION (link to primary knowledge base)
-- When user instructs you to check documentation, ensure you save the documentation links in a documentation.md file.
- ALWAYS UPDATE KNOWLEDGE BASE (explain where successful commands/workarounds should be recorded)
- TODO: Add any non-negotiable behaviours unique to this project (logging requirements, approval gates, etc.)

## Quick Orientation
- TODO: Link to the project README or onboarding doc
- TODO: Link to architecture or design references
- TODO: Link to environment setup guides or runbooks operators must read first

## Key Components
- TODO: List critical scripts/modules/playbooks. Include brief purpose and relative paths (e.g., `[src/main.py](../src/main.py) – REST API entry point`)
- TODO: Note generated artefacts (inventories, manifests, build outputs) and their locations

## Conventions To Preserve
- TODO: Document naming conventions, data schemas, or threading/parallelism parameters that should not change without discussion
- TODO: Capture policy rules (e.g., sizing logic, hostname parsing) that influence automation outcomes
- TODO: Mention default configuration files (e.g., `ansible.cfg`, `.env.example`) that must remain authoritative

## Security Expectations
- TODO: Describe secrets handling (1Password, AWS SSM, Vault, etc.) and explicitly forbid embedding credentials in repo
- TODO: Call out logging redactions or data handling constraints (PII, PCI, etc.)

## Before Finishing Changes
- TODO: List validation commands (tests, linters, compile steps)
- TODO: Remind contributors to update documentation or runbooks when behaviour shifts
- TODO: Specify where to capture notable learnings for the knowledge base

## Optional Sections
- **Testing Shortcuts:** TODO if there are helper scripts or Make targets for common verification flows
- **Escalation Contacts:** TODO to add Slack channels, email groups, or rotation docs when human approval is needed
- **Infrastructure Notes:** TODO for cloud accounts, bastion hosts, or VPN requirements that influence development workflows

## File Structure Expectations
- TODO: Identify documentation files the instructions will reference (e.g., README, architecture guides) and ensure they exist in the repo
- TODO: Call out configuration directories (config/, inventory/, scripts/) that Copilot should be aware of when suggesting changes
- TODO: List generated outputs that should be ignored or archived (CSV exports, inventories) so guidance remains accurate
- TODO: Mention any templates or starter files (e.g., docs/copilot-instructions-template.md) that must stay up to date alongside the instructions

---

> Tip: Keep link targets relative so the instructions work whether Copilot runs locally or in Codespaces. Update this template as your standard operating procedures evolve.
