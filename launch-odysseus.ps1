#Requires -Version 5.1
<#
  Fast daily launcher — starts Odysseus only (no pip install, no setup.py).

  Use this or the desktop shortcut for everyday use. Run launch-windows.ps1
  (without -Quick) after git pull or when dependencies change.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\launch-odysseus.ps1
#>
param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1",
    [switch]$AccessLog
)

$launch = Join-Path $PSScriptRoot "launch-windows.ps1"
$args = @("-Quick", "-Port", "$Port", "-BindHost", $BindHost)
if ($AccessLog) { $args += "-AccessLog" }
& $launch @args
