# How To: Migrate adguard-home + tailscale to Dockhand

Follow this after `infisical-agent` (already done 2026-08-15, see `DOCKHAND_READINESS.md`). Both apps here are independent — no cross-stack networks, no env_file dependency on infisical-agent's output. Pure bind mounts to `/mnt/Fast/docker/<app>/`, so deleting the midclt app is safe: nothing lives outside those paths.

Do them one at a time, verify each before moving to the next. Order between the two doesn't matter — they don't depend on each other.

All commands below assume you're in the repo root (`/Users/kieran/repos/homelab` locally) and use `$PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"`.

---

## adguard-home

**Risk first: DNS for the whole network goes down between steps 2 and 5.** AdGuard Home is the only DNS server (no fallback configured). Do this at a low-usage time.

**Step 1 — start one ssh-agent session and keep it open for everything below** (don't kill it between steps, you need it for scp + every ssh call):

```bash
PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS \
  --domain http://192.168.20.22:8081 --projectId "$PROJECT_ID" --plain 2>/dev/null | ssh-add - 2>/dev/null
```

**Step 2 — copy the compose file over first** (it doesn't exist at the live path yet — confirmed):

```bash
scp truenas/stacks/adguard-home/compose.yaml kero66@192.168.20.22:/mnt/Fast/docker/adguard-home/compose.yaml
```

**Step 3 — check nothing else is squatting on port 53, then delete the midclt app** (`app.delete`, not `app.stop` — `app.stop` leaves the container in place still holding the name `adguard-home`, which blocks Dockhand from creating a container with that same name):

```bash
ssh kero66@192.168.20.22 "sudo midclt call -j app.delete adguard-home"
```

**Step 4 — verify the container is actually gone and port 53 is free:**

```bash
ssh kero66@192.168.20.22 "sudo docker ps -a --filter name=adguard-home --format '{{.Names}} {{.Status}}'"
ssh kero66@192.168.20.22 "sudo ss -tlnp | grep :53; sudo ss -ulnp | grep :53"
```
First command should print nothing. Second should also print nothing (if something does show up, stop and investigate before deploying — you'll get a port bind failure otherwise).

**Step 5 — stage into the Dockhand stacks path and deploy:**

```bash
ssh kero66@192.168.20.22 "sudo mkdir -p /mnt/.ix-apps/app_mounts/dockhand/data/stacks/adguard-home && sudo cp /mnt/Fast/docker/adguard-home/compose.yaml /mnt/.ix-apps/app_mounts/dockhand/data/stacks/adguard-home/compose.yaml"
ssh kero66@192.168.20.22 "sudo docker compose -f /mnt/Fast/docker/adguard-home/compose.yaml up -d"
```

**Step 6 — verify:**

```bash
ssh kero66@192.168.20.22 "sudo docker ps --filter name=adguard-home --format '{{.Names}} {{.Status}}'"
ssh kero66@192.168.20.22 "sudo docker logs adguard-home --tail 30"
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.20.22:3080
dig @192.168.20.22 jellyfin.home +short
```
`docker ps` should show `Up ... (healthy)`. The `curl` should print `200` (or `302`). `dig` should return `192.168.20.22`. If the AdGuard UI shows the first-run setup wizard instead of your existing config, stop — that means it's reading an empty/wrong conf path, don't proceed further.

**Step 7 — confirm it's off midclt's app list:**

```bash
ssh kero66@192.168.20.22 "sudo midclt call app.query 2>/dev/null | python3 -c \"import sys,json; print([a['name'] for a in json.load(sys.stdin)])\""
```
`adguard-home` should not appear.

**Step 8 — close the agent** (only after both apps are done, or now if you're stopping here):

```bash
ssh-agent -k > /dev/null
```

---

## tailscale

Same pattern. If you already closed the ssh-agent session from adguard-home, re-open it (Step 1 above) before continuing.

**Step 1** (skip if your agent session from adguard-home is still open):
```bash
PROJECT_ID="5086c25c-310d-4cfb-9e2c-24d1fa92c152"
eval $(ssh-agent -s) > /dev/null
infisical secrets get kero66_ssh_key --env dev --path /TrueNAS \
  --domain http://192.168.20.22:8081 --projectId "$PROJECT_ID" --plain 2>/dev/null | ssh-add - 2>/dev/null
```

**Step 2 — copy the compose file over:**
```bash
scp truenas/stacks/tailscale/compose.yaml kero66@192.168.20.22:/mnt/Fast/docker/tailscale/compose.yaml
```

**Step 3 — delete the midclt app** (again `app.delete`, not `app.stop`):
```bash
ssh kero66@192.168.20.22 "sudo midclt call -j app.delete tailscale"
```

**Step 4 — verify gone:**
```bash
ssh kero66@192.168.20.22 "sudo docker ps -a --filter name=tailscale --format '{{.Names}} {{.Status}}'"
```
Should print nothing.

**Step 5 — check the env file survived** (it's one of the six files `infisical-agent` re-renders; `app.delete` shouldn't touch it since it lives at `/mnt/Fast/docker/tailscale/.env`, outside the app's managed scope, but confirm before deploying):
```bash
ssh kero66@192.168.20.22 "sudo test -s /mnt/Fast/docker/tailscale/.env && echo 'present' || echo 'MISSING — stop and investigate'"
```

**Step 6 — stage and deploy:**
```bash
ssh kero66@192.168.20.22 "sudo mkdir -p /mnt/.ix-apps/app_mounts/dockhand/data/stacks/tailscale && sudo cp /mnt/Fast/docker/tailscale/compose.yaml /mnt/.ix-apps/app_mounts/dockhand/data/stacks/tailscale/compose.yaml"
ssh kero66@192.168.20.22 "sudo docker compose -f /mnt/Fast/docker/tailscale/compose.yaml up -d"
```

**Step 7 — verify:**
```bash
ssh kero66@192.168.20.22 "sudo docker ps --filter name=tailscale --format '{{.Names}} {{.Status}}'"
ssh kero66@192.168.20.22 "sudo docker logs tailscale --tail 30"
```
Logs should show `Backend state: Running`. Then check the Tailscale admin console (https://login.tailscale.com/admin/machines) — the `truenas` device should show as connected with its existing IP (100.98.14.66), not appear as a new device. If it's a new device, the state volume (`/mnt/Fast/docker/tailscale`) didn't mount — stop and check before doing anything else (don't approve a new subnet route without figuring out why first).

From another Tailscale-connected device:
```bash
ping 100.98.14.66
```

**Step 8 — confirm off midclt's list:**
```bash
ssh kero66@192.168.20.22 "sudo midclt call app.query 2>/dev/null | python3 -c \"import sys,json; print([a['name'] for a in json.load(sys.stdin)])\""
```

**Step 9 — close the agent:**
```bash
ssh-agent -k > /dev/null
```

---

## After both are done

Update `truenas/DOCKHAND_READINESS.md`'s per-stack table and deployment order (mark both ✅ Migrated with today's date) and `truenas/TRUENAS_STATE.md`'s midclt-managed app list — same edits made for infisical-agent.
