# Sand worm (enemy "worm"): bursts from the sand; exactly pose 1 of
# assets/probe/worm_posen.ps1. Writes <Out>/worm.png; -Anim writes the animation
# sheets into ui/assets/gegner (swaying, bites down, hit, sinks into the sand).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('hide', '#22120f', '#4e2c20', '#80502f', '#b27e48', '#e2b878')
  $s.Ramp('belly', '#3a2218', '#70482e', '#a87c50', '#dcb484', '#f6e0b4')
  $s.Ramp('gum', '#2a0810', '#5e1620', '#94303a', '#c86058')
  $s.Ramp('dark', '#080304', '#12060a', '#220a10')
  $s.Ramp('tooth', '#80745c', '#c8bc94', '#fbf4d6')
  $s.Ramp('sand', '#2e1c16', '#5c3c28', '#8e6640', '#c09560')
  $s.Glow('lava', '#d8421a', '#ff8c2a', '#ffd860')
  $s.Contrast = 1.15; $s.EdgeDepth = 1.6; $s.EdgeSame = 6
}
function Dune($s, [double]$x, [double]$w) { $s.Group('sand', 1.6); $s.Ell($x, -0.4, 0, $w, 2.4, 6.4, 0, 0, 0, ''); $s.Ell($x - $w * 0.6, 0, 3, 3.4, 1.4, 3, 0, 0, 0, ''); $s.Ell($x + $w * 0.6, 0, 1, 3.6, 1.6, 3.2, 0, 0, 0, '') }
# Smooth points along a Catmull-Rom curve through x,y,z triples.
function Curve($pts, [int]$per) {
  $n = $pts.Count / 3; $q = @()
  for ($i = 0; $i -lt $n - 1; $i++) { $a = [Math]::Max(0, $i - 1); $d = [Math]::Min($n - 1, $i + 2)
    for ($k = 0; $k -lt $per; $k++) { $t = $k / $per; $v = for ($c = 0; $c -lt 3; $c++) { [double]$p0 = $pts[$a * 3 + $c]; [double]$p1 = $pts[$i * 3 + $c]; [double]$p2 = $pts[($i + 1) * 3 + $c]; [double]$p3 = $pts[$d * 3 + $c]; 0.5 * (2 * $p1 + (-$p0 + $p2) * $t + (2 * $p0 - 5 * $p1 + 4 * $p2 - $p3) * $t * $t + (-$p0 + 3 * $p1 - 3 * $p2 + $p3) * $t * $t * $t) }; $q += , $v } }
  $q += , @([double]$pts[($n - 1) * 3], [double]$pts[($n - 1) * 3 + 1], [double]$pts[($n - 1) * 3 + 2]); , $q
}
# Ringed body: every ring its own group, so the seams show as dark lines.
function Rings($s, $pts, [double]$r1, [double]$r2) {
  $q = Curve $pts 3; $n = $q.Count
  for ($i = 0; $i -lt $n; $i++) {
    $r = $r1 + ($r2 - $r1) * $i / ($n - 1); $bulge = $r * (1 + 0.07 * ($i % 2))
    $s.Group($(if ($i % 2) { 'hide' } else { 'belly' }), 0.4); $s.Ball($q[$i][0], $q[$i][1], $q[$i][2], $bulge, '')
  }
}
# Maw at a point looking along the turned -x axis: lip ring, throat, teeth.
function Maw($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$r, [int]$teeth = 6) {
  $s.Push($x, $y, $z, 0, $ry, $rz)
  $s.Group('hide', 1.0); $s.Ell(0, 0, 0, $r * 0.95, $r * 1.28, $r * 1.28, 0, 0, 0, ""); $s.Cut(-$r * 1.0, 0, 0, $r * 1.15, $r * 0.9, $r * 0.9, 0, 0, 0, "dark")
  $s.Group('dark', 0); $s.Ell(-$r * 0.05, 0, 0, $r * 0.3, $r * 0.5, $r * 0.5, 0, 0, 0, "gum")
  $s.Group('lava', 0); $s.Ball(-$r * 0.2, 0, 0, $r * 0.28, "")
  $s.Group('tooth', 0); for ($i = 0; $i -lt $teeth; $i++) { $a = $i * 2 * [Math]::PI / $teeth; $c = [Math]::Cos($a); $d = [Math]::Sin($a); $s.Cap(-$r * 0.66, $r * 0.98 * $c, $r * 0.98 * $d, -$r * 1.0, $r * 0.62 * $c, $r * 0.62 * $d, 0.9, 0.35, '') }
  $s.Pop()
}
# Wedge head with eyes and side mandibles for the non-round variants.
function Jaws($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$r, [double]$open) {
  $s.Push($x, $y, $z, 0, $ry, $rz)
  $s.Group('hide', 1.0); $s.Ell(0, 0, 0, $r * 1.1, $r, $r, 0, 0, 0, ''); $s.Cut(-$r * 1.2, -0.2, 0, $r * 1.2, $r * 0.4, $r * 0.8, 0, 0, 0, 'gum')
  foreach ($q in @(0, 1), @(125, 1), @(235, 1)) { $a = $q[0] * [Math]::PI / 180; $c = [Math]::Cos($a); $d = [Math]::Sin($a); $s.Group('hide', 0.6); $s.Chain([double[]]@(0, ($r * 0.8 * $c), ($r * 0.8 * $d), (-$r * 1.2), ($r * (0.8 + 0.5 * $open) * $c), ($r * (0.8 + 0.5 * $open) * $d), (-$r * 2.2), ($r * 0.45 * $open * $c), ($r * 0.45 * $open * $d)), ($r * 0.42), 0.5, ''); $s.Group('tooth', 0); $s.Cap(-$r * 1.2, $r * (0.6 + 0.4 * $open) * $c, $r * (0.6 + 0.4 * $open) * $d, -$r * 1.5, $r * 0.2 * $c, $r * 0.2 * $d, 0.8, 0.3, '') }
  $s.Group('lava', 0); $s.Ball(-$r * 0.4, 0, 0, $r * 0.35, ''); foreach ($d in -1, 1) { $s.Ell(-$r * 0.35, $r * 0.72, $r * 0.55 * $d, 0.9, 0.7, 0.8, 0, 0, 0, '') }
  $s.Pop()
}

