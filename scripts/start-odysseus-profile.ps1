#Requires -Version 5.1
<#
  Launch Odysseus for a prod or dev worktree profile (server window + browser).

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\start-odysseus-profile.ps1 -Profile Prod
    powershell -ExecutionPolicy Bypass -File .\scripts\start-odysseus-profile.ps1 -Profile Dev
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Prod", "Dev")]
    [string]$Profile,

    [string]$BindHost = "127.0.0.1",
    [int]$MaxWaitSeconds = 90
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "odysseus-profiles.ps1")
$cfg = Get-OdysseusProfile $Profile

if (-not (Test-Path $cfg.RepoRoot)) {
    Write-Host "ERROR: Repo path not found: $($cfg.RepoRoot)" -ForegroundColor Red
    Write-Host "Run: powershell -ExecutionPolicy Bypass -File .\scripts\setup-worktrees.ps1" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$launch = Join-Path $cfg.RepoRoot "launch-odysseus.ps1"
if (-not (Test-Path $launch)) {
    Write-Host "ERROR: launch-odysseus.ps1 not found in $($cfg.RepoRoot)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$branch = git -C $cfg.RepoRoot branch --show-current 2>$null
if ($branch -and $branch -ne $cfg.Branch) {
    Write-Host "WARNING: Expected branch '$($cfg.Branch)' but '$branch' is checked out in $($cfg.RepoRoot)." -ForegroundColor Yellow
}

$url = "http://{0}:{1}" -f $BindHost, $cfg.Port
Write-Host ""
Write-Host "Odysseus $($cfg.Label)" -ForegroundColor Cyan
Write-Host "  Repo:  $($cfg.RepoRoot)"
Write-Host "  Branch: $($cfg.Branch) (checked out: $branch)"
Write-Host "  Data:  $($cfg.DataDir)"
Write-Host "  URL:   $url"
Write-Host ""

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
            # Server still booting.
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

# Dedicated server window for this instance (Ctrl+C or close window to stop).
Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-ExecutionPolicy", "Bypass",
    "-File", $launch,
    "-Port", "$($cfg.Port)",
    "-BindHost", $BindHost
) -WorkingDirectory $cfg.RepoRoot

if (Wait-ForServer -TargetUrl $url -TimeoutSeconds $MaxWaitSeconds) {
    Write-Host "Odysseus $($cfg.Label) is ready — opening browser." -ForegroundColor Green
} else {
    Write-Host "Odysseus is still starting — opening browser anyway (refresh if needed)." -ForegroundColor Yellow
}

Start-Process $url
Start-Sleep -Seconds 2
