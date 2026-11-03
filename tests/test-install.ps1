# Round-trip test for the Windows fallback installer. Never touches your real profile:
# it runs the installer in a child process whose USERPROFILE points at a temp folder.
#   powershell -ExecutionPolicy Bypass -File tests\test-install.ps1     (Windows PowerShell 5.1)
#   pwsh -File tests\test-install.ps1                                   (PowerShell 7)
$ErrorActionPreference = 'Stop'
# If anything crashes, say exactly what and where (CI logs are only visible when signed in).
trap {
    $msg = "$($_.Exception.Message) (tests\test-install.ps1 line $($_.InvocationInfo.ScriptLineNumber))"
    Write-Host "CRASH  $msg" -ForegroundColor Red
    if ($env:GITHUB_ACTIONS) { Write-Output "::error title=Windows installer test crashed::$msg" }
    exit 1
}
$repo = Split-Path $PSScriptRoot -Parent
$shell = (Get-Process -Id $PID).Path
$script:failed = 0; $script:passed = 0
function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { $script:passed++ } else {
        $script:failed++; Write-Host "FAIL  $Name" -ForegroundColor Red
        if ($env:GITHUB_ACTIONS) { Write-Output "::error title=Windows installer test::$Name" }
    }
}
function Invoke-Installer([string]$Home_, [string]$Script, [string[]]$Extra = @()) {
    $old = $env:USERPROFILE, $env:HOME
    $env:USERPROFILE = $Home_; $env:HOME = $Home_; $env:PUSHIT_NO_SOUND = '1'
    try { & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts\$Script") @Extra | Out-Host; return $LASTEXITCODE }
    finally { $env:USERPROFILE, $env:HOME = $old }
}

$h = Join-Path ([IO.Path]::GetTempPath()) ("pushit-test-" + [guid]::NewGuid())
$c = Join-Path $h '.claude'
New-Item -ItemType Directory -Force -Path (Join-Path $c 'push-it') | Out-Null
$settings = Join-Path $c 'settings.json'
@'
{
  "model": "keep-me",
  "hooks": { "UserPromptSubmit": [
    { "hooks": [ { "type": "command", "command": "echo other-hook" } ] },
    { "hooks": [ { "type": "command", "command": "bash ~/bin/git-push-hook.sh" },
                 { "type": "command", "command": "powershell -File C:/u/.claude/push-it/push-hook.ps1" } ] } ] }
}
'@ | Set-Content -Path $settings -Encoding UTF8
"# My rules`n`n<!-- push-it:start -->`nold rule`n<!-- push-it:end -->`n" | Set-Content -Path (Join-Path $c 'CLAUDE.md')
$sample = (Get-ChildItem (Join-Path $repo 'plugin\sounds') -Filter *.wav | Select-Object -First 1).FullName
Copy-Item $sample (Join-Path $c 'push-it\legacy-custom.wav')

Check 'install succeeds' ((Invoke-Installer $h 'install.ps1' @('-NoPrompt')) -eq 0)
Check 'rerun succeeds' ((Invoke-Installer $h 'install.ps1' @('-NoPrompt')) -eq 0)
$s = Get-Content $settings -Raw
Check 'hook registered exactly once' (([regex]::Matches($s, 'push-it\.sh')).Count -eq 1)
Check 'unrelated settings kept' ($s.Contains('keep-me') -and $s.Contains('other-hook'))
Check 'similar-looking user hook in the same group kept' ($s.Contains('git-push-hook.sh'))
Check 'legacy hook entry removed' (-not $s.Contains('push-it/push-hook'))
Check 'hook list is a JSON array of 3 groups' (@((ConvertFrom-Json $s).hooks.UserPromptSubmit).Count -eq 3)
$rules = Get-Content (Join-Path $c 'CLAUDE.md') -Raw
Check 'legacy CLAUDE.md block removed, rest kept' ((-not $rules.Contains('push-it:start')) -and $rules.Contains('My rules'))
Check 'legacy custom clip migrated' (Test-Path (Join-Path $c 'push-it\sounds\legacy-custom.wav'))

Check 'uninstall succeeds' ((Invoke-Installer $h 'uninstall.ps1') -eq 0)
$s = Get-Content $settings -Raw
Check 'uninstall removes the hook' (-not $s.Contains('push-it.sh'))
Check 'uninstall keeps other hooks' ($s.Contains('other-hook'))
Check 'uninstall removes app files' (-not (Test-Path (Join-Path $c 'push-it\app')))
Check 'uninstall keeps custom sounds' (Test-Path (Join-Path $c 'push-it\sounds\legacy-custom.wav'))

# clean install + uninstall leaves no trace
$h2 = "$h-2"; $c2 = Join-Path $h2 '.claude'; New-Item -ItemType Directory -Force -Path $c2 | Out-Null
'{"model":"x"}' | Set-Content -Path (Join-Path $c2 'settings.json')
$null = Invoke-Installer $h2 'install.ps1' @('-NoPrompt'); $null = Invoke-Installer $h2 'uninstall.ps1'
Check 'clean uninstall leaves no hooks object' (-not (Get-Content (Join-Path $c2 'settings.json') -Raw).Contains('"hooks"'))
Check 'clean uninstall removes the user folder' (-not (Test-Path (Join-Path $c2 'push-it')))

# never install over the plugin; a disabled plugin doesn't count
'{"enabledPlugins":{"push-it@push-it":true}}' | Set-Content -Path (Join-Path $c2 'settings.json')
$null = Invoke-Installer $h2 'install.ps1' @('-NoPrompt')
Check 'installer refuses to double-install over the plugin' (-not (Test-Path (Join-Path $c2 'push-it')))
'{"enabledPlugins":{"push-it@push-it":false}}' | Set-Content -Path (Join-Path $c2 'settings.json')
$null = Invoke-Installer $h2 'install.ps1' @('-NoPrompt')
Check 'a disabled plugin does not block the installer' ((Get-Content (Join-Path $c2 'settings.json') -Raw).Contains('push-it.sh'))

# invalid settings.json: fail cleanly, leave it unchanged
'{ "model": ' | Set-Content -Path (Join-Path $c2 'settings.json') -NoNewline
Check 'invalid settings.json fails cleanly' ((Invoke-Installer $h2 'install.ps1' @('-NoPrompt')) -ne 0)
Check 'invalid settings.json left unchanged' ((Get-Content (Join-Path $c2 'settings.json') -Raw) -eq '{ "model": ')

Remove-Item -LiteralPath $h, $h2 -Recurse -Force
Write-Host ''; Write-Host "passed: $script:passed  failed: $script:failed"
if ($script:failed) { exit 1 }
exit 0
