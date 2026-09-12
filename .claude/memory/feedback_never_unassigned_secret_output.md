---
name: feedback_never_unassigned_secret_output
description: Never run `infisical secrets get ... --plain` (or any secret fetch) without capturing straight into a variable — printing to check "does this exist" leaks the value
metadata:
  type: feedback
---

Ran `infisical secrets get SHOKO_API_KEY --env dev --path /media ... --plain 2>&1` directly (not `VAR=$(...)`) just to check whether the secret existed, intending the `2>&1` to only surface the CLI's update-nag text. Instead it also printed the real key value to visible tool output in the conversation transcript — a live credential exposure caught by the user, not by me.

**Why:** Any secret-fetching command must be captured into a shell variable in the same breath it's invoked. There is no safe way to "peek" at whether infisical returns a real value by letting its stdout render directly — even `2>&1` for exit codes/error-text purposes drags the payload along, and a bare invocation with no redirection at all is just as exposed. The existing `feedback_no_secret_output.md` covered replaying/echoing an already-fetched secret; this is the same failure at the fetch step itself.

**How to apply:** Every `infisical secrets get` (and equivalent for any other secret store) must be written as `VAR=$(infisical secrets get KEY ... --plain 2>/dev/null)` — capture first, inspect only `${#VAR}` (length) or a grep against the captured variable for existence/format checks, never let the raw call run bare or with `2>&1` un-captured. If a leak happens anyway, treat the value as compromised immediately: rotate/regenerate it and update every place it's stored, don't rationalize the exposure as "low risk because it's LAN-only."
