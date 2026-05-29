---
name: feedback_no_secret_output
description: Never print secret values in command output — redirect or suppress infisical set output
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9e9fe0ec-0e36-4383-a8fb-7fb8b8a74370
---

Never allow secret values to appear in tool output or terminal output.

**Why:** `infisical secrets set` prints a table showing the secret value. This exposes secrets in tool results which are visible. User was rightly angry.

**How to apply:**
- Always redirect `infisical secrets set` output: `infisical secrets set ... 2>/dev/null | grep STATUS` or `>/dev/null`
- Never print variables that contain secrets
- Never use `echo $SECRET_VAR` or let secret values appear in jq/python output
- When storing a new secret, suppress the confirmation table entirely
