# Ash priest (enemy "priest", elite, 48 x 48): hooded cultist; exactly pose 7
# of assets/probe/priest_posen2.ps1. Writes <Out>/priest.png; -Anim writes the
# animation sheets into ui/assets/gegner (flames flicker, hurls fire, hit, turns
# to ash and leaves the robe).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('robe', '#140f12', '#2e2526', '#50423e', '#7c6a5e', '#b09a84')
  $s.Ramp('cloak', '#180a0c', '#3a1416', '#642420', '#94402c', '#c87048')
  $s.Ramp('skin', '#140e10', '#30242a', '#544248', '#806a66')
  $s.Ramp('iron', '#16161c', '#34343c', '#60605e', '#989488')
  $s.Ramp('void', '#050306', '#080508', '#0c070a')
  $s.Ramp('wood', '#1c1210', '#402820', '#6e4832', '#a07450')
  $s.Glow('glow', '#ff6a1a', '#ffa838', '#ffe890')
  $s.Glow('ember', '#c8321a', '#ff7c24', '#ffc850')
  $s.Fire('flame', '#701410', '#c8321a', '#f4681e', '#ffa62c', '#ffe070')
  $s.Contrast = 1.2; $s.EdgeDepth = 1.7; $s.EdgeSame = 5; $s.Grain('robe', 0.04)
}
# Ragged robe: body, folds and torn strips hanging to the ground.
function Robe($s, [double]$x0, [double]$x1, [double]$y1, [double]$w) {
  $s.Group('robe', 1.8); $s.Cap($x0, 3, 0, ($x0 + $x1) / 2, $y1 * 0.55, 0, $w * 0.86, $w * 0.62, ''); $s.Cap(($x0 + $x1) / 2, $y1 * 0.55, 0, $x1, $y1, 0, $w * 0.62, $w * 0.62, '')
  $s.Group('robe', 0.5)
  for ($i = 0; $i -lt 15; $i++) { $a = $i * 2 * [Math]::PI / 15; $l = 0.4 + (($i * 7) % 5) * 0.75; $s.Chain([double[]]@(($x1 + $w * 0.42 * [Math]::Cos($a)), ($y1 - 5), ($w * 0.42 * [Math]::Sin($a)), ($x0 + $w * 0.8 * [Math]::Cos($a)), 6, ($w * 0.8 * [Math]::Sin($a)), ($x0 + $w * 1.02 * [Math]::Cos($a)), $l, ($w * 1.02 * [Math]::Sin($a))), 1.2, 1.0, '') }
}
# Short cloak over the shoulders with a torn edge.
function Mantle($s, [double]$x, [double]$y, [double]$w) {
  $s.Group('cloak', 1.4); $s.Ell($x, $y, 0, $w * 0.72, 3.2, $w, 0, 0, 8, '')
  $s.Group('cloak', 0.5); for ($i = 0; $i -lt 13; $i++) { $a = $i * 2 * [Math]::PI / 13; $l = 3.6 + (($i * 5) % 4) * 1.0; $s.Cap($x + $w * 0.6 * [Math]::Cos($a), $y + 0.4, $w * 0.86 * [Math]::Sin($a), $x + $w * 0.8 * [Math]::Cos($a), $y - $l, $w * 1.04 * [Math]::Sin($a), 1.5, 0.7, '') }
}
# Deep pointed hood: opening is pure dark, two eyes glow inside.
function Hood($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$k = 1.1) {
  $s.Push($x, $y, $z, 0, ($ry + 10), $rz); $s.Group('robe', 1.2); $s.Ell(0.6, 0.4, 0, 4.4 * $k, 4.6 * $k, 4.2 * $k, 0, 0, 0, ''); $s.Chain([double[]]@(0.4, 3.4, 0, 2.4, 6.2, 0, 5.4, 6.8, 0), 2.6 * $k, 0.8, ''); $s.Cap(-2.4, 2.6, 0, -4.4, 2.0, 0, 2.2 * $k, 1.2, ''); $s.Cap(0, -3, 0, 0.6, -5, 0, 3.6 * $k, 3.8 * $k, '')
  $s.Cut(-4.4 * $k, -0.9 * $k, 0, 3.6 * $k, 3.3 * $k, 2.8 * $k, 0, 0, 0, 'void')
  $s.Group('void', 0); $s.Ell(-0.4, -0.6, 0, 1.8 * $k, 2.8 * $k, 2.4 * $k, 0, 0, 0, '')
  $s.Pop()
  $s.Push($x, $y, $z, 0, ($ry + 10), $rz); $s.Mark(-2.4, -0.3, 0, 'o...o/yo.oy', 'o=#ff6a1a,y=#ffe890', $true); $s.Pop()
}
function Sleeve($s, $p, [double]$dx, [double]$dy, [bool]$fist = $false) {
  $s.Group('robe', 1.0); $s.Chain([double[]]$p, 1.9, 2.6, ''); $n = $p.Count; [double]$x = $p[$n - 3]; [double]$y = $p[$n - 2]; [double]$z = $p[$n - 1]
  foreach ($q in @(0.4, 3.6), @(1.6, 2.8), @(-0.6, 2.6)) { $s.Cap($x + $q[0], $y - 0.6, $z, $x + $q[0] * 1.4, $y - $q[1], $z, 1.4, 0.6, '') }
  $s.Group('skin', 0.3); $s.Cap($x, $y, $z, $x + $dx * 2.6, $y + $dy * 2.6, $z, 1.2, 1.2, '')
  if ($fist) { $s.Ball($x + $dx * 3.2, $y + $dy * 3.2, $z, 1.5, '') } else { foreach ($k in -1.2, 0, 1.2) { $s.Group('skin', 0.2); $s.Cap($x + $dx * 2.6, $y + $dy * 2.6, $z, $x + $dx * 4.8 - $dy * 1.3 * $k, $y + $dy * 4.8 + $dx * 1.3 * $k, $z + 0.7 * $k, 0.75, 0.6, ''); $s.Group('glow', 0); $s.Ball($x + $dx * 5.2 - $dy * 1.4 * $k, $y + $dy * 5.2 + $dx * 1.4 * $k, $z + 0.8 * $k, 0.6, '') } }
}
# Chain through the points: alternating iron and ember links.
function Links($s, $p, [int]$per = 4) { $n = $p.Count / 3; $c = 0; for ($i = 0; $i -lt $n - 1; $i++) { for ($k = 0; $k -lt $per; $k++) { $t = $k / $per; $s.Group($(if ($c % 2) { 'ember' } else { 'iron' }), 0); $s.Ball($p[$i * 3] + ($p[$i * 3 + 3] - $p[$i * 3]) * $t, $p[$i * 3 + 1] + ($p[$i * 3 + 4] - $p[$i * 3 + 1]) * $t, $p[$i * 3 + 2] + ($p[$i * 3 + 5] - $p[$i * 3 + 2]) * $t, 0.85, ''); $c++ } } }
function Flame($s, [double]$x, [double]$y, [double]$z, [double]$r) { $s.Group('flame', 1.0); $s.Ball($x, $y, $z, $r, ''); $s.Chain([double[]]@($x, $y, $z, ($x + $r * 0.6), ($y + $r * 1.6), $z, ($x + $r * 0.1), ($y + $r * 3.0), $z), $r * 0.9, 0.5, ''); $s.Chain([double[]]@(($x - $r * 0.5), $y, $z, ($x - $r), ($y + $r * 1.7), $z), $r * 0.6, 0.4, '') }
# Chain slung round the chest.
function Sash($s, [double]$x, [double]$y) { Links $s @(($x - 3.4), ($y + 2), -5, ($x - 5.4), ($y - 1.4), -1.6, ($x - 5.2), ($y - 4), 2.4, ($x - 2.4), ($y - 6), 5.6) 4 }

