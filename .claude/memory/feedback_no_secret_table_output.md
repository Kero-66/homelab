---
name: feedback_no_secret_table_output
description: Never run infisical secrets without --plain on a specific key — table output prints all secrets in cleartext
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ba4aedc4-f21d-45b3-84ce-dacaffe816d6
---

Never run `infisical secrets` (list/table form) without `--plain` on a specific named key. Table output exposes ALL secrets in cleartext in tool results and conversation output.

**Why:** User explicitly corrected this twice in the same session. Running the table form after being told not to is unacceptable.

**How to apply:** Only ever use `infisical secrets get <KEY> --plain`. Never use the bare `infisical secrets` table command, even with grep filtering — the secrets are printed before grep runs.
