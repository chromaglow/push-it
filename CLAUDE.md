# Push it: notes for Claude Code

This repo is the **Push it** plugin for Claude Code. Read `docs/ARCHITECTURE.md` before changing behavior.

## If the user asks you to install it

1. Prefer the plugin. Tell the user to run these in Claude Code, since they're slash commands you can't run for them:
   `/plugin marketplace add chromaglow/push-it`, then `/plugin install push-it@push-it`. Then start a new session.
2. If they can't use plugins, run the fallback installer from this folder without prompts:
   - Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -NoPrompt`
   - macOS or Linux: `PUSHIT_NOPROMPT=1 bash scripts/install.sh`
3. Show the installer's output. If it fails, show the exact error. Don't edit `settings.json` by hand.
4. Ask whether they heard the test clip. If not, point them to `docs/TROUBLESHOOTING.md`.

## If you're changing the code

- All runtime behavior is in `plugin/hooks/push-it.sh`. It must always exit 0 and stay silent unless it fires.
- Run `bash tests/run.sh` and `shellcheck -x plugin/hooks/*.sh scripts/*.sh tests/*.sh *.command` before calling a change done.
- New trigger phrases need a row in `tests/trigger-cases.tsv`.
- Follow `CONTRIBUTING.md`.
