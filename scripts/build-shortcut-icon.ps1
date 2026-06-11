#Requires -Version 5.1
<#
  Build a multi-size Windows .ico from static/napzter-logo.png for desktop shortcuts.
  Windows Shell often ignores PNG shortcut icons and falls back to a generic icon.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\scripts\build-shortcut-icon.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\build-shortcut-icon.ps1 -Variant Dev -RepoRoot E:\Odysseus-develop
#>
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("Prod", "Dev")]
    [string]$Variant = "Prod"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$pngPath = Join-Path $RepoRoot "static\napzter-logo.png"
$icoName = if ($Variant -eq "Dev") { "napzter-dev.ico" } else { "napzter.ico" }
$icoPath = Join-Path $RepoRoot "static\$icoName"

if (-not (Test-Path $pngPath)) {
    throw "Logo PNG not found: $pngPath"
}

function Add-DevVariantOverlay {
    param([System.Drawing.Bitmap]$Bmp)

    $size = $Bmp.Width
    $g = [System.Drawing.Graphics]::FromImage($Bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $accent = [System.Drawing.Color]::FromArgb(255, 0, 255, 65)
    $borderWidth = [Math]::Max(1, [int][Math]::Round($size / 20.0))
    $pen = New-Object System.Drawing.Pen($accent, $borderWidth)
    $inset = [Math]::Max(1, [int][Math]::Round($borderWidth / 2.0))
    $g.DrawRectangle($pen, $inset, $inset, $size - (2 * $inset) - 1, $size - (2 * $inset) - 1)
    $pen.Dispose()

    $badgeH = [Math]::Max(8, [int][Math]::Round($size * 0.24))
    $badgeW = [Math]::Max(18, [int][Math]::Round($size * 0.42))
    $badgeX = $size - $badgeW - [Math]::Max(1, [int][Math]::Round($size * 0.04))
    $badgeY = $size - $badgeH - [Math]::Max(1, [int][Math]::Round($size * 0.04))
    $badgeRect = New-Object System.Drawing.Rectangle $badgeX, $badgeY, $badgeW, $badgeH

    $badgeBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 8, 8, 8))
    $g.FillRectangle($badgeBg, $badgeRect)
    $badgeBg.Dispose()

    $badgeBorder = New-Object System.Drawing.Pen($accent, [Math]::Max(1, [int][Math]::Round($size / 64.0)))
    $g.DrawRectangle($badgeBorder, $badgeRect)
    $badgeBorder.Dispose()

    $fontSize = [Math]::Max(5.0, $size / 8.5)
    $font = [System.Drawing.Font]::new("Segoe UI", [single]$fontSize, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 124, 252, 0))
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("DEV", $font, $textBrush, ([System.Drawing.RectangleF]$badgeRect), $format)

    $font.Dispose()
    $textBrush.Dispose()
    $format.Dispose()
    $g.Dispose()
}

function New-SquareBitmap {
    param(
        [System.Drawing.Image]$Source,
        [int]$Size,
        [switch]$DevVariant
    )

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Black)

    $scale = [Math]::Min($Size / $Source.Width, $Size / $Source.Height)
    if ($DevVariant) { $scale *= 0.92 }
    $w = [Math]::Max(1, [int][Math]::Round($Source.Width * $scale))
    $h = [Math]::Max(1, [int][Math]::Round($Source.Height * $scale))
    $x = [int](($Size - $w) / 2)
    $y = [int](($Size - $h) / 2)
    $g.DrawImage($Source, $x, $y, $w, $h)
    $g.Dispose()

    if ($DevVariant) {
        Add-DevVariantOverlay -Bmp $bmp
    }

    return $bmp
}

function Export-MultiSizeIco {
    param(
        [string]$InputPng,
        [string]$OutputIco,
        [switch]$DevVariant,
        [int[]]$Sizes = @(16, 32, 48, 64, 128, 256)
    )

    $source = [System.Drawing.Image]::FromFile($InputPng)
    try {
        $pngChunks = New-Object System.Collections.Generic.List[byte[]]
        foreach ($size in $Sizes) {
            $bmp = New-SquareBitmap -Source $source -Size $size -DevVariant:$DevVariant
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

$devSwitch = ($Variant -eq "Dev")
Export-MultiSizeIco -InputPng $pngPath -OutputIco $icoPath -DevVariant:$devSwitch
Write-Host "Wrote $icoPath ($Variant)"
