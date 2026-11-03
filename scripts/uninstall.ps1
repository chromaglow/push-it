# Removes the fallback install (and anything left by the pre-1.0 kit).
# Your own sounds and push-it.conf in ~\.claude\push-it are kept.
# Installed as a plugin? Use  /plugin uninstall push-it@push-it  instead.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

if (Test-Path $Settings) {
    Backup-File $Settings
    Update-SettingsFile -Mode remove
    Say "Removed the hook from settings.json (backup: settings.json.bak-$Stamp)" Green
}
Remove-Legacy
foreach ($p in $AppDir, (Join-Path $UserDir 'last-clip')) {
    if (Test-Path $p) { Remove-Item -LiteralPath $p -Recurse -Force }
}
if (Test-Path $UserDir) {
    if (@(Get-ChildItem -LiteralPath $UserDir -Force).Count -eq 0) { Remove-Item -LiteralPath $UserDir -Force }
    else { Say "Kept your custom files in $UserDir" }
}
Say 'Push it is uninstalled. Open a new Claude Code session.' Green
