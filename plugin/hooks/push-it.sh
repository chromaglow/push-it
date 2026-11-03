#!/usr/bin/env bash
# push-it: Claude Code UserPromptSubmit hook.
#
# Contract
#   stdin   Claude Code's hook JSON (we only read the "prompt" field).
#   stdout  When the prompt is a short push command: one line of context telling
#           Claude how to reply. Otherwise: nothing.
#   exit    Always 0. A sound effect must never block or break a prompt.
#
# One script serves macOS, Linux and Windows (Claude Code runs hooks through Git Bash
# on Windows). See docs/ARCHITECTURE.md for the design decisions.
#
# Environment (all optional)
#   PUSHIT_HOME         user folder for custom sounds/config (default ~/.claude/push-it)
#   CLAUDE_PLUGIN_DATA  set by Claude Code for plugins; where rotation state is kept
#   PUSHIT_NO_SOUND=1   skip playback and log the chosen clip to stderr (tests, CI)

set -u

# --- cheap pre-filter: most prompts never mention "push" ---------------------
# This runs on every message, and process start-up is slow in Git Bash, so reject
# with bash builtins only before doing anything else.
IFS= read -r -d '' input || true
case "$input" in *[Pp][Uu][Ss][Hh]*) ;; *) exit 0 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_DIR="${PUSHIT_HOME:-$HOME/.claude/push-it}"
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$USER_DIR}"

# --- config: bundled defaults, then the user's overrides --------------------
reply="Push it real good."
auto_commit=false
max_words=6
allowed_words=""

trim() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; REPLY="${v%"${v##*[![:space:]]}"}"; }  # result in $REPLY, no subshell
load_conf() {
  [ -f "$1" ] || return 0
  local key value
  while IFS='=' read -r key value || [ -n "$key" ]; do
    trim "$key"; key="$REPLY"
    trim "${value%$'\r'}"; value="$REPLY"       # tolerate CRLF files and stray spaces
    case "$key" in
      ''|\#*)        ;;
      reply)         reply="$value" ;;
      auto_commit)   auto_commit="$value" ;;
      max_words)     max_words="$value" ;;
      allowed_words) allowed_words="$value" ;;
    esac
  done < "$1"
}
load_conf "$ROOT/config/push-it.conf"
load_conf "$USER_DIR/push-it.conf"
case "$max_words" in ''|*[!0-9]*) max_words=6 ;; esac

# --- is this a push command? ------------------------------------------------
# Pull out the "prompt" string with a bash regex (no jq/node/python needed).
# Escapes are left as-is, which is fine for deciding "is this only a push command":
# an escaped newline or tab means a multi-line message, which never fires.
re='"prompt"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
[[ "$input" =~ $re ]] || exit 0
prompt="${BASH_REMATCH[1]}"
case "$prompt" in *'\n'*|*'\r'*|*'\t'*) exit 0 ;; esac

normalized="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' ' ')"
# shellcheck disable=SC2086  # word splitting is the point here
set -- $normalized
[ "${1:-}" = "push" ] || exit 0
[ "$#" -le "$max_words" ] || exit 0
shift
for word in "$@"; do        # every word after "push" must be on the list
  case " $allowed_words " in
    *" $word "*) ;;
    *) exit 0 ;;
  esac
done

# --- pick the next clip (user's sounds win over the bundled ones) ------------
clips=()
for dir in "$USER_DIR/sounds" "$ROOT/sounds"; do
  for f in "$dir"/*.wav; do [ -f "$f" ] && clips+=("$f"); done
  [ "${#clips[@]}" -gt 0 ] && break
done

play() {
  local file="$1" win
  if command -v afplay >/dev/null 2>&1; then
    afplay "$file"
  elif command -v powershell.exe >/dev/null 2>&1; then  # Windows Git Bash, or WSL
    win="$file"
    if command -v cygpath >/dev/null 2>&1; then win="$(cygpath -w "$file")"
    elif command -v wslpath >/dev/null 2>&1; then win="$(wslpath -w "$file")"; fi
    win="${win//\'/\'\'}"
    powershell.exe -NoProfile -NonInteractive -Command "(New-Object System.Media.SoundPlayer '$win').PlaySync()"
  elif command -v paplay >/dev/null 2>&1; then
    paplay "$file"
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q "$file"
  fi
}

if [ "${#clips[@]}" -gt 0 ]; then
  mkdir -p "$STATE_DIR" 2>/dev/null
  state="$STATE_DIR/last-clip"
  i="$(cat "$state" 2>/dev/null || echo -1)"
  case "$i" in ''|*[!0-9]*) i=-1 ;; esac
  i=$(( (i + 1) % ${#clips[@]} ))
  echo "$i" > "$state" 2>/dev/null
  if [ "${PUSHIT_NO_SOUND:-}" = "1" ]; then
    echo "push-it: would play ${clips[$i]}" >&2
  else
    play "${clips[$i]}" >/dev/null 2>&1
  fi
fi

# --- tell Claude what to do -------------------------------------------------
if [ "$auto_commit" = "true" ]; then
  action="If there are uncommitted changes, commit them with a short descriptive message. Then push the current branch (git push; set the upstream if needed)."
else
  action="Push the current branch (git push; set the upstream if needed). Do not commit anything yourself: if there are uncommitted changes, say so and offer to commit them."
fi
echo "push-it: The user's message is a push command and their push clip just played. Begin your reply with exactly: \"$reply\" $action If there is nothing to push, say so right after that line."
exit 0
