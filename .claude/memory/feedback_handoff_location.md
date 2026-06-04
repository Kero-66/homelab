---
name: feedback_handoff_location
description: Handoff files live in ai/handoff-YYYY-MM-DD.md in the repo — always check before writing to avoid overwrites
metadata:
  type: feedback
---

Handoff files are stored at `ai/handoff-YYYY-MM-DD.md` in the homelab repo — not in `/tmp` or any OS temp dir.

**Why:** The skill default writes to OS temp dir, but this project keeps handoffs in the repo for persistence and git history.

**How to apply:** Before writing a handoff, check `ls ai/handoff*.md`. If today's date exists, append to it rather than creating a new file or overwriting.
