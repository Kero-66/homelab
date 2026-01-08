# DO NOT RUN SCRIPTS AUTOMATICALLY

Several diagnostic scripts live under `scripts/` for Sonarr/Radarr inspection and health checks.

Safety rules:
- Scripts are intentionally non-destructive and many are disabled by default.
- To run a script that is disabled by default, set the required guard env var (example: `RUN_SONARR_INSPECT=1`).
- Do not run the scripts from CI or via automation without reviewing them first.

Files of interest:
- `sonarr_series_health_check.sh` — health-check and report; safe to run manually.
- `sonarr_inspect.sh` — low-impact inspection; disabled by default (requires `RUN_SONARR_INSPECT=1`).

If you'd like, I can add a small systemd timer / cron example and webhook integration for alerting next.
