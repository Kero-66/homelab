---
name: feedback_ssh_pattern
description: Always use the ssh-agent pattern from PATTERNS.md for TrueNAS SSH — never improvise key handling
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f30b580b-5864-421b-bf6c-974d525a0a70
---

**ALWAYS use the ssh-agent pattern — never write the key to a temp file.** Pipe directly from Infisical into `ssh-add -`:

```bash
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS \
  --domain http://192.168.20.22:8081 --projectId "$INFISICAL_PROJECT_ID" \
  --plain 2>/dev/null | ssh-add - 2>/dev/null
ssh kero66@192.168.20.22 "your-command"
ssh-agent -k > /dev/null
```

**Why:** The key can go directly from Infisical into the agent's memory — no temp file needed. The temp file fallback in PATTERNS.md is broken (CRLF encoding issues) and was the wrong approach all along. User has corrected this twice.

**How to apply:** Any time SSH to TrueNAS is needed, use ssh-agent + pipe. Never create a temp file for the key.