function Build($s, $A) {
  $s.Yaw = 20; Dune $s 5 8
  if ($A.die -gt 0.6) { $s.Douse('lava', '#5e1620', '#94303a') }
  # Body points and, as the last five numbers, maw x, y and its turn.
  $p = Get-Swing @(5, -2, 0, 7.4, 6, 0, 7.6, 13, 0, 4, 19, 0, -2, 20, 0, -4.6, 19.2, 14) @(5, -2, 0, 8.6, 6, 0, 9.8, 13, 0, 7.4, 20, 0, 1.8, 22, 0, -0.9, 21.6, 2) @(5, -2, 0, 6.8, 6, 0, 5.4, 12, 0, 0.6, 15, 0, -5.4, 12.4, 0, -7.6, 10.8, 44) $A
  $p = Get-Mix $p @(5, -2, 0, 8.2, 6, 0, 10, 13, 0, 8.4, 19, 0, 3, 22, 0, 0.2, 22.4, -16) $A.hit
  for ($i = 1; $i -lt 5; $i++) { $p[$i * 3] += 0.3 * $i * $A.s }; $p[15] += 1.35 * $A.s
  $q = [double[]]($p[0..14]); if ($A.die -gt 0) { for ($i = 0; $i -lt 5; $i++) { $q[$i * 3 + 1] -= 29 * $A.die; $q[$i * 3] += (6 - $q[$i * 3]) * 0.5 * $A.die } }
  Rings $s $q 5.2 4.2
  Maw $s ($p[15] + 5 * $A.die) ($p[16] - 29 * $A.die) 0 40 $p[17] (4.9 + 0.5 * $A.wind + 0.02 * $A.s)
}
$still = { param($s) Add-Ramps $s; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 32 $true
$bmp.Save((Join-Path $Out 'worm.png'))
if ($Anim) { Save-Sheets 'worm' { param($s, $A) Add-Ramps $s; Build $s $A } 32 (Get-Fit $still 32) @{ breath = 0.0; windBend = 0; actBend = 0; hitBend = 0; actPx = -1; windPx = 0; hitPx = 1 } (Get-GameDir) }
