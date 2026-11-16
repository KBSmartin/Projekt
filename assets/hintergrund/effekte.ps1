# Transparent 320x180 effect layers for the animated backgrounds. Particle layers
# wrap around the edges so they can scroll endlessly; CSS moves them in steps of
# one art pixel. Writes into ui/assets/hintergrund/fx/.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\hintergrund\fx'), [int]$Seed = 5)
New-Item -ItemType Directory -Force $Out | Out-Null

function Layer($name, [scriptblock]$draw) {
  . (Join-Path $PSScriptRoot 'pixel.ps1')
  $script:rng = [Random]::new($Seed + $name.Length * 31)
  & $draw
  $g.Dispose(); $bmp.Save((Join-Path $Out "$name.png"), [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
# Pixel that wraps around the tile edges.
function Dot($hex, $x, $y, $w = 1, $h = 1, $a = 255) {
  foreach ($ox in @(0, -320, 320)) { foreach ($oy in @(0, -180, 180)) { Rect $hex ($x + $ox) ($y + $oy) $w $h $a } }
}
function Glow($hex, $x, $y, $a = 255) { Dot $hex $x $y 1 1 $a; foreach ($d in @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))) { Dot $hex ($x + $d[0]) ($y + $d[1]) 1 1 ([int]($a * 0.35)) } }

Layer 'schnee_gross' { for ($k = 0; $k -lt 70; $k++) { Dot '#ffffff' (Rnd 0 319) (Rnd 0 179) 2 2 (Rnd 170 240) } }
Layer 'schnee_klein' { for ($k = 0; $k -lt 160; $k++) { Dot '#e8f2ff' (Rnd 0 319) (Rnd 0 179) 1 1 (Rnd 110 200) } }
Layer 'glut' { for ($k = 0; $k -lt 70; $k++) { $c = @('#ffb040', '#ff7a2a', '#ffe080', '#ff5a1a')[(Rnd 0 3)]; $s = if ((Rnd 0 5) -eq 0) { 2 } else { 1 }; Dot $c (Rnd 0 319) (Rnd 0 179) $s $s (Rnd 170 255) } }
Layer 'asche' { for ($k = 0; $k -lt 60; $k++) { Dot '#8a7a74' (Rnd 0 319) (Rnd 0 179) (Rnd 1 2) 1 (Rnd 90 160) } }
Layer 'blaetter' {
  for ($k = 0; $k -lt 34; $k++) {
    $c = @('#4a8a3a', '#6aa04a', '#a8a040', '#c8702e')[(Rnd 0 3)]; $x = Rnd 0 319; $y = Rnd 0 179
    if ((Rnd 0 1) -eq 0) { Dot $c $x $y 2 1 } else { Dot $c $x $y 1 2 }
  }
}
Layer 'nebel' {
  for ($k = 0; $k -lt 26; $k++) {
    $x = Rnd 0 319; $y = Rnd 95 160; $w = Rnd 40 110; $h = Rnd 6 14
    foreach ($ox in @(0, -320, 320)) { Ell '#d8e4dc' ($x + $ox) $y $w $h (Rnd 14 26) }
  }
}
Layer 'nebel_dunkel' {
  for ($k = 0; $k -lt 22; $k++) {
    $x = Rnd 0 319; $y = Rnd 110 170; $w = Rnd 50 120; $h = Rnd 6 12
    foreach ($ox in @(0, -320, 320)) { Ell '#a898c8' ($x + $ox) $y $w $h (Rnd 10 20) }
  }
}
Layer 'funken' { for ($k = 0; $k -lt 26; $k++) { Glow '#e8ff7a' (Rnd 4 315) (Rnd 70 170) (Rnd 180 255) } }
Layer 'sterne' { for ($k = 0; $k -lt 50; $k++) { Dot '#ffffff' (Rnd 0 319) (Rnd 0 95) 1 1 (Rnd 160 255) } }
Layer 'polarlicht' { for ($x = -320; $x -lt 640; $x += 2) { $y = 26 + 8 * [Math]::Sin($x * 2 * [Math]::PI / 160) + 4 * [Math]::Sin($x * 2 * [Math]::PI / 64); Rect '#5af0b0' $x $y 2 (Rnd 8 20) 34 } }
Layer 'feuerschein' { Ell '#ffb060' 44 142 58 24 70; Ell '#ffd080' 60 148 26 12 90 }
