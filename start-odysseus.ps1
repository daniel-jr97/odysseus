#Requires -Version 5.1
<#
  Desktop launcher: opens Odysseus in a server window + browser tab.
  Double-click the desktop shortcut to use this.
#>
param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1",
    [int]$MaxWaitSeconds = 90
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$url = "http://{0}:{1}" -f $BindHost, $Port
$launch = Join-Path $root "launch-odysseus.ps1"

if (-not (Test-Path $launch)) {
    Write-Host "ERROR: launch-odysseus.ps1 not found in $root" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

function Wait-ForServer {
    param([string]$TargetUrl, [int]$TimeoutSeconds)
    Write-Host "Waiting for Odysseus to start (up to ${TimeoutSeconds}s)..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $resp = Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
                return $true
            }
        } catch {
            # Connection refused / timeout — server still booting.
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

# Server logs in a dedicated window (close it or Ctrl+C to stop Odysseus).
Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-File", $launch,
    "-Port", "$Port",
    "-BindHost", $BindHost
) -WorkingDirectory $root

if (Wait-ForServer -TargetUrl $url -TimeoutSeconds $MaxWaitSeconds) {
    Write-Host "Odysseus is ready — opening browser." -ForegroundColor Green
} else {
    Write-Host "Odysseus is still starting — opening browser anyway (refresh if needed)." -ForegroundColor Yellow
}

Start-Process $url
Start-Sleep -Seconds 2
