#Requires -Version 5.1
<#
  Odysseus - native Windows launcher (no Docker).

  One command to: create a virtualenv, install dependencies, run first-time
  setup (prints an admin password on first run), and start the server.
  Safe to re-run - it skips whatever already exists.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 -Quick
    powershell -ExecutionPolicy Bypass -File .\launch-windows.ps1 -Port 7000 -BindHost 127.0.0.1

  -Quick  Skip pip install and setup.py (daily startup — use launch-odysseus.ps1
          or the desktop shortcut). Run the full script after pulling updates.

  Tip: bind 127.0.0.1 (default) for local-only use. Use 0.0.0.0 only when you
  intentionally want other devices on your LAN to reach it.
#>
param(
    [int]$Port = 7000,
    [string]$BindHost = "127.0.0.1",
    # Show every HTTP request line (cookbook/email polling is very chatty).
    [switch]$AccessLog,
    # Skip dependency install + setup.py (already configured installs).
    [switch]$Quick
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Write-Step($msg) { Write-Host ""; Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Fail($msg) {
    Write-Host ""
    Write-Host ("ERROR: " + $msg) -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

function Enable-ConsoleAnsi {
    # Restore colored uvicorn logs on native Windows (avoids raw ←[32m noise).
    if (-not ([Environment]::OSVersion.Platform -eq "Win32NT")) { return }
    try {
        $sig = @'
using System;
using System.Runtime.InteropServices;
public static class WinConsole {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetConsoleMode(IntPtr h, out uint mode);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetConsoleMode(IntPtr h, uint mode);
}
'@
        Add-Type -TypeDefinition $sig -ErrorAction Stop
        $ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
        foreach ($handleId in @(-11, -12)) {
            $h = [WinConsole]::GetStdHandle($handleId)
            $mode = [uint32]0
            if ([WinConsole]::GetConsoleMode($h, [ref]$mode)) {
                [void][WinConsole]::SetConsoleMode($h, ($mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING))
            }
        }
    } catch {
        # Non-fatal — logs still work, just without colors.
    }
}

function Find-GitBash {
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $roots = @()
    foreach ($name in @("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)", "LocalAppData")) {
        $base = [Environment]::GetEnvironmentVariable($name)
        if ($base) { $roots += (Join-Path $base "Git") }
    }
    $roots += @("C:\Program Files\Git", "C:\Program Files (x86)\Git")

    foreach ($root in ($roots | Select-Object -Unique)) {
        foreach ($relative in @("bin\bash.exe", "usr\bin\bash.exe")) {
            $candidate = Join-Path $root $relative
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

$venvPy = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
$startChroma = Join-Path $PSScriptRoot "scripts\start-chromadb.ps1"
if (Test-Path $startChroma) {
    . $startChroma
    [void](Ensure-ChromaDbRunning -RepoRoot $PSScriptRoot)
}

if ($Quick) {
    if (-not (Test-Path $venvPy)) {
        Fail "venv not found. Run the full launcher once first: .\launch-windows.ps1"
    }
    Write-Step ("Starting Odysseus at http://{0}:{1}" -f $BindHost, $Port)
    Enable-ConsoleAnsi
    if (-not $AccessLog) {
        Write-Host "Quick start (skipped pip + setup). Pass -AccessLog for HTTP request logs."
    }
    Write-Host "Press Ctrl+C to stop."
    Write-Host ""
    $uvicornArgs = @("-m", "uvicorn", "app:app", "--host", $BindHost, "--port", "$Port")
    if (-not $AccessLog) { $uvicornArgs += "--no-access-log" }
    & $venvPy @uvicornArgs
    exit $LASTEXITCODE
}

# 1. Locate a Python interpreter (3.11+ required)
Write-Step "Checking for Python"
function Get-PythonVersionText($launcher, $launcherArgs) {
    try {
        return (& $launcher @launcherArgs -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>$null).Trim()
    } catch {
        return $null
    }
}

$pyExe = $null
$pyArgs = @()
$pyVersion = $null

$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pyLauncher) {
    foreach ($v in @("-3.13", "-3.12", "-3.11")) {
        $ver = Get-PythonVersionText $pyLauncher.Source @($v)
        if ($ver) {
            $pyExe = $pyLauncher.Source
            $pyArgs = @($v)
            $pyVersion = $ver
            break
        }
    }
}

if (-not $pyExe) {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $ver = Get-PythonVersionText $pythonCmd.Source @()
        if ($ver) {
            $versionParts = $ver.Split('.')
            $major = [int]$versionParts[0]
            $minor = [int]$versionParts[1]
            if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 11)) {
                $pyExe = $pythonCmd.Source
                $pyVersion = $ver
            }
        }
    }
}

if (-not $pyExe) {
    Fail "Couldn't find Python 3.11+ for Windows setup. Install Python 3.11+ (or open the Python launcher with 'py -3.11') from https://www.python.org/downloads/, then re-run this script."
}
$pythonLabel = ("Using Python {0}: {1} {2}" -f $pyVersion, $pyExe, ($pyArgs -join ' ')).TrimEnd()
Write-Host $pythonLabel

# 2. Create the virtualenv if missing
if (-not (Test-Path $venvPy)) {
    Write-Step "Creating virtual environment (venv)"
    & $pyExe @pyArgs -m venv venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPy)) { Fail "Failed to create the virtual environment." }
} else {
    Write-Host "venv already exists - skipping creation."
}

# 3. Install / update dependencies
Write-Step "Installing dependencies (first run can take a few minutes)"
& $venvPy -m pip install --upgrade pip --quiet
& $venvPy -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { Fail "Dependency install failed. Scroll up for the pip error." }

# Native Windows: ChromaDB server CLI (RAG / memory vectors). The app uses
# chromadb-client over HTTP; the full package provides `chroma run`.
$chromaCli = Join-Path $PSScriptRoot "venv\Scripts\chroma.exe"
if (-not (Test-Path $chromaCli)) {
    Write-Host "Installing ChromaDB server package (for local vector store)..."
    & $venvPy -m pip install chromadb --quiet
}

# 4. First-time setup (creates data dirs, DB, .env, admin user)
Write-Step "Running first-time setup"
& $venvPy setup.py
if ($LASTEXITCODE -ne 0) { Fail "setup.py failed." }

# 5. Friendly note about Git Bash (full Cookbook / agent-shell parity)
if (-not (Find-GitBash)) {
    Write-Host ""
    Write-Host "NOTE: Git Bash (bash.exe) was not found on PATH." -ForegroundColor Yellow
    Write-Host "      The core app works without it. For full Cookbook background" -ForegroundColor Yellow
    Write-Host "      downloads and the agent shell tool, install Git for Windows:" -ForegroundColor Yellow
    Write-Host "      https://git-scm.com/download/win" -ForegroundColor Yellow
}

# 6. Start the server (use `python -m uvicorn` - bare `uvicorn` may not be on PATH)
Write-Step ("Starting Odysseus at http://{0}:{1}" -f $BindHost, $Port)
Enable-ConsoleAnsi
if (-not $AccessLog) {
    Write-Host "HTTP access log suppressed (UI polling is chatty). Pass -AccessLog to show every request."
}
Write-Host "Press Ctrl+C to stop."
Write-Host ""
$uvicornArgs = @(
    "-m", "uvicorn", "app:app",
    "--host", $BindHost,
    "--port", "$Port"
)
if (-not $AccessLog) {
    $uvicornArgs += "--no-access-log"
}
& $venvPy @uvicornArgs
