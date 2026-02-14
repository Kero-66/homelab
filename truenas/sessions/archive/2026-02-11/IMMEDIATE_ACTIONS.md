# IMMEDIATE ACTION ITEMS - TrueNAS Migration 2026-02-11

## 🔴 CRITICAL #1: FIX JELLYFIN LIBRARY PATHS

**Status**: BLOCKING - Users cannot watch content

**Problem**: 
- Jellyfin configured to look in `/data/shows` and `/data/movies`
- Media actually stored at `/data/media/shows` and `/data/media/movies`
- Libraries appear empty in UI

**Solution (Pick ONE - Option A is simplest)**:

### Option A: Update via Jellyfin Web UI (FASTEST)
1. Open: http://192.168.20.22:8096
2. Click: Dashboard → Settings → Libraries
3. Click: TV Shows
4. **Change folder path FROM** `/data/shows` **TO** `/data/media/shows`
5. Save & Refresh
6. Repeat for Movies library (change FROM `/data/movies` TO `/data/media/movies`)
7. Click refresh/rescan on each library
8. Verify: Movies should show 11 items, TV Shows should show content

### Option B: Update Compose File (PERMANENT FIX)
```bash
# Verify current config
ssh root@192.168.20.22 'docker inspect jellyfin | jq ".[0].Mounts"'

# Check where media is mounted
ssh root@192.168.20.22 'docker exec jellyfin ls -l /data/'

# Expected output should show /data/media exists

# If jellyfin compose is in truenas/stacks/jellyfin/compose.yaml:
# Change volumes from:
#   - /mnt/Data/media:/data/movies
#   - /mnt/Data/media:/data/shows
# To:
#   - /mnt/Data/media:/data/media
# Then recreate container
```

### Option C: Update Database Directly (IF UI doesn't work)
```bash
ssh root@192.168.20.22

# Stop Jellyfin
docker stop jellyfin

# Check library paths
sqlite3 /mnt/Fast/docker/jellyfin/config/data/data/jellyfin.db \
  "SELECT Id, Name, Path FROM MediaItems WHERE Path LIKE '%/data/shows%' OR Path LIKE '%/data/movies%';"

# Update paths
sqlite3 /mnt/Fast/docker/jellyfin/config/data/data/jellyfin.db \
  "UPDATE MediaItems SET Path = REPLACE(Path, '/data/shows', '/data/media/shows') WHERE Path LIKE '%/data/shows%';"
sqlite3 /mnt/Fast/docker/jellyfin/config/data/data/jellyfin.db \
  "UPDATE MediaItems SET Path = REPLACE(Path, '/data/movies', '/data/media/movies') WHERE Path LIKE '%/data/movies%';"

# Restart
docker start jellyfin

# Verify
curl http://localhost:8096/health
```

**Validation**:
```bash
# After fix, verify media is found
ssh root@192.168.20.22 'docker logs jellyfin --tail 50 | grep -i "found\|media\|library"'

# Check from workstation
curl http://192.168.20.22:8096/web/ # Should show content in libraries
```

---

## 🔴 CRITICAL #2: MIGRATE JELLYSTAT DATABASE

**Status**: BLOCKING - Jellystat can't connect to database

**Problem**:
- Jellystat running on TrueNAS with empty PostgreSQL database
- 71MB backup exists on workstation with historical data
- Previous restore attempt failed due to SSH pipe cancellation

**Solution (USE SEPARATE TERMINALS - DO NOT CHAIN WITH PIPES)**:

### Step 1: Create Backup on Workstation (Terminal A)
```bash
# On workstation, fresh shell
docker start jellystat-db
sleep 5

# Verify it started
docker ps | grep jellystat-db

# Create full dump
docker exec jellystat-db pg_dumpall -U postgres > /tmp/jellystat-backup.sql

# Verify file created
ls -lh /tmp/jellystat-backup.sql  # Should be ~11MB
head -20 /tmp/jellystat-backup.sql  # Should show "PostgreSQL database cluster dump"
```

### Step 2: Transfer to TrueNAS (Terminal B - different shell)
```bash
# Wait for Step 1 to complete fully, then:
# (On workstation)

ls -lh /tmp/jellystat-backup.sql  # Verify it exists

# Transfer to TrueNAS
scp /tmp/jellystat-backup.sql root@192.168.20.22:/tmp/jellystat-restore.sql

# Verify transfer
ssh root@192.168.20.22 'ls -lh /tmp/jellystat-restore.sql'  # Should be ~11MB
```

