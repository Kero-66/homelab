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

---

## TrueNAS Migration Session (2026-02-11) - CRITICAL ISSUES

21 | RESOLVED: jellyfin_library_paths | Jellyfin libraries working correctly. Mount `/mnt/Data/media:/data` maps shows to `/data/shows` and movies to `/data/movies`. 41 TV shows and 11 movies detected. Compose paths corrected to match actual TrueNAS datasets. | AI | 2026-02-11 | completed | truenas/stacks/jellyfin/compose.yaml

22 | RESOLVED: jellystat_db_synced | Jellystat database has data via Jellyfin sync: 211 playback activities, 73 library items, 6 libraries. Historical workstation data not migrated but current sync is working. | AI | 2026-02-11 | completed | /mnt/Fast/databases/jellystat/postgres

23 | cleanup_workstation_services | Optional: Stop and cleanup remaining containers on workstation (192.168.20.66) and verify cold spare status | AI | 2026-02-11 | open | /mnt/library/repos/homelab/media/

---

## TrueNAS Jellyfin Migration (2026-02-11)

35 | truenas_jellyfin_infisical_setup | ✅ COMPLETED: Infisical Agent configured on TrueNAS with Machine Identity and Universal Auth | GitHub Copilot | 2026-02-11 | completed | truenas/scripts/setup_agent.sh, truenas/stacks/infisical-agent/

36 | truenas_docker_ipv6_fix | ✅ COMPLETED: Resolved Docker image pull timeouts by removing IPv6 pools (home network lacks IPv6 routing) | GitHub Copilot | 2026-02-11 | completed | truenas/SESSION_2026-02-11_SUMMARY.md, .github/TROUBLESHOOTING.md

37 | truenas_jellyfin_api_limitation | ✅ DOCUMENTED: Custom Apps cannot be created via API in TrueNAS 25.10.1; must use Web UI. Created DEPLOYMENT_GUIDE.md with step-by-step UI instructions | GitHub Copilot | 2026-02-11 | completed | truenas/DEPLOYMENT_GUIDE.md

38 | truenas_custom_app_deployment | ✅ COMPLETED: All Custom Apps deployed via TrueNAS Web UI (infisical-agent, jellyfin, arr-stack, downloaders) | GitHub Copilot | 2026-02-11 | completed | truenas/DEPLOYMENT_GUIDE.md, truenas/stacks/

39 | truenas_jellystat_restore | ✅ COMPLETED: Jellystat synced from Jellyfin (211 activities, 73 items). Historical workstation data not migrated. | GitHub Copilot | 2026-02-11 | completed | truenas/stacks/jellyfin/

40 | media_transfer_monitoring | ✅ COMPLETED: Media transfer done. 43 shows, 18 movies, anime, music present on /mnt/Data/media/ | GitHub Copilot | 2026-02-11 | completed | truenas/scripts/transfer_media.sh

41 | truenas_arr_stack_assessment | ✅ COMPLETED: Arr stack migration prepared. Created compose.yaml with Sonarr, Radarr, Prowlarr, Bazarr, Recyclarr, FlareSolverr, Cleanuparr. Templates created for least-privilege secrets | GitHub Copilot | 2026-02-11 | completed | truenas/stacks/arr-stack/, truenas/ARR_DEPLOYMENT.md

42 | truenas_downloader_assessment | ✅ COMPLETED: Downloader stack migration prepared. Created compose.yaml for qBittorrent and SABnzbd. VPN (gluetun) integration documented but deferred for separate assessment | GitHub Copilot | 2026-02-11 | completed | truenas/stacks/downloaders/, truenas/ARR_DEPLOYMENT.md

43 | truenas_supporting_services_assessment | ✅ COMPLETED: Supporting services included in arr-stack (FlareSolverr, Recyclarr, Cleanuparr). FileFlows deferred (requires hardware acceleration assessment) | GitHub Copilot | 2026-02-11 | completed | truenas/stacks/arr-stack/compose.yaml

44 | truenas_migration_strategy | ✅ DECIDED: Full migration strategy chosen for arr + downloaders. Phased rollout: Tailscale → Arr Stack → Downloaders. Rollback plan documented. Testing checklist included | GitHub Copilot | 2026-02-11 | completed | truenas/ARR_DEPLOYMENT.md

45 | truenas_infisical_templates | ✅ COMPLETED: Created 3 Infisical Agent templates: arr-stack.tmpl (API keys only), downloaders.tmpl (credentials), tailscale.tmpl (auth key). Updated agent-config.yaml | GitHub Copilot | 2026-02-11 | completed | truenas/stacks/infisical-agent/{arr-stack.tmpl,downloaders.tmpl,tailscale.tmpl}

46 | truenas_vpn_integration | DEFERRED: VPN (gluetun) integration for downloaders documented but not deployed. Can be added later if needed. Compose includes commented template | GitHub Copilot | 2026-02-11 | open | truenas/stacks/downloaders/compose.yaml

47 | truenas_tailscale_setup | ✅ COMPLETED: Tailscale compose and template created. Configured as subnet router for 192.168.20.0/24. Deployment guide includes auth key generation and subnet approval | GitHub Copilot | 2026-02-11 | completed | truenas/stacks/tailscale/, truenas/ARR_DEPLOYMENT.md

