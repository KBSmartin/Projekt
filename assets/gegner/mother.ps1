# Bark mother (enemy "mother", boss): an ancient leafless oak, pose 21 of
# assets/probe/mother_posen5.ps1. Writes <Out>/mother_<Size>.png; -Anim writes
# the animation sheets into ui/assets/gegner (boughs swaying, whipping, hit).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [int]$Size = 48, [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('bark', '#120d10', '#2e2322', '#524238', '#80684f', '#b59a72')
  $s.Ramp('dark', '#060405', '#0c0708', '#150c0c')
  $s.Ramp('splint', '#33261e', '#5c4636', '#8c7052')
  $s.Ramp('lichen', '#1c2416', '#3c4a28', '#687838', '#98a458')
  $s.Glow('glow', '#b04c0c', '#ff9c28', '#ffe890')
  $s.Grain('bark', 0.10); $s.Contrast = 1.2; $s.EdgeDepth = 2.0
}
function Wood($s, $p, [double]$r1, [double]$r2, [double]$k = 1.2) { $s.Group('bark', $k); $s.Chain([double[]]$p, $r1, $r2, '') }
function Roots($s, [double]$x, [double]$y, $list) { foreach ($r in $list) { Wood $s @($x, $y, 0, ($x + ($r[0] - $x) * 0.45), ($y * 0.55), ($r[1] * 0.45), ($x + ($r[0] - $x) * 0.8), 1.8, ($r[1] * 0.85), $r[0], 0.4, $r[1]) 3.2 0.7 1.6 } }
# Smooth limb through the points (Catmull-Rom), tapering; for whips and boughs.
function Limb($s, $pts, [double]$r1, [double]$r2, [double]$k = 0.8) {
  $n = $pts.Count / 3; $q = [Collections.Generic.List[double]]::new()
  for ($i = 0; $i -lt $n - 1; $i++) {
    $a = [Math]::Max(0, $i - 1); $d = [Math]::Min($n - 1, $i + 2)
    for ($t = 0.0; $t -lt 0.99; $t += 0.25) { for ($c = 0; $c -lt 3; $c++) {
      [double]$p0 = $pts[$a * 3 + $c]; [double]$p1 = $pts[$i * 3 + $c]; [double]$p2 = $pts[($i + 1) * 3 + $c]; [double]$p3 = $pts[$d * 3 + $c]
      $q.Add(0.5 * (2 * $p1 + (-$p0 + $p2) * $t + (2 * $p0 - 5 * $p1 + 4 * $p2 - $p3) * $t * $t + (-$p0 + 3 * $p1 - 3 * $p2 + $p3) * $t * $t * $t))
    } }
  }
  for ($c = 0; $c -lt 3; $c++) { $q.Add([double]$pts[($n - 1) * 3 + $c]) }
  $s.Group('bark', $k); $s.Chain($q.ToArray(), $r1, $r2, '')
}
# Bare bough: grows from a point along (dx, dy, dz) and forks with gnarled bends.
function Bough($s, $rng, [double]$x, [double]$y, [double]$z, [double]$dx, [double]$dy, [double]$dz, [double]$len, [double]$r, [int]$depth) {
  # $script:whip turns every segment a little further, so the tips lag behind.
  if ($script:whip -ne 0) { $a = $script:whip * (3.2 - $depth) * 0.5 * [Math]::PI / 180; $qx = $dx * [Math]::Cos($a) - $dy * [Math]::Sin($a); $dy = $dx * [Math]::Sin($a) + $dy * [Math]::Cos($a); $dx = $qx }
  $mx = $x + $dx * $len * 0.5 + ($rng.NextDouble() - 0.5) * $len * 0.35; $my = $y + $dy * $len * 0.5 + ($rng.NextDouble() - 0.5) * $len * 0.3; $mz = $z + $dz * $len * 0.5
  $ex = $x + $dx * $len; $ey = $y + $dy * $len; $ez = $z + $dz * $len
  $s.Group('bark', 0.6); $s.Chain([double[]]@($x, $y, $z, $mx, $my, $mz, $ex, $ey, $ez), $r, [Math]::Max(0.55, $r * 0.6), '')
  if ($depth -le 0) { return }
  foreach ($q in -1, 1) {
    $a = $q * (0.45 + 0.35 * $rng.NextDouble()); $nx = $dx * [Math]::Cos($a) - $dy * [Math]::Sin($a); $ny = $dx * [Math]::Sin($a) + $dy * [Math]::Cos($a)
    Bough $s $rng $ex $ey $ez $nx $ny ($dz + ($rng.NextDouble() - 0.5) * 0.7) ($len * (0.58 + 0.2 * $rng.NextDouble())) ([Math]::Max(0.6, $r * 0.62)) ($depth - 1)
  }
}
function Knots($s, $list) { $s.Group('bark', 1.4); foreach ($k in $list) { $s.Ell($k[0], $k[1], $k[2], $k[3], $k[3] * 0.8, $k[3], 0, 0, 0, '') } }
# Old face: deep sockets, crooked crack of a mouth with bark splinters.
function Visage($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$R, [double]$open) {
  $s.Push($x, $y, $z, 0, $ry, $rz)
  Add-Face $s @{ R = $R; eyeY = 2.6; dist = ($R * 0.46); slant = 24; eye = 1.8; brow = 1.4; mouthY = -3.6; mouthW = ($R * 0.62); mouthH = (1.1 + $open); teeth = 4; tooth = 'splint'; curve = -0.9; nose = $true }
  $s.Pop()
}

