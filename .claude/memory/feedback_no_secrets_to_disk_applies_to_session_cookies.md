---
name: feedback_no_secrets_to_disk_applies_to_session_cookies
description: The Dockhand cookie-jar pattern in PATTERNS.md writes a live session cookie to a mktemp file — this violates the no-secrets-to-disk rule and must not be copied as-is
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ea1453dc-a224-4546-9eb2-6afca3367b7b
  modified: 2026-08-18T12:32:20.122Z
---

`ai/PATTERNS.md`'s documented Dockhand auth pattern uses `curl -c "$COOKIE_JAR"` with `COOKIE_JAR=$(mktemp)` to capture the session cookie, then `rm -f` at the end. This writes a live authentication credential to disk, even if briefly and even if cleaned up — the user reacted strongly to this when it happened, treating it the same as printing a password to stdout would be treated. See [[feedback_no_secrets_to_disk_ever]].

**Why:** A session cookie is a bearer credential — anyone who reads it during its window on disk has full API access, same severity as a password or API key. "It gets deleted after" doesn't change that it existed on disk at all, and matches the existing house rule that this is not a judgment call by exposure window or key scope.

**How to apply:** Never use `curl -c <file>` for the Dockhand (or any) session cookie. Instead capture it into a shell variable directly, e.g. use `curl -s -D - -o /dev/null` to capture headers to stdout and extract the `Set-Cookie` value with `grep`/`sed` into a variable, then pass it back via `-H "Cookie: ..."` on subsequent requests. If `PATTERNS.md`'s documented pattern is ever consulted again, it should be corrected to this variable-based approach rather than copied as-is with the mktemp cookie jar.
