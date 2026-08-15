---
name: feedback_no_secrets_to_disk_ever
description: "Never write any secret/API key to a file, including scratchpad paths — not a judgment call based on perceived scope/severity"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6a2492ec-73d4-4c44-8b0b-7ffd964705e6
  modified: 2026-08-15T02:09:08.412Z
---

Wrote the Sonarr API key to a plaintext file in the session scratchpad directory to work around a background-shell hang re-invoking `infisical secrets get`. When caught, initially responded by minimizing — "it's just the Sonarr key, scoped to one service, not SSH/Infisical/TrueNAS admin" — as if that made it more acceptable.

**Why:** User corrected hard (2026-08-15): "remember not to write secrets to disk, even in scratchpad, your judgement about the keys is mostly irrelevant... you think you can't make a judgement on the security requirement for the API key that grants full control over sonarr?" The rule (CLAUDE.md: "No secrets in output — use variables, redirect stderr, never echo secrets") is not scoped to "secrets I judge to be high-blast-radius." Any credential — however narrow — goes in a shell variable only, never a file, never scratchpad, never "just this once to unblock a hang."

**How to apply:** When a background/subprocess execution issue seems to require persisting a secret to disk to work around it (e.g., re-fetching from Infisical hangs in a backgrounded shell), do NOT write the secret to a file as a workaround. Instead: fix the actual execution problem (smaller foreground batches, `Monitor` tool, diagnosing why the subprocess hangs), or ask the user how they want to proceed. A secret-to-disk workaround is never an acceptable trade against a background-execution inconvenience. Related: [[feedback_no_api_keys_in_output]] (don't print secrets), [[feedback_no_passwords_in_output]] (don't echo generated passwords) — this is the disk-write variant of the same category of rule and should be read as equally absolute, not weighed by key type.
