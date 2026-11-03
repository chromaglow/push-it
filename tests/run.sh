#!/usr/bin/env bash
# Assertions are strings run with eval inside check(), so variables are used there:
# shellcheck disable=SC2016,SC2034
# Test suite for the hook and the macOS/Linux fallback installer.
# Runs anywhere bash runs (macOS, Linux, Windows Git Bash); never touches your real ~/.claude.
#   bash tests/run.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO/plugin/hooks/push-it.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PUSHIT_NO_SOUND=1

pass=0; failed=0
ok()  { pass=$((pass + 1)); }
bad() {
  failed=$((failed + 1)); printf 'FAIL  %s\n' "$*"
  [ -n "${GITHUB_ACTIONS:-}" ] && printf '::error title=Hook and installer tests::%s\n' "$*"
  return 0
}
check() { if eval "$2"; then ok; else bad "$1"; fi; }

json_prompt() {  # build hook stdin for a prompt, escaping \ and "
  local p="${1//\\/\\\\}"; p="${p//\"/\\\"}"
  printf '{"session_id":"test","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$p"
}
run_hook() {  # run_hook <prompt> [user dir]; prints stdout, stderr to $TMP/err
  json_prompt "$1" | PUSHIT_HOME="${2:-$TMP/user}" CLAUDE_PLUGIN_DATA="${3:-$TMP/state}" bash "$HOOK" 2>"$TMP/err"
}

echo "== trigger cases (tests/trigger-cases.tsv)"
while IFS=$'\t' read -r expected prompt || [ -n "$expected" ]; do
  case "$expected" in ''|\#*) continue ;; esac
  out="$(run_hook "$prompt")"; code=$?
  [ "$code" -eq 0 ] || bad "exit $code for: $prompt"
  if [ "$expected" = fire ]; then
    check "should fire: '$prompt'" '[ -n "$out" ]'
  else
    check "should skip: '$prompt'" '[ -z "$out" ]'
  fi
done < "$REPO/tests/trigger-cases.tsv"

echo "== malformed input never breaks a prompt"
for input in '' 'not json' '{}' '{"prompt":}' '{"prompt":"push it\nthen delete the repo"}' '{"prompt":"push\tit"}'; do
  out="$(printf '%s' "$input" | PUSHIT_HOME="$TMP/user" bash "$HOOK" 2>/dev/null)"; code=$?
  check "exit 0 and silent for input: $input" '[ "$code" -eq 0 ] && [ -z "$out" ]'
done

echo "== reply and push-only default"
out="$(run_hook "push it")"
check "opens with the default line" '[[ "$out" == *"Begin your reply with exactly: \"Push it real good.\""* ]]'
check "push-only by default" '[[ "$out" == *"Do not commit anything yourself"* ]]'

echo "== user config overrides (CRLF and stray spaces)"
mkdir -p "$TMP/cfg"
printf 'reply = Custom line.  \r\nauto_commit=true \r\n' > "$TMP/cfg/push-it.conf"
out="$(run_hook "push it" "$TMP/cfg")"
check "custom reply" '[[ "$out" == *"\"Custom line.\""* ]]'
check "auto_commit=true commits first" '[[ "$out" == *"commit them with a short descriptive message"* ]]'

