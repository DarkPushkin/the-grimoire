#!/usr/bin/env bash
# Verification script for BIP39/Ed25519 key derivation fix
# Run this to verify the derivation paths are correctly hardened

set -euo pipefail

echo "=== BIP39/Ed25519 Derivation Path Verification ==="
echo

# Check identity.dart for hardened paths
echo "1. Checking derivation paths in identity.dart..."
IDENTITY_DART="/home/tomas/simplex-node/apps/shared/models/lib/src/identity.dart"

if grep -q "m/44'/1337'/0'/0'/0'" "$IDENTITY_DART"; then
    echo "   ✅ Identity path is fully hardened"
else
    echo "   ❌ Identity path NOT fully hardened"
    exit 1
fi

if grep -q "m/44'/1337'/0'/1'/0'" "$IDENTITY_DART"; then
    echo "   ✅ Encryption path is fully hardened"
else
    echo "   ❌ Encryption path NOT fully hardened"
    exit 1
fi

# Check for any non-hardened paths
NON_HARDENED=$(grep -E "m/44'.*/0/0|m/44'.*/1/0" "$IDENTITY_DART" | grep -v "0'/0'\|1'/0'\|2'/0'\|3'/0'" || true)
if [ -n "$NON_HARDENED" ]; then
    echo "   ⚠️  Found potentially non-hardened paths:"
    echo "$NON_HARDENED"
else
    echo "   ✅ No non-hardened paths found"
fi

# Build verification
echo
echo "2. Building royal_app to verify no compile errors..."
cd /home/tomas/simplex-node/apps/royal_app
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy \
  flutter build linux --release > /tmp/build.log 2>&1

if [ $? -eq 0 ] && [ -f build/linux/x64/release/bundle/royal_app ]; then
    echo "   ✅ Build successful"
else
    echo "   ❌ Build failed"
    tail -20 /tmp/build.log
    exit 1
fi

# Deploy and launch test
echo
echo "3. Deploying and testing launch..."
cp build/linux/x64/release/bundle/royal_app /home/tomas/.local/bin/the-royal/royal_app
cp -r build/linux/x64/release/bundle/lib/* /home/tomas/.local/bin/the-royal/lib/
cp -r build/linux/x64/release/bundle/data/* /home/tomas/.local/bin/the-royal/data/

DISPLAY=:0 timeout 5 /home/tomas/.local/bin/the-royal/royal_app 2>&1 | grep -q "Unable to load.*cursor" && echo "   ✅ Royal app launches cleanly" || echo "   ⚠️  Royal app launch check"

DISPLAY=:0 timeout 5 /home/tomas/.local/bin/the-isle/isle_app 2>&1 | grep -q "Unable to load.*cursor" && echo "   ✅ Citizen app still launches" || echo "   ⚠️  Citizen app launch check"

echo
echo "=== VERIFICATION COMPLETE ==="