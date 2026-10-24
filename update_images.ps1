# ============================================================
# Gallery compiler
#
# Usage:
#   1) Drop images into img/ (any names, jpg/png/gif/webp/...,
#      subfolders supported)
#   2) Right-click this file -> "Run with PowerShell"
#      (or run  .\update_images.ps1  in a PowerShell window)
#
# Effect:
#   - Recompiles gallery.html: embeds the full image list into
#     the inline IMAGES array (self-contained single file)
#   - Also rewrites images.json (kept in sync, optional to deploy)
# ============================================================

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$imgDir = Join-Path $root "img"
$galleryPath = Join-Path $root "gallery.html"
$manifestPath = Join-Path $root "images.json"

if (-not (Test-Path $imgDir)) {
    Write-Host "ERROR: img folder not found: $imgDir" -ForegroundColor Red
    exit 1
}

$exts = @('.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.avif')
$files = Get-ChildItem $imgDir -File -Recurse |
    Where-Object { $_.Extension -in $exts } |
    Sort-Object Name

if ($files.Count -eq 0) {
    Write-Host "WARNING: no image files found in img folder" -ForegroundColor Yellow
    exit 0
}

# ---- build the IMAGES block ----
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("    /* ===IMAGES-BEGIN=== (auto-generated, do not edit manually) */")
[void]$sb.AppendLine("    const IMAGES = [")
foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
    [void]$sb.AppendLine('      { src: "' + $rel + '", title: "" },')
}
[void]$sb.AppendLine("    ];")
[void]$sb.AppendLine("    /* ===IMAGES-END=== */")
$block = $sb.ToString()

# ---- compile gallery.html ----
if (-not (Test-Path $galleryPath)) {
    Write-Host "ERROR: gallery.html not found: $galleryPath" -ForegroundColor Red
    exit 1
}

$enc = New-Object System.Text.UTF8Encoding($false)
$html = [System.IO.File]::ReadAllText($galleryPath, $enc)

$patternNew = '(?s)/\* ===IMAGES-BEGIN===.*?/\* ===IMAGES-END=== \*/'
$patternOld = '(?s)const IMAGES = \[.*?\];'

if ([regex]::IsMatch($html, $patternNew)) {
    $html = [regex]::Replace($html, $patternNew, { param($m) $block })
} else {
    $html = [regex]::Replace($html, $patternOld, { param($m) $block })
}

[System.IO.File]::WriteAllText($galleryPath, $html, $enc)

# ---- also rewrite images.json (kept in sync) ----
$items = @($files | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    [ordered]@{ src = $rel; title = "" }
})
$json = $items | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText($manifestPath, $json, $enc)

Write-Host ("Compiled gallery.html: {0} images" -f $items.Count) -ForegroundColor Green
