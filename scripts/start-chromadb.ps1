#Requires -Version 5.1
<#
  Ensure a local ChromaDB server is running for RAG / memory vectors.

  Uses the full `chromadb` package's `chroma run` CLI (not Docker). Data is
  persisted under <ODYSSEUS_DATA_DIR>/chroma_server.

  Usage:
    . .\scripts\start-chromadb.ps1
    Ensure-ChromaDbRunning

  Environment (optional, read from .env in repo root):
    ODYSSEUS_DATA_DIR  — data root (default: <repo>/data)
    CHROMADB_HOST      — bind/connect host (default: 127.0.0.1)
    CHROMADB_PORT      — port (default: 8100)
#>

function Read-DotEnvValue {
    param([string]$EnvPath, [string]$Key)
    if (-not (Test-Path $EnvPath)) { return $null }
    foreach ($line in Get-Content $EnvPath -Encoding UTF8) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        if ($t -match '^\s*export\s+') { $t = $t -replace '^\s*export\s+', '' }
        if ($t -match ("^\s*{0}\s*=\s*(.+)$" -f [regex]::Escape($Key))) {
            $val = $Matches[1].Trim()
            if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                $val = $val.Substring(1, $val.Length - 2)
            }
            return $val
        }
    }
    return $null
}

function Test-TcpPortOpen {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 1500)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { $client.Close(); return $false }
        $client.EndConnect($iar) | Out-Null
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

function Ensure-ChromaDbRunning {
    param(
        [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
        [int]$MaxWaitSeconds = 30
    )

    $envFile = Join-Path $RepoRoot ".env"
    $dataDir = Read-DotEnvValue $envFile "ODYSSEUS_DATA_DIR"
    if (-not $dataDir) { $dataDir = Join-Path $RepoRoot "data" }

    $hostName = Read-DotEnvValue $envFile "CHROMADB_HOST"
    if (-not $hostName) { $hostName = "127.0.0.1" }

    $portText = Read-DotEnvValue $envFile "CHROMADB_PORT"
    $port = if ($portText) { [int]$portText } else { 8100 }

    if (Test-TcpPortOpen $hostName $port) {
        Write-Host "ChromaDB already running at ${hostName}:${port}" -ForegroundColor DarkGray
        return $true
    }

    $venvChroma = Join-Path $RepoRoot "venv\Scripts\chroma.exe"
    if (-not (Test-Path $venvChroma)) {
        Write-Host "ChromaDB not running and chroma CLI not found in venv." -ForegroundColor Yellow
        Write-Host "  Install with: venv\Scripts\python.exe -m pip install chromadb" -ForegroundColor Yellow
        return $false
    }

    $persistPath = Join-Path $dataDir "chroma_server"
    New-Item -ItemType Directory -Force -Path $persistPath | Out-Null

    Write-Host "Starting ChromaDB at ${hostName}:${port} (data: $persistPath)..." -ForegroundColor Cyan
    Start-Process -FilePath $venvChroma -ArgumentList @(
        "run",
        "--path", $persistPath,
        "--host", $hostName,
        "--port", "$port"
    ) -WindowStyle Minimized -WorkingDirectory $RepoRoot | Out-Null

    $deadline = (Get-Date).AddSeconds($MaxWaitSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-TcpPortOpen $hostName $port) {
            Write-Host "ChromaDB is ready at ${hostName}:${port}" -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 1
    }

    Write-Host "ChromaDB did not become reachable within ${MaxWaitSeconds}s." -ForegroundColor Yellow
    return $false
}
