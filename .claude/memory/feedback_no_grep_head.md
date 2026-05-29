---
name: feedback_no_grep_head
description: Do not pipe curl/command output through grep or head — always read raw output first
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9e9fe0ec-0e36-4383-a8fb-7fb8b8a74370
---

Do not pipe command output through grep, head, tail, or similar filters on the first attempt.

**Why:** Over-filtering hides the actual response (status codes, error messages, redirects) and wastes time. User has corrected this multiple times.

**How to apply:** Run the bare command first, read the full output, then filter only if output is too large to reason about.
