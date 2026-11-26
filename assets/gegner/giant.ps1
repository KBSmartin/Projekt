# Snow giant (enemy "giant"): frost giant with a horned helmet, long beard and
# a tree trunk club; pose 6 with head 5 of assets/probe/giant_posen4.ps1.
# Writes <Out>/giant.png; -Anim writes the animation sheets into
# ui/assets/gegner (breathing, club slam, hit, falls on the back).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)
# Chosen among the trials: the massive build and head 5.
$script:m = 1.2; $script:face = 5; $script:st = 2

function Add-Ramps($s) {
  $s.Ramp('skin', '#141e46', '#223a74', '#38609a', '#5c8cba', '#98c4dc')
  $s.Ramp('beard', '#8098b8', '#b4cce0', '#e4f0f8', '#ffffff')
  $s.Ramp('pelt', '#1c1412', '#44302a', '#705044', '#a07e68', '#d0b498')
  $s.Ramp('wood', '#1a120e', '#3c281c', '#664830', '#94704c', '#c49c70')
  $s.Ramp('tusk', '#4c4438', '#8c8068', '#ccc09c', '#f8f0d4'); $s.Ramp('iron', '#14161e', '#343c4a', '#64707c', '#a0acb4')
  $s.Ramp('ice', '#16305c', '#2a64a4', '#54a4d8', '#a4e0f4', '#f6ffff')
  $s.Ramp('dark', '#080a14', '#101424', '#1c2038')
  $s.Contrast = 1.2; $s.EdgeDepth = 1.8; $s.EdgeSame = 5
}
function Arm($s, $p, [double]$k = 1) { $s.Group('skin', 1.0); $s.Cap($p[0], $p[1], $p[2], $p[3], $p[4], $p[5], 3.3 * $k, 2.6 * $k, ''); $s.Cap($p[3], $p[4], $p[5], $p[6], $p[7], $p[8], 2.7 * $k, 2.2 * $k, ''); $s.Group('pelt', 0.3); $s.Cap(($p[3] * 0.4 + $p[6] * 0.6), ($p[4] * 0.4 + $p[7] * 0.6), ($p[5] * 0.4 + $p[8] * 0.6), ($p[3] * 0.12 + $p[6] * 0.88), ($p[4] * 0.12 + $p[7] * 0.88), ($p[5] * 0.12 + $p[8] * 0.88), 2.6 * $k, 2.4 * $k, ''); $s.Group('skin', 0.4); $s.Ball($p[6], $p[7], $p[8], 2.3 * $k, '') }
function Leg($s, [double]$x, [double]$z, [double]$fx) { $z = $z * $script:m; $s.Group('skin', 0.8); $s.Cap($x, 9, $z, $fx + 0.4, 4.6, $z * 1.1, 2.9 * $script:m, 2.3 * $script:m, ''); $s.Group('pelt', 0.4); $s.Cap($fx + 0.4, 4.4, $z * 1.1, $fx, 1.8, $z * 1.15, 2.5 * $script:m, 2.7 * $script:m, ''); $s.Ell($fx - 1.4, 1.2, $z * 1.15, 3.0, 1.4, 2.1, 0, 0, 0, '') }
# Barrel chest, belly, pelt kilt with a belt, pelt over one shoulder.
function Body($s, [double]$x, [double]$rz) {
  $s.Push($x, 10, 0, 0, 0, $rz); $s.Group('skin', 1.8); $s.Ell(-0.3, 3, 0, 4.6 * $script:m, 4.4, 5.2 * $script:m, 0, 0, 0, ''); $s.Ell(0.4, 9.0, 0, 5.2 * $script:m, 4.8, 8.0 * $script:m, 0, 0, 0, ''); foreach ($q in -1, 1) { $s.Ell(-3.0 * $script:m, 8.6, 2.9 * $q * $script:m, 2.4, 2.4, 2.8 * $script:m, 0, 0, 0, '') }
  $s.Group('pelt', 0.8); $s.Cap(0, -0.4, -2.6 * $script:m, 0, -0.4, 2.6 * $script:m, 4.4 * $script:m, 4.4 * $script:m, ''); for ($i = 0; $i -lt 10; $i++) { $a = $i * 0.628; $s.Cap(4.4 * $script:m * [Math]::Cos($a), -0.6, 6.0 * $script:m * [Math]::Sin($a), 5.0 * $script:m * [Math]::Cos($a), -3.2 - ($i % 2), 6.6 * $script:m * [Math]::Sin($a), 2.0, 1.0, '') }
  $s.Group('iron', 0.2); $s.Ell(-4.4, 1.0, 0, 1.0, 1.5, 1.6, 0, 0, 0, ''); $s.Group('pelt', 0.7); foreach ($q in @(0.6, 12, -5.4), @(2.2, 11.6, -2), @(-1.6, 11.4, -6.4), @(1.6, 10.6, -7.4)) { $s.Ball($q[0], $q[1], $q[2], 2.4, '') }; $s.Group('pelt', 0.4); foreach ($q in @(-2.6, 10.4, -6.6), @(-0.4, 9.6, -8.4), @(2.4, 9.8, -7.6)) { $s.Cap($q[0], $q[1], $q[2], $q[0] - 0.4, $q[1] - 3.4, $q[2] - 0.4, 1.4, 0.5, '') }
  $s.Pop()
}
# Head variants ($script:face); the beard is the main feature.
function Head($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz) {
  $f = $script:face; $s.Push($x, $y, $z, 0, ($ry + 12), $rz)
  $s.Group('skin', 0.9); $s.Ell(0, 0, 0, 3.1, 3.4, 3.1, 0, 0, 0, ''); $s.Cap(-2.8, 0.2, 0, -3.7, -0.7, 0, 0.8, 1.0, '')
  # hair
  if ($f -ne 5) { $s.Group('beard', 0.7); $s.Ell(1.8, 2.2, 0, 2.7, 2.3, 3.3, 0, 0, 0, ''); foreach ($q in -1, 1) { $s.Cap(1.4, 0.4, 3.0 * $q, 2.0, -4.0, 3.6 * $q, 1.5, 0.8, '') } }
  # brows
  $s.Group('beard', 0.3); foreach ($q in -1, 1) { $s.Cap(-2.8, 1.9, 0.6 * $q, -2.0, 2.7, 2.7 * $q, 0.8, 0.6, '') }
  if ($f -eq 1) { # long full beard down to the belly
    $s.Group('beard', 1.2); $s.Ell(-1.8, -2.8, 0, 2.4, 2.0, 3.2, 0, 0, 0, ''); $s.Cap(-2.4, -3.6, 0, -3.2, -10.6, 0, 3.0, 1.2, ''); foreach ($q in -1, 1) { $s.Cap(-2.2, -3.6, 2.0 * $q, -2.8, -8.6, 1.8 * $q, 1.6, 0.8, '') }
  } elseif ($f -eq 2) { # two braids with iron rings
    $s.Group('beard', 1.0); $s.Ell(-1.8, -2.8, 0, 2.4, 1.9, 3.2, 0, 0, 0, ''); foreach ($q in -1, 1) { foreach ($k in 0, 1, 2) { $s.Group('beard', 0.2); $s.Ball(-2.8 - 0.2 * $k, -5.0 - 2.1 * $k, 1.7 * $q, 1.6 - 0.15 * $k, '') }; $s.Group('iron', 0); $s.Ell(-3.2, -10.8, 1.7 * $q, 1.3, 0.8, 1.3, 0, 0, 0, ''); $s.Group('beard', 0); $s.Cap(-3.2, -11.4, 1.7 * $q, -3.4, -13.4, 1.8 * $q, 1.1, 0.5, '') }
  } elseif ($f -eq 3) { # beard of icicles
    $s.Group('beard', 0.8); $s.Ell(-1.8, -2.4, 0, 2.3, 1.5, 3.1, 0, 0, 0, ''); foreach ($q in @(0, 9.0), @(1.5, 7.2), @(-1.5, 7.2), @(2.8, 5.0), @(-2.8, 5.0)) { $s.Group('ice', 0); $s.Cap(-2.6, -3.0, $q[0], -3.2, -3.4 - $q[1], $q[0] * 0.8, 1.4, 0.4, '') }
  } elseif ($f -eq 4) { # wild mane: hair and beard in one shaggy ring
    $s.Group('beard', 0.6); for ($i = 0; $i -lt 14; $i++) { $a = $i * 0.449; $l = 5.4 + 1.2 * ($i % 3) + $(if ([Math]::Sin($a) -lt -0.3) { 2.6 } else { 0 }); $s.Cap(0.2, 2.8 * [Math]::Sin($a), 2.8 * [Math]::Cos($a), -0.6, $l * [Math]::Sin($a), $l * 0.95 * [Math]::Cos($a), 2.0, 0.6, '') }; $s.Ell(-2.0, -3.0, 0, 1.8, 1.8, 2.6, 0, 0, 0, '')
  } elseif ($f -eq 5) { # horned iron helmet, long beard
    $s.Group('iron', 0.5); $s.Ell(0.4, 1.6, 0, 3.5, 2.6, 3.5, 0, 0, 0, ''); $s.Cap(-2.8, 1.8, 0, -3.4, 0.2, 0, 0.7, 0.6, ''); $s.Group('tusk', 0.3); foreach ($q in -1, 1) { $s.Chain([double[]]@(0.4, 2.4, (3.2 * $q), 0.6, 3.6, (5.8 * $q), -0.4, 6.4, (6.8 * $q), -1.6, 8.0, (6.2 * $q)), 1.5, 0.5, '') }
    $s.Group('beard', 1.2); $s.Ell(-1.8, -2.8, 0, 2.4, 2.0, 3.2, 0, 0, 0, ''); $s.Cap(-2.4, -3.6, 0, -3.0, -9.6, 0, 2.9, 1.0, '')
  } else { # roaring: big moustache, mouth open, beard below
    $s.Group('beard', 0.9); foreach ($q in -1, 1) { $s.Chain([double[]]@(-3.2, -1.2, (0.6 * $q), -3.0, -1.6, (2.4 * $q), -2.2, -3.6, (3.6 * $q)), 1.2, 0.6, '') }; $s.Cap(-2.2, -5.4, -1.6, -2.2, -5.4, 1.6, 1.9, 1.9, ''); $s.Cap(-2.6, -5.8, 0, -3.2, -11, 0, 2.8, 1.0, ''); $s.Group('dark', 0); $s.Ell(-3.0, -3.0, 0, 0.9, 1.3, 1.7, 0, 0, 0, '')
  }
  $s.Mark(-3.0, 0.2, 0, 'kk.kk/kw.wk', 'k=#0a1024,w=#d8fbff', $true)
  $s.Pop()
}
# Tree trunk club from the grip to the thick end, iron band and ice spikes.
function Club($s, [double]$x1, [double]$y1, [double]$z1, [double]$x2, [double]$y2, [double]$z2) {
  $s.Group('wood', 0.3); $s.Cap($x1, $y1, $z1, $x2, $y2, $z2, 1.1, 3.0, ''); $mx = $x1 + ($x2 - $x1) * 0.62; $my = $y1 + ($y2 - $y1) * 0.62; $mz = $z1 + ($z2 - $z1) * 0.62
  $s.Group('iron', 0.2); $s.Cap($mx, $my, $mz, $mx + ($x2 - $x1) * 0.05, $my + ($y2 - $y1) * 0.05, $mz, 2.7, 2.8, '')
  $l = [Math]::Sqrt(($x2 - $x1) * ($x2 - $x1) + ($y2 - $y1) * ($y2 - $y1)) + 0.01; $nx = -($y2 - $y1) / $l; $ny = ($x2 - $x1) / $l
  foreach ($q in @(0.8, 1), @(0.8, -1), @(0.98, 1), @(0.98, -1)) { $s.Group('ice', 0); $s.Cap($x1 + ($x2 - $x1) * $q[0] + $nx * 2.2 * $q[1], $y1 + ($y2 - $y1) * $q[0] + $ny * 2.2 * $q[1], $z2, $x1 + ($x2 - $x1) * $q[0] + $nx * 5.2 * $q[1], $y1 + ($y2 - $y1) * $q[0] + $ny * 5.2 * $q[1], $z2, 1.2, 0.4, '') }
}
function Pose6($s, $A) {
  $s.Yaw = 42; $m = $script:m; $u = 0.25 * $A.s
  Leg $s 0.6 3.4 0; Leg $s 1.4 -3.4 1.6; Body $s 1 4
  # The club comes off the shoulder, over the head and down in front.
  $p = Get-Swing @(0, 20, (7.4 * $m), -1.4, 15, (9.6 * $m), -3.4, (18 + $u), (9.4 * $m)) @(0, 20, (7.4 * $m), 1.0, 22, (10.4 * $m), 0.6, 27, (9.4 * $m)) @(0, 20, (7.4 * $m), -4.6, 16.6, (9.2 * $m), -9, 14, (7.6 * $m)) $A
  $w = Get-Swing @(-4.4, (17 + $u), (9.4 * $m), 7, (29.6 + $u), (9.0 * $m)) @(-0.4, 25.6, (9.4 * $m), 11, 36, (9.0 * $m)) @(-8.6, 14.6, (7.6 * $m), -21, 4.4, (7.0 * $m)) $A
  Arm $s $p $m; Club $s $w[0] $w[1] $w[2] $w[3] $w[4] $w[5]
  Arm $s @(-0.2, 20, (-7.4 * $m), (-2 - 1.0 * $A.hit), (14 + 0.4 * $u), (-10 * $m), (-4.6 - 2.4 * $A.hit), (9.4 + $u + 3 * $A.hit), (-9.6 * $m)) $m
  Head $s -3.0 (24.2 + $u) 0 12 (6 - 6 * $A.wind + 4 * $A.act - 12 * $A.hit)
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.0; Pose6 $s (Get-Still) }
$bmp = New-FittedSprite $still 32
$bmp.Save((Join-Path $Out 'giant.png'))
if ($Anim) {

  Save-Sheets 'giant' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.0; Pose6 $s $A } 32 (Get-Fit $still 32) @{ breath = 0.01; y0 = 6; y1 = 14; windBend = -8; actBend = 12; actPx = -1; windPx = 1; hitBend = -10; hitPx = 2; pivX = 1.0; pivY = 8.0; tod = @{ rz = -80; pvX = 4; pvY = 3; px = -9; py = -2; marksUntil = 2 } } (Get-GameDir)
}
