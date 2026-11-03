<p align="center"><img src="plugin/.claude-plugin/icon.png" width="96" alt=""></p>

<h1 align="center">Push it</h1>

<p align="center">
  Type <b><code>push it</code></b> in Claude Code. A clip plays, Claude says <b>"Push it real good."</b>, and your branch goes up to GitHub.
</p>

<p align="center">
  <a href="https://github.com/chromaglow/push-it/actions/workflows/ci.yml"><img src="https://github.com/chromaglow/push-it/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-d97757.svg" alt="Claude Code plugin">
</p>

---

## Quick start

In Claude Code, run:

```
/plugin marketplace add chromaglow/push-it
/plugin install push-it@push-it
```

Start a new session and type `push it`. That's it.

<details>
<summary><b>No plugin support? Use the installer instead</b></summary>

```bash
git clone https://github.com/chromaglow/push-it.git
cd push-it
```

| Computer | Double-click | Or run |
| --- | --- | --- |
| Windows | `install.cmd` | `powershell -ExecutionPolicy Bypass -File scripts\install.ps1` |
| macOS | `install.command` | `bash scripts/install.sh` |
| Linux | | `bash scripts/install.sh` (needs Node.js) |

The installer copies the hook to `~/.claude/push-it/app`, adds one entry to `~/.claude/settings.json` (backing it up first and keeping everything else), and plays a test clip. On Windows, PowerShell may reformat `settings.json` while doing this; the content is the same and the backup is next to it. It's safe to rerun. Prefer to let Claude do it? Open Claude Code in the folder and say *"install push-it for me"*.

If Windows says "Windows protected your PC", click **More info → Run anyway**. If macOS blocks the file, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
</details>

## What it does

When your **whole message** is a short, single-line push command, Push it:

1. plays a clip (the bundled clips take turns, or use your own), then
2. tells Claude to open its reply with **"Push it real good."** and push the current branch, setting the upstream if needed.

By default it **only pushes**. If you have uncommitted changes, Claude tells you and offers to commit; it never commits on its own unless you turn on `auto_commit`.

| Fires | Doesn't fire |
| --- | --- |
| `push` · `push it` · `Push it!` · `push to github` · `push my changes` · `push to main` | `push back on that idea` · `push the meeting to friday` · `please push` · `git push origin main` |

The full list of cases is in [`tests/trigger-cases.tsv`](tests/trigger-cases.tsv), and CI checks every one on Windows, macOS and Linux.

## Customize

Create a `push-it` folder inside your `.claude` folder and put any of these in it. Your files win over the defaults and survive updates and uninstalls.

The folder is `C:\Users\<you>\.claude\push-it` on Windows and `~/.claude/push-it` on macOS and Linux. On a Mac, `.claude` is hidden in Finder; press **Cmd+Shift+.** to show it.

| Want to… | Do this |
| --- | --- |
| Use your own sound | Put one or more `.wav` files in `~/.claude/push-it/sounds/`. They take turns. |
| Cut a clip from a song or video | Use [GitTrim](https://github.com/chromaglow/GitTrim), a free in-browser trimmer that exports WAV. Nothing is uploaded. |
| Change the line Claude says | Copy [`plugin/config/push-it.conf`](plugin/config/push-it.conf) to `~/.claude/push-it/push-it.conf` and edit `reply=`. |
| Let it commit before pushing | In that same file, set `auto_commit=true`. |
| Change which phrases fire | Edit `allowed_words=` and `max_words=` in that file. |

Sounds must be WAV, since that's the one format every OS can play without extra software. About 2 seconds works best, because Claude waits for the clip before replying.

## Compatibility

| Platform | Status | Notes |
| --- | --- | --- |
| macOS | ✅ CI tested | Plays with the built-in `afplay`. |
| Linux | ✅ CI tested | Needs `paplay` or `aplay` for sound. |
| Windows | ✅ CI tested | Needs [Git for Windows](https://git-scm.com/download/win), which Claude Code uses to run hooks (and you need anyway to push). |
| Cloud and web sessions | ⚠️ No sound | Sound can only play on your own computer. |

"CI tested" covers matching, configuration, rotation and install/uninstall. Audio playback itself can't be tested on CI servers, so if you hear nothing, see [Troubleshooting](docs/TROUBLESHOOTING.md).

## Uninstall

- **Plugin:** `/plugin uninstall push-it@push-it`, then `/plugin marketplace remove push-it` to remove the source too.
- **Installer:** double-click `uninstall.cmd` or `uninstall.command`, or run `scripts/uninstall.ps1` or `scripts/uninstall.sh`. Your custom sounds and config are kept.

## FAQ

**Does it send anything anywhere?** No. It's a local script that reads your message, plays a file and prints one line for Claude. It makes no network requests. It stores only which clip played last, so the next one can take a turn.

**Does it slow down every message?** No. It runs on every prompt, but if the message doesn't contain "push" it exits without starting a single extra process. Only when it fires does Claude wait for the clip, about 2 seconds.

**Could it push by accident?** It only fires on messages that are nothing but a push command, like `push it to main`. Anything else, like `push the meeting to friday`, a multi-line message or more than 6 words, is ignored. Pushing then goes through Claude's normal permission prompts.

**Can I use a clip from the actual song?** For your own machine, that's between you and the song's rights holders. Please don't commit copyrighted audio to forks of this repo.

## Learn more

- [How it works and why it's built this way](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

## License

[MIT](LICENSE) © Ezra Shively-Stjarna. The bundled sounds and their source are listed in [plugin/sounds/README.md](plugin/sounds/README.md).
