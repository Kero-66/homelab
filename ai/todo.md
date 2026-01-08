# AI / Project TODO

This file records suggestions, unanswered questions, and follow-ups the AI should append when the user does not answer.

Format: id | title | description | created_by | created_at | status | related_files

1 | secret_manager_choice | Choose secret manager for homelab (Vault / SOPS+KMS / cloud / local) | AI | 2025-12-16 | open | ai/ideas.md, media/config_samples/.env.sample

2 | draft_sample_files | Should AI draft `media/config_samples/.env.sample` and `media/.config/.credentials.sample` now? | AI | 2025-12-16 | open | media/config_samples/

3 | allow_copilot_update | Permission to update `.github/copilot-instructions.md` to record AI behaviour rules (unanswered questions auto-appended to `ai/todo.md`)? | AI | 2025-12-16 | open | .github/copilot-instructions.md, ai/improve_copilot_instructions.md

4 | secret_storage_policy | Confirm preferred secret storage policy (local files only vs integrate Vault/SOPS) | AI | 2025-12-16 | open | ai/ideas.md

5 | ci_secret_scan | Add CI/pre-commit secret-scan and ensure `.sample` files exist for all tracked configs | AI | 2025-12-16 | open | .github/, .gitignore
6 | cleanuparr_live_mode | Transition Cleanuparr to Live mode (disable dryRun) and verify queue cleanup | AI | 2026-01-08 | completed | media/cleanuparr/config.yml, ai/reference.md
7 | cleanuparr_failed_imports | Configure Cleanuparr to handle 'Invalid season or episode' failed imports | AI | 2026-01-08 | completed | media/cleanuparr/config.yml

---

Notes for AI behaviour (to be mirrored into `.github/copilot-instructions.md` and `ai/improve_copilot_instructions.md`):

- When a user question remains unanswered after a reasonable clarification attempt, append the question to `ai/todo.md` with status `open` and continue with safe non-destructive work.
- Always record external sources used into `ai/reference.md` when the AI references external documentation.
- Do not modify or commit secrets; create `.sample` files instead.

6 | sabnzbd_access_and_automation | Complete SABnzbd browser access fix (set inet_exposure=0) and ensure all hardening is automated in the generation script. | GitHub Copilot | 2026-01-08 | completed | apps/homepage/scripts/generate_env_from_media.sh, media/sabnzbd/sabnzbd.ini
7 | jackett_removal | Jackett has been removed from media stack, homepage, and caddy. Associated config directories and credentials purged. | GitHub Copilot | 2026-01-08 | completed | media/compose.yaml, apps/homepage/, networking/.config/caddy/Caddyfile
8 | easynews_setup | Configured Easynews with 20 connections and verified pipeline | GitHub Copilot | 2026-01-08 | completed | media/.config/.credentials, media/docs/USENET_SETUP.md, apps/homepage/scripts/generate_env_from_media.sh
9 | jellyseerr_dashboard | Added Jellyseerr widget to Homepage and fixed API 403 error | GitHub Copilot | 2026-01-08 | completed | apps/homepage/config/services.yaml, apps/homepage/compose.yaml
10 | drunkenslug_prowlarr | Enabled DrunkenSlug in Prowlarr and updated with provided API key | GitHub Copilot | 2026-01-08 | completed | (Prowlarr API config)
