# Pixel-art background "Frostfestung", 320x180: night sky with stars and a faint
# aurora, snowy peaks, a dark fortress with lit windows and icicles, snowy pines,
# drifts, rocks with snow caps and falling snow. Deterministic (fixed seed).
param([string]$Out = (Join-Path $PSScriptRoot 'festung.png'), [int]$Seed = 23)
. (Join-Path $PSScriptRoot 'pixel.ps1')

function Pine($x, $base, $h) {
  Rect '#1a2430' ($x - 1) ($base - 3) 2 3
  for ($k = 0; $k -lt 3; $k++) {
    $ty = $base - 3 - $h * ($k / 3.0); $w = $h * 0.35 * (1 - $k * 0.25)
    Poly '#16283a' @($x, ($ty - $h * 0.45), ($x - $w), $ty, ($x + $w), $ty)
    Poly '#dfeaf4' @($x, ($ty - $h * 0.45), ($x - $w * 0.5), ($ty - $h * 0.2), ($x + $w * 0.2), ($ty - $h * 0.25))
  }
}
function Tower($x, $w, $top, $base) {
  Rect '#2a3446' $x $top $w ($base - $top)
  Rect '#3a4660' $x $top 2 ($base - $top)
  for ($cx = $x; $cx -lt $x + $w; $cx += 4) { Rect '#2a3446' $cx ($top - 3) 2 3; Rect '#e8f2fa' $cx ($top - 4) 2 1 }
  Poly '#1e2636' @(($x - 1), $top, ($x + $w / 2), ($top - 14), ($x + $w + 1), $top)
  Poly '#e8f2fa' @(($x + $w / 2), ($top - 14), ($x + $w / 2 - 3), ($top - 9), ($x + $w / 2 + 1), ($top - 10))
}

Gradient '#060a18' '#1a2e52' 0 80
Gradient '#1a2e52' '#5a7aa0' 81 118
Gradient '#5a7aa0' '#8aa8c8' 119 179
for ($k = 0; $k -lt 70; $k++) { Rect '#ffffff' (Rnd 0 319) (Rnd 0 70) 1 1 (Rnd 80 230) }
# Aurora.
for ($x = 0; $x -lt $ImgW; $x += 2) { $y = 26 + 8 * [Math]::Sin($x * 0.03) + 4 * [Math]::Sin($x * 0.09); Rect '#5af0b0' $x $y 2 (Rnd 10 18) 26 }
# Mountains with snow caps.
foreach ($m in @(@(30, 70), @(90, 60), @(160, 50), @(230, 64), @(300, 58))) {
  $mx = $m[0]; $my = $m[1]
  Poly '#3a5070' @(($mx - 60), 122, $mx, $my, ($mx + 60), 122)
  Poly '#dce8f4' @($mx, $my, ($mx - 14), ($my + 16), ($mx - 6), ($my + 13), ($mx + 2), ($my + 18), ($mx + 12), ($my + 14))
  Poly '#2a3c58' @($mx, $my, ($mx + 60), 122, ($mx + 22), 122)
}
# Fortress: curtain wall, gate, towers, keep.
Rect '#232c3c' 96 92 128 40
for ($cx = 96; $cx -lt 224; $cx += 5) { Rect '#232c3c' $cx 88 3 4; Rect '#e8f2fa' $cx 87 3 1 }
Tower 136 22 66 132; Tower 162 18 56 132
Tower 90 14 80 132; Tower 216 14 82 132
Poly '#0c1018' @(152, 132, 152, 116, 160, 108, 168, 116, 168, 132)
foreach ($w in @(@(142, 80), @(150, 80), @(168, 72), @(174, 72), @(95, 96), @(221, 98), @(112, 104), @(204, 104))) { Rect '#ffd27a' $w[0] $w[1] 2 3; Rect '#ffd27a' $w[0] ($w[1] - 1) 2 1 120 }
for ($ix = 98; $ix -lt 222; $ix += (Rnd 3 6)) { Rect '#c8e4f8' $ix 92 1 (Rnd 1 4) }
# Blue banners.
Rect '#1a1a24' 147 38 1 14; Rect '#2a5ac8' 148 38 6 5; Rect '#1a1a24' 171 30 1 12; Rect '#2a5ac8' 172 30 6 5
# Snowfields.
Hills '#8aa8c8' 128 3 0.04 0.3
Hills '#b4c8dc' 140 4 0.03 1.7
# Pines.
foreach ($p in @(@(20, 140, 26), @(44, 142, 20), @(66, 138, 16), @(248, 140, 18), @(272, 142, 24), @(300, 140, 28))) { Pine $p[0] $p[1] $p[2] }
# Path of trodden snow to the gate.
Poly '#9ab4cc' @(156, 132, 164, 132, 196, 180, 124, 180)
Hills '#d6e4f0' 158 5 0.025 3.0
# Rocks with snow caps in the foreground.
foreach ($r in @(@(4, 150, 40, 34), @(276, 152, 44, 30))) {
  Poly '#2c3848' @($r[0], ($r[1] + $r[3]), ($r[0] + 6), $r[1], ($r[0] + $r[2] * 0.6), ($r[1] - 6), ($r[0] + $r[2]), ($r[1] + 8), ($r[0] + $r[2]), ($r[1] + $r[3]))
  Poly '#eaf2fa' @(($r[0] + 6), $r[1], ($r[0] + $r[2] * 0.6), ($r[1] - 6), ($r[0] + $r[2]), ($r[1] + 8), ($r[0] + $r[2] * 0.7), ($r[1] + 2), ($r[0] + 10), ($r[1] + 4))
}
# Ice crystals.
foreach ($c in @(@(100, 168), @(220, 170), @(60, 172))) { Poly '#8ad0f0' @($c[0], ($c[1] - 9), ($c[0] + 3), $c[1], ($c[0] - 3), $c[1]); Poly '#e8faff' @($c[0], ($c[1] - 9), ($c[0] + 1), ($c[1] - 2), ($c[0] - 1), ($c[1] - 3)) }
# Falling snow.
for ($k = 0; $k -lt 110; $k++) { $s = Rnd 1 2; Rect '#ffffff' (Rnd 0 319) (Rnd 0 179) $s $s (Rnd 120 230) }
Finish $Out 2 6 14
