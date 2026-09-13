---
name: feedback_dockhand_sync_unreliable_verify_disk
description: "Dockhand git-stack sync can report success/updated:true while never actually writing the file to the live path - always diff git-repos/ vs stacks/ on disk after a sync you care about"
metadata:
  type: feedback
---

Dockhand's `POST /api/git/stacks/<id>/sync` response (`success`, `updated`, `changedFiles`) is
not reliable proof that a file actually changed on the path the container mounts from. Confirmed
twice in one session (2026-09-11, grafana-alloy, a nested `config/provisioning/dashboards/json/*.json`
file): first sync reported plain `success: true`; the SECOND time, after that first silent
failure, sync even reported `success: true, updated: true, changedFiles: [...]` and STILL didn't
write the file. Diffing `git-repos/TrueNAS/<stack>/...` (Dockhand's raw git clone, always
correct) against `stacks/TrueNAS/<stack>/...` (the live path compose actually runs from) showed
they differed both times.

**Why this matters beyond a one-off:** once a sync silently fails to write a file, Dockhand's
`lastCommit` bookkeeping already thinks it's at the target commit. Every subsequent `sync` call
for that stack reports success and does nothing more — there is no automatic retry, no error
surfaced anywhere. Only a live browser/user catching the dashboard still showing old content
revealed this; the API told a coherent, complete lie both times. See [[feedback_verify_actual_effect_not_deploy_success]] and
`.claude/memory/feedback_dockhand_git_stack_file_only_changes_need_force_recreate.md` — this is
a third, distinct failure mode in the same family (that one is about `deploy` not recreating a
container even though the file DID update; this one is about `sync` not writing the file at all).

**How to apply:** after any git-stack `sync` whose effect matters (not just "keep it eventually
consistent" background maintenance), verify by diffing the two on-disk paths directly:
```bash
ssh kero66@192.168.20.22 "sudo diff -q /mnt/.ix-apps/app_mounts/dockhand/data/git-repos/TrueNAS/<stack>/truenas/stacks/<stack>/<path> /mnt/.ix-apps/app_mounts/dockhand/data/stacks/TrueNAS/<stack>/<path>"
```
If they differ, `sudo cp` the git-repos file over the stacks file directly, then force-recreate
the affected service — don't just re-run `sync` again, it will report success and do nothing.

**Root cause found (2026-09-11), via Dockhand's own public source
(`github.com/Finsys/dockhand`, `git-deploy-policy.ts`): this same `gitUpdated` flag gates BOTH
manual `sync`+`deploy` AND the nightly `autoUpdateCron` job — `shouldDeployGitStack` only
deploys, and `shouldForceRecreateGitStack` only force-recreates, when `gitUpdated` (or
`forceRedeploy`) is true. `arr-stack`'s `mem_limit` rightsizing sat un-applied on every live
container for a full day of nightly cron runs because of this exact flag going wrong.
`forceRedeploy: true` (`PUT /api/git/stacks/<id>`, `{"forceRedeploy": true}`) is Dockhand's own
documented escape hatch — bypasses the flaky detection, always deploys+force-recreates. **This
was already identified once in a prior session and never applied or written down — that's how it
got lost.** Applied to `arr-stack` and `grafana-alloy` 2026-09-11; the other 15 git-stacks still
have it `false`. See `ai/PATTERNS.md`'s Dockhand git-stack section for the full writeup.

**Addendum (2026-09-13, confirmed live):** the two paths this memory describes are real and
independently verified — `git-repos/TrueNAS/<stack>/...` and `stacks/TrueNAS/<stack>/...` can and
do diverge (found again on `caddy`'s Caddyfile). A force-recreate run directly from the
`git-repos/` directory (per `feedback_dockhand_git_stack_file_only_changes_need_force_recreate.md`
and `feedback_docker_policy.md`) fixes the *running container* immediately, because the compose
file's relative bind mount (`./Caddyfile`) resolves against whatever directory you ran `docker
compose` from — but it does **not** update Dockhand's own `stacks/` copy, which stays stale.
This means after a manual force-recreate-from-git-repos, `stacks/TrueNAS/<stack>/` and the
container's actual live content are no longer the same directory Dockhand's own sync writes to
going forward — a future `sync` may write into `stacks/` (unused by the container now) while
`git-repos/` (what's actually mounted) only updates on the next manual recreate. Not fully
root-caused which path Dockhand intends as canonical vs. which one a given container actually
binds from at any point in time; treat every deploy as unverified until you've diffed both paths
against the container's actual content, not just one.
