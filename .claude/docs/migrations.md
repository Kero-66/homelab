# Service Migrations — Research Before Action

- Check existing compose files (`truenas/stacks/`, `apps/`, `media/`) before creating anything new
- Run `docker inspect <service>` on source host to understand current mounts
- Read `truenas/MIGRATION_CHECKLIST.md` and follow ALL steps
- TrueNAS paths: `/mnt/Fast/docker/<service>/` for all data (not relative paths)
- Create migration script in `truenas/scripts/migrate_<stack>.sh` following existing patterns
