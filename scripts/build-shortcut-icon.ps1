#Requires -Version 5.1
<#
  Build a multi-size Windows .ico from static/napzter-logo.png for desktop shortcuts.
  Windows Shell often ignores PNG shortcut icons and falls back to a generic icon.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\build-shortcut-icon.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\build-shortcut-icon.ps1 -RepoRoot E:\Odysseus-develop
#>
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$pngPath = Join-Path $RepoRoot "static\napzter-logo.png"
$icoPath = Join-Path $RepoRoot "static\napzter.ico"

if (-not (Test-Path $pngPath)) {
    throw "Logo PNG not found: $pngPath"
}

function New-SquareBitmap {
    param(
        [System.Drawing.Image]$Source,
        [int]$Size
    )

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Black)

    $scale = [Math]::Min($Size / $Source.Width, $Size / $Source.Height)
    $w = [Math]::Max(1, [int][Math]::Round($Source.Width * $scale))
    $h = [Math]::Max(1, [int][Math]::Round($Source.Height * $scale))
    $x = [int](($Size - $w) / 2)
    $y = [int](($Size - $h) / 2)
    $g.DrawImage($Source, $x, $y, $w, $h)
    $g.Dispose()
    return $bmp
}

function Export-MultiSizeIco {
    param(
        [string]$InputPng,
        [string]$OutputIco,
        [int[]]$Sizes = @(16, 32, 48, 64, 128, 256)
    )

    $source = [System.Drawing.Image]::FromFile($InputPng)
    try {
        $pngChunks = New-Object System.Collections.Generic.List[byte[]]
        foreach ($size in $Sizes) {
            $bmp = New-SquareBitmap -Source $source -Size $size
            try {
                $ms = New-Object System.IO.MemoryStream
                try {
                    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                    $pngChunks.Add($ms.ToArray())
                } finally {
                    $ms.Dispose()
                }
            } finally {
                $bmp.Dispose()
            }
        }

        $fs = [System.IO.File]::Open($OutputIco, [System.IO.FileMode]::Create)
        try {
            $bw = New-Object System.IO.BinaryWriter $fs
            $bw.Write([uint16]0)
            $bw.Write([uint16]1)
            $bw.Write([uint16]$Sizes.Count)

            $offset = 6 + (16 * $Sizes.Count)
            for ($i = 0; $i -lt $Sizes.Count; $i++) {
                $size = $Sizes[$i]
                $data = $pngChunks[$i]
                $bw.Write([byte]([Math]::Min($size, 255)))
                $bw.Write([byte]([Math]::Min($size, 255)))
                $bw.Write([byte]0)
                $bw.Write([byte]0)
                $bw.Write([uint16]1)
                $bw.Write([uint16]32)
                $bw.Write([uint32]$data.Length)
                $bw.Write([uint32]$offset)
                $offset += $data.Length
            }
            foreach ($data in $pngChunks) {
                $bw.Write($data)
            }
            $bw.Flush()
        } finally {
            $fs.Dispose()
        }
    } finally {
        $source.Dispose()
    }
}

Export-MultiSizeIco -InputPng $pngPath -OutputIco $icoPath
Write-Host "Wrote $icoPath"
