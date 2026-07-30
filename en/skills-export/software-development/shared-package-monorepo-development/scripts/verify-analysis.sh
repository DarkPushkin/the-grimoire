#!/bin/bash
# Verification script for Isle app screen analysis
# Run from simplex-node root directory

set -e

echo "=== Isle App Screen Analysis Verification ==="
echo ""

cd /home/tomas/simplex-node

echo "1. Analyzing shared models..."
dart analyze apps/shared/models/lib/src/
echo "✓ Models clean"
echo ""

echo "2. Analyzing Isle app screens..."
dart analyze apps/isle_app/lib/screens/
echo "✓ Isle screens clean"
echo ""

echo "3. Analyzing Royal app screens..."
dart analyze apps/royal_app/lib/screens/
echo "✓ Royal screens clean"
echo ""

echo "4. Building Go backend..."
go build ./cmd/simplex-node/
echo "✓ Backend builds"
echo ""

echo "=== All Checks Passed ==="