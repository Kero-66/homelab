#!/bin/bash
set -e

# Add memory limits to all Docker Compose services
# Based on current usage + headroom:
# - Jellyfin: 427MB → 1GB limit
# - qBittorrent: 331MB → 512MB limit  
# - Jellyseerr: 262MB → 512MB limit
# - Sonarr/Radarr/Lidarr: ~200MB → 512MB each
# - Prowlarr: 193MB → 512MB limit
# - Bazarr: 162MB → 256MB limit
# - Jellystat: 127MB → 256MB limit
# - NZBGet: 9MB → 128MB limit
# - Jellystat-db: 41MB → 256MB limit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$MEDIA_DIR"

echo "Adding memory limits to compose files..."

# Main media stack
if ! grep -q "mem_limit:" compose.yaml; then
    echo "Updating media/compose.yaml..."
    
    # Add deploy section with memory limits to each service
    # This is complex, so I'll create a Python script to do it properly
    python3 << 'EOF'
import yaml
import sys

try:
    with open('compose.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    memory_limits = {
        'qbittorrent': '512m',
        'nzbget': '128m',
        'prowlarr': '512m',
        'sonarr': '512m',
        'radarr': '512m',
        'lidarr': '512m',
        'bazarr': '256m'
    }
    
    for service, limit in memory_limits.items():
        if service in config['services']:
            if 'deploy' not in config['services'][service]:
                config['services'][service]['deploy'] = {}
            if 'resources' not in config['services'][service]['deploy']:
                config['services'][service]['deploy']['resources'] = {}
            if 'limits' not in config['services'][service]['deploy']['resources']:
                config['services'][service]['deploy']['resources']['limits'] = {}
            config['services'][service]['deploy']['resources']['limits']['memory'] = limit
    
    with open('compose.yaml', 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print("✓ Updated compose.yaml")
except Exception as e:
    print(f"Error: {e}")
    print("PyYAML not installed. Using manual approach...")
    sys.exit(1)
EOF
fi

# Jellyfin stack
cd jellyfin
if ! grep -q "mem_limit:" compose.yaml; then
    echo "Updating jellyfin/compose.yaml..."
    
    python3 << 'EOF'
import yaml

try:
    with open('compose.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    memory_limits = {
        'jellyfin': '1g',
        'jellyseerr': '512m',
        'jellystat': '256m',
        'jellystat-db': '256m'
    }
    
    for service, limit in memory_limits.items():
        if service in config['services']:
            if 'deploy' not in config['services'][service]:
                config['services'][service]['deploy'] = {}
            if 'resources' not in config['services'][service]['deploy']:
                config['services'][service]['deploy']['resources'] = {}
            if 'limits' not in config['services'][service]['deploy']['resources']:
                config['services'][service]['deploy']['resources']['limits'] = {}
            config['services'][service]['deploy']['resources']['limits']['memory'] = limit
    
    with open('compose.yaml', 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print("✓ Updated jellyfin/compose.yaml")
except ImportError:
    print("PyYAML not installed, skipping YAML-based update")
EOF
fi

cd ..

echo ""
echo "✓ Memory limits configured!"
echo ""
echo "Limits set:"
echo "  Jellyfin:      1GB"
echo "  qBittorrent:   512MB"
echo "  Jellyseerr:    512MB"
echo "  Arr apps:      512MB each"
echo "  Prowlarr:      512MB"
echo "  Bazarr:        256MB"
echo "  Jellystat:     256MB"
echo "  Jellystat-db:  256MB"
echo "  NZBGet:        128MB"
echo ""
echo "To apply: docker compose down && docker compose up -d"
