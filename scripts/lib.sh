# Shared helpers for install.sh / uninstall.sh. Sourced, not run.
# shellcheck shell=bash
# Variables here are used by the scripts that source this file:
# shellcheck disable=SC2034

CLAUDE_DIR="$HOME/.claude"
USER_DIR="$CLAUDE_DIR/push-it"     # user's custom sounds/config live here and survive uninstall
APP_DIR="$USER_DIR/app"            # what the installer copies; safe to delete
SETTINGS="$CLAUDE_DIR/settings.json"
RULES="$CLAUDE_DIR/CLAUDE.md"
STAMP="$(date +%Y%m%d-%H%M%S)"

say()  { printf '  %s\n' "$*"; }
fail() { printf '  X  %s\n' "$*" >&2; exit 1; }

backup() { [ -f "$1" ] && cp "$1" "$1.bak-$STAMP"; return 0; }

# True when the push-it plugin is enabled in user settings (both together would play twice).
plugin_enabled() { [ -f "$SETTINGS" ] && grep -Eq '"push-it@[^"]*"[[:space:]]*:[[:space:]]*true' "$SETTINGS"; }

# merge_settings add <command> | merge_settings remove
merge_settings() {
  mkdir -p "$CLAUDE_DIR"
  local script="$KIT/scripts/merge-settings.js"
  if command -v osascript >/dev/null 2>&1; then          # macOS: built in, nothing to install
    osascript -l JavaScript "$script" "$SETTINGS" "$@" >/dev/null
  elif command -v node >/dev/null 2>&1; then
    node "$script" "$SETTINGS" "$@"
  else
    fail "Editing settings.json needs Node.js on Linux. Install it, or use the plugin instead."
  fi
}

# The pre-1.0 kit appended a marked block to CLAUDE.md and kept files loose in USER_DIR.
remove_legacy() {
  if [ -f "$RULES" ] && grep -q 'push-it:start' "$RULES"; then
    backup "$RULES"
    perl -0pi -e 's/\s*<!-- push-it:start -->.*?<!-- push-it:end -->//s' "$RULES"
    say "Removed the old Push it rule from CLAUDE.md (backup: CLAUDE.md.bak-$STAMP)"
  fi
  rm -f "$USER_DIR"/push-hook.ps1 "$USER_DIR"/push-hook.sh "$USER_DIR"/push-hook.js "$USER_DIR"/last.txt
}
