# Fallback installer for Windows, for Claude Code setups without plugin support.
# Prefer the plugin: /plugin marketplace add chromaglow/push-it  then  /plugin install push-it@push-it
# Safe to rerun.
[CmdletBinding()]
param([switch]$NoPrompt)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host ''; Say 'PUSH IT  -  installer for Claude Code' Yellow; Write-Host ''

if (Test-PluginEnabled) {
    Say 'Push it is already installed as a Claude Code plugin. Nothing to do.' Green
    Say '(Installing both would play the sound twice.)'
    exit 0
}
$bash = Find-GitBash
if (-not $bash) { Fail 'Git for Windows is needed (Claude Code runs hooks with its Git Bash). Install it from https://git-scm.com/download/win and rerun.' }

# 1. files
if (Test-Path $AppDir) { Remove-Item -LiteralPath $AppDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
foreach ($d in 'hooks', 'config', 'sounds') { Copy-Item -Recurse -Force (Join-Path $Kit "plugin\$d") $AppDir }
# Keep any custom clips from the pre-1.0 kit, which stored them loose in the user folder.
$loose = @(Get-ChildItem -Path $UserDir -Filter *.wav -File -ErrorAction SilentlyContinue)
if ($loose.Count) {
    $dest = Join-Path $UserDir 'sounds'; New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $loose | Move-Item -Destination $dest -Force
}
Remove-Legacy
Say "[1/3] Copied the hook and sounds to $AppDir" Green

# 2. settings.json
Backup-File $Settings
$hookPath = (Join-Path $AppDir 'hooks\push-it.sh') -replace '\\', '/'
Update-SettingsFile -Mode add -Command "bash `"$hookPath`""
if (-not ((Read-Text $Settings) -match 'push-it\.sh')) { Fail "Could not confirm the hook in $Settings" }
Say "[2/3] Added the hook to $Settings (backup: settings.json.bak-$Stamp)" Green

# 3. run the installed hook exactly as Claude Code will
Say '[3/3] Testing the hook - turn your volume up...' Yellow
$out = Invoke-Hook $bash $hookPath 'push it'
if (-not $out) { Fail 'The hook ran but did not respond to "push it"' }
if (-not $NoPrompt) {
    $a = Read-Host '  Did you hear it? (y/n)'
    if ($a -notmatch '^[yY]') { Say 'Check your volume and default output device (Settings > System > Sound), then rerun. It is safe to rerun.' Yellow }
}
Write-Host ''; Say 'Done! Open a NEW Claude Code session and type:  push it' Cyan; Write-Host ''
