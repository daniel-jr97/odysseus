#Requires -Version 5.1
<#
  One-time (or refresh) setup for prod + dev git worktrees.

  - E:\Odysseus          -> main branch (production)
  - E:\Odysseus-develop  -> develop branch (staging)
  - E:\OdysseusData      -> production data
  - E:\OdysseusData-dev  -> development data

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-worktrees.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\setup-worktrees.ps1 -SkipDevSetup
#>
param(
    [switch]$SkipDevSetup
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

. (Join-Path $PSScriptRoot "odysseus-profiles.ps1")
$prod = Get-OdysseusProfile Prod
$dev = Get-OdysseusProfile Dev
$mainRoot = $prod.RepoRoot

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Set-EnvFileValue {
    param(
        [string]$EnvPath,
        [string]$Key,
        [string]$Value
    )

    $lines = @()
    if (Test-Path $EnvPath) {
        $lines = @(Get-Content $EnvPath -Encoding UTF8)
    }

    $pattern = "^\s*(#?\s*)?$([regex]::Escape($Key))\s*="
    $replacement = "$Key=$Value"
    $found = $false
    $updated = foreach ($line in $lines) {
        if ($line -match $pattern) {
            $found = $true
            $replacement
        } else {
            $line
        }
    }

    if (-not $found) {
        if ($updated.Count -gt 0 -and $updated[-1] -ne "") {
            $updated += ""
        }
        $updated += "# Instance settings (managed by scripts/setup-worktrees.ps1)"
        $updated += $replacement
    }

    $dir = Split-Path $EnvPath -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -Path $EnvPath -Value $updated -Encoding UTF8
}

function Initialize-InstanceEnv {
    param(
        $Profile,
        [string]$SourceEnvPath
    )

    $envPath = Join-Path $Profile.RepoRoot ".env"
    if (-not (Test-Path $envPath) -and (Test-Path $SourceEnvPath)) {
        Copy-Item $SourceEnvPath $envPath
        Write-Host "  Copied .env -> $envPath"
    } elseif (-not (Test-Path $envPath)) {
        $example = Join-Path $Profile.RepoRoot ".env.example"
        if (Test-Path $example) {
            Copy-Item $example $envPath
            Write-Host "  Created .env from .env.example"
        } else {
            New-Item -ItemType File -Force -Path $envPath | Out-Null
            Write-Host "  Created empty .env"
        }
    }

    Set-EnvFileValue -EnvPath $envPath -Key "ODYSSEUS_DATA_DIR" -Value $Profile.DataDir
    Set-EnvFileValue -EnvPath $envPath -Key "APP_PORT" -Value "$($Profile.Port)"
    Set-EnvFileValue -EnvPath $envPath -Key "CHROMADB_PORT" -Value "$($Profile.ChromaPort)"
    Write-Host "  Configured $($Profile.Label): data=$($Profile.DataDir), app=$($Profile.Port), chroma=$($Profile.ChromaPort)"
}

Write-Step "Checking git repository at $mainRoot"
if (-not (Test-Path (Join-Path $mainRoot ".git"))) {
    throw "Not a git repository: $mainRoot"
}

Write-Step "Ensuring main worktree is on branch '$($prod.Branch)'"
$current = git -C $mainRoot branch --show-current
if ($current -ne $prod.Branch) {
    git -C $mainRoot checkout $prod.Branch
    if ($LASTEXITCODE -ne 0) { throw "Failed to checkout $($prod.Branch) in $mainRoot" }
}

Write-Step "Creating develop worktree at $($dev.RepoRoot)"
if (Test-Path $dev.RepoRoot) {
    $wtList = git -C $mainRoot worktree list --porcelain
    if ($wtList -match [regex]::Escape($dev.RepoRoot)) {
        Write-Host "  Worktree already exists."
    } else {
        throw "Path exists but is not a git worktree: $($dev.RepoRoot). Move or remove it, then re-run."
    }
} else {
    git -C $mainRoot worktree add $dev.RepoRoot $dev.Branch
    if ($LASTEXITCODE -ne 0) { throw "Failed to create worktree at $($dev.RepoRoot)" }
}

Write-Step "Linking shared Python venv into develop worktree"
$mainVenv = Join-Path $mainRoot "venv"
$devVenv = Join-Path $dev.RepoRoot "venv"
if (-not (Test-Path $mainVenv)) {
    Write-Host "  WARNING: $mainVenv not found. Run .\launch-windows.ps1 once on prod first." -ForegroundColor Yellow
} elseif (Test-Path $devVenv) {
    Write-Host "  venv already present in develop worktree."
} else {
    cmd /c mklink /J "$devVenv" "$mainVenv" | Out-Null
    Write-Host "  Junction: $devVenv -> $mainVenv"
}

Write-Step "Creating data directories"
foreach ($dir in @($prod.DataDir, $dev.DataDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "  $dir"
}

Write-Step "Writing per-instance .env files"
$mainEnv = Join-Path $mainRoot ".env"
Initialize-InstanceEnv -Profile $prod -SourceEnvPath $mainEnv
Initialize-InstanceEnv -Profile $dev -SourceEnvPath $mainEnv

if (-not $SkipDevSetup) {
    Write-Step "Running first-time setup for develop instance (if needed)"
    $devDb = Join-Path $dev.DataDir "app.db"
    $venvPy = Join-Path $dev.RepoRoot "venv\Scripts\python.exe"
    if (-not (Test-Path $venvPy)) {
        Write-Host "  Skipping setup.py - venv not available yet." -ForegroundColor Yellow
    } elseif (Test-Path $devDb) {
        Write-Host "  Develop data already initialized ($devDb)."
    } else {
        Push-Location $dev.RepoRoot
        try {
            & $venvPy setup.py
            if ($LASTEXITCODE -ne 0) { throw "setup.py failed for develop instance." }
        } finally {
            Pop-Location
        }
    }
}

Write-Step "Worktree layout"
git -C $mainRoot worktree list

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host "  Prod: $($prod.RepoRoot)  [$($prod.Branch)]  http://127.0.0.1:$($prod.Port)"
Write-Host "  Dev:  $($dev.RepoRoot)  [$($dev.Branch)]  http://127.0.0.1:$($dev.Port)"
Write-Host ""
Write-Host 'Next: powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-shortcut.ps1'
