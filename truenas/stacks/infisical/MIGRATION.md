# Infisical Migration: Workstation → TrueNAS

**Status**: COMPLETE (2026-06-18)  
**From**: 192.168.20.66:8081  
**To**: 192.168.20.22:8081  

---

## What was done

1. **Backed up** workstation postgres DB via `docker exec infisical-db pg_dump`
2. **Created dirs** on TrueNAS: `/mnt/Fast/docker/infisical/`, `/mnt/Fast/databases/infisical/{postgres,redis}/`
3. **Deployed via Dockhand** — NOT midclt (see gotcha below)
4. **Copied DB** via `sudo rsync` of the postgres data directory (live copy while workstation DB running)
5. **Restarted** TrueNAS infisical-db/infisical to pick up restored data
6. **Updated** infisical-agent config to point at `192.168.20.22:8081` and restarted
7. **Stopped** workstation infisical

---

## Dockhand /mnt/Fast mount

Dockhand runs in a container. By default it only has `/var/run/docker.sock` mounted, so
`env_file: /mnt/Fast/...` paths fail at deploy time.

**Fix applied 2026-06-18**: Added `/mnt/Fast` host path mount to Dockhand via TrueNAS REST API:
```bash
curl -sk -X PUT -H "Authorization: Bearer $TRUENAS_API" -H "Content-Type: application/json" \
  -d '{"values": {"storage": {"data": {"type": "ix_volume", "ix_volume_config": {"acl_enable": false, "dataset_name": "data"}}, "additional_storage": [{"type": "host_path", "read_only": false, "mount_path": "/mnt/Fast", "host_path_config": {"acl_enable": false, "path": "/mnt/Fast"}}]}}}' \
  "https://192.168.20.22/api/v2.0/app/id/dockhand"
```

Note: `midclt call app.update` does NOT work for this (rejects all fields as "extra inputs").
Use the REST API with a `{"values": {...}}` wrapper instead.

After this fix, `env_file` in Dockhand stacks resolves correctly and `compose.yaml` can be
deployed as-is.

---

## Rollback

Workstation infisical containers are stopped (not removed). To roll back:
```bash
cd /path/to/homelab/security/infisical
docker compose up -d
# Update infisical-agent config back to 192.168.20.66:8081 and restart
```

---

## Post-migration: backup

Set up a cron on TrueNAS to dump DB periodically. See `backup.sh` in this directory.

```bash
# On TrueNAS — add to kero66 crontab
crontab -e
# Add: 0 3 * * * bash /mnt/Fast/docker/infisical/backup.sh >> /mnt/Fast/docker/infisical/backup.log 2>&1
```
