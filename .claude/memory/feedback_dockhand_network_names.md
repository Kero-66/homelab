---
name: feedback-dockhand-network-names
description: TrueNAS native app docker networks are prefixed ix-, not the bare compose service name — wrong name silently fails Dockhand deploys
metadata:
  type: feedback
---

When a Dockhand-managed compose stack needs to join an existing network created by a TrueNAS native app (midclt-managed), the actual docker network name is prefixed `ix-<compose-project>_default`, not the bare `<compose-project>_default` name that appears inside that app's own `compose.yaml` in this repo.

Example: `truenas/stacks/jellyfin/compose.yaml` defines `networks: jellyfin_default: name: jellyfin_default` — but `docker network ls` on the actual host shows it as `ix-jellyfin_default`. TrueNAS's midclt app deployment silently applies the `ix-` prefix to all networks it creates; this isn't reflected in the compose file itself.

**Why:** Deployed SuggestArr via Dockhand referencing `jellyfin_default: external: true` — the Dockhand `POST /api/stacks` job returned `status: done, error: None` with **zero errors surfaced**, but `docker ps` showed no container was ever created. No error anywhere pointed at the network name being wrong; only checking `docker network ls` directly revealed the real name (`ix-jellyfin_default`).

**How to apply:** Before writing any new compose file that joins an existing TrueNAS native app's network as `external: true`, run `docker network ls | grep <app-name>` on the TrueNAS host first and use the exact name found there (with `name:` override if the compose service name differs), not the name from that app's own `networks:` block in the repo. A Dockhand deploy job reporting "done" with no error is NOT sufficient evidence the stack actually came up — always follow with `docker ps -a --filter name=<container>` to confirm the container exists and is running.
