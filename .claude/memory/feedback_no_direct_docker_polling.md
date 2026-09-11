---
name: feedback_no_direct_docker_polling
description: Don't poll docker inspect/ps directly over SSH for health/status checks — use Grafana/Loki (the monitoring stack) instead
metadata:
  type: feedback
---

Don't go direct to `docker inspect`/`docker ps` over SSH in a loop (or repeatedly) to check
container health or status. Use the existing monitoring stack (Grafana dashboards, Loki logs via
the datasource-proxy pattern in `ai/PATTERNS.md`) instead.

**Why:** User has corrected this multiple times ("you shouldn't be going direct to docker, how
many times do I have to tell you"). The whole point of the observability stack
([[feedback_check_docs_before_acting_not_after]], `ai/OBSERVABILITY.md`) is to answer these
questions without ad-hoc SSH polling loops.

**How to apply:** For "is X healthy/running/what's its status" — check Grafana/Prometheus/Loki
first. A single one-off `docker inspect` to confirm something immediately after a deploy is
probably fine; repeated polling loops or checking basic health that the dashboard already tracks
is not.
