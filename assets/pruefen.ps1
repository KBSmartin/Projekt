# Checks the enemy sprite sheets in ui/assets/gegner: every <id>_<anim>.png
# for idle, angriff and treffer exists, is 8 frames of 32x32 side by side, has
# only fully opaque or fully transparent pixels (the ground shadow may be
# half transparent), and no frame is empty or touches the top edge.
# Exits with 1 and lists the problems if anything is wrong.
param([string[]]$Enemies = @('rat'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$dir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\ui\assets\gegner'))
$frame = 32; $frames = 8
$problems = @()
foreach ($id in $Enemies) {
  foreach ($anim in 'idle', 'angriff', 'treffer') {
    $f = Join-Path $dir "${id}_$anim.png"
    if (-not (Test-Path $f)) { $problems += "$id/${anim}: Datei fehlt"; continue }
    $b = [Drawing.Bitmap]::FromFile($f)
    if ($b.Width -ne $frame * $frames -or $b.Height -ne $frame) {
      $problems += "$id/${anim}: Größe $($b.Width)x$($b.Height), erwartet $($frame * $frames)x$frame"
      $b.Dispose(); continue
    }
    $alphas = @{}
    for ($k = 0; $k -lt $frames; $k++) {
      $solid = 0; $top = $false
      for ($y = 0; $y -lt $frame; $y++) { for ($x = 0; $x -lt $frame; $x++) {
        $a = $b.GetPixel($k * $frame + $x, $y).A
        $alphas[$a] = $true
        if ($a -eq 255) { $solid++; if ($y -eq 0) { $top = $true } }
      } }
      if ($solid -lt 40) { $problems += "$id/$anim Bild ${k}: fast leer" }
      if ($top) { $problems += "$id/$anim Bild ${k}: stößt oben an" }
    }
    $odd = @($alphas.Keys | Where-Object { $_ -ne 0 -and $_ -ne 255 -and $_ -ne 110 })
    if ($odd.Count) { $problems += "$id/${anim}: halbdurchsichtige Pixel ($($odd -join ', '))" }
    $b.Dispose()
  }
}
if ($problems.Count) { $problems | ForEach-Object { Write-Host $_ }; exit 1 }
Write-Host "Gegner-Sprites in Ordnung: $($Enemies -join ', ')"
