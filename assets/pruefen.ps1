# Checks the enemy sprite sheets in ui/assets/gegner: every <id>_<anim>.png for
# idle, angriff, treffer and tod exists, has 8 square frames of the expected
# size, only opaque or transparent pixels (plus the half transparent ground
# shadow), no frame is empty (the end of a death may be) or cut off at the top,
# left or right edge, and the figure starts every animation in the same still.
# Exits with 1 and lists the problems if anything is wrong.
# Frame size = art size + 16 pixels of margin (the rat has none).
param([hashtable]$Enemies = @{ rat = 32; shroom = 48; wolf = 48; moss = 64; mother = 64; scorp = 48; spark = 48; worm = 48; priest = 64; colossus = 64; guard = 48; elem = 48; giant = 48; knight = 64; king = 64 })
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\ui\assets\gegner'))
$frames = 8; $outline = [Drawing.Color]::FromArgb(255, 12, 10, 16).ToArgb()
$problems = @()
foreach ($id in ($Enemies.Keys | Sort-Object)) {
  $frame = $Enemies[$id]; $stills = @{}
  foreach ($anim in 'idle', 'angriff', 'treffer', 'tod') {
    $f = Join-Path $dir "${id}_$anim.png"
    if (-not (Test-Path $f)) { $problems += "$id/${anim}: Datei fehlt"; continue }
    $b = [Drawing.Bitmap]::FromFile($f)
    if ($b.Width -ne $frame * $frames -or $b.Height -ne $frame) {
      $problems += "$id/${anim}: Größe $($b.Width)x$($b.Height), erwartet $($frame * $frames)x$frame"
      $b.Dispose(); continue
    }
    $alphas = @{}
    for ($k = 0; $k -lt $frames; $k++) {
      $solid = 0; $cut = 0; $sum = [Text.StringBuilder]::new()
      for ($y = 0; $y -lt $frame; $y++) { for ($x = 0; $x -lt $frame; $x++) {
        $c = $b.GetPixel($k * $frame + $x, $y); $a = $c.A
        $alphas[[int]$a] = $true
        if ($k -eq 0) { [void]$sum.Append($c.ToArgb()).Append(',') }
        if ($a -eq 255) { $solid++; if (($y -eq 0 -or $x -eq 0 -or $x -eq $frame - 1) -and $c.ToArgb() -ne $outline) { $cut++ } }
      } }
      if ($k -eq 0) { $stills[$anim] = $sum.ToString() }
      if ($solid -lt 40 -and $anim -ne 'tod') { $problems += "$id/$anim Bild ${k}: fast leer" }
      if ($cut) { $problems += "$id/$anim Bild ${k}: am Rand angeschnitten ($cut Pixel)" }
    }
    $odd = @($alphas.Keys | Where-Object { $_ -ne 0 -and $_ -ne 255 -and $_ -ne 110 })
    if ($odd.Count) { $problems += "$id/${anim}: halbdurchsichtige Pixel ($($odd -join ', '))" }
    $b.Dispose()
  }
  if (@($stills.Values | Select-Object -Unique).Count -gt 1) { $problems += "${id}: die Animationen beginnen nicht mit demselben Standbild" }
}
# Every region, event, character and relic in data/ has its symbols.
$sym = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\ui\assets\symbole')); $data = Join-Path $PSScriptRoot '..\data'
foreach ($q in @('regions', '8', ''), @('regions', '32', '_bild'), @('events', '32', ''), @('characters', '8', ''), @('relics', '16', '')) {
  foreach ($e in (Get-Content (Join-Path $data "$($q[0]).json") -Raw -Encoding UTF8 | ConvertFrom-Json)) {
    $f = Join-Path $sym "$($e.id)$($q[2]).png"
    if (-not (Test-Path $f)) { $problems += "$($q[0])/$($e.id): Symbol fehlt ($(Split-Path $f -Leaf))"; continue }
    $b = [Drawing.Bitmap]::FromFile($f); if ($b.Width -ne [int]$q[1] -or $b.Height -ne [int]$q[1]) { $problems += "$(Split-Path $f -Leaf): $($b.Width)x$($b.Height) statt $($q[1])x$($q[1])" }; $b.Dispose()
  }
}
if ($problems.Count) { $problems | ForEach-Object { Write-Host $_ }; exit 1 }
Write-Host "Gegner-Sprites in Ordnung: $(($Enemies.Keys | Sort-Object) -join ', ')"
exit 0