function Build($s, $A) {
  $s.Yaw = 48
  Robe $s 2.4 1.4 19 7.4; Mantle $s 1 19.4 7.4; Sash $s 1 15.4
  # Hands up with the fire, then thrown forward; the flames leave the hands.
  $u = 0.35 * $A.s; $d = $A.die
  $f = Get-Swing @(1, 18.6, -5, 0, (19 + $u), -10, -2, (24 + $u), -12) @(1, 18.6, -5, 2, 20, -10.4, 2, 26, -12.4) @(1, 18.6, -5, -4, 18.4, -8.4, -9.4, 20.4, -8.6) $A
  $n = Get-Swing @(1, 18.6, 5, 0, (19 + $u), 10, -2, (24 + $u), 12) @(1, 18.6, 5, 2, 20, 10.4, 2, 26, 12.4) @(1, 18.6, 5, -4, 18.4, 8.4, -9.4, 20.4, 8.6) $A
  if ($d -gt 0) { $f = Get-Mix $f @(1, 18.6, -5, 1, 14, -8, 0, 9, -9) $d; $n = Get-Mix $n @(1, 18.6, 5, 1, 14, 8, 0, 9, 9) $d }
  $dx = -0.2 - 0.7 * $A.act; $dy = 0.95 - 0.7 * $A.act
  Sleeve $s $f $dx $dy; Sleeve $s $n $dx $dy
  foreach ($h in $f, $n) {
    [double]$r = 2.2 + 0.25 * $A.s + 0.9 * $A.wind - 0.5 * $A.hit; $fly = 0.0
    if ($A.anim -eq 'angriff') { $r = @(2.2, 2.7, 3.1, 2.9, 2.5, 1.6, 1.0, 2.2)[$A.f]; $fly = @(0, 0, 0, 1.5, 7, 12, 0, 0)[$A.f] }
    if ($d -lt 0.5) { Flame $s ($h[6] + 5.2 * $dx - 0.56 - $fly) ($h[7] + 5.2 * $dy + 2.06 - 0.2 * $fly) ($h[8] + $(if ($h[8] -gt 0) { 0.4 } else { -0.4 })) ($r * (1 - 1.6 * $d)) }
  }
  Hood $s -1.4 (23.4 + 0.2 * $A.s) 0 8 (4 - 8 * $A.wind + 6 * $A.act - 10 * $A.hit + 14 * $d)
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.4; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 48 $true
$bmp.Save((Join-Path $Out 'priest.png'))
if ($Anim) { Save-Sheets 'priest' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.4; Build $s $A } 48 (Get-Fit $still 48) @{ breath = 0.008; sway = 0.3; y0 = 2; y1 = 18; windBend = -6; actBend = 12; actPx = -4; hitBend = -10; hitPx = 3; tod = @{ squash = 0.42; fx = 'ash'; from = 3; ember = @('#2e2526', '#642420', '#ff7c24', '#ffe890'); rise = 22; wind = 6; keep = 0.45; down = 0.8; marksUntil = 3 } } (Get-GameDir) }
