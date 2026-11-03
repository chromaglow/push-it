# Troubleshooting

## Test the hook by hand

This runs the hook exactly as Claude Code does, outside Claude.

**Plugin install**, in a terminal (Git Bash on Windows):

```bash
echo '{"prompt":"push it"}' | bash "$(ls -d ~/.claude/plugins/cache/push-it/push-it/*/ | tail -1)hooks/push-it.sh"
```

**Fallback install:**

```bash
echo '{"prompt":"push it"}' | bash ~/.claude/push-it/app/hooks/push-it.sh
```

You should hear the clip, then see a line starting with `push-it: The user's message is a push command`.

## Nothing happens when I type "push it"

- **Start a new session.** Claude Code loads hooks when a session starts.
- **Check that it's installed.** Run `/plugin`; `push-it` should show as enabled. For the fallback, `~/.claude/settings.json` should contain `push-it.sh`.
- **Check the message.** It has to be the *whole* message, on one line, starting with "push", with every other word from `allowed_words` in [the config](../plugin/config/push-it.conf). `please push` and `push the meeting to friday` are ignored on purpose.
- **Windows:** make sure [Git for Windows](https://git-scm.com/download/win) is installed. Claude Code runs hooks with its Git Bash.

## Claude says the line but I hear nothing

- Turn the volume up and check the **default** output device: on Windows, Settings → System → Sound → Output; on macOS, System Settings → Sound → Output. A monitor without speakers is a common culprit.
- On Linux, install PulseAudio's `paplay` or ALSA's `aplay`.
- Run the hand test above. If it prints the line but stays silent, the problem is the audio device, not push-it.

## I hear the sound twice

You have both the plugin and the fallback installer active. Remove one: `/plugin uninstall push-it@push-it`, or run the uninstaller.

## My custom sound doesn't play

It must be a `.wav` file in `~/.claude/push-it/sounds/`. MP3 and M4A files are ignored. [GitTrim](https://github.com/chromaglow/GitTrim) converts any audio or video file to WAV in your browser.

## settings.json "isn't valid JSON"

The fallback installer won't edit a `settings.json` it can't read, and leaves it exactly as it was. Fix the file (a trailing comma is the usual cause), or restore one of the `settings.json.bak-*` copies next to it, then rerun.

## Still stuck?

[Open an issue](https://github.com/chromaglow/push-it/issues/new?template=bug_report.yml) with your OS, `claude --version` and the hand-test output.
