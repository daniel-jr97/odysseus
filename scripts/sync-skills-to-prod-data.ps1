#Requires -Version 5.1
<#
  Copy published skills from dev data dir to prod data dir (SKILL.md only).
  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\sync-skills-to-prod-data.ps1
#>
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "odysseus-profiles.ps1")

$src = Join-Path (Get-OdysseusProfile Dev).DataDir "skills"
$dst = Join-Path (Get-OdysseusProfile Prod).DataDir "skills"

if (-not (Test-Path $src)) {
    throw "Dev skills dir not found: $src"
}

New-Item -ItemType Directory -Force -Path $dst | Out-Null
Get-ChildItem -Path $src -Recurse -Filter "SKILL.md" | ForEach-Object {
    $rel = $_.FullName.Substring($src.Length).TrimStart("\")
    $targetDir = Join-Path $dst (Split-Path $rel -Parent)
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item $_.FullName (Join-Path $dst $rel) -Force
    Write-Host "Copied $rel"
}

$usagePath = Join-Path $dst "_usage.json"
if (-not (Test-Path $usagePath)) {
    "{}" | Set-Content -Path $usagePath -Encoding UTF8
    Write-Host "Created empty _usage.json"
}

Write-Host ""
Write-Host "Prod skills ready at $dst"
