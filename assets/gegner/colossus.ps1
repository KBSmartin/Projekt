# Magma colossus (enemy "colossus", boss, 48 x 48): muscular lava giant, basalt
# plates on a lava body; stage 1 with face 1 of assets/probe/colossus_posen4.ps1.
# Writes <Out>/colossus.png; -Anim writes the animation sheets into
# ui/assets/gegner (breathing, punch, hit, cools down and crumbles).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)
# Trial stages and faces were chosen: 1 and 1.
$script:st = 1; $script:face = 1; $script:faces = @('.kkkkkkk./kyykkkyyk/.kkykykk./..k...k../........./.........')

function Add-Ramps($s) {
  $s.Ramp('crust', '#120d11', '#2e252a', '#504244', '#7c6862', '#b49c88')
  $s.Glow('lava', '#b4241a', '#f05a1e', '#ffa02c', '#ffdc6c')
  $s.Glow('glow', '#ff8c24', '#ffc044', '#fff0a8')
  $s.Fire('flame', '#701410', '#c8321a', '#f4681e', '#ffa62c', '#ffe070')
  $s.Ramp('dark', '#1c0608', '#38100c', '#5c1c10')
  $s.Ramp('tooth', '#241a1e', '#4c3e3c', '#84705e')
  $s.Contrast = 1.2; $s.EdgeDepth = 1.8; $s.EdgeSame = 6
}
function P($s, [double]$x, [double]$y, [double]$z, [double]$a, [double]$b, [double]$c, [double]$rx = 0, [double]$ry = 0, [double]$rz = 0) { $s.Group('crust', 0.3); $s.Box($x, $y, $z, $a, $b, $c, $rx, $ry, $rz, [Math]::Min($a, [Math]::Min($b, $c)) * 0.75, '') }
function L($s, $p, [double]$r1, [double]$r2) { $s.Group('lava', 1.0); $s.Chain([double[]]$p, $r1, $r2, '') }
function Fist($s, [double]$x, [double]$y, [double]$z, [double]$r) { P $s $x $y $z $r ($r * 0.95) $r; foreach ($d in -1, 0, 1) { $s.Group('crust', 0.2); $s.Box($x - $r * 0.85, $y - $r * 0.2, $z + $d * $r * 0.66, $r * 0.42, $r * 0.62, $r * 0.29, 0, 0, 0, 0.5, '') } }
# Arm from the shoulder: swing ($rx sideways, $rz forward), elbow $bend.
function Arm($s, [double]$x, [double]$y, [double]$z, [double]$rx, [double]$rz, [double]$bend, [double]$side) {
  P $s $x ($y + 0.6) ($z + 1.2 * $side) 4.0 3.8 3.4 0 (8 * $side) 8
  if ($script:st -eq 3) { $s.Group('crust', 0.4); foreach ($q in @(0.6, 4.6, 1.4), @(2.4, 3.6, 3.4), @(-1.0, 3.4, 3.6)) { $s.Cap($x + $q[0], $y + 3, $z + $q[2] * $side, $x + $q[0] * 1.5 + 0.6, $y + 3 + $q[1], $z + $q[2] * 1.25 * $side, 1.7, 0.5, '') }; $s.Group('lava', 0.3); $s.Ell($x + 0.6, $y + 3.6, $z + 2.4 * $side, 2.2, 0.9, 1.8, 0, 0, 0, '') }
  $s.Push($x, $y, ($z + 1.6 * $side), $rx, 0, $rz)
  L $s @(0, 0, 0, 0, -7, 0) 2.3 2.0; P $s -0.6 -4.4 0 2.6 $(if ($script:st -eq 4) { 2.1 } else { 2.7 }) 2.7
  $s.Push(0, -8, 0, 0, 0, $bend)
  L $s @(0, 0, 0, 0, -7, 0) 2.2 2.0; if ($script:st -eq 4) { P $s 0 -2.2 0 3.1 1.6 3.1; P $s 0 -5.4 0 3.0 1.4 3.0 } else { P $s 0 -3.6 0 3.1 3.2 3.1 }; $s.Group('crust', 0.2); $s.Cap(1.4, -1.6, 0, 3.6, 0.8, 0, 1.4, 0.5, ''); P $s -0.4 -9.0 0 3.2 3.0 3.2
  foreach ($d in -1, 0, 1) { $s.Group('crust', 0.1); $s.Box(-0.6, -11.6, (2.1 * $d), 2.5, 1.2, 0.9, 0, 0, 0, 0.5, '') }; $s.Group('crust', 0.2); $s.Cap(-3.0, -8.0, (-2.2 * $side), -3.4, -10.6, (-0.8 * $side), 1.1, 0.9, '')
  if ($script:st -ge 3) { foreach ($d in -0.5, 0.5) { $s.Group('lava', 0); $s.Cap(-1.8, -11.2, (2.1 * $d), -3.0, -9.8, (2.1 * $d), 0.45, 0.45, '') } }
  $s.Pop(); $s.Pop()
}
function Leg($s, [double]$x, [double]$z, [double]$rz, [double]$knee) {
  $s.Push($x, 11, $z, 0, 0, $rz); L $s @(0, 0, 0, 0, -5, 0) 2.6 2.2; P $s -0.5 $(if ($script:st -eq 1) { -2.4 } else { -1.9 }) 0 3.1 $(if ($script:st -eq 1) { 2.7 } else { 3.2 }) 3.0
  $s.Push(0, -5.4, 0, 0, 0, $knee); L $s @(0, 0, 0, 0, -4, 0) 2.2 2.2; P $s -0.2 -2.2 0 2.7 1.9 2.6; P $s -1.0 -4.6 0 3.8 1.4 3.0; $s.Pop(); $s.Pop()
}
# Torso in its own frame (origin at the hips): lava core, abs, two breast plates.
function Torso($s) {
  L $s @(0, 0, 0, 0, 6, 0) 4.0 5.0; $s.Group('lava', 1.6); $s.Ell(0, 10, 0, 4.6, 4.6, 7.8, 0, 0, 0, '')
  P $s 0.2 -0.2 0 4.3 2.4 5.2; foreach ($q in -1, 1) { P $s -2.6 2.8 ($(if ($script:st -eq 4) { 2.4 } else { 1.9 }) * $q) 2.2 1.0 $(if ($script:st -eq 4) { 1.4 } else { 1.6 }); P $s -3.0 5.6 ($(if ($script:st -eq 4) { 2.5 } else { 1.9 }) * $q) 2.2 1.0 $(if ($script:st -eq 4) { 1.4 } else { 1.6 }); P $s -2.4 10 ($(if ($script:st -eq 4) { 4.7 } else { 3.9 }) * $q) 3.6 $(if ($script:st -eq 4) { 2.9 } else { 3.2 }) $(if ($script:st -eq 4) { 3.0 } else { 3.3 }) 0 (-8 * $q) 8; P $s 0.4 4.2 (4.3 * $q) $(if ($script:st -eq 2 -or $script:st -eq 3) { 2.9 } else { 2.6 }) 2.8 1.4 (8 * $q) 0 0 }
  P $s 2.8 10.4 0 3.2 4.4 7.0; $s.Group('crust', 0.3); foreach ($q in @(14.6, 3), @(13.4, -3), @(11, 0)) { $s.Cap(4.4, $q[0] - 2, $q[1], 7.4, $q[0] + 1.6, $q[1], 2.0, 0.5, '') }
}
# Bull neck, horned basalt head with burning eyes.
function Head($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$open) {
  L $s @(($x + 2.4), ($y - 4), 0, ($x + 0.6), ($y - 1), $z) 2.8 2.6
  $s.Push($x, $y, $z, 0, $ry, $rz); $s.Group('crust', 0.9); $s.Ell(0, 0.4, 0, 4.4, 4.5, 4.4, 0, 0, 0, ''); $s.Box(-0.8, (-3.0 - 0.6 * $open), 0, 3.0, 1.6, 3.2, 0, 0, 0, 1.0, '')
  # Rock crest instead of horns, a glowing seam between the crags.
  foreach ($c in @(-0.4, 0, 3.4, 1.9), @(1.2, 2.6, 2.6, 1.6), @(1.2, -2.6, 2.6, 1.6), @(3.0, 0.4, 2.4, 1.7)) { $s.Cap($c[0], 2.6, $c[1], $c[0] + 1.0, 2.8 + $c[2], $c[1] * 1.15, $c[3], 0.8, '') }
  foreach ($q in -1, 1) { $s.Cap(-4.8, 2.1, 0.5 * $q, -3.8, 4.1, 3.3 * $q, 1.05, 0.7, '') }
  if ($script:face -eq 6) { foreach ($q in @(-3.2, 2.4, 2.6), @(-4.0, 0.8, 3.4), @(-4.0, -0.8, 3.0), @(-3.2, -2.4, 2.4)) { $s.Cap($q[0], -4.6, $q[1], $q[0] - 0.4, -4.6 - $q[2], $q[1] * 0.8, 1.2, 0.5, '') } }
  $s.Mark(-4.0, -0.8, 0, $script:faces[$script:face - 1], 'k=#14080a,y=#ffe070,o=#ff8c24,r=#e0481c,t=#b09a84', $true)
  if ($script:st -eq 3) { $s.Group('flame', 1.2); $s.Chain([double[]]@(2.4, 3.0, 0, 5.0, 5.0, 0, 5.6, 7.0, 0, 8.6, 8.4, 0), 2.8, 0.5, ''); foreach ($q in -1, 1) { $s.Chain([double[]]@(2.6, 2.0, (2.6 * $q), 5.4, 3.6, (3.4 * $q), 7.0, 6.0, (3.4 * $q)), 1.9, 0.5, '') } }
  $s.Pop()
}
function Pose7($s, $A) {
  $s.Yaw = 52
  if ($A.die -gt 0.9) { $s.Douse('lava', '#2c1214', '#48201c', '#642c20', '#7c3c28') } elseif ($A.die -gt 0.25) { $s.Douse('lava', '#641814', '#98301a', '#c45424', '#d88040') }
  Leg $s 0.4 5.4 -8 8; Leg $s 2 -5.4 -4 6
  $s.Push(1.4, 12, 0, 0, 0, -2); Torso $s
  # The near arm draws back and punches; the far one stays raised as a guard.
  Arm $s 0 (12 + 0.2 * $A.s) 9.4 (-36 + 10 * $A.wind + 28 * $A.act) (-6 - 1.5 * $A.s + 34 * $A.wind - 66 * $A.act + 12 * $A.hit) (-62 - 30 * $A.wind + 42 * $A.act) 1
  Arm $s 0 (12 + 0.2 * $A.s) -9.4 (58 - 8 * $A.wind - 24 * $A.die) (-14 + 1.5 * $A.s + 14 * $A.act + 10 * $A.hit) (-104 + 30 * $A.act + 40 * $A.die) -1
  Head $s -2.4 (17.4 + 0.25 * $A.s) 0 6 (-4 - 5 * $A.wind + 3 * $A.act - 8 * $A.hit) 1.6
  if ($script:st -ge 3) { $s.Group('lava', 0.4); $s.Cap(-5.6, 12.2, 1.4, -5.8, 9.6, 1.4, 0.6, 0.8, ''); if ($script:st -eq 4) { $s.Cap(-4.8, 1.6, 2.2, -4.9, -0.8, 2.2, 0.7, 0.9, '') } }
  $s.Pop()
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.4; Pose7 $s (Get-Still) }
$bmp = New-FittedSprite $still 48
$bmp.Save((Join-Path $Out 'colossus.png'))
if ($Anim) { Save-Sheets 'colossus' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.4; Pose7 $s $A } 48 (Get-Fit $still 48) @{ breath = 0.008; y0 = 9; y1 = 16; windBend = -6; actBend = 12; actPx = -3; windPx = 2; hitBend = -8; hitPx = 2; pivX = 1.4; pivY = 11.0; tod = @{ fx = 'chunks'; cell = 7; seed = 8; spread = 0.7; pile = 0.2; from = 3; marksUntil = 2 } } (Get-GameDir) }
