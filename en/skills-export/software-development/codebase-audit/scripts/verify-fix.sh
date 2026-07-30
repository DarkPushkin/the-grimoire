#!/usr/bin/env bash
# verify-fix.sh — Ad-hoc verification script template for multi-faceted fix validation
# Usage: Customize the checks array for your session, then run

set -euo pipefail

checks=(
    # Go syntax
    "gofmt -e internal/api/paranoidx_vless.go > /dev/null && echo '✅ paranoidx_vless.go: valid Go syntax'"
    "gofmt -e cmd/simplex-node/main.go > /dev/null && echo '✅ main.go: valid Go syntax'"
    
    # Shell syntax
    "bash -n scripts/setup-vless.sh && echo '✅ setup-vless.sh: valid bash syntax'"
    "bash -n scripts/logrotate-simplex-node && echo '✅ logrotate-simplex-node: valid syntax'"
    
    # Logrotate config syntax
    "logrotate --debug scripts/logrotate-simplex-node 2>&1 | grep -q 'error:' && echo '❌ logrotate config has errors' || echo '✅ logrotate config: valid syntax'"
    
    # Desktop entries
    "desktop-file-validate ~/.local/share/applications/royal-island.desktop && echo '✅ Royal Island .desktop: valid'"
    
    # Executable paths
    "[[ -x ~/.local/bin/the-isle/isle_app ]] && echo '✅ isle_app binary exists and executable' || echo '❌ isle_app missing'"
    
    # Icons
    "[[ -f ~/.local/share/icons/hicolor/512x512/apps/the-island.png ]] && echo '✅ the-island.png exists' || echo '❌ the-island.png missing'"
    
    # Process cleanup
    "! ps aux | grep -E 'v2raya' | grep -v grep | grep -q root && echo '✅ No v2rayA running as root' || echo '❌ v2rayA still running as root'"
    
    # Port cleanup
    "! ss -tlnp | grep -q ':10808' && echo '✅ Port 10808 freed' || echo '⚠️ Port 10808 still listening'"
    
    # Expected processes
    "ps aux | grep -E 'xray run' | grep -v grep | wc -l | xargs -I{} echo 'ℹ️ Found {} Xray processes'"
    
    # New files created
    "[[ -f scripts/setup-vless.sh ]] && echo '✅ setup-vless.sh created'"
    "[[ -f internal/api/paranoidx_vless.go ]] && echo '✅ paranoidx_vless.go created'"
    "[[ -f scripts/logrotate-simplex-node ]] && echo '✅ logrotate config created'"
    
    # Life Elements Game
    "[[ -d ~/LifeElementGame ]] && echo '✅ LifeElementGame extracted' || echo '❌ LifeElementGame missing'"
    
    # Disk space
    "df -h /home/tomas | awk 'NR==2 {print \"ℹ️ Disk: \" \$3 \" / \" \$2 \" (\" \$5 \")\"}'"
)

echo "=== SIMPLEX-NODE FIX VERIFICATION ==="
echo ""

passed=0
failed=0

for check in "${checks[@]}"; do
    if eval "$check"; then
        ((passed++))
    else
        ((failed++))
    fi
done

echo ""
echo "=== SUMMARY: $passed passed, $failed failed ==="

if [[ $failed -gt 0 ]]; then
    exit 1
fi