### Step 3: Restore on TrueNAS (Terminal C - different shell)
```bash
# Wait for Step 2 to complete fully, then:
# (On any machine with SSH access to TrueNAS)

ssh root@192.168.20.22 'docker stop jellystat'

# Verify stopped
ssh root@192.168.20.22 'docker ps | grep jellystat'  # Should not show jellystat

# Restore database IN SEPARATE SHELLS (do NOT pipe)
ssh root@192.168.20.22 'cat /tmp/jellystat-restore.sql | docker exec -i jellystat-db psql -U postgres'

# Wait for this to complete (may take 1-2 minutes)
ssh root@192.168.20.22 'sleep 120 && docker start jellystat'

# Verify restoration
ssh root@192.168.20.22 'docker logs jellystat --tail 30'  # Should not show auth errors
```

### Alternative if Step 3 still fails:
```bash
# Use file instead of pipe
ssh root@192.168.20.22 'docker exec -i jellystat-db psql -U postgres < /tmp/jellystat-restore.sql'

# Or restore directly
ssh root@192.168.20.22 << 'EOF'
docker stop jellystat
docker exec -i jellystat-db psql -U postgres -f /tmp/jellystat-restore.sql
docker start jellystat
EOF
```

**Validation**:
```bash
# Check Jellystat logs
ssh root@192.168.20.22 'docker logs jellystat --tail 20'

# Should NOT see "FATAL" auth errors (code 28P01)

# Verify data was restored
ssh root@192.168.20.22 'docker exec jellystat-db psql -U postgres -d jfstat -c "SELECT COUNT(*) FROM jf_libraries;"'

# Should return a number > 0 (not 0)

# Access Jellystat
curl http://192.168.20.22:3002/
```

---

## ✅ POST-FIX VALIDATION CHECKLIST

After both fixes, run these commands:

```bash
# 1. All services healthy?
ssh root@192.168.20.22 'docker ps --format "table {{.Names}}\t{{.Status}}"'
# All should show "Up X minutes (healthy)"

# 2. Jellyfin can find media?
ssh root@192.168.20.22 'docker exec jellyfin find /data/media -name "*.mkv" | wc -l'
# Should return 100+

# 3. Jellyfin libraries populated?
curl http://192.168.20.22:8096/Items?IncludeItemTypes=Movie | jq '.TotalRecordCount'
# Should be 11 or more

# 4. Jellystat database restored?
ssh root@192.168.20.22 'docker exec jellystat-db psql -U postgres -d jfstat -c "SELECT COUNT(*) FROM jf_libraries;"'
# Should return > 0

# 5. Try playing a video
# Visit http://192.168.20.22:8096/web/ → Select a movie/show → Click Play
# Should start playback without "file not found" errors
```

---

## 📋 TROUBLESHOOTING

**If Jellyfin library still empty after path fix**:
```bash
# Force rescan
ssh root@192.168.20.22 'docker exec jellyfin curl -X POST http://localhost:8096/Libraries/Refresh'

# Check container can read files
ssh root@192.168.20.22 'docker exec jellyfin ls -la /data/media/shows | head -5'

# Check ownership
ssh root@192.168.20.22 'ls -la /mnt/Data/media/shows | head -5'
# Should show kero66:kero66 (UID 1000:1000) ownership
```

**If Jellystat still can't connect**:
```bash
# Check PostgreSQL is running
ssh root@192.168.20.22 'docker ps | grep jellystat-db'

# Check credentials
ssh root@192.168.20.22 'docker logs jellystat --tail 50 | grep -i "pass\|auth\|error"'

# Try connecting directly
ssh root@192.168.20.22 'docker exec jellystat-db psql -U postgres -c "\\l"'
# Should list databases including "jfstat"
```

**If Jellystat shows "127 FPS" errors**:
- This means database restored but queries taking too long (performance, not failure)
- Just wait for initial sync to complete, it's normal

---

## 📝 SUCCESS CRITERIA

- ✅ Jellyfin web UI shows non-empty Movies and TV Shows libraries
- ✅ Can click on a title and see metadata/description
- ✅ Can click Play and video starts streaming (or transcoding)
- ✅ Jellystat dashboard accessible at http://192.168.20.22:3002
- ✅ Jellystat shows historical playback data (not empty database)
- ✅ No auth/connection errors in any service logs

---

**Related Documentation**: [Multi-session context at ai/sessions/migration-2026-02-11.md](ai/sessions/migration-2026-02-11.md)
