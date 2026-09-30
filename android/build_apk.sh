#!/bin/bash
set -e

echo "========================================================================"
echo "       MEJDE NETWORK - ANDROID APK BUILDER (ring2apk)                   "
echo "       بناء تطبيق مَجْد لنظام أندرويد (تجميع البايت كود والواجهة)        "
echo "========================================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
cd "$PROJECT_ROOT"

echo ""
echo "[1/3] Building Frontend bundle (Svelte + Vite)..."
cd "$PROJECT_ROOT/frontend"
npm run build
cd "$PROJECT_ROOT"

echo ""
echo "[2/3] Preparing Android assets directory..."
mkdir -p "$PROJECT_ROOT/android/assets/dist"
cp "$PROJECT_ROOT/frontend/dist/index.html" "$PROJECT_ROOT/android/assets/dist/index.html"
echo "[*] Frontend assets copied to android/assets/dist/index.html"

echo ""
echo "[3/3] Triggering ring2apk Android compilation..."
if ! command -v ring &> /dev/null; then
    echo "[ERROR] Ring compiler not found in PATH!"
    exit 1
fi

ring ring2apk.ring

echo ""
echo "========================================================================"
echo "[DONE] Android compilation process finished."
echo "========================================================================"
