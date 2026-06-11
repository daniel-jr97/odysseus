#Requires -Version 5.1
<#
  Desktop launcher for the stable (main) Odysseus worktree.
#>
& (Join-Path $PSScriptRoot "scripts\start-odysseus-profile.ps1") -Profile Prod @args
