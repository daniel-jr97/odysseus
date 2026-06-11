#Requires -Version 5.1
<#
  Create (or refresh) desktop shortcuts for prod and dev Odysseus worktrees.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-shortcut.ps1
#>
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "odysseus-profiles.ps1")

function Install-OdysseusShortcut {
    param(
        [string]$ProfileName,
        [string]$StarterScript
    )

    $cfg = Get-OdysseusProfile $ProfileName
    $starter = Join-Path $root $StarterScript
    if (-not (Test-Path $starter)) {
        throw "$StarterScript not found at $starter"
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "$($cfg.Shortcut).lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$starter`""
    $shortcut.WorkingDirectory = $root
    $shortcut.Description = $cfg.Description
    $icon = Join-Path $cfg.RepoRoot "static\napzter-logo.png"
    if (Test-Path $icon) {
        $shortcut.IconLocation = "$($icon),0"
    } else {
        Write-Host "  WARNING: Logo not found at $icon - shortcut keeps its previous icon." -ForegroundColor Yellow
    }
    $shortcut.Save()

    Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
}

Install-OdysseusShortcut -ProfileName Prod -StarterScript "start-odysseus-prod.ps1"
Install-OdysseusShortcut -ProfileName Dev -StarterScript "start-odysseus-dev.ps1"

$legacy = Join-Path ([Environment]::GetFolderPath("Desktop")) "Odysseus.lnk"
if (Test-Path $legacy) {
    Remove-Item $legacy -Force
    Write-Host "Removed legacy shortcut: $legacy" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Prod -> http://127.0.0.1:$((Get-OdysseusProfile Prod).Port)  (main, E:\Odysseus)"
Write-Host "Dev  -> http://127.0.0.1:$((Get-OdysseusProfile Dev).Port)  (develop, E:\Odysseus-develop)"
