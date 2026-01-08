#!/bin/bash

# Quick reference for Jellyseerr manual setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "═══════════════════════════════════════════════════════════"
echo "  Jellyseerr Configuration Helper"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Access Jellyseerr: http://localhost:5055"
echo ""
echo "RADARR (Movies):"
echo "  Name: Radarr"
echo "  Hostname: 172.39.0.5"
echo "  Port: 7878"
echo "  API Key: $(grep -oP '<ApiKey>\K[^<]+' radarr/config.xml)"
echo "  Root Folder: /data/movies"
echo ""
echo "SONARR (TV Shows):"
echo "  Name: Sonarr"
echo "  Hostname: 172.39.0.4"
echo "  Port: 8989"
echo "  API Key: $(grep -oP '<ApiKey>\K[^<]+' sonarr/config.xml)"
echo "  Root Folder: /data/shows"
echo ""
echo "═══════════════════════════════════════════════════════════"
