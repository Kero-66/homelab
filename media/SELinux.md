# SELinux notes for the Media stack

Summary
-------
This documents the SELinux fix applied after restoring files from Windows. The problem was host files under the repository copied from Windows had no SELinux file contexts (showed as `unlabeled_t`), which prevented container processes from accessing them. The persistent fix was to add a file-context rule and run `restorecon` to apply `container_file_t` recursively.

Why this happened
-----------------
- Files restored from Windows (NTFS) or copied without preserving SELinux xattrs lose file contexts and appear as `unlabeled_t` on an SELinux-enabled Linux host.
- Containers running in the container domain need host objects mounted with appropriate types (commonly `container_file_t`) to permit access.

Applied fix (commands run)
--------------------------
1. Add a persistent fcontext rule for the media tree (replace path if different):

```bash
sudo semanage fcontext -a -t container_file_t '/mnt/library/repos/homelab/media(/.*)?'
```

2. Apply the contexts recursively:

```bash
sudo restorecon -Rv /mnt/library/repos/homelab/media
```

What this does
--------------
- `semanage fcontext` records a persistent mapping so SELinux will label new files created under the path correctly.
- `restorecon` updates current filesystem objects to the recorded context.

Verification
------------
- Check labels:

```bash
ls -ldZ /mnt/library/repos/homelab/media /mnt/library/repos/homelab/media/*
```

- Focused AVC check (requires sudo) to ensure no container denials remain for the media tree:

```bash
sudo ausearch -m avc --raw | grep container_t | grep '/mnt/library/repos/homelab/media' -C3 || true
```

Alternatives and notes
----------------------
- For ephemeral or one-off mounts you can use volume relabel flags in Compose (`:Z` or `:z`) to relabel at mount time.
- For quick tests use `chcon -R -t container_file_t <path>` but this is not persistent across a `restorecon` or labeling policy changes.
- Avoid using `audit2allow` to create broad policy exceptions unless you fully understand the security implications.

Rollback
--------
To remove the persistent rule:

```bash
sudo semanage fcontext -d '/mnt/library/repos/homelab/media(/.*)?'
sudo restorecon -Rv /mnt/library/repos/homelab/media
```

References
----------
- `man semanage`
- `man restorecon`
- SELinux container labeling patterns and Docker/Podman docs about `:Z`/`:z` volume flags.

Last updated: 2025-12-17
