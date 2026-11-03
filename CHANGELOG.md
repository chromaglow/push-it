# Changelog

All notable changes are listed here. This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- New bundled clips (`push1.wav`, `push2.wav`).
- The clip trimmer moved to its own project, [GitTrim](https://github.com/chromaglow/GitTrim). The README and troubleshooting guide link there, and `tools/` is gone.

### Fixed
- CI: PSScriptAnalyzer now runs correctly, and crashes in the test suites are reported as errors.
- CI: the Windows installer test no longer fails after all checks pass (it inherited the last installer's deliberate error code), and its helper is renamed so PSScriptAnalyzer stops flagging it.

## [1.0.0] - 2026-11-03

First public release. Replaces the earlier zip kit that was shared privately.

### Added
- Claude Code plugin: install with `/plugin marketplace add chromaglow/push-it` and `/plugin install push-it@push-it`.
- One cross-platform hook (`plugin/hooks/push-it.sh`) for Windows, macOS and Linux.
- Settings file (`plugin/config/push-it.conf`) for the reply line, trigger words and opt-in `auto_commit`, overridable from `~/.claude/push-it/push-it.conf`.
- Custom sounds in `~/.claude/push-it/sounds/`, kept across updates and uninstalls.
- Test suite, shared trigger cases and CI on Windows, macOS and Linux.
- Architecture and troubleshooting docs.

### Changed
- Stricter matching: every word after "push" must be on an allow list, messages must be one line and 6 words or fewer, so phrases like "push the meeting to friday" no longer fire.
- Pushes only by default. If there are uncommitted changes, Claude says so and offers to commit, instead of committing on its own.
- No longer edits `~/.claude/CLAUDE.md`. The hook passes instructions to Claude directly.
- The fallback installers only touch push-it's own hook entry, upgrade the old kit in place, won't install over the plugin, and stop cleanly if `settings.json` is invalid.

### Fixed
- Uninstalling no longer leaves an empty `UserPromptSubmit` list in `settings.json`.

[Unreleased]: https://github.com/chromaglow/push-it/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/chromaglow/push-it/releases/tag/v1.0.0