function Build($s, [double]$z, $A) {
  if ($A.die -gt 0.6) { $s.Douse('glow', '#150c0c', '#241410') }
  $script:whip = 4.0 * $A.s - 12 * $A.wind + 19 * $A.act - 12 * $A.hit - 16 * $A.die
  $s.Yaw = 22; $s.Zoom = 0.7 * $z
  $rng = [Random]::new(7)
  Roots $s 2 8 @(@(-10, 5), @(-8, -8), @(13, 6), @(14, -6), @(1, 12), @(6, -11))
  $s.Group('bark', 3.0); $s.Cap(2, 3, 0, 2, 15, 0, 7.6, 6.8, ''); $s.Cap(2, 15, 2, 6, 21, 3, 5.2, 3.4, ''); $s.Cap(2, 15, -2, -3, 21, -3, 5.2, 3.2, '')
  # Crown base and bough stubs belong to the trunk, so no seam lines show.
  $s.Ell(2, 18.4, 0, 6.4, 4.4, 5.6, 0, 0, 0, ''); $s.Cap(6, 21, 3, 8.6, 25.6, 3.4, 3.2, 2.4, ''); $s.Cap(7, 19, 3, 11.6, 20.6, 3.8, 2.8, 2.0, ''); $s.Cap(-3, 21, -3, -4.8, 25.8, -3.4, 3.0, 2.3, ''); $s.Cap(-4, 19, -3, -8.6, 20.4, -3.8, 2.8, 2.0, ''); $s.Cap(2, 20, 0, 2.2, 25, 0, 3.0, 2.1, '')
  $s.Push(2, 12.4, 0, 0, 0, 0); $s.Ell(0, 0, 0, 7.6, 8.0, 7.4, 0, 0, 0, ''); $s.Pop(); Visage $s 2 12.4 0 46 2 7.5 (0.4 + 1.4 * $A.act + 0.6 * $A.wind + 0.8 * $A.hit)
  Bough $s $rng 6 21 3 0.45 0.9 0.1 8 2.6 2; Bough $s $rng 7 19 3 0.95 0.35 0.2 6.5 2.0 2; Bough $s $rng -3 21 -3 -0.35 0.95 -0.1 8 2.4 2; Bough $s $rng -4 19 -3 -0.95 0.3 -0.2 7.1 2.0 2; Bough $s $rng 2 21 0 0.05 1 0 7 2.2 2
  Knots $s @(@(8.6, 8, 4, 2.6), @(7, 15, 5, 1.8))
}
$script:whip = 0.0; $still = @{ s = 0.0; wind = 0.0; act = 0.0; hit = 0.0; die = 0.0 }
$s = New-Scene; Add-Ramps $s; Build $s ($Size / 32.0) $still
$bmp = New-Sprite $s $Size; $bmp.Save((Join-Path $Out "mother_$Size.png"))
if ($Anim) { Save-Sheets 'mother' { param($s, $A) Add-Ramps $s; Build $s ($Size / 32.0) $A } $Size $null @{ breath = 0.006; sway = 0.5; y0 = 3; y1 = 22; windBend = -9; actBend = 14; actPx = -4; hitBend = -10; hitPx = 2; pivX = 2.0; pivY = 3.0; tod = @{ squash = 0.9; fx = 'chunks'; cell = 7; spread = 0.5; pile = 0.2; from = 3 } } (Get-GameDir) }