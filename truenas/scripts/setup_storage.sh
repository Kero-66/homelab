#!/usr/bin/env bash
# truenas/scripts/setup_storage.sh
#
# Creates ZFS pools and datasets on TrueNAS Scale CE via midclt.
# Run this script on the TrueNAS box via SSH.
#
# Usage:
#   ssh admin@<TRUENAS_IP>
#   # Copy this script to /tmp and run it, or run commands individually
#   bash setup_storage.sh [--discover|--create-pools|--create-datasets|--all]
#
# Prerequisites:
#   - TrueNAS Scale CE 25.10+ installed and accessible via SSH
#   - Disks visible in TrueNAS (check Storage > Disks in Web UI)
#   - No existing pools on the target disks
#
# API Reference:
#   - disk.query: https://api.truenas.com/v25.10/
#   - pool.create: https://api.truenas.com/v25.10/
#   - pool.dataset.create: https://api.truenas.com/v25.10/
#   - TrueNAS midclt client: https://github.com/truenas/api_client
#
# Pool Layout:
#   fast (NVMe mirror) - 2x 1TB NVMe
#     ├── fast/apps
#     ├── fast/databases
#     └── fast/docker
#
#   bulk (HDD mirror) - 2x 8TB HDD
#     ├── bulk/media
#     ├── bulk/photos
#     ├── bulk/cloud-sync
#     ├── bulk/backups
#     └── bulk/downloads

set -euo pipefail

# --- Configuration ---
POOL_FAST="${POOL_FAST:-fast}"
POOL_BULK="${POOL_BULK:-bulk}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Helper: Check midclt is available ---
check_midclt() {
    if ! command -v midclt &>/dev/null; then
        log_error "midclt not found. This script must be run on a TrueNAS system."
        exit 1
    fi
}

# --- Step 1: Discover Disks ---
# Lists all disks, their types, sizes, and whether they're already in a pool.
# Use this to identify which disks to assign to each pool.
discover_disks() {
    log_info "Discovering disks..."
    echo ""

    # Query all disks and format output
    # midclt call disk.query returns JSON array of disk objects
    midclt call disk.query | python3 -c "
import json, sys

disks = json.load(sys.stdin)
print(f'{'Name':<10} {'Serial':<25} {'Size':<12} {'Type':<8} {'Model':<35} {'Pool':<10}')
print('-' * 100)
for d in sorted(disks, key=lambda x: x.get('name', '')):
    name = d.get('name', 'unknown')
    serial = d.get('serial', 'unknown')[:24]
    size_bytes = d.get('size', 0)
    size_gb = size_bytes / (1024**3) if size_bytes else 0
    size_str = f'{size_gb:.0f} GiB'
    dtype = d.get('type', 'unknown')
    model = (d.get('model', 'unknown') or 'unknown')[:34]
    pool = d.get('pool', '') or 'available'
    print(f'{name:<10} {serial:<25} {size_str:<12} {dtype:<8} {model:<35} {pool:<10}')
"
    echo ""
    log_info "Disks marked 'available' can be used for new pools."
    log_info "The boot disk will show as part of the 'boot-pool'."
    echo ""
    log_warn "IMPORTANT: Note down the disk names (e.g., nvme0n1, sda) for pool creation."
    log_warn "NVMe disks are typically nvme*n1, HDDs are typically sd*."
}

