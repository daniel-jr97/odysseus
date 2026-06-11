#Requires -Version 5.1
<#
  Create (or refresh) desktop shortcuts for prod and dev Napzter worktrees.

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

    $ico = Join-Path $cfg.RepoRoot $cfg.IconFile
    if (-not (Test-Path $ico)) {
        $variant = if ($ProfileName -eq "Dev") { "Dev" } else { "Prod" }
        & (Join-Path $PSScriptRoot "build-shortcut-icon.ps1") -RepoRoot $cfg.RepoRoot -Variant $variant
    }
    if (-not (Test-Path $ico)) {
        throw "Shortcut icon not found and could not be built: $ico"
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "$($cfg.Shortcut).lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$starter`""
    $shortcut.WorkingDirectory = $root
    $shortcut.Description = $cfg.Description
    $shortcut.IconLocation = "$($ico),0"
    $shortcut.Save()

    Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
}

function Remove-LegacyShortcut {
    param([string]$Name)
    $path = Join-Path ([Environment]::GetFolderPath("Desktop")) "$Name.lnk"
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "Removed legacy shortcut: $path" -ForegroundColor DarkGray
    }
}

& (Join-Path $PSScriptRoot "build-shortcut-icon.ps1") -RepoRoot (Get-OdysseusProfile Prod).RepoRoot -Variant Prod
$devRoot = (Get-OdysseusProfile Dev).RepoRoot
if (Test-Path $devRoot) {
    & (Join-Path $PSScriptRoot "build-shortcut-icon.ps1") -RepoRoot $devRoot -Variant Dev
}

Install-OdysseusShortcut -ProfileName Prod -StarterScript "start-odysseus-prod.ps1"
Install-OdysseusShortcut -ProfileName Dev -StarterScript "start-odysseus-dev.ps1"

foreach ($legacyName in @("Odysseus", "Odysseus (Prod)", "Odysseus (Dev)")) {
    Remove-LegacyShortcut -Name $legacyName
}

Write-Host ""
Write-Host "Napzter AI -> http://127.0.0.1:$((Get-OdysseusProfile Prod).Port)  (main, E:\Odysseus)"
Write-Host "Napzter Dev -> http://127.0.0.1:$((Get-OdysseusProfile Dev).Port)  (develop, E:\Odysseus-develop)"
