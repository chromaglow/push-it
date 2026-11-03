#!/usr/bin/env bash
# Double-click uninstaller for macOS. Same as: bash scripts/uninstall.sh
cd "$(dirname "$0")" && bash scripts/uninstall.sh
echo; read -n 1 -r -s -p "  Press any key to close..."; echo
