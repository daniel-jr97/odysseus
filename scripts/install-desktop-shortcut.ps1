#Requires -Version 5.1
<#
  Create (or refresh) a desktop shortcut for Odysseus.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-shortcut.ps1
#>
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$starter = Join-Path $root "start-odysseus.ps1"
if (-not (Test-Path $starter)) {
    throw "start-odysseus.ps1 not found at $starter"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Odysseus.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$starter`""
$shortcut.WorkingDirectory = $root
$shortcut.Description = "Start Odysseus AI workspace"
$shortcut.IconLocation = "imageres.dll,109"
$shortcut.Save()

Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
