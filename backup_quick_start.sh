#!/usr/bin/env bash

# =============================================================================
# QUICK BACKUP EXECUTION - Run This!
# =============================================================================
# This script will:
# 1. Verify your system
# 2. Optionally stop services for clean backup
# 3. Run the backup
# 4. Show you where everything is
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}       HOMELAB BACKUP - Quick Start                         ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "This will backup your entire homelab to the D drive."
echo ""

# Step 1: Verify
echo -e "${CYAN}Step 1: Verifying system...${NC}"
echo ""
./verify_before_migration.sh

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}Verification found critical issues!${NC}"
    echo "Please fix the issues above before continuing."
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Verification passed!${NC}"
echo ""

# Step 2: Stop services?
echo -e "${CYAN}Step 2: Stop services (optional but recommended)${NC}"
echo ""
echo "Stopping services ensures a consistent backup state."
echo ""
read -p "Stop all services before backup? (Y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "Stopping services..."
    
    if [ -f "media/compose.yaml" ]; then
        cd media && docker compose down && cd ..
        echo -e "${GREEN}✓${NC} Media services stopped"
    fi
    
    if [ -f "monitoring/compose.yaml" ]; then
        cd monitoring && docker compose down && cd ..
        echo -e "${GREEN}✓${NC} Monitoring services stopped"
    fi
    
    if [ -f "proxy/compose.yaml" ]; then
        cd proxy && docker compose down && cd ..
        echo -e "${GREEN}✓${NC} Proxy services stopped"
    fi
    
    echo ""
    echo -e "${GREEN}All services stopped${NC}"
else
    echo ""
    echo "Continuing with services running (live backup)..."
fi

echo ""

# Step 3: Backup
echo -e "${CYAN}Step 3: Starting backup...${NC}"
echo ""
read -p "Press Enter to start backup..." 

echo ""
./backup_to_d_drive.sh

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                   BACKUP COMPLETE!                         ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo "1. Check backup location:"
    echo -e "   ${YELLOW}ls -lh /mnt/d/homelab-backup/${NC}"
    echo ""
    echo "2. Copy to external storage (recommended):"
    echo -e "   ${YELLOW}cp /mnt/d/homelab-backup/homelab_backup_*.tar.gz /path/to/usb/${NC}"
    echo ""
    echo "3. Read the migration guide:"
    echo -e "   ${YELLOW}cat MIGRATION_GUIDE.md${NC}"
    echo ""
    echo "4. When ready to restore on Linux:"
    echo -e "   ${YELLOW}tar -xzf homelab_backup_*.tar.gz${NC}"
    echo -e "   ${YELLOW}cd homelab_backup_*/; ./restore.sh ~/homelab${NC}"
    echo ""
    
    # Offer to restart services
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        read -p "Restart services now? (Y/n) " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo "Restarting services..."
            
            if [ -f "media/compose.yaml" ]; then
                cd media && docker compose up -d && cd ..
                echo -e "${GREEN}✓${NC} Media services started"
            fi
            
            if [ -f "monitoring/compose.yaml" ]; then
                cd monitoring && docker compose up -d && cd ..
                echo -e "${GREEN}✓${NC} Monitoring services started"
            fi
            
            if [ -f "proxy/compose.yaml" ]; then
                cd proxy && docker compose up -d && cd ..
                echo -e "${GREEN}✓${NC} Proxy services started"
            fi
            
            echo ""
            echo -e "${GREEN}All services restarted${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Ready to say goodbye to Windows and hello to Linux! 🐧${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}Backup failed!${NC}"
    echo "Check the output above for errors."
    exit 1
fi
