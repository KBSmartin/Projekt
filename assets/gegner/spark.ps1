# Spark spirit (enemy "spark"): fire elemental; exactly pose 8 of
# assets/probe/spark_posen2.ps1. Writes <Out>/spark.png; -Anim writes the
# animation sheets into ui/assets/gegner (whirling, throws embers, hit, burns out).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Fire('flame', '#4c0c10', '#901c14', '#d04018', '#f47c22', '#ffb43c')
  $s.Fire('hot', '#b03418', '#f07422', '#ffb03a', '#ffe070')
  $s.Ramp('coal', '#0e0a0e', '#241c24', '#443638', '#6e564c', '#a07c60')
  $s.Ramp('dark', '#10040a', '#1c0608', '#2c0a0a')
  $s.Glow('red', '#ffd860', '#fff2b0', '#ffffff')
  $s.Shadow = $false; $s.EdgeDepth = 2.2; $s.EdgeSame = 7
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
  $s.Chain([double[]]@(1.0, 2, 0, 3.4, 5.6, 0, 3.0, 8.4, 0, 5.4, 10.6, 0), 2.6 * $k, 0.5, ''); foreach ($q in -1, 1) { $s.Chain([double[]]@(0.6, 2.0, (2.6 * $q), 1.4, 5.0, (4.4 * $q), 1.0, 7.6, (4.0 * $q)), 1.5 * $k, 0.5, '') }
  $s.Cut(-4.0 * $k, -0.5 * $k, 0, 2.8 * $k, 2.9 * $k, 3.0 * $k, 0, 0, 0, 'dark')
  $s.Mark(-2.8 * $k, 0.2 * $k, 0, 'y...y/ry.yr', 'y=#ffe890,r=#ff6a2a', $true)
  $s.Pop()
}
function Arm($s, $p, [double]$dx, [double]$dy, [double]$r = 2.2) {
  Ch $s 'flame' $p $r ($r * 0.75); $n = $p.Count; [double]$x = $p[$n - 3]; [double]$y = $p[$n - 2]; [double]$z = $p[$n - 1]
  $s.Group('hot', 0.5); foreach ($k in -1, 0, 1) { $s.Chain([double[]]@($x, $y, $z, ($x + 2.2 * $dx - 1.5 * $k * $dy), ($y + 2.2 * $dy + 1.5 * $k * $dx), ($z + $k), ($x + 4.6 * $dx - 1.4 * $k * $dy), ($y + 4.6 * $dy + 1.4 * $k * $dx), ($z + $k)), 1.2, 0.5, '') }
  # Wisp trailing from the elbow.
  Ch $s 'flame' @($p[3], $p[4], $p[5], ($p[3] + 2.4), ($p[4] + 2.0), $p[5], ($p[3] + 4.4), ($p[4] + 5.0), $p[5]) 1.6 0.5
}
function Ember($s, $list) { $s.Group('hot', 0); foreach ($e in $list) { $s.Ball($e[0], $e[1], $e[2], $e[3], '') } }

function Build($s, $A) {
  $s.Yaw = 44; $script:spin = 2.1 * $A.phase + 4.2 * $A.act + 2.1 * $A.wind
  Whirl $s (4 + 0.6 * $A.s) 0 1 10 3.6 1.3; Torso $s 0.6 15 4 1.25
  # Both arms fly up and back, then push the fire at the hero.
  $u = 0.4 * $A.s
  $n = Get-Swing @(0, 18.6, 6.4, -1, (13 + $u), 10.6, -5, (11 + 2 * $u), 10) @(0, 18.6, 6.4, 3, 17, 11, 1, 21, 12) @(0, 18.6, 6.4, -5, 16, 9, -10, 15.6, 6) $A
  $f = Get-Swing @(0, 18.6, -6.4, -1, (13 + $u), -10.6, -5, (11 + 2 * $u), -10) @(0, 18.6, -6.4, 3, 17, -11, 1, 21, -12) @(0, 18.6, -6.4, -5, 16, -9, -10, 15.6, -6) $A
  Arm $s $f -0.9 (0.1 + 0.6 * $A.wind) 2.8; Arm $s $n -0.9 (0.1 + 0.6 * $A.wind) 2.8
  Head $s -2 (23 + 0.2 * $A.s) 0 10 (6 - 8 * $A.wind + 8 * $A.act - 12 * $A.hit) 1.05
  if ($A.embers) { Ember $s $A.embers }
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.05; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 32 $true
$bmp.Save((Join-Path $Out 'spark.png'))
if ($Anim) {
  $keys = { param($A) $A.embers = $null; if ($A.anim -eq 'angriff' -and $A.f -ge 4 -and $A.f -le 6) { $k = $A.f - 4; $A.embers = @(@((-14.5 - 1.6 * $k), (16 + 0.4 * $k), 5, (1.7 - 0.4 * $k)), @((-13.5 - 2.2 * $k), (13 - 0.6 * $k), 1, (1.4 - 0.3 * $k)), @((-12 - 1.8 * $k), (19 + 0.8 * $k), -2, (1.2 - 0.3 * $k))) } }
  Save-Sheets 'spark' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.05; Build $s $A } 32 (Get-Fit $still 32) @{ breath = 0.02; sway = 0.5; bob = 0; y0 = 1; y1 = 12; windBend = -8; actBend = 14; actPx = -4; hitBend = -16; hitPx = 3; tod = @{ squash = 0.8; fx = 'ash'; from = 2; ember = @('#4c0c10', '#901c14', '#f47c22', '#ffe070'); rise = 16; wind = 3; down = 0.35; marksUntil = 2 } } (Get-GameDir) $keys
}
