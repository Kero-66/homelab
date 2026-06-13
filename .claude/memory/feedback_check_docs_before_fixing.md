---
name: feedback_check_docs_before_fixing
description: Check docs and established patterns before applying fixes — don't assume the fix, verify it
metadata:
  type: feedback
---

Don't jump to applying a fix just because the cause looks obvious. Check docs and existing patterns first, especially for permissions/ownership changes which can have security implications.

**Why:** User stopped a `chown` command because I assumed the fix without verifying it against docs or the established permission pattern for that service.

**How to apply:** When a fix seems obvious (e.g. chown to match other dirs), still pause and check: (1) service docs for expected ownership, (2) existing working dirs for the established pattern, (3) whether the proposed change matches both. Only then proceed — or present findings and ask for confirmation on destructive/security-relevant changes.
