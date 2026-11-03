#!/usr/bin/env bash
# Removes the fallback install (and anything left by the pre-1.0 kit).
# Your own sounds and push-it.conf in ~/.claude/push-it are kept.
# Installed as a plugin? Use  /plugin uninstall push-it@push-it  instead.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$KIT/scripts/lib.sh"

if [ -f "$SETTINGS" ]; then
  backup "$SETTINGS"
  merge_settings remove
  say "Removed the hook from settings.json (backup: settings.json.bak-$STAMP)"
fi
remove_legacy
rm -rf "$APP_DIR"
rm -f "$USER_DIR/last-clip"
if [ -d "$USER_DIR" ]; then
  if [ -z "$(ls -A "$USER_DIR")" ]; then rmdir "$USER_DIR"
  else say "Kept your custom files in $USER_DIR"; fi
fi
say "Push it is uninstalled. Open a new Claude Code session."
