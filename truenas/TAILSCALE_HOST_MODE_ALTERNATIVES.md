# Tailscale Without Host Mode - Research & Solutions

## Problem
Current Tailscale setup uses `network_mode: host` which:
- Bypasses Docker networking
- Breaks service discovery via container names
- Reduces security isolation
- Goes against Docker best practices

## Solution Options

### Option A: Userspace Networking (TS_USERSPACE=true) ⭐ RECOMMENDED TO TRY FIRST
**Pros:**
- Works in bridge mode (no host networking needed)
- Doesn't require NET_ADMIN capability
- More secure
- Simple configuration change

**Cons:**
- Slower performance (userspace vs kernel)
- May not support all Tailscale features
- Subnet routing effectiveness unknown in userspace mode

**Implementation:**
```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale
    restart: unless-stopped
    hostname: truenas
    # network_mode: host  # REMOVED
    # cap_add:            # REMOVED - not needed in userspace
    #   - NET_ADMIN
    #   - SYS_MODULE
    env_file:
      - /mnt/Fast/docker/tailscale/.env
    environment:
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=true  # ADDED - enable userspace networking
      - TS_EXTRA_ARGS=--advertise-routes=192.168.20.0/24 --accept-routes
    volumes:
      - /mnt/Fast/docker/tailscale:/var/lib/tailscale
      # /dev/net/tun REMOVED - not needed in userspace
    networks:
      - default
```

**Testing:**
```bash
# Deploy and check logs
docker logs tailscale -f

# Verify subnet routes advertised
tailscale status

# From remote device, test accessing services
curl http://<truenas-tailscale-ip>:8096  # Jellyfin
ping 192.168.20.22  # TrueNAS via subnet route
```

---

### Option B: Tailscale Serve (App-level proxying)
**Pros:**
- Share specific services, not entire subnet
- Works in bridge mode
- More granular control
- Can use HTTPS with Tailscale's certificates

**Cons:**
- Must configure each service individually
- Can't access ALL homelab services easily
- More complex setup
- Doesn't work for non-HTTP services

**Implementation:**
```yaml
services:
  tailscale:
    image: tailscale/tailscale:latest
    restart: unless-stopped
    environment:
      - TS_USERSPACE=true
      - TS_STATE_DIR=/var/lib/tailscale
    volumes:
      - /mnt/Fast/docker/tailscale:/var/lib/tailscale
    networks:
      - jellyfin_network
      - arr_network
    command: |
      sh -c '
        tailscaled --state=/var/lib/tailscale/tailscaled.state &
        tailscale up --authkey=${TS_AUTHKEY}
        tailscale serve --bg http://jellyfin:8096
        tailscale serve --bg http://sonarr:8989
        tailscale serve --bg http://radarr:7878
        wait
      '
```

**Use case:** Share specific services publicly via Tailscale Funnel

---

### Option C: macvlan Network (Physical LAN IP)
**Pros:**
- Gives container its own IP on physical network (e.g., 192.168.20.200)
- Acts like a real device on LAN
- Full routing capabilities
- Best performance

**Cons:**
- More complex network setup
- Uses another IP from your network
- Docker host can't communicate directly with macvlan containers
- Requires understanding of macvlan networking

**Implementation:**
```yaml
networks:
  lan:
    driver: macvlan
    driver_opts:
      parent: eno1  # Replace with actual interface name
    ipam:
      config:
        - subnet: 192.168.20.0/24
          gateway: 192.168.20.1
          ip_range: 192.168.20.200/32  # Single IP for Tailscale

services:
  tailscale:
    image: tailscale/tailscale:latest
    restart: unless-stopped
    hostname: truenas-tailscale
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_EXTRA_ARGS=--advertise-routes=192.168.20.0/24
    volumes:
      - /mnt/Fast/docker/tailscale:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    networks:
      lan:
        ipv4_address: 192.168.20.200
```

**Setup steps:**
1. Find physical interface: `ip addr` (look for interface with 192.168.20.x)
2. Update `parent:` with interface name
3. Reserve IP 192.168.20.200 in router DHCP (prevent conflicts)
4. Deploy container
5. Container will appear as separate device on network

---

### Option D: Accept Host Mode (Pragmatic) ⚠️ FALLBACK
**Pros:**
- Guaranteed to work
- Best performance
- Simplest setup
- Well-documented

**Cons:**
- Less isolation
- Can't use Docker service discovery FROM Tailscale container
- Security trade-off

**When to use:**
- Subnet routing is critical requirement
- Performance is important
- Network is already trusted
- Other options don't work

**Current implementation:** See `truenas/stacks/tailscale/compose.yaml`

---

## Testing Strategy

### Phase 1: Test Userspace Mode (Recommended First)
1. Create backup of current Tailscale config
2. Update compose.yaml with Option A
3. Deploy via TrueNAS Web UI
4. Check logs: `docker logs tailscale`
5. Verify from remote device:
   ```bash
   # Can you access TrueNAS via Tailscale?
   ping <truenas-tailscale-ip>

   # Can you access homelab devices via subnet routing?
   ping 192.168.20.22
   curl http://192.168.20.22:8096  # Jellyfin
   ```

**Expected result:**
- ✅ Tailscale connects
- ✅ Can access TrueNAS via Tailscale IP
- ❓ Subnet routing may or may not work in userspace mode

### Phase 2: If Userspace Fails, Try macvlan
1. Identify physical interface: `ip addr`
2. Reserve IP 192.168.20.200 in router
3. Update compose.yaml with Option C
4. Deploy and test

### Phase 3: If Still Issues, Use Host Mode
1. Revert to current compose.yaml
2. Accept the trade-off
3. Document decision

---

## Known Limitations

### Userspace Mode
- **Subnet routing:** May not work (needs testing)
- **Performance:** ~10-20% slower than kernel mode
- **Features:** Exit node may not work

### macvlan Mode
- **Host isolation:** Docker host (TrueNAS) can't talk to macvlan container
- **Complexity:** Requires network knowledge
- **IP management:** Need to track used IPs

### Host Mode
- **Isolation:** Container shares host network namespace
- **Docker networking:** Can't use container names/service discovery

---

## Decision Matrix

| Requirement | Userspace | macvlan | Host Mode |
|-------------|-----------|---------|-----------|
| No host mode | ✅ | ✅ | ❌ |
| Subnet routing | ❓ | ✅ | ✅ |
| Docker networking | ✅ | ⚠️ | ❌ |
| Simple setup | ✅ | ❌ | ✅ |
| Best performance | ❌ | ✅ | ✅ |
| Security | ✅ | ⚠️ | ❌ |

**Recommendation:** Try **Userspace** → If fails, try **macvlan** → Last resort: **Host mode**

---

## Next Steps
1. Decide which option to test first
2. Update `truenas/stacks/tailscale/compose.yaml`
3. Deploy and test
4. Document results in this file
5. Update `ai/SESSION_NOTES.md` with outcome
