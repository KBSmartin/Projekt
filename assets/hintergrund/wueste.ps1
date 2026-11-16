# Pixel-art background "Aschewüste", 320x180: smouldering dusk sky, a hazy ember sun,
# far mesas and a ruined arch, layered ash dunes, dead trees, glowing cracks, smoke
# and drifting embers. Deterministic (fixed seed).
param([string]$Out = (Join-Path $PSScriptRoot 'wueste.png'), [int]$Seed = 11)
. (Join-Path $PSScriptRoot 'pixel.ps1')

# Dead tree: crooked trunk with forked branches, all dark.
function DeadTree([double]$x, [double]$base, [double]$h, [double]$w, [int]$dir) {
  $col = '#1a0e0c'
  Poly $col @(($x - $w), $base, ($x - 1), ($base - $h * 0.6), ($x + $dir * 3), ($base - $h), ($x + 1), ($base - $h * 0.55), ($x + $w), $base)
  $tx = $x + $dir * 3; $ty = $base - $h
  Line $col ($x) ($base - $h * 0.55) ($x - $dir * $h * 0.35) ($base - $h * 0.85) 2
  Line $col ($x - $dir * $h * 0.35) ($base - $h * 0.85) ($x - $dir * $h * 0.45) ($base - $h * 1.0) 1
  Line $col ($x + $dir * 1) ($base - $h * 0.7) ($x + $dir * $h * 0.4) ($base - $h * 0.9) 2
  Line $col ($x + $dir * $h * 0.4) ($base - $h * 0.9) ($x + $dir * $h * 0.55) ($base - $h * 0.85) 1
  Line $col $tx $ty ($tx + $dir * 4) ($ty - 5) 1
  Line '#3a1c14' ($x - $w + 1) ($base - 1) ($x - 1) ($base - $h * 0.55) 1
}

Gradient '#1c0c10' '#5a2418' 0 70
Gradient '#5a2418' '#d0682c' 71 112
Gradient '#d0682c' '#7a4a34' 113 179
# Ember sun behind the haze.
Ell '#f0a050' 136 62 48 48 120; Ell '#ffd080' 146 72 28 28 110
foreach ($y in @(74, 82, 90)) { Rect '#5a2418' 120 $y 80 2 150 }
# Far mesas and a ruined arch.
Poly '#4a1e18' @(0, 120, 0, 98, 18, 98, 24, 104, 60, 104, 66, 112, 110, 112, 112, 120)
Poly '#4a1e18' @(210, 120, 214, 106, 240, 106, 246, 96, 290, 96, 296, 104, 320, 104, 320, 120)
Rect '#3a1612' 170 96 5 20; Rect '#3a1612' 194 92 5 24; Poly '#3a1612' @(170, 98, 182, 88, 199, 92, 199, 97, 182, 93, 175, 99)
Rect '#3a1612' 0 112 $ImgW 8
# Dunes, back to front.
Hills '#7a4a34' 122 4 0.035 0.5
Hills '#5e3a2c' 132 5 0.028 2.1
Hills '#4a2e26' 146 6 0.022 4.0
# Smoke columns rising from the far dunes.
foreach ($sx in @(58, 248, 132)) {
  for ($k = 0; $k -lt 26; $k++) { $r = 5 + $k * 0.6; Ell '#2a1a1a' ($sx + [int](6 * [Math]::Sin($k * 0.35)) - $r / 2) (120 - $k * 3.6) $r ($r * 0.9) 34 }
}
# Trail of flat stones towards the middle.
for ($k = 0; $k -lt 14; $k++) { $py = 150 + $k * 2; $sw = 2 + [int]($k / 3); Rect '#6a4434' (158 + (Rnd -6 6) - $sw / 2) $py $sw 1 }
# Front ground and glowing cracks.
Hills '#2e1c18' 160 4 0.03 1.0
foreach ($c in @(@(20, 168, 60, 172), @(60, 172, 84, 166), @(230, 170, 270, 165), @(270, 165, 300, 174), @(110, 176, 140, 171))) {
  Line '#ff7a2a' $c[0] $c[1] $c[2] $c[3] 1; Line '#a03010' $c[0] ($c[1] + 1) $c[2] ($c[3] + 1) 1
}
# Dead trees.
DeadTree 34 168 70 5 1
DeadTree 288 170 82 6 -1
DeadTree 86 150 28 2 1
DeadTree 236 152 30 2 -1
# Bones and a small skull.
Rect '#d8ccb0' 196 168 7 1; Rect '#d8ccb0' 195 167 1 3; Rect '#d8ccb0' 203 167 1 3
Ell '#d8ccb0' 112 163 6 5; Rect '#1a0e0c' 113 165 1 1; Rect '#1a0e0c' 116 165 1 1
# Drifting embers.
for ($k = 0; $k -lt 60; $k++) { $c = @('#ffb040', '#ff7a2a', '#ffe080')[(Rnd 0 2)]; Rect $c (Rnd 0 319) (Rnd 20 175) 1 1 (Rnd 140 255) }
Finish $Out 12 4 2
