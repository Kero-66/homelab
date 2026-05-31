---
name: Troubleshooting approach - check logs first
description: Never assume a cause for a broken service; always check logs before diagnosing
type: feedback
---

When a service is broken or not loading, ALWAYS check container logs first before forming any hypothesis.

**Why:** I repeatedly jumped to "networking issue" as the first guess when services broke, which was wrong multiple times. The user had to interrupt me mid-action. The actual cause (e.g. homepage host validation, a bad env var) is always visible in the logs immediately.

**How to apply:**
1. First command for any broken service: `sudo docker logs <container> --tail 30`
2. Also check the proxy logs if relevant: `sudo docker logs caddy --tail 20`
3. Only after reading logs, form a hypothesis and act
4. Never assume networking is the issue just because services are in different stacks — the existing setup works and networking is rarely the cause
