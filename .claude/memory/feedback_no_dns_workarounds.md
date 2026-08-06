---
name: feedback_no_dns_workarounds
description: Never edit /etc/hosts or otherwise circumvent DNS to work around resolution failures
metadata:
  type: feedback
---

Never modify /etc/hosts (or any local system DNS config) to route around a DNS resolution problem, even when it looks like the fastest fix.

**Why:** User explicitly forbade this after I attempted `sudo sh -c 'echo "192.168.20.22 infisical.home" >> /etc/hosts'` to work around infisical.home not resolving via the shell's default resolver (Infisical CLI session was bound to the `infisical.home` domain, which only resolves correctly through AdGuard at 192.168.20.22, not the default macOS resolver). Hardcoding hosts entries creates hidden, hard-to-debug divergence between this machine's name resolution and the network's real DNS.

**How to apply:** If an internal `.home` domain fails to resolve in a command's shell, do not add /etc/hosts entries or otherwise bypass DNS. Ask the user how they want to proceed instead — e.g. re-run the command with an IP-based endpoint/domain flag, fix the actual DNS/resolver config, or have the user run it themselves in a shell where resolution already works.
