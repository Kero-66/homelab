# AI / Project TODO

This file records suggestions, unanswered questions, and follow-ups the AI should append when the user does not answer.

Format: id | title | description | created_by | created_at | status | related_files

1 | secret_manager_choice | Choose secret manager for homelab (Vault / SOPS+KMS / cloud / local) | AI | 2025-12-16 | open | ai/ideas.md, media/config_samples/.env.sample

2 | draft_sample_files | Should AI draft `media/config_samples/.env.sample` and `media/.config/.credentials.sample` now? | AI | 2025-12-16 | open | media/config_samples/

3 | ai_standards_hook | Review value of check-ai-standards-version.sh hook for new repos/projects. Hook removed 2026-06-01 (golden repo path was hardcoded to Fedora /mnt/library, always silently exited on other machines). If reinstating: make GOLDEN_REPO configurable via AI_STANDARDS_GOLDEN_REPO env var so it works portably. Consider running in new project init workflow rather than every prompt. | AI | 2026-06-01 | open | .claude/hooks/check-ai-standards-version.sh

3 | allow_copilot_update | Permission to update `.github/copilot-instructions.md` to record AI behaviour rules (unanswered questions auto-appended to `ai/todo.md`)? | AI | 2025-12-16 | open | .github/copilot-instructions.md, ai/improve_copilot_instructions.md

4 | secret_storage_policy | Confirm preferred secret storage policy (local files only vs integrate Vault/SOPS) | AI | 2025-12-16 | open | ai/ideas.md

5 | ci_secret_scan | Add CI/pre-commit secret-scan and ensure `.sample` files exist for all tracked configs | AI | 2025-12-16 | open | .github/, .gitignore

---

Notes for AI behaviour (to be mirrored into `.github/copilot-instructions.md` and `ai/improve_copilot_instructions.md`):

- When a user question remains unanswered after a reasonable clarification attempt, append the question to `ai/todo.md` with status `open` and continue with safe non-destructive work.
- Always record external sources used into `ai/reference.md` when the AI references external documentation.
- Do not modify or commit secrets; create `.sample` files instead.

11 | better_stack_review | Re-evaluate Better Stack for external fail-safe monitoring (deferred: cloud-only) | GitHub Copilot | 2026-01-08 | open | ai/ideas.md
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

23 | cleanup_workstation_services | Optional: Stop and cleanup remaining containers on workstation (192.168.20.66) and verify cold spare status | AI | 2026-02-11 | open | /mnt/library/repos/homelab/media/

---

## TrueNAS Jellyfin Migration (2026-02-11)

46 | truenas_vpn_integration | DEFERRED: VPN (gluetun) integration for downloaders documented but not deployed. Can be added later if needed. Compose includes commented template | GitHub Copilot | 2026-02-11 | open | truenas/stacks/downloaders/compose.yaml

51 | truenas_homepage_remote_access | Configure Homepage to access TrueNAS containers (192.168.20.22) instead of localhost. Caddy reverse proxy or direct IP configuration needed. | Claude | 2026-02-12 | open | apps/homepage/, networking/

53 | claude_memory_review | Review and consolidate .claude/memory files to properly reference .github and ai/ folder content. Ensure consistency and remove duplication. | Claude | 2026-02-12 | open | ~/.claude/projects/-mnt-library-repos-homelab/memory/, .github/, ai/

54 | truenas_docs_review | Review truenas/ directory structure and documentation for correctness, clarity, and organization. Consolidate or restructure as needed. | Claude | 2026-02-12 | open | truenas/

56 | migrate_infisical_to_truenas | Migrate Infisical server from workstation (192.168.20.66:8081) to TrueNAS for centralized deployment. Current connection restored but should migrate for consistency. | Claude | 2026-02-12 | done 2026-06-18 | security/infisical/, truenas/stacks/infisical-agent/

57 | standardize_kero66_password | Update kero66 password to be consistent across all services (TrueNAS, Infisical, AdGuard, etc.) for password manager storage. Currently using different passwords. | User | 2026-02-12 | open | Various services

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

---

## Session 2026-02-14: Documentation & Tailscale Architecture

65 | tailscale_caddy_research | Research Caddy-based approach for Tailscale (user watched videos recommending this). Add as Option E to TAILSCALE_HOST_MODE_ALTERNATIVES.md | Claude | 2026-02-14 | open | truenas/TAILSCALE_HOST_MODE_ALTERNATIVES.md

66 | truenas_gitops_evaluation | Evaluate GitOps approach with dockhand for TrueNAS deployments instead of direct SSH. Document pros/cons, migration path, and recommendation. | Claude | 2026-02-14 | open | truenas/, .github/

72 | test_vscode_chat_panel_mcp | Test if Claude Code VSCode chat panel can access VSCode MCP servers (Context7, Pylance, Upstash). Compare with Copilot Chat capabilities. | User | 2026-02-14 | in_progress | ~/.config/Code/User/extensions/anthropic.claude-code-*

