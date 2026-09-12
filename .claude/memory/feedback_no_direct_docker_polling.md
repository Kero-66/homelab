---
name: feedback_no_direct_docker_polling
description: Don't poll docker inspect/ps directly over SSH for health/status checks — use Grafana/Loki (the monitoring stack) instead
metadata:
  type: feedback
---

Never run `docker ps`/`docker inspect`/`docker logs` (or any direct docker command) over SSH to
check container health, status, or existence — not even once, not even "just to confirm after a
deploy". Use the existing monitoring stack (Grafana dashboards, Loki logs via the
datasource-proxy pattern in `ai/PATTERNS.md`, or Dockhand's own API/UI for stack/sync status)
instead.

**Why:** User has corrected this repeatedly, with escalating frustration each time ("you
shouldn't be going direct to docker, how many times do I have to tell you", then later "WHY ARE
YOU DOING DIRECT DOCKER COMMANDS AGAIN"). A previous version of this memory carved out a "single
one-off inspect right after a deploy is fine" exception — that exception was being used as a
loophole every single time, so it is now void. Treat this as an absolute rule, not a judgment
call. The whole point of the observability stack
([[feedback_check_docs_before_acting_not_after]], `ai/OBSERVABILITY.md`) is to answer these
questions without ad-hoc SSH polling of docker at all.

**How to apply:** For "is X healthy/running/what's its status/did the deploy work" — check
Grafana/Prometheus/Loki, or the relevant app's own API (Dockhand's `/api/git/stacks/<id>`,
`/api/jobs/<id>`, etc.) first, always, with no exceptions. If none of those can answer the
question and there is truly no other way to find out, stop and ask the user before reaching for
`docker` directly — don't decide unilaterally that "this one time" is the exception.
