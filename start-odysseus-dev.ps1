#Requires -Version 5.1
<#
  Desktop launcher for the staging (develop) Odysseus worktree.
#>
& (Join-Path $PSScriptRoot "scripts\start-odysseus-profile.ps1") -Profile Dev @args
