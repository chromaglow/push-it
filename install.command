#!/usr/bin/env bash
# Double-click installer for macOS. Same as: bash scripts/install.sh
cd "$(dirname "$0")" && bash scripts/install.sh
echo; read -n 1 -r -s -p "  Press any key to close..."; echo
