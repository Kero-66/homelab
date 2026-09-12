---
name: feedback_dockhand_git_stack_delete_leaves_containers
description: "DELETE /api/git/stacks/<id> only removes Dockhand's DB record — it does NOT stop or remove the actual containers, leaving them behind as an orphaned 'Untracked' stack"
metadata:
  type: feedback
---

`DELETE /api/git/stacks/<id>` (used to tear down a Dockhand-managed git stack) only deletes
Dockhand's own tracking record for that stack. It does **not** run `docker compose down` and does
**not** stop or remove the underlying containers. Confirmed 2026-09-12 tearing down SigNoz
(git-stack id 16): the DELETE returned `{"success":true}`, and both `/api/git/stacks` and
`/api/stacks` immediately showed no `signoz` entry — but the actual containers kept running.
Dockhand's own container discovery then re-surfaced them as a separate, new "Untracked" stack
entry (status `stopped` once the containers eventually exited, 3-4 containers, source
`Untracked`, not `Git`) — a *different* stack record than the one just deleted, not the same one
resurrected.

**Why this matters:** it makes a git-stack teardown look complete (git-stacks API, and even
`/api/stacks`, briefly agree it's gone) when it isn't. The user caught this from the Dockhand UI
directly ("it's clearly still in dockhand") after every API check I ran said otherwise — the UI
was right, my API-only verification was incomplete. See [[feedback_verify_actual_effect_not_deploy_success]]
for the general pattern this repeats: an API success response is not proof of the real end state.

**The follow-up bug, still unresolved (2026-09-12):** the documented internal-stack removal path
(`DELETE /api/stacks/<name>`, per `truenas/DOCKHAND_GITOPS_GUIDE.md` — previously used
successfully for `maintainerr`) failed for this orphaned `signoz` entry with a 500 and, per
Dockhand's own logs (via Loki, `container_name="ix-dockhand-dockhand-1"`), the underlying error
`Error removing compose stack: Error: No environment specified`. Tried `?environmentId=1`,
`?environment=1`, `?envId=1`, `?env=TrueNAS` as query params — same error every time. Not
resolved via API; had to fall back to deleting it manually via the Dockhand web UI's trash icon
on that stack's row.

**How to apply — until Dockhand's git-stack delete is confirmed to actually tear down
containers:**
1. After `DELETE /api/git/stacks/<id>`, don't trust `/api/git/stacks` or `/api/stacks` alone —
   check the Dockhand **UI's** Stacks page (or ask the user to) for a leftover "Untracked" entry
   with the same name.
2. If one appears, do not keep guessing at `DELETE /api/stacks/<name>` query params — it errored
   identically on every param tried. Use the Dockhand UI's own delete/trash action on that stack
   row instead.
3. Consider, before deleting a git stack going forward, first stopping it (find and use whatever
   "stop" action Dockhand exposes for that stack) so containers are actually brought down before
   the tracking record disappears — this might avoid creating the orphaned "Untracked" entry in
   the first place. Not yet verified as a fix; flagged as the next thing to try.
4. File a note in `truenas/DOCKHAND_GITOPS_GUIDE.md` under a "Tearing down a stack" section (see
   `ai/todo.md` for the tracking item) once this is actually root-caused, so the next teardown
   doesn't repeat the same false-clean verification.
