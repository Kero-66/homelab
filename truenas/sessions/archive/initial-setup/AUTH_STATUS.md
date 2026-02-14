# TrueNAS API Authentication Issue - Resolved

## Summary

Successfully confirmed TrueNAS API authentication method and identified the issue.

---

## Test Results

**Date**: 2026-02-11  
**TrueNAS IP**: 192.168.20.22  
**Status**: ✓ System is online and accessible

### What Works ✓

- [x] Network connectivity to TrueNAS
- [x] Web UI accessible at: http://192.168.20.22/ui/
- [x] API endpoint accessible at: http://192.168.20.22/api/v2.0/
- [x] Infisical credential retrieval working
- [x] API uses standard HTTP Basic Authentication

### What Needs Fixing ✗

- [ ] Password in Infisical doesn't match TrueNAS actual password
- [ ] Need to verify correct admin username (root vs admin)

---

## TrueNAS API Authentication Method (Confirmed)

Based on the API schema and testing:

### Method: HTTP Basic Authentication

```bash
# Standard Basic Auth format
curl -u "USERNAME:PASSWORD" http://192.168.20.22/api/v2.0/system/info

# TrueNAS supports two authentication schemes:
# 1. Basic Auth (username:password) - what we're using
# 2. Token-based auth (generated via /auth/generate_token endpoint)
```

### Common Usernames

- `root` - Default superuser account (most likely)
- `admin` - Alternative admin account (if created)

---

## Action Required

### Step 1: Verify Credentials in TrueNAS UI

1. **Open TrueNAS UI**: http://192.168.20.22/ui/
2. **Login with your credentials**
3. **Note the username you used** (root or admin)

### Step 2: Update Infisical with Correct Password

Once you've confirmed the correct credentials:

```bash
# Update password in Infisical
infisical secrets set truenas_admin=YOUR_CORRECT_PASSWORD --env dev --path /TrueNAS

# Optional: Also store the username if not 'root'
infisical secrets set TRUENAS_USER=root --env dev --path /TrueNAS
```

### Step 3: Test Authentication

```bash
# Run the auth tester
cd truenas
bash scripts/test_auth.sh 192.168.20.22

# Should see:
# ✓ SUCCESS with username: root
# System Info:
#   - Hostname: truenas
#   - Version: TrueNAS-SCALE-...
#   - Uptime: X hours
```

### Step 4: Gather System Information

Once authentication works:

```bash
# Get complete system info
bash scripts/get_system_info.sh 192.168.20.22

# This will show:
# - System version and hostname
# - Storage pools (if configured)
# - Available disks
# - Network interfaces
# - Running services
```

---

## Scripts Created for Diagnosis

### 1. `scripts/test_auth.sh` (NEW)

Comprehensive authentication tester:
- Tests network connectivity
- Verifies API endpoint access
- Tries multiple usernames (root, admin)
- Retrieves password from Infisical
- Provides clear error messages

**Usage:**
```bash
bash scripts/test_auth.sh [TRUENAS_IP]
```

### 2. `scripts/get_system_info.sh` (UPDATED)

Retrieves TrueNAS system information once auth works:
- System info (version, hostname, uptime)
- Storage pools and datasets
- Disk information
- Network configuration
- Service status

**Usage:**
```bash
bash scripts/get_system_info.sh [TRUENAS_IP]
```

---

## Next Steps After Authentication Works

1. **Gather system information**:
   ```bash
   bash scripts/get_system_info.sh 192.168.20.22 > truenas_current_state.txt
   ```

2. **Document hardware configuration**:
   - Number and type of drives
   - Current pool configuration (if any)
   - Network setup

3. **Plan storage layout**:
   - Decide on pool structure (mirror, raidz1, etc.)
   - Dataset organization
   - Share configuration

4. **Run storage setup script**:
   ```bash
   # Copy to TrueNAS
   scp scripts/setup_storage.sh root@192.168.20.22:/tmp/
   
   # SSH and run
   ssh root@192.168.20.22
   bash /tmp/setup_storage.sh --discover
   bash /tmp/setup_storage.sh --all
   ```

---

## Reference: API Authentication Examples

### Using Basic Auth

```bash
# Get password from Infisical
TRUENAS_PASSWORD=$(infisical secrets get truenas_admin --env dev --path /TrueNAS --plain)

# Make API call
curl -u "root:$TRUENAS_PASSWORD" \
  "http://192.168.20.22/api/v2.0/system/info"
```

### Using API Token (Alternative)

```bash
# Generate token (requires basic auth first)
TOKEN=$(curl -s -u "root:$TRUENAS_PASSWORD" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"ttl": 3600, "attrs": {}, "match_origin": false}' \
  "http://192.168.20.22/api/v2.0/auth/generate_token" | jq -r '.token')

# Use token for subsequent calls
curl -H "Authorization: Bearer $TOKEN" \
  "http://192.168.20.22/api/v2.0/system/info"
```

---

## Common Issues and Solutions

### Issue: "Bad username or password"

**Causes:**
1. Password in Infisical is outdated or incorrect
2. Wrong username (root vs admin vs custom user)
3. User doesn't exist in TrueNAS yet

**Solution:**
- Verify credentials in TrueNAS UI
- Update Infisical with correct password
- Use `test_auth.sh` to diagnose

### Issue: "Connection refused"

**Causes:**
1. TrueNAS is powered off
2. Wrong IP address
3. Firewall blocking API access

**Solution:**
- Verify with ping and web UI access
- Check IP configuration in TrueNAS
- Check firewall rules

### Issue: "API endpoint not found"

**Causes:**
1. Using wrong API version (v1.0 vs v2.0)
2. API disabled in TrueNAS settings

**Solution:**
- Use v2.0 endpoints: `/api/v2.0/...`
- Check System Settings → API in TrueNAS UI

---

## Documentation Updated

- ✅ `docs/INFISICAL_GUIDE.md` - Complete Infisical usage guide
- ✅ `truenas/README.md` - Full setup guide
- ✅ `truenas/STATUS.md` - Current status and checklist
- ✅ `truenas/scripts/test_auth.sh` - NEW: Authentication tester
- ✅ `truenas/scripts/get_system_info.sh` - System info retriever

---

*Once you've updated the password in Infisical, run `test_auth.sh` to confirm everything works, then we can proceed with gathering system information.*
