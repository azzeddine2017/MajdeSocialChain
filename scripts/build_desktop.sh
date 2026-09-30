#!/usr/bin/env bash
# ==============================================================================
# Mejde Network - Linux/macOS Desktop Builder (Powered by ring2exe-plus)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

DIST_DIR="$PROJECT_ROOT/release/Mejde-Linux-x64"
mkdir -p "$DIST_DIR"

echo "========================================================================"
echo "       MEJDE NETWORK - DESKTOP BUILDER (Powered by ring2exe-plus)"
echo "========================================================================"

echo ""
echo "[1/3] Building Frontend bundle and synchronizing brand logo..."
cd "$PROJECT_ROOT/frontend"
npm run build
cd "$PROJECT_ROOT"

echo ""
echo "[2/3] Compiling standalone Mejde executable using ring2exe-plus..."
if command -v ring2exe &> /dev/null; then
    ring2exe app.ring -gui -auto-libs -icon=public/logo.png -output=Mejde -release
elif command -v ring &> /dev/null; then
    ring ring2exe.ring app.ring -gui -auto-libs -icon=public/logo.png -output=Mejde -release
else
    echo "[ERROR] ring2exe or ring executable not found on PATH!"
    exit 1
fi

if [ -f "Mejde" ]; then
    mv "Mejde" "$DIST_DIR/"
    chmod +x "$DIST_DIR/Mejde"
fi

echo ""
echo "[3/3] Finalizing standalone distribution package..."
mkdir -p "$DIST_DIR/frontend/dist"
cp "frontend/dist/index.html" "$DIST_DIR/frontend/dist/"
if [ -d "public" ]; then
    cp -r "public" "$DIST_DIR/"
fi

echo ""
echo "========================================================================"
echo "[SUCCESS] Mejde Linux Standalone Application built successfully!"
echo "Location: $DIST_DIR"
echo "========================================================================"
