# Frost guard (enemy "guard"): frozen skeleton warrior; exactly pose 3 of
# assets/probe/guard_posen.ps1. Writes <Out>/guard.png; -Anim writes the
# animation sheets into ui/assets/gegner (breathing, spear thrust, hit, falls
# into bones).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('bone', '#34384a', '#6c7080', '#a6a8a8', '#d8d6c8', '#fbf7e6')
  $s.Ramp('iron', '#12141e', '#2a3040', '#4a5464', '#7a8894', '#b4c2c8')
  $s.Ramp('rust', '#1c1414', '#403028', '#6c5240', '#9c7c5c')
  $s.Ramp('ice', '#16385c', '#2c6c9c', '#58a8d0', '#9cdcf0', '#e8fcff')
  $s.Ramp('wood', '#1c1410', '#40301f', '#6e5434', '#a0804c')
  $s.Ramp('dark', '#06070c', '#0c0e16', '#141822')
  $s.Glow('glow', '#38b8ff', '#90e8ff', '#f0ffff')
  $s.Contrast = 1.2; $s.EdgeDepth = 1.7; $s.EdgeSame = 5
}
function Bone($s, $p, [double]$r = 0.95) { $s.Group('bone', 0.3); $s.Chain([double[]]$p, $r, $r * 0.85, ''); for ($i = 0; $i -lt $p.Count; $i += 3) { $s.Ball($p[$i], $p[$i + 1], $p[$i + 2], $r * 1.35, '') } }
# Ribcage with ice inside, spine, pelvis; origin at the pelvis.
function Torso($s, [double]$x, [double]$y, [double]$rz) {
  $s.Push($x, $y, 0, 0, 0, $rz); $s.Group('bone', 0.4); $s.Cap(0.8, 0, 0, 1.0, 9, 0, 0.9, 0.9, ''); $s.Ell(0, 0.2, 0, 1.6, 1.4, 2.6, 0, 0, 0, '')
  $s.Group('ice', 0.5); $s.Ell(0, 5.6, 0, 1.9, 2.8, 2.6, 0, 0, 0, '')
  foreach ($h in 3.6, 5.6, 7.6) { $s.Group('bone', 0.2); foreach ($q in -1, 1) { $s.Chain([double[]]@(1.0, ($h + 0.4), 0, 0.4, $h, (2.9 * $q), -1.8, ($h - 0.5), (2.3 * $q), -2.4, ($h - 0.6), 0.5), 0.75, 0.65, '') } }
  $s.Group('iron', 0.4); foreach ($q in -1, 1) { $s.Ell(0.4, 9.2, 3.4 * $q, 2.4, 1.9, 2.0, (14 * $q), 0, 0, '') }; $s.Group('rust', 0.3); $s.Cap(-1.4, -0.2, -2, -1.4, -0.2, 2, 0.9, 0.9, ''); foreach ($q in -1.4, 0, 1.4) { $s.Cap(-1.4, -0.8, $q, -1.6, -3.4, $q * 1.2, 0.9, 0.6, '') }
  $s.Pop()
}
# Helmeted skull: kettle helm with nasal, dark sockets, cold eyes, icicles.
function Skull($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz) {
  $s.Push($x, $y, $z, 0, $ry, $rz); $s.Group('bone', 0.7); $s.Ell(0, 0, 0, 3.0, 3.0, 2.9, 0, 0, 0, ''); $s.Box(-1.0, -2.6, 0, 1.6, 1.0, 1.7, 0, 0, 0, 0.5, '')
  $s.Group('iron', 0.5); $s.Ell(0.3, 1.4, 0, 3.4, 2.6, 3.3, 0, 0, 0, ''); $s.Cut(0, -2.6, 0, 9, 3.2, 9, 0, 0, 0, ''); $s.Cap(0.2, 3.4, 0, 0.6, 5.4, 0, 0.9, 0.5, '')
  $s.Mark(-2.4, -0.6, 0, 'kbbbk/kkbkk/kcbck/bbkbb/tktkt', 'k=#0a0c14,c=#90e8ff,b=#d8d6c8,t=#f6f2e0', $true); $s.Pop()
}
function Leg($s, [double]$hx, [double]$hy, [double]$z, [double]$kx, [double]$fx) { Bone $s @($hx, $hy, $z, $kx, ($hy * 0.52), ($z * 1.15), $fx, 1.4, ($z * 1.2)); $s.Group('iron', 0.3); $s.Cap($fx, 1.2, $z * 1.2, $fx - 1.8, 0.8, $z * 1.2, 1.2, 1.0, ''); $s.Cap($kx - 0.2, $hy * 0.52 - 1, $z * 1.15, $fx, 2.4, $z * 1.2, 1.35, 1.2, '') }
# Round shield with boss and ice crust, facing -x turned by $ry.
function Shield($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$r) {
  $s.Push($x, $y, $z, 0, $ry, $rz); $s.Group('iron', 0.2); $s.Ell(0, 0, 0, 1.0, $r, $r, 0, 0, 0, ''); $s.Group('wood', 0.2); $s.Ell(-0.4, 0, 0, 0.9, $r * 0.82, $r * 0.82, 0, 0, 0, ''); $s.Group('iron', 0.3); $s.Ell(-1.0, 0, 0, 1.2, $r * 0.32, $r * 0.32, 0, 0, 0, ''); $s.Cap(-1.0, $r * 0.8, 0, -1.0, -$r * 0.8, 0, 0.6, 0.6, '')
  $s.Group('ice', 0.5); $s.Ell(-0.7, $r * 0.72, -$r * 0.3, 1.0, 1.4, 2.4, 0, 0, 0, ''); foreach ($q in @(-2.4, 2.6), @(0, 3.4), @(2.2, 2.2)) { $s.Cap(-0.4, -$r * 0.86, $q[0], -0.4, -$r * 0.86 - $q[1], $q[0], 0.9, 0.35, '') }
  $s.Pop()
}
function Spear($s, [double]$x1, [double]$y1, [double]$z1, [double]$x2, [double]$y2, [double]$z2) {
  $s.Group('wood', 0); $s.Cap($x1, $y1, $z1, $x2, $y2, $z2, 0.75, 0.75, ''); $l = [Math]::Sqrt(($x2 - $x1) * ($x2 - $x1) + ($y2 - $y1) * ($y2 - $y1)); $dx = ($x2 - $x1) / $l; $dy = ($y2 - $y1) / $l
  $s.Group('ice', 0); $s.Cap($x2, $y2, $z2, $x2 + $dx * 1.6, $y2 + $dy * 1.6, $z2, 1.5, 1.4, ''); $s.Cap($x2 + $dx * 1.4, $y2 + $dy * 1.4, $z2, $x2 + $dx * 5.4, $y2 + $dy * 5.4, $z2, 1.4, 0.35, '')
}

