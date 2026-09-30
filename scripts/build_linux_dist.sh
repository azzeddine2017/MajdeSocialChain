#!/usr/bin/env bash
# Forward legacy build script to modern ring2exe-plus builder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/build_desktop.sh"
