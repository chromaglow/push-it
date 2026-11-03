# Contributing

Thanks for helping. Push it is deliberately small, so most changes touch one file.

## Before you open a pull request

```bash
bash tests/run.sh                                                         # hook + installer tests
shellcheck -x plugin/hooks/*.sh scripts/*.sh tests/*.sh *.command         # lint
claude plugin validate . && claude plugin validate plugin                 # manifests
```

On Windows, also run `powershell -ExecutionPolicy Bypass -File tests\test-install.ps1`. CI runs all of this on Windows, macOS and Linux.

## Where things go

- **Behavior** (matching, playback, the message to Claude) lives only in `plugin/hooks/push-it.sh`.
- **New trigger phrases:** add a row to `tests/trigger-cases.tsv` first, then change `allowed_words` in `plugin/config/push-it.conf`.
- **Settings merging** exists twice, in `scripts/merge-settings.js` and `scripts/lib.ps1`. Change both, and add a case to both round-trip tests.
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before changing a design decision. If you change one, update that page too.

## Conventions

- The hook must always exit 0 and stay silent when it doesn't fire.
- No new runtime dependencies in the hook.
- Line endings are enforced by `.gitattributes`: CRLF for `.cmd` and `.ps1`, LF for everything else.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:` and so on).
- Add a line to `CHANGELOG.md` under an `Unreleased` heading.
- No copyrighted audio. Bundled sounds must be original or openly licensed.