# --- Step 2: Create Pools ---
# Creates two mirrored ZFS pools:
#   - fast: NVMe mirror for app/container data
#   - bulk: HDD mirror for media/bulk storage
#
# midclt call pool.create requires a JSON payload with:
#   - name: pool name
#   - topology: vdev layout (data vdevs, cache, log, spare, etc.)
#   - allow_duplicate_serials: false (safety check)
#
# Each data vdev needs:
#   - type: MIRROR
#   - disks: array of disk names
create_pools() {
    log_info "Creating storage pools..."

    # Discover available disks and categorize them
    local nvme_disks hdd_disks
    nvme_disks=$(midclt call disk.query | python3 -c "
import json, sys
disks = json.load(sys.stdin)
available = [d['name'] for d in disks if not d.get('pool') and 'nvme' in d.get('name', '')]
print(' '.join(available))
")
    hdd_disks=$(midclt call disk.query | python3 -c "
import json, sys
disks = json.load(sys.stdin)
available = [d['name'] for d in disks if not d.get('pool') and d.get('name', '').startswith('sd')]
print(' '.join(available))
")

    log_info "Available NVMe disks: ${nvme_disks:-none}"
    log_info "Available HDD disks: ${hdd_disks:-none}"

    # Count available disks
    local nvme_count hdd_count
    nvme_count=$(echo "$nvme_disks" | wc -w)
    hdd_count=$(echo "$hdd_disks" | wc -w)

    # --- Create fast pool (NVMe mirror) ---
    if [ "$nvme_count" -ge 2 ]; then
        # Check if pool already exists
        local existing_fast
        existing_fast=$(midclt call pool.query '[["name", "=", "'"$POOL_FAST"'"]]' | python3 -c "
import json, sys
pools = json.load(sys.stdin)
print(len(pools))
")
        if [ "$existing_fast" -gt 0 ]; then
            log_warn "Pool '$POOL_FAST' already exists, skipping."
        else
            # Get first two NVMe disks
            local nvme1 nvme2
            nvme1=$(echo "$nvme_disks" | awk '{print $1}')
            nvme2=$(echo "$nvme_disks" | awk '{print $2}')

            log_info "Creating pool '$POOL_FAST' as mirror: $nvme1 + $nvme2"

            # pool.create is a job method - use -j flag to wait for completion
            midclt call -j pool.create '{
                "name": "'"$POOL_FAST"'",
                "allow_duplicate_serials": false,
                "topology": {
                    "data": [
                        {
                            "type": "MIRROR",
                            "disks": ["'"$nvme1"'", "'"$nvme2"'"]
                        }
                    ]
                }
            }' > /dev/null

            log_ok "Pool '$POOL_FAST' created successfully."
        fi
    else
        log_error "Need at least 2 available NVMe disks for '$POOL_FAST' pool. Found: $nvme_count"
        log_error "Run '$0 --discover' to check disk availability."
    fi

    # --- Create bulk pool (HDD mirror) ---
    if [ "$hdd_count" -ge 2 ]; then
        local existing_bulk
        existing_bulk=$(midclt call pool.query '[["name", "=", "'"$POOL_BULK"'"]]' | python3 -c "
import json, sys
pools = json.load(sys.stdin)
print(len(pools))
")
        if [ "$existing_bulk" -gt 0 ]; then
            log_warn "Pool '$POOL_BULK' already exists, skipping."
        else
            local hdd1 hdd2
            hdd1=$(echo "$hdd_disks" | awk '{print $1}')
            hdd2=$(echo "$hdd_disks" | awk '{print $2}')

            log_info "Creating pool '$POOL_BULK' as mirror: $hdd1 + $hdd2"

            midclt call -j pool.create '{
                "name": "'"$POOL_BULK"'",
                "allow_duplicate_serials": false,
                "topology": {
                    "data": [
                        {
                            "type": "MIRROR",
                            "disks": ["'"$hdd1"'", "'"$hdd2"'"]
                        }
                    ]
                }
            }' > /dev/null

            log_ok "Pool '$POOL_BULK' created successfully."
        fi
    else
        log_error "Need at least 2 available HDD disks for '$POOL_BULK' pool. Found: $hdd_count"
        log_error "Run '$0 --discover' to check disk availability."
    fi

    echo ""
    log_info "Current pools:"
    midclt call pool.query | python3 -c "
import json, sys
pools = json.load(sys.stdin)
for p in pools:
    name = p.get('name', 'unknown')
    status = p.get('status', 'unknown')
    healthy = p.get('healthy', False)
    print(f'  {name}: status={status}, healthy={healthy}')
"
}

# --- Step 3: Create Datasets ---
# Creates the dataset hierarchy under each pool.
# Datasets in ZFS are like directories with their own properties:
#   - compression: lz4 (good balance of speed and ratio)
#   - atime: off (reduces write overhead)
#   - recordsize: tuned per workload
#
# API: midclt call pool.dataset.create
create_datasets() {
    log_info "Creating datasets..."

    # Helper function to create a dataset if it doesn't exist
    create_dataset() {
        local name="$1"
        local recordsize="${2:-128K}"
        local comment="${3:-}"

        # Check if dataset exists
        local exists
        exists=$(midclt call pool.dataset.query '[["id", "=", "'"$name"'"]]' | python3 -c "
import json, sys
print(len(json.load(sys.stdin)))
")
        if [ "$exists" -gt 0 ]; then
            log_warn "Dataset '$name' already exists, skipping."
            return 0
        fi

        log_info "Creating dataset: $name (recordsize=$recordsize)"

        midclt call pool.dataset.create '{
            "name": "'"$name"'",
            "type": "FILESYSTEM",
            "compression": "LZ4",
            "atime": false,
            "recordsize": "'"$recordsize"'",
            "comments": "'"$comment"'"
        }' > /dev/null

        log_ok "Dataset '$name' created."
    }

    # --- Fast pool datasets ---
    # apps: container configs, small files - default 128K recordsize
    create_dataset "${POOL_FAST}/apps" "128K" "Container app configuration and data"

    # databases: PostgreSQL, Redis - 16K recordsize matches PG page size
    # Ref: https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Workload%20Tuning.html
    create_dataset "${POOL_FAST}/databases" "16K" "Database storage (PostgreSQL, Redis)"

    # docker: TrueNAS container/app runtime storage
    create_dataset "${POOL_FAST}/docker" "128K" "Docker/container runtime storage"

    # --- Bulk pool datasets ---
    # media: large video files - 1M recordsize for sequential reads
    # Ref: https://www.truenas.com/docs/references/performance/
    create_dataset "${POOL_BULK}/media" "1M" "Media library (movies, TV, music)"

    # photos: mixed sizes (RAW files, thumbnails) - 256K
    create_dataset "${POOL_BULK}/photos" "256K" "Photo library (Immich originals)"

    # cloud-sync: general files from cloud providers
    create_dataset "${POOL_BULK}/cloud-sync" "128K" "Cloud provider sync (Google Drive, Dropbox)"

    # backups: large backup files - 1M recordsize
    create_dataset "${POOL_BULK}/backups" "1M" "Backup target for other machines"

    # downloads: staging area for downloads
    create_dataset "${POOL_BULK}/downloads" "1M" "Download staging area"

    echo ""
    log_info "Dataset summary:"
    midclt call pool.dataset.query '[]' '{"select": ["id", "type", "compression", "comments"]}' | python3 -c "
import json, sys
datasets = json.load(sys.stdin)
for ds in sorted(datasets, key=lambda x: x.get('id', '')):
    dsid = ds.get('id', '')
    # Skip root pool datasets (just the pool names) and boot-pool
    if '/' not in dsid or dsid.startswith('boot-pool'):
        continue
    comp = ds.get('compression', {})
    comp_val = comp.get('value', 'unknown') if isinstance(comp, dict) else comp
    comment = ds.get('comments', {})
    comment_val = comment.get('value', '') if isinstance(comment, dict) else (comment or '')
    print(f'  {dsid}: compression={comp_val} - {comment_val}')
"
}

# --- Step 4: Verify Setup ---
verify() {
    log_info "Verifying storage configuration..."
    echo ""

    # Check pools
    echo "=== Pools ==="
    midclt call pool.query | python3 -c "
import json, sys
pools = json.load(sys.stdin)
for p in pools:
    name = p.get('name', 'unknown')
    if name == 'boot-pool':
        continue
    status = p.get('status', 'unknown')
    healthy = p.get('healthy', False)
    path = p.get('path', 'unknown')
    topo = p.get('topology', {})
    data_vdevs = topo.get('data', [])
    for vdev in data_vdevs:
        vtype = vdev.get('type', 'unknown')
        disks = [c.get('disk', 'unknown') for c in vdev.get('children', [])]
        print(f'  {name}: {vtype} ({\" + \".join(disks)}) - status={status}, healthy={healthy}, path={path}')
"
    echo ""

    # Check datasets
    echo "=== Datasets ==="
    midclt call pool.dataset.query '[]' '{"select": ["id", "available", "used", "compression", "recordsize"]}' | python3 -c "
import json, sys

def get_val(field):
    if isinstance(field, dict):
        return field.get('parsed', field.get('value', field.get('rawvalue', 'unknown')))
    return field

def human_bytes(b):
    if not b or b == 'unknown':
        return 'unknown'
    b = int(b)
    for unit in ['B', 'KiB', 'MiB', 'GiB', 'TiB']:
        if b < 1024:
            return f'{b:.1f} {unit}'
        b /= 1024
    return f'{b:.1f} PiB'

datasets = json.load(sys.stdin)
for ds in sorted(datasets, key=lambda x: x.get('id', '')):
    dsid = ds.get('id', '')
    if dsid.startswith('boot-pool'):
        continue
    avail = human_bytes(get_val(ds.get('available', {})))
    used = human_bytes(get_val(ds.get('used', {})))
    comp = get_val(ds.get('compression', {}))
    rs = get_val(ds.get('recordsize', {}))
    rs_str = human_bytes(rs) if isinstance(rs, (int, float)) else str(rs)
    print(f'  {dsid}: available={avail}, used={used}, compression={comp}, recordsize={rs_str}')
"
    echo ""
    log_ok "Verification complete."
}

# --- Main ---
main() {
    check_midclt

    local action="${1:---help}"

    case "$action" in
        --discover)
            discover_disks
            ;;
        --create-pools)
            create_pools
            ;;
        --create-datasets)
            create_datasets
            ;;
        --verify)
            verify
            ;;
        --all)
            discover_disks
            echo ""
            echo "================================================================"
            echo ""
            create_pools
            echo ""
            echo "================================================================"
            echo ""
            create_datasets
            echo ""
            echo "================================================================"
            echo ""
            verify
            ;;
        --help|*)
            echo "TrueNAS Storage Setup Script"
            echo ""
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  --discover         List all disks and their current pool assignments"
            echo "  --create-pools     Create 'fast' (NVMe mirror) and 'bulk' (HDD mirror) pools"
            echo "  --create-datasets  Create dataset hierarchy under each pool"
            echo "  --verify           Show current pool and dataset configuration"
            echo "  --all              Run discover, create-pools, create-datasets, and verify"
            echo "  --help             Show this help message"
            echo ""
            echo "Recommended order:"
            echo "  1. $0 --discover          # Identify your disks"
            echo "  2. $0 --create-pools      # Create the ZFS pools"
            echo "  3. $0 --create-datasets   # Create the dataset hierarchy"
            echo "  4. $0 --verify            # Confirm everything looks right"
            ;;
    esac
}

main "$@"
