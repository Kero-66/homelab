---
name: Do not automate Bitwarden access
description: Never suggest scripts or automation that reads from the user's Bitwarden vault
type: feedback
---

Never propose scripts, tools, or automation that reads from the user's Bitwarden vault (via `bw get`, `bw unlock`, or any Bitwarden CLI/API access).

**Why:** Any script that can read Bitwarden gives Claude (via Bash tool) access to the user's entire vault — not just the specific credentials intended. The user correctly identified this as an unacceptable security risk.

**How to apply:** For infisical authentication, the correct approach is the user manually runs `infisical login --domain http://192.168.20.66:8081` in their terminal (browser-based OAuth). Claude then uses the resulting session. If the session expires, prompt the user to re-run the login command — do not suggest Bitwarden automation as a shortcut.