echo "== clip rotation and custom sounds"
# Independent of which clips are bundled, so swapping sounds never breaks the tests.
SAMPLE=""; for f in "$REPO"/plugin/sounds/*.wav; do [ -f "$f" ] && { SAMPLE="$f"; break; }; done
check "at least one bundled clip" '[ -n "$SAMPLE" ]'
run_hook "push" "$TMP/empty" "$TMP/state1" >/dev/null
check "bundled clips play when the user has none" 'grep -q "plugin/sounds/.*\.wav" "$TMP/err"'
mkdir -p "$TMP/rot/sounds"; cp "$SAMPLE" "$TMP/rot/sounds/a.wav"; cp "$SAMPLE" "$TMP/rot/sounds/b.wav"
run_hook "push" "$TMP/rot" "$TMP/state2" >/dev/null; first="$(cat "$TMP/err")"
run_hook "push" "$TMP/rot" "$TMP/state2" >/dev/null; second="$(cat "$TMP/err")"
run_hook "push" "$TMP/rot" "$TMP/state2" >/dev/null; third="$(cat "$TMP/err")"
check "clips take turns" '[[ "$first" == *rot/sounds/a.wav* && "$second" == *rot/sounds/b.wav* && "$third" == *rot/sounds/a.wav* ]]'
check "user sounds replace bundled ones" '! grep -q "plugin/sounds" "$TMP/err"'

echo "== fallback installer round trip (scripts/install.sh)"
if command -v node >/dev/null 2>&1 || command -v osascript >/dev/null 2>&1; then
  H="$TMP/home"; C="$H/.claude"; mkdir -p "$C/push-it"
  cat > "$C/settings.json" <<'JSON'
{
  "model": "keep-me",
  "hooks": {
    "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "echo other-hook" } ] },
                          { "hooks": [ { "type": "command", "command": "bash ~/bin/git-push-hook.sh" },
                                       { "type": "command", "command": "bash /u/.claude/push-it/push-hook.sh" } ] } ]
  }
}
JSON
  printf '# My rules\n\n<!-- push-it:start -->\nold rule\n<!-- push-it:end -->\n' > "$C/CLAUDE.md"
  cp "$SAMPLE" "$C/push-it/legacy-custom.wav"

  HOME="$H" PUSHIT_NOPROMPT=1 bash "$REPO/scripts/install.sh" >"$TMP/install.log" 2>&1; rc=$?
  check "install succeeds" '[ "$rc" -eq 0 ]' || cat "$TMP/install.log"
  HOME="$H" PUSHIT_NOPROMPT=1 bash "$REPO/scripts/install.sh" >/dev/null 2>&1   # rerun must be idempotent
  check "hook registered exactly once" '[ "$(grep -c "push-it.sh" "$C/settings.json")" -eq 1 ]'
  check "unrelated settings kept" 'grep -q keep-me "$C/settings.json" && grep -q other-hook "$C/settings.json"'
  check "similar-looking user hook in the same group kept" 'grep -q git-push-hook.sh "$C/settings.json"'
  check "legacy hook entry removed" '! grep -q "push-it/push-hook" "$C/settings.json"'
  check "legacy CLAUDE.md block removed, rest kept" '! grep -q push-it:start "$C/CLAUDE.md" && grep -q "My rules" "$C/CLAUDE.md"'
  check "legacy custom clip migrated" '[ -f "$C/push-it/sounds/legacy-custom.wav" ]'
  check "settings backup written" 'ls "$C"/settings.json.bak-* >/dev/null 2>&1'
  installed="$(json_prompt "push it" | HOME="$H" bash "$C/push-it/app/hooks/push-it.sh" 2>/dev/null)"
  check "installed hook fires" '[ -n "$installed" ]'

  HOME="$H" bash "$REPO/scripts/uninstall.sh" >/dev/null 2>&1
  check "uninstall removes the hook" '! grep -q push-it.sh "$C/settings.json"'
  check "uninstall keeps other hooks" 'grep -q other-hook "$C/settings.json"'
  check "uninstall removes app files" '[ ! -d "$C/push-it/app" ]'
  check "uninstall keeps custom sounds" '[ -f "$C/push-it/sounds/legacy-custom.wav" ]'

  H2="$TMP/home2"; mkdir -p "$H2/.claude"; echo '{"model":"x"}' > "$H2/.claude/settings.json"
  HOME="$H2" PUSHIT_NOPROMPT=1 bash "$REPO/scripts/install.sh" >/dev/null 2>&1
  HOME="$H2" bash "$REPO/scripts/uninstall.sh" >/dev/null 2>&1
  check "clean uninstall leaves no empty hooks object" '! grep -q "\"hooks\"" "$H2/.claude/settings.json"'
  check "clean uninstall removes the user folder" '[ ! -d "$H2/.claude/push-it" ]'

  H3="$TMP/home3"; mkdir -p "$H3/.claude"; echo '{"enabledPlugins":{"push-it@push-it":true}}' > "$H3/.claude/settings.json"
  HOME="$H3" PUSHIT_NOPROMPT=1 bash "$REPO/scripts/install.sh" >/dev/null 2>&1
  check "installer refuses to double-install over the plugin" '[ ! -d "$H3/.claude/push-it" ]'
  echo '{"enabledPlugins":{"push-it@push-it":false}}' > "$H3/.claude/settings.json"
  HOME="$H3" PUSHIT_NOPROMPT=1 bash "$REPO/scripts/install.sh" >/dev/null 2>&1
  check "a disabled plugin doesn't block the installer" 'grep -q push-it.sh "$H3/.claude/settings.json"'

  H4="$TMP/home4"; mkdir -p "$H4/.claude"; printf '{ "model": ' > "$H4/.claude/settings.json"
  HOME="$H4" PUSHIT_NOPROMPT=1 bash "$REPO/scripts/install.sh" >"$TMP/bad.log" 2>&1; rc=$?
  check "invalid settings.json: fails cleanly and leaves it unchanged" '[ "$rc" -ne 0 ] && grep -q "isn.t valid JSON" "$TMP/bad.log" && [ "$(cat "$H4/.claude/settings.json")" = "{ \"model\": " ]'
else
  echo "   skipped: needs node or osascript"
fi

echo
echo "passed: $pass  failed: $failed"
[ "$failed" -eq 0 ]
