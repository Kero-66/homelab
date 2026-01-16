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
11 | better_stack_review | Re-evaluate Better Stack for external fail-safe monitoring (deferred: cloud-only) | GitHub Copilot | 2026-01-08 | open | ai/ideas.md
12 | beszel_provisioning | Auto-provisioned Beszel admin and fixed Hub-Agent connectivity | GitHub Copilot | 2026-01-09 | completed | monitoring/compose.yaml, monitoring/.env, ai/reference.md
13 | radarr_anime_language_fix | Update Radarr/Sonarr Anime scoring to prioritize Japanese/Original audio over German releases | GitHub Copilot | 2026-01-10 | completed | media/recyclarr/config/recyclarr.yml, ai/reference.md
14 | watch_history_persistence | Configured Recycle Bin (/data/.recycle) and TRaSH naming schemes with IDs to preserve Jellyfin watch history | GitHub Copilot | 2026-01-10 | completed | media/recyclarr/config/recyclarr.yml, Radarr/Sonarr API
15 | bazarr_language_config | Configure Bazarr wanted languages (English/Japanese) to ensure multiple subtitles are downloaded | GitHub Copilot | 2026-01-10 | open | media/bazarr/config/config.yaml

---

## Repository Security & Architecture Review (2026-01-15)

16 | fix_plaintext_passwords | Remove plaintext password from monitoring/.env and implement proper credential management | AI | 2026-01-15 | open | monitoring/.env, networking/.config/.credentials.sample

17 | add_security_headers | Implement security headers in Caddy reverse proxy configuration (CSP, HSTS, X-Frame-Options) | AI | 2026-01-15 | open | networking/.config/caddy/Caddyfile

18 | create_root_orchestration | Add root-level docker-compose.yml to orchestrate all stacks with proper service dependencies | AI | 2026-01-15 | open | docker-compose.yaml (root), */compose.yaml

19 | standardize_env_vars | Standardize environment variable naming conventions across all stacks (networking, monitoring, automations) | AI | 2026-01-15 | open | */.env, */.env.sample

20 | harden_docker_networking | Review and reduce network_mode: host usage, evaluate privileged containers, implement proper network isolation | AI | 2026-01-15 | open | proxy/compose.yaml, surveillance/compose.yaml, automations/compose.yml

21 | add_centralized_logging | Implement centralized logging solution (ELK stack or similar) for all homelab services | AI | 2026-01-15 | open | monitoring/, */compose.yaml

22 | implement_health_checks | Add comprehensive health checks to all services missing them, create monitoring dashboard | AI | 2026-01-15 | open | */compose.yaml, monitoring/

23 | create_backup_verification | Verify backup scripts cover all persistent data, add automated backup testing and off-site strategy | AI | 2026-01-15 | open | backup_*.sh, */README.md

24 | add_deployment_automation | Create deployment scripts with rollback capability and configuration drift detection | AI | 2026-01-15 | open | scripts/, */README.md

25 | document_service_dependencies | Create comprehensive documentation of service interdependencies, startup order, and network topology | AI | 2026-01-15 | open | docs/, README.md

26 | fix_hardcoded_ips | Replace hardcoded IPs with environment variables or service discovery (automations, proxy configs) | AI | 2026-01-15 | open | automations/compose.yml, proxy/compose.yaml

27 | bazarr_sync | Configure Bazarr to prioritize subtitle languages and providers, aligning with Anime/Standard logic | AI | 2026-01-15 | open | media/bazarr/config/config.yaml

28 | fileflows_optimization | Review and consolidate FileFlows sandbox scripts and optimize for hardware acceleration | AI | 2026-01-15 | open | media/fileflows/

29 | prowlarr_tagging | Define Prowlarr indexer tags to align with Recyclarr's Anime/Standard profiles | AI | 2026-01-15 | open | prowlarr/
30 | caddy_optional_proxies | Add Caddy routes for optional media services (huntarr, FileFlows, Cleanuparr) so they are reachable whenever enabled instead of being blocked by the current proxy | GitHub Copilot | 2026-01-15 | open | networking/.config/caddy/Caddyfile, media/compose.yaml