77 | dockhand_gitops_setup | 🔄 IN PROGRESS: Setting up Dockhand GitOps workflow for Homepage stack. Authentication working (cookie-based, credentials in Infisical at /TrueNAS path). GitOps configuration pending (likely via web UI at http://192.168.20.22:30328/). See truenas/DOCKHAND_GITOPS_GUIDE.md for procedures. Next: Configure git repo connection and auto-sync. | Claude | 2026-02-14 | in_progress | truenas/DOCKHAND_GITOPS_GUIDE.md, truenas/stacks/homepage/compose.yaml

79 | health_check_audit | Audit all compose files across stacks for broken health checks. Known issues: jellystat used curl (not installed), fixed to wget. Pattern: verify the tool used in healthcheck EXISTS in the container image before deploying. | Claude | 2026-02-18 | open | truenas/stacks/*/compose.yaml

85 | comicarr_configure | ✅ COMPLETED 2026-05-30: ix-arr-stack_default added to compose, redeployed via Dockhand. config.ini written with CV key, qBittorrent (host qbittorrent:8080, torrent_downloader=3), SABnzbd (host sabnzbd, nzb_downloader=1), Prowlarr Torznab+Newznab for 1337x/TPB/Nyaa.si/altHUB/DrunkenSlug/SceneNZB. Library paths /comics+/manga set. Pending: homepage widget (needs api_enabled=True first). | Claude | 2026-05-30 | completed | truenas/stacks/comicarr/compose.yaml

86 | comicarr_infisical | Add Infisical Agent template + init script for Comicarr so secrets (CV key, qBit creds, SABnzbd key, Prowlarr key) are re-injected into config.ini on fresh deploy. Current config.ini has secrets written directly — works but not reproducible if volume is wiped. Approach: Infisical Agent renders comicarr.env, entrypoint script maps env vars → config.ini. | Claude | 2026-05-30 | open | truenas/stacks/comicarr/, truenas/stacks/infisical-agent/

84 | mangarr_fork | Build a Radarr-based fork for manga/manhwa/webtoon acquisition. Radarr chosen as base (C#/.NET, open source, manga volumes are discrete releases like movies). Key changes: swap TheMovieDB metadata for MangaDex API, update search/matching for manga volume/chapter naming, swap quality profiles for CBZ/CBR/PDF formats, update file naming conventions. Prowlarr integration, download clients (qBittorrent/SABnzbd), UI, scheduling, notifications all reused unchanged. Prowlarr already supports manga indexers (NyaaTorrents, BakaBT etc). Intended to be open sourced — fills a real gap (Readarr retired 2026, Mangarr archived, Mylar3 has no manga support, Kapowarr rejected Prowlarr). MangaDex API: api.mangadex.org (free, no auth for basic queries). Radarr source: github.com/Radarr/Radarr | Claude | 2026-05-29 | open |

83 | watch_order_playlist_script | Build a script: given a show name, use AniDB HTTP API to get watch order (relations: sequel/prequel/movie), check Jellystat history for what's already watched, then create/update a Jellyfin playlist with remaining unwatched content in correct order. AniDB chosen over AniList — more authoritative data, already integrated in the stack. Manual process documented in ai/SESSION_NOTES.md → "Watch Order Playlists". APIs verified: Jellystat GET /api/getHistory, Jellyfin POST /Playlists. AniDB HTTP API: http://api.anidb.net:9001/httpapi — rate limit 1 req/2s, register client at anidb.net. | Claude | 2026-05-29 | open | truenas/scripts/, ai/SESSION_NOTES.md

82 | arr_stack_redeploy_network | Redeploy arr-stack on TrueNAS to apply ix-jellyfin_default network join (sonarr/radarr/bazarr need restart for change to take effect). Use midclt stop/start. | Claude | 2026-04-11 | open | truenas/stacks/arr-stack/compose.yaml

81 | subdl_re_enable | Re-enable subdl provider in Bazarr once the KeyError: 'subtitles' bug is fixed upstream. Bug: `result['subtitles']` is accessed without checking key existence in `custom_libs/subliminal_patch/providers/subdl.py` — API sometimes returns success without that key. Fix is `result.get('subtitles', [])`. Track: https://github.com/morpheus65535/bazarr — check releases for subdl fix. Config: `media/.config/bazarr/config.yaml` → `enabled_providers`. | Claude | 2026-03-31 | open | media/.config/bazarr/config.yaml

87 | mempalace_value_review | Evaluate whether MemPalace is delivering value. It saves diary + drawers at session end and now loads via SessionStart hook — but if context injected is noisy/irrelevant or token cost exceeds benefit, remove it. Review after ~4 weeks of use (target: 2026-07-01). Signals to check: does wake-up output actually inform responses? Does it surface past decisions unprompted? If not — remove plugin, Stop/PreCompact hooks, and SessionStart hook. | Claude | 2026-06-01 | open |

86 | recurring_workflow_skills | Identify repeating homelab workflows that would benefit from being Claude skills with explicit model routing (e.g. Haiku for log triage → Sonnet for fix → Haiku for summary). Candidate areas: TrueNAS service health checks, Infisical secret rotation, arr-stack health + missing media triage, Caddy config changes. Goal: spawn subagents at appropriate model tiers instead of running everything in main thread. Use write-a-skill skill to build them. | Claude | 2026-06-01 | open | .claude/skills/, ai/PATTERNS.md

83 | check_sonarr_missing_results | Sonarr SeriesSearch triggered for all 22 series with missing episodes (VOTOMS, Robotech, Tekkaman Blade, Blue Gender, Macross variants, Trigun, Gasaraki, Gundam Wing, .hack, etc.). Check http://sonarr.home/activity/queue and wanted list to see what was grabbed. autobrr filters also set up for ongoing monitoring. | Claude | 2026-05-22 | open | truenas/stacks/autobrr/seed_config.py

84 | autobrr_seed_script_test | Re-run autobrr seed_config.py on a clean instance to verify idempotency. Current live config was set up manually then script updated — needs end-to-end test. | Claude | 2026-05-22 | open | truenas/stacks/autobrr/seed_config.py

85 | bazarr_settings_api_bug | Bazarr POST /system/settings API silently ignores enabled_providers changes — only config.yaml edit works. If Bazarr is ever redeployed, re-add subf2m to enabled_providers in config.yaml before starting. | Claude | 2026-05-22 | open | /mnt/Fast/docker/bazarr/config/config.yaml

86 | animetosho_replacement | AnimeTosho is shutting down — replace it in Prowlarr. An NZB group is reportedly archiving all AnimeTosho content; find and add that indexer. Nyaa.si may cover the torrent gap. Review once AnimeTosho goes offline. | Kieran | 2026-06-13 | open | truenas/stacks/prowlarr/

88 | autobrr_version_upgrade_test | autobrr is pinned to v1.79.0 (compose.yaml) because v1.80.0 crashes on startup with a nil pointer dereference in indexer.(*service).Start — restart loop, found empirically, no matching public GitHub issue found on search. Releases since then: v1.81.0, v1.82.0, v1.82.1, v1.83.0 (as of 2026-07-27) — none of their changelogs mention a fix for this specific crash, so it's unconfirmed whether it's resolved. As a future test, bump the pin to latest and watch `docker logs autobrr` closely right after `docker compose up -d --force-recreate` for a restart loop; revert to v1.79.0 immediately if it recurs. | Kieran | 2026-08-06 | open | truenas/stacks/autobrr/compose.yaml

89 | investigate_missing_episodes | 31 monitored series currently have missing episodes in Sonarr (supersedes/updates stale #83 from 2026-05-22, which only tracked 22 shows and predates the VOTOMS/GetBackers root-cause findings from this session). Full list (id, title, files/total): 97 Armored Trooper VOTOMS 2/89, 74 Robotech 36/92, 80 Tekkaman Blade 3/55, 131 Getbackers 0/49, 55 .hack 67/96, 112 Zoids: Chaotic Century 5/34, 111 Mars Daybreak 0/26, 113 GUN×SWORD 0/26, 67 Macross 7 49/70, 95 Blue Gender 9/27, 100 VOTOMS: Pailsen Files 0/12, 117 Broken Blade 0/12, 34 Trigun 17/27, 68 Macross Frontier 30/40, 101 Macross Dynamite 7 0/8, 118 Gurren Lagann 41/49, 70 Macross 37/44, 114 Mazinkaiser 0/7, 98 VOTOMS: Phantom Chapter 0/6, 135 Armitage III 0/6, 66 GRIP. A Toyota Story 0/5, 71 Macross Zero 1/6, 99 VOTOMS: Shining Heresy 0/5, 29 Mobile Suit Gundam Wing 57/60, 133 Gundam 0083: Stardust Memory 13/16, 72 Macross II 5/7, 73 Macross Plus 4/6, 96 Gasaraki 23/25, 106 The Big O 11/13, 21 MF GHOST 0/1, 48 Attack on Titan 8/9, 56 Goblin Slayer 0/1, 129 Smoking Behind the Supermarket with You 4/5. Three confirmed root-cause patterns so far (see ai/PATTERNS.md → "Unable to parse release" for the mechanics): (1) VOTOMS + Armitage III — releases with no episode markers at all ("Complete"/compilation packs); fixed both via one-time manual override grab (shouldOverride + explicit seriesId/episodeIds/quality/languages), both confirmed downloading. (2) GetBackers — TVDB season-split vs. release group's continuous numbering; needs a persistent scene-numbering fix (proposed, not yet applied — requires explicit user confirmation before bulk-writing episode data). (3) Trigun — genuine content scarcity: the source that worked before (SacReD DVD-rip via SceneNZB) is still active but specific episodes/seasons (e.g. Robotech S2) aren't currently indexed/in retention; not a config bug, may need a batch/pack release instead of individual episode posts. Also corrected two wrong assumptions during this investigation (see feedback_verify_before_asserting.md): Robotech's gap is not about its production history, and SceneNZB is not anime-exclusive — it carries Western scene releases too (confirmed via grab history). Remaining ~27 series still need the same per-show diagnosis: check episode-level interactive search rejections before assuming any single fix applies broadly. | Claude | 2026-08-07 | open | ai/PATTERNS.md

