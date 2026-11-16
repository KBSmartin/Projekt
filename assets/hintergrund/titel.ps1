# Pixel-art background for the title screen, 320x180: a night crossroads. On the
# horizon all three regions are visible (forest left, glowing desert in the
# middle, snowy fortress right); in front a signpost, a ruined arch and a small
# campfire. Deterministic (fixed seed).
param([string]$Out = (Join-Path $PSScriptRoot 'titel.png'), [int]$Seed = 31)
. (Join-Path $PSScriptRoot 'pixel.ps1')

Gradient '#07060f' '#1e1430' 0 90
Gradient '#1e1430' '#4a2a40' 91 120
Gradient '#4a2a40' '#1a1220' 121 179
for ($k = 0; $k -lt 90; $k++) { Rect '#ffffff' (Rnd 0 319) (Rnd 0 95) 1 1 (Rnd 70 220) }
# Moon with halo and craters.
Ell '#c8c0e0' 222 6 64 64 18; Ell '#d8d0e8' 230 14 48 48 24
Ell '#ece6d2' 236 20 36 36
Ell '#cfc6ae' 244 28 8 6; Ell '#cfc6ae' 256 40 6 5; Ell '#cfc6ae' 248 44 4 3
# Desert glow behind the middle of the horizon.
Ell '#e07a3a' 104 92 120 30 46; Ell '#ff9a4a' 132 102 64 20 60
# Horizon: forest (left), mesas (middle), mountains with fortress (right).
for ($x = -4; $x -lt 120; $x += (Rnd 4 7)) { $h = Rnd 10 22; Poly '#142420' @($x, (120 - $h), ($x - 4), 121, ($x + 4), 121) }
Poly '#3a1a18' @(110, 121, 116, 108, 140, 108, 146, 114, 176, 114, 180, 121)
Poly '#4a2018' @(150, 121, 156, 112, 196, 112, 200, 121)
foreach ($m in @(@(226, 92), @(262, 86), @(300, 94))) { Poly '#2e3a52' @(($m[0] - 34), 121, $m[0], $m[1], ($m[0] + 34), 121); Poly '#dfe8f4' @($m[0], $m[1], ($m[0] - 7), ($m[1] + 8), ($m[0] + 6), ($m[1] + 7)) }
Rect '#161a26' 252 104 22 17; Rect '#161a26' 256 98 5 6; Rect '#161a26' 266 96 5 8
Rect '#ffd27a' 258 108 1 2; Rect '#ffd27a' 268 102 1 2; Rect '#ffd27a' 262 112 1 1
Rect '#0e0c16' 0 120 $ImgW 3
# Rolling hills.
Hills '#1a1424' 136 5 0.03 0.6
Hills '#120e1a' 150 6 0.024 2.2
# Path from the bottom splitting towards the three regions.
Poly '#4a3a34' @(136, 180, 186, 180, 166, 150, 156, 150)
Poly '#3e3030' @(154, 152, 164, 149, 92, 131, 84, 133)
Poly '#3e3030' @(157, 150, 164, 150, 161, 127, 158, 127)
Poly '#3e3030' @(157, 150, 168, 152, 250, 131, 242, 129)
# Ruined arch on the right.
Rect '#2a2432' 232 128 10 40; Rect '#3a3444' 232 128 2 40
Rect '#2a2432' 268 136 10 32; Rect '#3a3444' 268 136 2 32
Poly '#2a2432' @(232, 130, 246, 118, 258, 120, 252, 126, 242, 128)
Rect '#2a2432' 246 160 8 6; Rect '#2a2432' 284 162 6 4
# Signpost with three boards.
Rect '#4a3020' 108 128 3 34
Poly '#7a5232' @(92, 132, 108, 132, 108, 137, 92, 137, 88, 134.5)
Poly '#6e4a2c' @(111, 138, 128, 138, 132, 140.5, 128, 143, 111, 143)
Poly '#7a5232' @(98, 145, 108, 145, 108, 149, 98, 149, 95, 147)
# Campfire.
Ell '#ff9a4a' 58 150 30 14 46
Rect '#4a3020' 66 160 14 2; Rect '#3a2418' 68 158 10 2
Poly '#f07020' @(73, 147, 78, 158, 68, 158); Poly '#ffd040' @(73, 151, 75, 158, 71, 158)
Ell '#3a3444' 63 159 4 3; Ell '#3a3444' 79 159 4 3
# Grass along the bottom edge.
for ($x = 0; $x -lt $ImgW; $x += 2) { $h = Rnd 2 8; Rect '#0a0810' $x (180 - $h) 1 $h }
Finish $Out 4 2 10
