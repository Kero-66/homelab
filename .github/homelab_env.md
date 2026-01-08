# Homelab environment summary (auto-saved)

Date: 2025-12-26
Repository: TechHutTV/homelab (branch: main)

## Key runtime facts
- Media root: `/mnt/wd_media/homelab-data`
- Example problematic file:
  `/mnt/wd_media/homelab-data/shows/My Status as an Assassin Obviously Exceeds the Hero's/Season 1/My.Status.as.an.Assassin.Obviously.Exceeds.the.Heros.S01E11.The.Assassin.Browses.1080p.CR.WEB-DL.DUAL.AAC2.0.H.264-VARYG.mkv`
  - Size: ~1.54 GB
  - Owner: `kero66:kero66`
  - Mode: `0755`
  - SELinux context observed: `system_u:object_r:fusefs_t:s0`
- Host mount: `/dev/sdb1` mounted on `/mnt/wd_media` as FUSE (`fuseblk`) with `allow_other` (so containers/users can access).

## Jellyfin observations
- No `jellyfin.service` systemd unit on host (Unit not found).
- Jellyfin observed running (container) and also a `/usr/bin/jellyfin` process under user `kero66`.
- Logs and container details need inspection; common locations:
  - Host logs: `/var/lib/jellyfin/logs/` or `/var/log/jellyfin/`
  - Docker: `docker ps` / `docker logs <container>` / `docker inspect <container>`

## Common causes & fixes for missing episodes
1. Container missing media bind mount. Verify with:
   - `docker inspect <jellyfin-container> --format '{{json .Mounts}}' | jq .`
   - If missing, add host path to container volume mounts in compose and `docker compose up -d`.
2. Permissions/traverse issue for FUSE mounts. `allow_other` is present — confirm container user can read files.
3. Naming/parsing mismatch. Rename to match series pattern (S01E11) and rescan library.
4. Partial or temp files. Look for `.part`, `.tmp`, or similar in season folder.
5. Sonarr/automation may have moved or renamed file; check Sonarr Activity → History.

## Quick commands
- Inspect container mounts:
  - `docker ps -a --filter name=jellyfin --format '{{.Names}}'`
  - `docker inspect <container-name> --format '{{json .Mounts}}' | jq .`
- Check file permissions and SELinux context:
  - `ls -l "/mnt/wd_media/.../Season 1/<file>"`
  - `stat "/mnt/wd_media/.../Season 1/<file>"`
  - `ls -ld /mnt/wd_media /mnt/wd_media/homelab-data /mnt/wd_media/homelab-data/shows` 
- Trigger rescan (Jellyfin UI) and check logs:
  - Admin → Libraries → Scan library files
  - `docker logs <container-name> --tail 200` or host logs in `/var/lib/jellyfin/logs/`

## Notes for contributors
- Do not commit secrets or credentials into repo. Use `.env` files ignored by VCS for sensitive config.
- Validate compose changes with: `docker compose -f <file> config` before deploying.

Recorded by: assistant during troubleshooting session
