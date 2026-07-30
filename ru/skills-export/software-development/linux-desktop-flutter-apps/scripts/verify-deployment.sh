#!/bin/bash
# Verification script for Flutter Linux desktop app deployment
# Usage: bash scripts/verify-deployment.sh

set -euo pipefail

echo "=== FLUTTER LINUX DESKTOP APP DEPLOYMENT VERIFICATION ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() {
    local desc="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $desc${NC}"
        return 0
    else
        echo -e "${RED}❌ $desc${NC}"
        return 1
    fi
}

warn() {
    local desc="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $desc${NC}"
    else
        echo -e "${YELLOW}⚠️  $desc${NC}"
    fi
}

FAIL=0

echo "1. Desktop Files"
check "The Island .desktop validates" "desktop-file-validate ~/.local/share/applications/the-island.desktop"
check "Royal Island .desktop validates" "desktop-file-validate ~/.local/share/applications/royal-island.desktop"
check "The Island desktop copy exists" "[ -f ~/Desktop/'The Island.desktop' ]"
check "Royal Island desktop copy exists" "[ -f ~/Desktop/'Royal Island.desktop' ]"

echo ""
echo "2. Binary Paths & Exec Mapping"
check "Citizen binary exists" "[ -x ~/.local/bin/the-isle/isle_app ]"
check "Admin binary exists" "[ -x ~/.local/bin/the-royal/royal_app ]"
check "Citizen shortcut → correct binary" "grep -q 'the-isle/isle_app' ~/.local/share/applications/the-island.desktop"
check "Admin shortcut → correct binary" "grep -q 'the-royal/royal_app' ~/.local/share/applications/royal-island.desktop"
check "NO Isle Royal stale shortcut" "! [ -f ~/.local/share/applications/isle-royal.desktop ]"

echo ""
echo "3. Binary Identity Verification"
check "Citizen binary = org.stmaria.the_island" "strings ~/.local/bin/the-isle/isle_app | grep -qi 'org.stmaria.the_island'"
check "Admin binary = com.example.royal_app" "strings ~/.local/bin/the-royal/royal_app | grep -qi 'com.example.royal_app'"

echo ""
echo "4. Dependencies"
check "Citizen lib/ exists" "[ -d ~/.local/bin/the-isle/lib ]"
check "Citizen data/ exists" "[ -d ~/.local/bin/the-isle/data ]"
check "Admin lib/ exists" "[ -d ~/.local/bin/the-royal/lib ]"
check "Admin data/ exists" "[ -d ~/.local/bin/the-royal/data ]"

echo ""
echo "5. Icons"
check "Citizen icon exists" "[ -f ~/.local/share/icons/hicolor/512x512/apps/the-island.png ]"
check "Admin icon exists" "[ -f ~/.local/share/icons/hicolor/512x512/apps/isle-royal.png ]"

echo ""
echo "6. Background Processes (Should Be Stopped)"
warn "No simplex-node running" "! pgrep -f 'simplex-node' >/dev/null"
warn "No paranoidx running" "! pgrep -f 'paranoidx' >/dev/null"
warn "No node monitor running" "! pgrep -f 'node.*monitor' >/dev/null"
warn "No v2rayA root process" "! pgrep -f 'v2raya' | xargs -r ps -o user= | grep -q '^root$'"

echo ""
echo "7. Port Cleanup"
warn "Port 10808 free" "! ss -tlnp | grep -q ':10808'"

echo ""
echo "8. Disk Space"
DISK_FREE=$(df -h /home/tomas | awk 'NR==2 {print $4}')
echo "   Free space: $DISK_FREE"
warn "Disk space >8GB" "df /home/tomas | awk 'NR==2 {exit (\$4 < 8000000)}'"

echo ""
echo "9. Launch Test (Headless - GUI Timeout = Success)"
timeout 10 ~/.local/bin/the-isle/isle_app 2>&1 | grep -q "cursor theme" && echo -e "${GREEN}✅ Citizen app launches${NC}" || echo -e "${RED}❌ Citizen app fails${NC}; FAIL=1"
timeout 10 ~/.local/bin/the-royal/royal_app 2>&1 | grep -q "cursor theme" && echo -e "${GREEN}✅ Admin app launches${NC}" || echo -e "${RED}❌ Admin app fails${NC}; FAIL=1"

echo ""
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}=== ALL CRITICAL CHECKS PASSED ===${NC}"
    exit 0
else
    echo -e "${RED}=== SOME CHECKS FAILED ===${NC}"
    exit 1
fi