function Build($s, $A) {
  $s.Yaw = 36; $u = 0.25 * $A.s
  Leg $s 2 11 1.8 0.4 0; Leg $s 2.6 11 -1.8 2.4 5
  Torso $s 2 11.4 2;   # The spear is drawn back and thrust down at the hero.
  $p = Get-Swing @(5, 22, 6.6, 3, 25.6, 7) @(8, 23, 7, 6.4, 26.6, 7.4) @(-1, 20, 7.6, -4.4, 20.6, 7.6) $A
  Bone $s @(1.6, 20.4, 4, $p[0], $p[1], $p[2], $p[3], ($p[4] + $u), $p[5]) 0.9
  $w = Get-Swing @(9, 29.4, 7, -7, 22, 7) @(13.6, 29.4, 7.4, -3.2, 24, 7.4) @(4.4, 24.6, 7.6, -13.4, 15.4, 7.6) $A
  Spear $s $w[0] ($w[1] + $u) $w[2] $w[3] ($w[4] + $u) $w[5]
  Bone $s @(1.4, 20.4, -4, -2, 16.4, -6, -4.4, 15, -5) 0.9; Shield $s (-5.4 + 1.6 * $A.hit) (14.4 + $u) -5 10 (-10 * $A.hit) 6.0
  Skull $s 0 (24.6 + $u) 0 20 (4 - 6 * $A.wind + 6 * $A.act - 14 * $A.hit)
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.05; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 32 $true
$bmp.Save((Join-Path $Out 'guard.png'))
if ($Anim) { Save-Sheets 'guard' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.05; Build $s $A } 32 (Get-Fit $still 32) @{ breath = 0.008; y0 = 8; y1 = 15; windBend = -5; actBend = 9; actPx = -3; windPx = 2; hitBend = -10; hitPx = 3; pivX = 2.0; pivY = 11.0; tod = @{ fx = 'chunks'; cell = 5; seed = 3; spread = 0.8; pile = 0.2; from = 2; marksUntil = 3 } } (Get-GameDir) }
