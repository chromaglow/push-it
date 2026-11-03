# Shared helpers for install.ps1 / uninstall.ps1. Dot-sourced, not run.
# Mirrors scripts/lib.sh and scripts/merge-settings.js; keep the three in step.

$Kit       = Split-Path $PSScriptRoot -Parent
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$UserDir   = Join-Path $ClaudeDir 'push-it'   # user's custom sounds/config; survive uninstall
$AppDir    = Join-Path $UserDir 'app'          # what the installer copies; safe to delete
$Settings  = Join-Path $ClaudeDir 'settings.json'
$Rules     = Join-Path $ClaudeDir 'CLAUDE.md'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8      = New-Object System.Text.UTF8Encoding $false
# push-it's own hook commands: the fallback install and the pre-1.0 kit. Nothing else is touched.
$OursPattern = '[\\/]push-it[\\/](app[\\/]hooks[\\/]push-it\.sh|push-hook\.(ps1|sh|js))'

# Windows PowerShell 5.1 can serialize arrays as {value, Count}; drop the type data that causes it.
if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }

function Say([string]$Text, [string]$Color = 'Gray') { Write-Host "  $Text" -ForegroundColor $Color }
function Fail([string]$Text) { Write-Host "  X  $Text" -ForegroundColor Red; exit 1 }
function Read-Text([string]$Path) { [IO.File]::ReadAllText($Path).TrimStart([char]0xFEFF) }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $Utf8) }
function Backup-File([string]$Path) { if (Test-Path $Path) { Copy-Item $Path "$Path.bak-$Stamp" } }

function Find-GitBash {
    $candidates = @()
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        # Standard installs: ...\Git\cmd\git.exe -> ...\Git\bin\bash.exe
        $candidates += Join-Path (Split-Path (Split-Path $git.Source -Parent) -Parent) 'bin\bash.exe'
        # Scoop and other shims: ask git where it really lives (...\mingw64\libexec\git-core)
        $exec = & git --exec-path 2>$null
        if ($exec) { $candidates += Join-Path $exec '..\..\..\bin\bash.exe' }
    }
    $candidates += "$env:ProgramFiles\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    foreach ($p in $candidates) { if ($p -and (Test-Path $p)) { return (Resolve-Path $p).Path } }
    return $null
}

function Test-PluginEnabled {
    (Test-Path $Settings) -and ((Read-Text $Settings) -match '"push-it@[^"]*"\s*:\s*true')
}

function Read-Settings {
    if (-not (Test-Path $Settings)) { return [pscustomobject]@{} }
    $t = Read-Text $Settings
    if (-not $t.Trim()) { return [pscustomobject]@{} }
    try { return ($t | ConvertFrom-Json) }
    catch { Fail "$Settings isn't valid JSON, so it was left unchanged. Fix it (or restore a .bak copy) and rerun." }
}

function Update-SettingsFile([ValidateSet('add', 'remove')][string]$Mode, [string]$Command) {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    $s = Read-Settings
    $hooks = if ($s.PSObject.Properties['hooks']) { $s.hooks } else { [pscustomobject]@{} }
    $groups = @()
    if ($hooks.PSObject.Properties['UserPromptSubmit']) {
        foreach ($group in @($hooks.UserPromptSubmit)) {
            if (-not ($group -and $group.PSObject.Properties['hooks'])) { $groups += $group; continue }
            $kept = @($group.hooks | Where-Object { -not ($_.command -is [string] -and $_.command -match $OursPattern) })
            if ($kept.Count) { $group.hooks = $kept; $groups += $group }
        }
        $hooks.PSObject.Properties.Remove('UserPromptSubmit')
    }
    if ($Mode -eq 'add') {
        $groups += [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $Command; timeout = 10 }) }
    }
    if ($groups.Count) { $hooks | Add-Member -NotePropertyName UserPromptSubmit -NotePropertyValue $groups }
    if ($s.PSObject.Properties['hooks']) { $s.PSObject.Properties.Remove('hooks') }
    if (@($hooks.PSObject.Properties).Count) { $s | Add-Member -NotePropertyName hooks -NotePropertyValue $hooks }
    Write-Text $Settings ((ConvertTo-Json -InputObject $s -Depth 30) + "`n")
}

# Runs the installed hook the way Claude Code will. Native stderr must not count as a
# PowerShell error here (Windows PowerShell 5.1 turns it into one under 'Stop').
function Invoke-Hook([string]$Bash, [string]$HookPath, [string]$Prompt) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return (("{`"prompt`":`"$Prompt`"}" | & $Bash $HookPath 2>$null) -join "`n") }
    finally { $ErrorActionPreference = $prev }
}

# The pre-1.0 kit appended a marked block to CLAUDE.md and kept files loose in the user folder.
function Remove-Legacy {
    if ((Test-Path $Rules) -and ((Read-Text $Rules) -match 'push-it:start')) {
        Backup-File $Rules
        Write-Text $Rules ([regex]::Replace((Read-Text $Rules), '\s*<!-- push-it:start -->[\s\S]*?<!-- push-it:end -->', ''))
        Say "Removed the old Push it rule from CLAUDE.md (backup: CLAUDE.md.bak-$Stamp)" Green
    }
    foreach ($f in 'push-hook.ps1', 'push-hook.sh', 'push-hook.js', 'last.txt') {
        $p = Join-Path $UserDir $f
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
    }
}
