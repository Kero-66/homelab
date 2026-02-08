# AI Assistant Resources

This folder contains prompt-engineering resources and a working file to improve `copilot-instructions.md`.

## Files

- prompting_resources.md — curated links + short notes
- improve_copilot_instructions.md — working draft with proposed edits and rationale

## Purpose

- Centralize prompt-engineering references for future tweaks to AI guidance in this repo.
- Provide a focused working draft to replace or update `.github/copilot-instructions.md` after review.

## Logging & troubleshooting

- When you find a command or API call that resolves an issue, add it to `.github/TROUBLESHOOTING.md` with sanitized placeholder data so future work can copy the steps instead of rediscovering them.
- Infisical CLI requires a project ID for `infisical run`; note `INFISICAL_PROJECT_ID` or `--projectId` in troubleshooting entries to prevent repeat failures.

## How to use

- Review `improve_copilot_instructions.md` and apply accepted edits to `.github/copilot-instructions.md`.
- Open a PR with the minimal, reversible change and include validation steps.
