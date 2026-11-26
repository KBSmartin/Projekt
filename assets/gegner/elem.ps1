# Ice elemental (enemy "elem"): the spark spirit in ice, hooded head, colours of
# the northern lights; pose 25 of assets/probe/elem_posen5.ps1. Writes
# <Out>/elem.png; -Anim writes the animation sheets into ui/assets/gegner
# (whirling, throws ice shards, hit, shatters).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)
# Chosen among the trials: aurora colours, no crest.
$script:pal = 'polar'; $script:crest = $false

function Add-Ramps($s) {
  switch ($script:pal) {
    'frost'  { $s.Fire('flame', '#0e1e48', '#1a3e80', '#2e6ebc', '#5cacdf', '#b4ecff'); $s.Fire('hot', '#2e6ebc', '#6cb8e4', '#b4ecff', '#ffffff') }
    'glas'   { $s.Ramp('flame', '#12285a', '#24589c', '#489cd2', '#94d8f2', '#f4ffff'); $s.Ramp('hot', '#3878b8', '#78bce0', '#bce8f8', '#ffffff') }
    'polar'  { $s.Fire('flame', '#140e38', '#2a2670', '#3a58b0', '#48a8c4', '#a4f4e0'); $s.Fire('hot', '#3a58b0', '#48a8c4', '#98f0dc', '#f0fff8') }
  }
  $s.Fire('hand', '#2a4a94', '#3c88b4', '#62c4c8', '#a4f4e0')
  $s.Ramp('coal', '#0e0a0e', '#241c24', '#443638', '#6e564c', '#a07c60'); $s.Ramp('dark', '#040818', '#081026', '#0e1a3a')
  $s.Ramp('kristall', '#2c6cb0', '#70bce4', '#c4f0fc', '#ffffff')
  $s.Shadow = $false; $s.EdgeDepth = 1.7; $s.EdgeSame = 7
}
function Ch($s, [string]$m, $p, [double]$r1, [double]$r2, [double]$k = 1.0) { $s.Group($m, $k); $s.Chain([double[]]$p, $r1, $r2, '') }
# Whirl: flame ribbons winding round an axis from the tip (x0, y0) up to (x1, y1).
function Whirl($s, [double]$x0, [double]$y0, [double]$x1, [double]$y1, [double]$w, [double]$turns) {
  $s.Group('flame', 1.6); $s.Cap($x0, $y0, 0, $x1, $y1, 0, 0.8, $w * 0.7, '')
  foreach ($ph in 0, 2.1, 4.2) { $q = @(); for ($i = 0; $i -le 14; $i++) { $t = $i / 14.0; $a = $ph + $script:spin + $t * $turns * 6.283; $rr = 0.6 + $w * $t; $q += ($x0 + ($x1 - $x0) * $t + $rr * [Math]::Cos($a)), ($y0 + ($y1 - $y0) * $t), ($rr * [Math]::Sin($a)) }; $s.Group('hot', 0.4); $s.Chain([double[]]$q, 0.5, 1.3, '') }
}
function Torso($s, [double]$x, [double]$y, [double]$rz, [double]$k = 1) {
  $s.Push($x, $y, 0, 0, 0, $rz); $s.Group('flame', 2.2); $s.Cap(0, -4, 0, 0, 2, 0, 2.2 * $k, 3.4 * $k, ''); $s.Ell(0, 3, 0, 3.6 * $k, 3.2 * $k, 6.6 * $k, 0, 0, 0, '')
  foreach ($q in -1, 1) { $s.Chain([double[]]@(1, 4, (5 * $q * $k), 2.4, 7.4, (6.4 * $q * $k), 1.4, 10.4, (6.4 * $q * $k)), 2.4 * $k, 0.5, '') }
  $s.Pop()
}
# Head: flame crest blown back, black hollow with two slanted eyes.
function Head($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$k = 1.1) {
  $s.Push($x, ($y + 0.6), $z, 0, ($ry + 20), $rz); $s.Group('flame', 1.0); $s.Ell(0, 0, 0, 3.7 * $k, 4.0 * $k, 3.8 * $k, 0, 0, 0, '')
  if ($script:crest) { $s.Chain([double[]]@(1.0, 2, 0, 3.4, 5.6, 0, 3.0, 8.4, 0, 5.4, 10.6, 0), 2.6 * $k, 0.5, ''); foreach ($q in -1, 1) { $s.Chain([double[]]@(0.6, 2.0, (2.6 * $q), 1.4, 5.0, (4.4 * $q), 1.0, 7.6, (4.0 * $q)), 1.5 * $k, 0.5, '') } } else { $s.Chain([double[]]@(0.6, 1.4, 0, 3.6, 2.8, 0, 6.6, 2.4, 0, 9.6, 3.8, 0), 3.3 * $k, 0.5, ''); foreach ($q in -1, 1) { $s.Chain([double[]]@(1.4, 0.2, (1.8 * $q), 4.4, 0.0, (2.6 * $q), 7.4, 1.0, (2.4 * $q)), 2.0 * $k, 0.5, '') } }
  $s.Cut(-4.0 * $k, -0.5 * $k, 0, 2.8 * $k, 2.9 * $k, 3.0 * $k, 0, 0, 0, 'dark')
  $s.Mark(-2.8 * $k, 0.2 * $k, 0, 'y...y/ry.yr', 'y=#ffffff,r=#68dcff', $true)
  $s.Pop()
}
function Arm($s, $p, [double]$dx, [double]$dy, [double]$r = 2.2, [string]$sleeve = 'flame', [string]$hand = 'hot') {
  Ch $s $sleeve $p $r ($r * 0.75); $n = $p.Count; [double]$x = $p[$n - 3]; [double]$y = $p[$n - 2]; [double]$z = $p[$n - 1]
  $s.Group($hand, 0.5); foreach ($k in -1, 0, 1) { $s.Chain([double[]]@($x, $y, $z, ($x + 2.2 * $dx - 1.5 * $k * $dy), ($y + 2.2 * $dy + 1.5 * $k * $dx), ($z + $k), ($x + 4.6 * $dx - 1.4 * $k * $dy), ($y + 4.6 * $dy + 1.4 * $k * $dx), ($z + $k)), 1.2, 0.5, '') }
  # Wisp trailing from the elbow.
  Ch $s 'flame' @($p[3], $p[4], $p[5], ($p[3] + 2.4), ($p[4] + 2.0), $p[5], ($p[3] + 4.4), ($p[4] + 5.0), $p[5]) 1.6 0.5
}
function Ember($s, $list) { $s.Group('hot', 0); foreach ($e in $list) { $s.Ball($e[0], $e[1], $e[2], $e[3], '') } }
function Spirit($s, $A) {
  $s.Yaw = 44; $script:spin = 2.1 * $A.phase + 4.2 * $A.act + 2.1 * $A.wind; $u = 0.4 * $A.s
  Whirl $s (4 + 0.6 * $A.s) 0 1 10 3.6 1.3; Torso $s 0.6 15 4 1.25
  Arm $s (Get-Swing @(0, 18.6, -6.4, -1, (13 + $u), -10.6, -5, (11 + 2 * $u), -10) @(0, 18.6, -6.4, 2, 15, -11, 0, 18, -12) @(0, 18.6, -6.4, -4, 15, -9.6, -9.4, 15, -8) $A) -0.9 (0.1 + 0.5 * $A.wind) 2.8
  # The near arm is held out to the side, so its hand stands clear of the whirl;
  # it sweeps round to throw.
  Arm $s (Get-Swing @(0, 18.6, 6.8, 2.0, (14.2 + $u), 12.4, 0.8, (11.4 + 2 * $u), 15.0) @(0, 18.6, 6.8, 4.4, 18, 12.4, 4.6, 23, 14) @(0, 18.6, 6.8, -4, 16, 11, -8.6, 15, 9) $A) (-0.75 - 0.15 * $A.act) (-0.5 + 1.2 * $A.wind + 0.6 * $A.act) 2.6 'flame' 'hand'
  Head $s -2 (23 + 0.2 * $A.s) 0 10 (6 - 8 * $A.wind + 8 * $A.act - 12 * $A.hit) 1.05
  if ($A.shards) { $s.Group('kristall', 0); foreach ($e in $A.shards) { $s.Gem($e[0], $e[1], $e[2], 1.0, $e[3], 1.0, 0, 0, (80 + $e[4]), '') } }
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.05; Spirit $s (Get-Still) }
$bmp = New-FittedSprite $still 32
$bmp.Save((Join-Path $Out 'elem.png'))
if ($Anim) {
  $keys = { param($A) $A.shards = $null; if ($A.anim -eq 'angriff' -and $A.f -ge 4 -and $A.f -le 6) { $k = $A.f - 4; $l = 3.2 - 0.8 * $k; $A.shards = @(@((-13.5 - 2.4 * $k), (17 + 0.4 * $k), 5, $l, -12), @((-13 - 2.8 * $k), (13.4 - 0.8 * $k), 1, $l, 8), @((-11 - 2.4 * $k), (20.4 + 0.8 * $k), -2, ($l * 0.8), -20)) } }
  Save-Sheets 'elem' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.05; Spirit $s $A } 32 (Get-Fit $still 32) @{ breath = 0.02; sway = 0.5; y0 = 1; y1 = 12; windBend = -8; actBend = 14; actPx = -4; hitBend = -16; hitPx = 3; tod = @{ fx = 'chunks'; cell = 4.5; seed = 4; spread = 1.2; pile = 0.15; from = 2; marksUntil = 3 } } (Get-GameDir) $keys
}
