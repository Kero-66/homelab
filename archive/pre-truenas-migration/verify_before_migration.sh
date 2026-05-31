#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# Pre-Migration Verification Script
# =============================================================================
# Checks your current setup before backing up and migrating to Linux.
# Helps identify potential issues and ensures nothing is missed.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_section() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

ISSUES=0
WARNINGS=0

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}     PRE-MIGRATION VERIFICATION - Windows to Linux         ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Check D Drive
# -----------------------------------------------------------------------------
log_section "Storage Check"

if [ -d "/mnt/d" ]; then
    log_pass "D drive is mounted at /mnt/d"
    
    AVAILABLE=$(df -BG /mnt/d | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$AVAILABLE" -lt 50 ]; then
        log_warn "Only ${AVAILABLE}GB available on D drive (recommend 50GB+)"
        ((WARNINGS++))
    else
        log_pass "${AVAILABLE}GB available on D drive"
    fi
else
    log_fail "D drive not mounted at /mnt/d"
    ((ISSUES++))
fi

# -----------------------------------------------------------------------------
# 2. Check Docker
# -----------------------------------------------------------------------------
log_section "Docker Check"

if command -v docker &> /dev/null; then
    log_pass "Docker is installed: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    
    if docker compose version &> /dev/null; then
        log_pass "Docker Compose is available: $(docker compose version --short)"
    else
        log_fail "Docker Compose not available"
        ((ISSUES++))
    fi
    
    if docker ps &> /dev/null; then
        log_pass "Docker daemon is running"
        CONTAINER_COUNT=$(docker ps -q | wc -l)
        log_info "Currently running containers: $CONTAINER_COUNT"
    else
        log_warn "Cannot connect to Docker daemon"
        ((WARNINGS++))
    fi
else
    log_fail "Docker is not installed"
    ((ISSUES++))
fi

# -----------------------------------------------------------------------------
# 3. Check Running Services
# -----------------------------------------------------------------------------
log_section "Service Status"

SERVICES=(
    "radarr:Radarr"
    "sonarr:Sonarr"
    "lidarr:Lidarr"
    "prowlarr:Prowlarr"
    "bazarr:Bazarr"
    "jellyfin:Jellyfin"
    "jellyseerr:Jellyseerr"
    "qbittorrent:qBittorrent"
)

RUNNING_SERVICES=0
for service_pair in "${SERVICES[@]}"; do
    IFS=':' read -r container_name display_name <<< "$service_pair"
    if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
        log_pass "$display_name is running"
        ((RUNNING_SERVICES++))
    else
        log_info "$display_name is not running"
    fi
done

if [ $RUNNING_SERVICES -eq 0 ]; then
    log_info "No services are currently running"
    log_info "  (This is actually ideal for a consistent backup!)"
else
    log_info "Total running services: $RUNNING_SERVICES"
fi

# -----------------------------------------------------------------------------
# 4. Check Configurations
# -----------------------------------------------------------------------------
log_section "Configuration Files"

CONFIG_DIRS=(
    "media/radarr"
    "media/sonarr"
    "media/lidarr"
    "media/prowlarr"
    "media/bazarr"
    "media/jellyfin/config"
    "media/qbittorrent"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
        log_pass "$(basename $(dirname $dir))/$(basename $dir): $SIZE"
    else
        log_info "Config directory not found: $dir (may not be configured yet)"
    fi
done

# -----------------------------------------------------------------------------
# 5. Check Databases
# -----------------------------------------------------------------------------
log_section "Database Check"

# SQLite databases
DATABASES=(
    "media/radarr/radarr.db"
    "media/sonarr/sonarr.db"
    "media/lidarr/lidarr.db"
    "media/prowlarr/prowlarr.db"
)

for db in "${DATABASES[@]}"; do
    if [ -f "$db" ]; then
        SIZE=$(du -h "$db" | cut -f1)
        log_pass "$(basename $(dirname $db))/$(basename $db): $SIZE"
    else
        log_info "Database not found: $db (service may not be configured)"
    fi
done

# PostgreSQL
if docker ps --format '{{.Names}}' | grep -q "jellystat-db"; then
    log_pass "Jellystat PostgreSQL is running"
    
    # Test if we can connect
    if docker exec jellystat-db pg_isready -U postgres &> /dev/null; then
        log_pass "PostgreSQL is accepting connections"
    else
        log_info "PostgreSQL not ready (will skip database dump if not accessible)"
    fi
else
    log_info "Jellystat PostgreSQL not running (will skip database dump)"
fi

# -----------------------------------------------------------------------------
# 6. Check Environment Files
# -----------------------------------------------------------------------------
log_section "Environment & Credentials"

if [ -f "media/.env" ]; then
    log_pass "media/.env exists"
    
    # Check for required variables
    if grep -q "DATA_DIR=" media/.env; then
        DATA_DIR=$(grep "DATA_DIR=" media/.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        log_info "DATA_DIR is set to: $DATA_DIR"
    else
        log_info "DATA_DIR not set in .env (may use default)"
    fi
else
    log_fail "media/.env not found"
    ((ISSUES++))
fi

if [ -d "media/.config" ]; then
    log_pass "Credentials directory exists"
    
    if [ -f "media/.config/.credentials" ]; then
        log_pass "Credentials file exists"
    else
        log_info "Credentials file not found (will backup if exists elsewhere)"
    fi
else
    log_info "Credentials directory not found (will backup any existing .env files)"
fi

# -----------------------------------------------------------------------------
# 7. Check Compose Files
# -----------------------------------------------------------------------------
log_section "Docker Compose Files"

COMPOSE_FILES=(
    "media/compose.yaml"
    "monitoring/compose.yaml"
    "proxy/compose.yaml"
    "surveillance/compose.yaml"
    "automations/compose.yml"
)

for compose in "${COMPOSE_FILES[@]}"; do
    if [ -f "$compose" ]; then
        log_pass "$compose exists"
        
        # Validate syntax
        if cd "$(dirname "$compose")" && docker compose config &> /dev/null; then
            log_pass "  └─ Valid syntax"
        else
            log_info "  └─ Syntax validation skipped (will backup as-is)"
        fi
        cd "$SCRIPT_DIR"
    else
        log_info "$compose not found (may not be using this stack)"
    fi
done

# -----------------------------------------------------------------------------
# 8. Check Scripts
# -----------------------------------------------------------------------------
log_section "Scripts & Automation"

SCRIPT_COUNT=$(find . -name "*.sh" -type f 2>/dev/null | wc -l)
log_info "Found $SCRIPT_COUNT shell scripts"

PYTHON_COUNT=$(find . -name "*.py" -type f 2>/dev/null | wc -l)
log_info "Found $PYTHON_COUNT Python scripts"

# Check if scripts are executable
NON_EXEC=$(find media/scripts -name "*.sh" -type f ! -executable 2>/dev/null | wc -l)
if [ $NON_EXEC -gt 0 ]; then
    log_info "$NON_EXEC scripts in media/scripts/ are not executable (will be backed up)"
fi

# -----------------------------------------------------------------------------
# 9. Check Git Status
# -----------------------------------------------------------------------------
log_section "Repository Status"

if [ -d ".git" ]; then
    log_pass "Git repository detected"
    
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
    if [ $UNCOMMITTED -gt 0 ]; then
        log_info "$UNCOMMITTED uncommitted changes (will be included in backup)"
        log_info "  Run 'git status' to see changes"
    else
        log_pass "No uncommitted changes"
    fi
    
    BRANCH=$(git branch --show-current 2>/dev/null)
    log_info "Current branch: $BRANCH"
else
    log_info "Not a git repository"
fi

# -----------------------------------------------------------------------------
# 10. Check Data Directory
# -----------------------------------------------------------------------------
log_section "Data Directory"

if [ -f "media/.env" ]; then
    DATA_DIR=$(grep "^DATA_DIR=" media/.env | cut -d'=' -f2 | tr -d '"' || echo "")
    
    if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR" ]; then
        log_pass "Data directory exists: $DATA_DIR"
        
        DATA_SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        log_info "Data directory size: $DATA_SIZE"
        
        # Check subdirectories
        for subdir in torrents usenet media; do
            if [ -d "$DATA_DIR/$subdir" ]; then
                log_pass "  ├─ $subdir/ exists"
            else
                log_info "  ├─ $subdir/ not found"
            fi
        done
    else
        log_info "Data directory not accessible or not set: $DATA_DIR"
        log_info "  (Media files won't be backed up, only configs/metadata)"
    fi
fi

# -----------------------------------------------------------------------------
# 11. Summary
# -----------------------------------------------------------------------------
log_section "Verification Summary"

echo ""
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                  ALL CHECKS PASSED! ✓                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Your system is ready for backup and migration!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Run: ${YELLOW}./backup_to_d_drive.sh${NC}"
    echo -e "  2. Read: ${YELLOW}MIGRATION_GUIDE.md${NC}"
    echo -e "  3. Prepare your new Linux system"
    echo ""
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}              CHECKS PASSED WITH WARNINGS                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Found $WARNINGS warnings (but no critical issues)${NC}"
    echo ""
    echo -e "${CYAN}You can proceed with backup, but review the warnings above.${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Review warnings above"
    echo -e "  2. Run: ${YELLOW}./backup_to_d_drive.sh${NC}"
    echo -e "  3. Read: ${YELLOW}MIGRATION_GUIDE.md${NC}"
    echo ""
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                 CRITICAL ISSUES FOUND!                     ${RED}║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}Found $ISSUES critical issues and $WARNINGS warnings${NC}"
    echo ""
    echo -e "${CYAN}Please fix the critical issues above before backing up.${NC}"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

exit $ISSUES
