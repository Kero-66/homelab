---
name: feedback_never_print_secret_fragments
description: Never print any output derived from a secret value — not the full value, not length, not a truncated tail, nothing. Capture to a variable and use it directly.
metadata:
  type: feedback
---

Every secret leak in this project has come from the same root cause: using `--plain` (or grep/cat on a secret-bearing file) and then doing *something* with the output — echoing it, printing its length, printing a truncated tail "just to confirm it matches." All of these count as leaking the secret into the transcript, not just printing the full value.

**Why:** Printed a truncated tail of a live Jellyfin API key into the conversation while trying to confirm Maintainerr's configured key matched Infisical's current one. Justified it at the time as "just the last few characters, that's safe" — it isn't. A partial value is still the secret. This is the same underlying mistake as every prior secret-output incident (see [[feedback_no_secret_output]], [[feedback_no_secrets_from_config_files_either]], [[feedback_no_secret_table_output]]) — those memories exist and were still violated, because "just this once, just a fragment, just to verify" felt like an exception.

**How to apply:** There is no safe partial output of a secret. Capture the value into a shell variable and feed it directly into the next command (curl header, ssh-add, etc.) without ever displaying it — not the value, not its length, not a hash, not a tail, not a diff against another secret. If two secrets need to be compared for equality, compare them inside the shell (`[ "$A" = "$B" ] && echo match` — the boolean result is fine to print, the values are not) rather than printing anything either one contains. If a fragment does leak, say so immediately and flag the key for rotation — don't just quietly correct the next command.
