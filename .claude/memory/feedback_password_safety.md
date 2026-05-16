---
name: Never expose passwords in process listings or output
description: Passwords must not appear in command-line arguments or stdout — use env vars or stdin
type: feedback
---

Never pass secrets as positional arguments to subprocesses (e.g. `python3 script.py "$PASSWORD"` or `sys.argv`). They appear in `ps aux` output and process listings.

**Why:** User explicitly flagged this as unacceptable. Even if the password doesn't appear in Claude's tool output, it's visible to other processes on the system via `ps`.

**How to apply:**
- Pass credentials to python3 via environment variables: `DH_PASS="$PASS" python3 -c "import os; os.environ['DH_PASS']"`
- Build JSON with credentials using piped stdin, not shell string interpolation in `-d '...'`
- `curl -u "user:$PASS"` is acceptable — the variable is passed as a single curl arg and doesn't print to stdout
- Never use `sys.argv` for passwords in any documented pattern
- Never `echo "$PASSWORD"` or `printf "$PASSWORD"` — these print to stdout
