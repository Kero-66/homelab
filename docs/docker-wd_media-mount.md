**Docker Wait For /mnt/wd_media**

- **Drop-in installed:** /etc/systemd/system/docker.service.d/override.conf

- **Drop-in contents:**
```
[Unit]
RequiresMountsFor=/mnt/wd_media
```

- **What this does:** systemd will make `docker.service` depend on the mount unit for `/mnt/wd_media` so Docker will not start (or be restarted) until the mount unit has been processed.

- **fstab recommendation:** ensure the `/etc/fstab` entry for the drive is correct (partition UUID, not a folder). Example options that work well:

Mount-on-boot (wait up to 30s for device):
```
UUID=24E032B8E0329052  /mnt/wd_media  ntfs-3g  defaults,uid=1000,gid=1000,umask=022,x-systemd.device-timeout=30  0  0
```

If you prefer automount on first access (avoids boot-time race):
```
UUID=24E032B8E0329052  /mnt/wd_media  ntfs-3g  defaults,uid=1000,gid=1000,umask=022,nofail,x-systemd.automount  0  0
```

- **Notes on behavior:**
  - `nofail` lets boot continue even if the device is absent; combined with `RequiresMountsFor`, Docker may still be delayed or fail depending on timeouts. Remove `nofail` to expose mount failures at boot.
  - `x-systemd.device-timeout=` makes systemd wait for the device for the specified seconds before timing out.
  - `x-systemd.automount` defers the actual mount until the first access and avoids boot-time failures; use this when the drive may not be immediately ready.

- **Verification commands:**
```
sudo systemctl daemon-reload
sudo systemctl status docker --no-pager -n 5
findmnt /mnt/wd_media
sudo journalctl -b | egrep -i 'mnt-wd_media|ntfs|24E032B8E0329052'
```

- **Safety / operational notes:**
  - I installed the drop-in file but did not restart Docker; the drop-in affects future starts/restarts only.
  - If Docker must come up even when the drive is unavailable, prefer `x-systemd.automount` or keep `nofail` and accept missing volumes at boot.

If you want me to switch the `fstab` entry from `x-systemd.automount` to `x-systemd.device-timeout=30` (or remove `nofail`), tell me which behavior you prefer and I will update `/etc/fstab` and document the change.
