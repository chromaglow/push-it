#!/usr/bin/env bash
# Fallback installer for macOS and Linux, for Claude Code setups without plugin support.
# Prefer the plugin: /plugin marketplace add chromaglow/push-it  then  /plugin install push-it@push-it
# Safe to rerun. Set PUSHIT_NOPROMPT=1 to skip the "did you hear it?" question.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$KIT/scripts/lib.sh"

echo; say "PUSH IT  -  installer for Claude Code"; echo
command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$KIT" 2>/dev/null || true

if plugin_enabled; then
  say "Push it is already installed as a Claude Code plugin. Nothing to do."
  say "(Installing both would play the sound twice.)"
  exit 0
fi

# 1. files
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -R "$KIT/plugin/hooks" "$KIT/plugin/config" "$KIT/plugin/sounds" "$APP_DIR/"
chmod +x "$APP_DIR/hooks/push-it.sh"
# Keep any custom clips from the pre-1.0 kit, which stored them loose in USER_DIR.
for f in "$USER_DIR"/*.wav; do
  [ -f "$f" ] || continue
  mkdir -p "$USER_DIR/sounds"; mv "$f" "$USER_DIR/sounds/"
done
remove_legacy
say "[1/3] Copied the hook and sounds to $APP_DIR"

# 2. settings.json
backup "$SETTINGS"
merge_settings add "bash \"$APP_DIR/hooks/push-it.sh\""
grep -q 'push-it.sh' "$SETTINGS" || fail "Could not confirm the hook in $SETTINGS"
say "[2/3] Added the hook to $SETTINGS (backup: settings.json.bak-$STAMP)"

# 3. run the installed hook exactly as Claude Code will
say "[3/3] Testing the hook - turn your volume up..."
out="$(printf '{"prompt":"push it"}' | bash "$APP_DIR/hooks/push-it.sh")"
[ -n "$out" ] || fail "The hook ran but didn't respond to \"push it\""
if [ -z "${PUSHIT_NOPROMPT:-}" ]; then
  read -r -p "  Did you hear it? (y/n) " a
  case "$a" in [yY]*) ;; *) say "Check your volume and output device, then rerun this installer. It's safe to rerun." ;; esac
fi
echo; say "Done! Open a NEW Claude Code session and type:  push it"; echo