48 | truenas_arr_deployment | ✅ COMPLETED: All arr stack and downloader services deployed and healthy on TrueNAS. Download client hosts updated to container names. | GitHub Copilot | 2026-02-11 | completed | truenas/scripts/deploy_new_stacks.sh

49 | truenas_compose_paths_fixed | ✅ COMPLETED: Corrected all compose file paths from /mnt/truenas_docker/ and /mnt/wd_media/homelab-data/ to actual TrueNAS dataset paths /mnt/Fast/docker/ and /mnt/Data/ | Claude | 2026-02-12 | completed | truenas/stacks/*/compose.yaml

50 | truenas_download_dirs_created | ✅ COMPLETED: Created missing qBittorrent download directories and recycle bin on TrueNAS. Resolved Sonarr/Radarr RemotePathMappingCheck and RecyclingBinCheck errors. | Claude | 2026-02-12 | completed | /mnt/Data/downloads/qbittorrent/, /mnt/Data/media/.recycle

51 | truenas_homepage_remote_access | Configure Homepage to access TrueNAS containers (192.168.20.22) instead of localhost. Caddy reverse proxy or direct IP configuration needed. | Claude | 2026-02-12 | open | apps/homepage/, networking/

52 | truenas_tailscale_external_access | Set up Tailscale for external access to Jellyfin and other services. Generate auth key, deploy container, configure subnet routing. | Claude | 2026-02-12 | open | truenas/stacks/tailscale/, truenas/ARR_DEPLOYMENT.md

53 | claude_memory_review | Review and consolidate .claude/memory files to properly reference .github and ai/ folder content. Ensure consistency and remove duplication. | Claude | 2026-02-12 | open | ~/.claude/projects/-mnt-library-repos-homelab/memory/, .github/, ai/

54 | truenas_docs_review | Review truenas/ directory structure and documentation for correctness, clarity, and organization. Consolidate or restructure as needed. | Claude | 2026-02-12 | open | truenas/

55 | update_troubleshooting_docs | Document tonight's successful fixes: Prowlarr URLs, Jellystat health check, compose file updates, recycle bin permissions. | Claude | 2026-02-12 | completed | .github/TROUBLESHOOTING.md, ai/reference.md

56 | CRITICAL_migrate_infisical | Migrate Infisical server from workstation (192.168.20.66:8081) to TrueNAS. Infisical Agent on TrueNAS currently can't reach server (connection refused). All services depending on secrets will fail without this. | Claude | 2026-02-12 | open | security/infisical/, truenas/stacks/infisical-agent/

57 | standardize_kero66_password | Update kero66 password to be consistent across all services (TrueNAS, Infisical, AdGuard, etc.) for password manager storage. Currently using different passwords. | User | 2026-02-12 | open | Various services

58 | fix_workstation_docker | Docker appears to be broken on workstation (192.168.20.66). Investigate and fix, or complete full migration to TrueNAS so workstation can be shut down. | User | 2026-02-12 | open | Workstation troubleshooting

---

## Architecture & Improvements (2026-01-15)

51 | add_centralized_logging | Implement centralized logging solution (ELK stack or similar) for all homelab services | AI | 2026-01-15 | open | monitoring/, */compose.yaml

52 | implement_health_checks | Add comprehensive health checks to all services missing them, create monitoring dashboard | AI | 2026-01-15 | open | */compose.yaml, monitoring/

53 | create_backup_verification | Verify backup scripts cover all persistent data, add automated backup testing and off-site strategy | AI | 2026-01-15 | open | backup_*.sh, */README.md

54 | add_deployment_automation | Create deployment scripts with rollback capability and configuration drift detection | AI | 2026-01-15 | open | scripts/, */README.md

55 | document_service_dependencies | Create comprehensive documentation of service interdependencies, startup order, and network topology | AI | 2026-01-15 | open | docs/, README.md

56 | fix_hardcoded_ips | Replace hardcoded IPs with environment variables or service discovery (automations, proxy configs) | AI | 2026-01-15 | open | automations/compose.yml, proxy/compose.yaml

57 | bazarr_sync | Configure Bazarr to prioritize subtitle languages and providers, aligning with Anime/Standard logic | AI | 2026-01-15 | open | media/bazarr/config/config.yaml

58 | fileflows_optimization | Review and consolidate FileFlows sandbox scripts and optimize for hardware acceleration | AI | 2026-01-15 | open | media/fileflows/

59 | prowlarr_tagging | Define Prowlarr indexer tags to align with Recyclarr's Anime/Standard profiles | AI | 2026-01-15 | open | prowlarr/
60 | caddy_optional_proxies | Add Caddy routes for optional media services (FileFlows, Cleanuparr) so they are reachable whenever enabled instead of being blocked by the current proxy | GitHub Copilot | 2026-01-15 | open | networking/.config/caddy/Caddyfile, media/compose.yaml
61 | prowlarr_stats_visualization | Review and set up Exportarr + Prometheus + Grafana for Prowlarr indexer stats visualization | User | 2026-01-18 | open | monitoring/
62 | organizr_dashboard | Review and potentially set up Organizr for *arr apps dashboard | User | 2026-01-18 | open | apps/
63 | monitoring_observability_logs | Review and improve monitoring/observability/logs setup (Netdata, Beszel, centralized logging) | User | 2026-01-18 | open | monitoring/, networking/

