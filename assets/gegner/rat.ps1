# Forest rat (enemy "rat"): aggressive poses seen from the front or front
# three-quarter, built from ellipsoids, ray traced and snapped to pixels
# (light from the upper left, rim light, dark outline).
#   -Pose <name>   one of the poses below; writes <Out>/rat_<pose>.png
#   -Study         flat grey form study (pose phase)
#   -Sheet         combine all rendered studies into rat_posen3.png
#   -Anim <name>   idle, angriff, treffer or alle: 8-frame sheets of the
#                  chosen pose (hocken) as <Out>/rat_<anim>.png, by default
#                  into ui/assets/gegner
param(
  [string]$Pose = 'fauchen',
  [int]$Size = 32,
  [string]$Out = (Join-Path $PSScriptRoot '..\probe'),
  [switch]$Study,
  [switch]$Sheet,
  [double]$CamYaw = 999,
  [double]$HeadTurn = 999,
  [ValidateSet('', 'idle', 'angriff', 'treffer', 'alle')][string]$Anim = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if ($Anim) {
  $Pose = 'hocken'
  if (-not $PSBoundParameters.ContainsKey('Out')) { $Out = Join-Path $PSScriptRoot '..\..\ui\assets\gegner' }
}
$Out = [IO.Path]::GetFullPath($Out)
$titles = [ordered]@{
  fauchen   = '11 Frontal fauchend'
  sprung    = '12 Schraeg vorn, Sprungansatz'
  aufrecht  = '13 Aufgerichtet, Krallen'
  schnappen = '14 Kopf vorgestossen'
  buckel    = '15 Gebuckelt, gestraeubt'
}

if ($Sheet) {
  $forest = [Drawing.Bitmap]::FromFile([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\ui\assets\hintergrund\wald.png')))
  $cell = 300; $names = @($titles.Keys)
  $sh = [Drawing.Bitmap]::new($cell * $names.Count, 32 + 8 + 256 + 8 + 256 + 8 + 128 + 30)
  $g = [Drawing.Graphics]::FromImage($sh)
  $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
  $g.Clear([Drawing.Color]::FromArgb(24, 24, 32))
  $grey = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(150, 150, 158))
  $font = [Drawing.Font]::new('Consolas', 11)
  for ($i = 0; $i -lt $names.Count; $i++) {
    $f = Join-Path $Out "rat_$($names[$i])_studie.png"; if (-not (Test-Path $f)) { continue }
    $img = [Drawing.Bitmap]::FromFile($f)
    $sil = [Drawing.Bitmap]::new(32, 32)
    for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt 32; $x++) { if ($img.GetPixel($x, $y).A -gt 200) { $sil.SetPixel($x, $y, [Drawing.Color]::FromArgb(12, 10, 16)) } } }
    $x0 = $i * $cell + 22
    $g.DrawImage($img, $x0, 0, 32, 32); $g.DrawImage($sil, $x0 + 40, 0, 32, 32)
    $g.FillRectangle($grey, $x0, 40, 256, 256); $g.DrawImage($sil, $x0, 40, 256, 256)
    $g.FillRectangle($grey, $x0, 304, 256, 256); $g.DrawImage($img, $x0, 304, 256, 256)
    $g.DrawImage($forest, [Drawing.Rectangle]::new($x0, 568, 256, 128), [Drawing.Rectangle]::new(100, 116, 64, 32), 'Pixel')
    $g.DrawImage($img, $x0 + 64, 568, 128, 128)
    $g.DrawString($titles[$names[$i]], $font, [Drawing.Brushes]::White, $x0, 702)
    $img.Dispose(); $sil.Dispose()
  }
  $g.Dispose(); $forest.Dispose()
  $sh.Save((Join-Path $Out 'rat_posen3.png')); $sh.Dispose()
  return
}

$ramps = @{
  fur    = @('#1a1214', '#2e1c1e', '#442a28', '#5e3a32', '#784c3c', '#93624a', '#ae7c5c')
  pink   = @('#3e1a26', '#6a3040', '#934a58', '#b8646e', '#d88890')
  tooth  = @('#6e6248', '#a89a72', '#d8cca4', '#f6eed2')
  mouth  = @('#14040a', '#2c0a12', '#4a121c')
  tongue = @('#5a1a24', '#8a2e3a', '#b84a56')
  nose   = @('#6a3040', '#b8646e', '#f2a8a8')
  eye    = @('#8a0e0a', '#d8261a', '#ff5a2a', '#ffa060')
  ear    = @('#5a2834', '#8a4452', '#b8646e', '#e09098')
  study  = @('#3a3a44', '#54545e', '#70707a', '#8e8e98', '#acacb4')
}

$deg = [Math]::PI / 180
function MulM($A, $B) {
  $o = New-Object double[] 9
  for ($i = 0; $i -lt 3; $i++) { for ($j = 0; $j -lt 3; $j++) { $o[$i * 3 + $j] = $A[$i * 3] * $B[$j] + $A[$i * 3 + 1] * $B[3 + $j] + $A[$i * 3 + 2] * $B[6 + $j] } }
  , $o
}
function Mat([double]$rx, [double]$ry, [double]$rz) {
  $a = $rx * $deg; $b = $ry * $deg; $c = $rz * $deg
  $X = @(1, 0, 0, 0, [Math]::Cos($a), -[Math]::Sin($a), 0, [Math]::Sin($a), [Math]::Cos($a))
  $Y = @([Math]::Cos($b), 0, [Math]::Sin($b), 0, 1, 0, -[Math]::Sin($b), 0, [Math]::Cos($b))
  $Z = @([Math]::Cos($c), -[Math]::Sin($c), 0, [Math]::Sin($c), [Math]::Cos($c), 0, 0, 0, 1)
  MulM (MulM $Z $Y) $X
}
function MatVec($A, $v) { , @(($A[0] * $v[0] + $A[1] * $v[1] + $A[2] * $v[2]), ($A[3] * $v[0] + $A[4] * $v[1] + $A[5] * $v[2]), ($A[6] * $v[0] + $A[7] * $v[1] + $A[8] * $v[2])) }
function Mtv($A, $v) { , @(($A[0] * $v[0] + $A[3] * $v[1] + $A[6] * $v[2]), ($A[1] * $v[0] + $A[4] * $v[1] + $A[7] * $v[2]), ($A[2] * $v[0] + $A[5] * $v[1] + $A[8] * $v[2])) }
function Norm($v) { $l = [Math]::Sqrt($v[0] * $v[0] + $v[1] * $v[1] + $v[2] * $v[2]); , @(($v[0] / $l), ($v[1] / $l), ($v[2] / $l)) }
function Dot($a, $b) { $a[0] * $b[0] + $a[1] * $b[1] + $a[2] * $b[2] }

# Coordinates: y up, z towards the head, x sideways. lift brightens a part.
$parts = [Collections.Generic.List[object]]::new()
function PartM($c, $rad, $M, [string]$mat, [double]$lift = 0) { $parts.Add(@{ c = $c; rad = $rad; rot = $M; mat = $mat; lift = $lift }) }
function Ell($c, $rad, $rot, [string]$mat = 'fur', [double]$lift = 0) { PartM $c $rad (Mat $rot[0] $rot[1] $rot[2]) $mat $lift }
# Ellipsoid from point a to point b (a limb segment), radius r across.
function Limb($a, $b, [double]$r, [string]$mat = 'fur') {
  $dx = $a[0] - $b[0]; $dy = $a[1] - $b[1]; $dz = $a[2] - $b[2]
  $len = [Math]::Sqrt($dx * $dx + $dy * $dy + $dz * $dz)
  $ang = [Math]::Atan2($dz, $dy) / $deg; $roll = -[Math]::Atan2($dx, [Math]::Sqrt($dy * $dy + $dz * $dz)) / $deg
  Ell @((($a[0] + $b[0]) / 2), (($a[1] + $b[1]) / 2), (($a[2] + $b[2]) / 2)) @($r, ($len / 2 + $r * 0.3), $r) @($ang, 0, $roll) $mat
}
# Paw lying on the ground (or raised, with -Up) with three claws.
function Paw($p, [double]$yaw, [double]$len = 1.4, [switch]$Up) {
  if ($Up) {
    Ell $p @(0.95, 1.1, 0.6) @(-20, $yaw, 0) 'pink'
    for ($k = -1; $k -le 1; $k++) { Ell @(($p[0] + $k * 0.45), ($p[1] + 1.1), ($p[2] + 0.2)) @(0.17, 0.6, 0.17) @(-15, 0, ($k * 18)) 'tooth' }
  } else {
    Ell $p @(1.0, 0.5, $len) @(0, $yaw, 0) 'pink'
    $fw = Mat 0 $yaw 0; $tip = MatVec $fw @(0, 0, ($len - 0.1))
    for ($k = -1; $k -le 1; $k++) {
      $sd = MatVec $fw @(($k * 0.48), 0, 0)
      Ell @(($p[0] + $tip[0] + $sd[0]), 0.42, ($p[2] + $tip[2] + $sd[2])) @(0.17, 0.17, 0.55) @(0, ($yaw + $k * 18), 0) 'tooth'
    }
  }
}
# Head at $H facing +z, tilted down by $tilt degrees, turned by $turn, with
# the jaws open by $open (0..1) and scale $hs.
function HP($l, $rad, $rot, $mat, $lift = 0) {
  $w = MatVec $script:R @(($l[0] * $script:hs), ($l[1] * $script:hs), ($l[2] * $script:hs))
  PartM @(($script:H[0] + $w[0]), ($script:H[1] + $w[1]), ($script:H[2] + $w[2])) @(($rad[0] * $script:hs), ($rad[1] * $script:hs), ($rad[2] * $script:hs)) (MulM $script:R (Mat $rot[0] $rot[1] $rot[2])) $mat $lift
}
function Head($H, [double]$tilt, [double]$turn, [double]$open, [double]$hs) {
  $script:R = Mat $tilt $turn 0; $script:H = $H; $script:hs = $hs
  HP @(0, 0, 0) @(3.3, 2.9, 3.6) @(-10, 0, 0) 'fur' 0.05
  HP @(0, (0.4 + 0.3 * $open), 3.4) @(1.8, 1.3, 3.0) @((-26 - 12 * $open), 0, 0) 'fur' 0.08
  HP @(0, (-1.9 - 1.3 * $open), (2.8 - 0.3 * $open)) @(1.4, 0.8, 2.4) @((22 + 22 * $open), 0, 0) 'fur' -0.05
  if ($open -gt 0) {
    HP @(0, (-0.9 - 0.6 * $open), 3.1) @(1.45, (1.3 + 0.7 * $open), 2.2) @(0, 0, 0) 'mouth'
    HP @(0, (-1.7 - 0.9 * $open), 3.9) @(0.85, 0.35, 1.3) @(15, 0, 0) 'tongue'
  }
  HP @(0, (1.6 + 0.3 * $open), 6.3) @(0.72, 0.6, 0.6) @(0, 0, 0) 'nose'
  foreach ($s in -1, 1) {
    HP @(($s * 0.4), (-0.5 + 0.1 * $open), 6.0) @(0.38, 1.15, 0.3) @(-15, 0, 0) 'tooth'
    HP @(($s * 0.36), (-1.75 - 1.5 * $open), (5.0 - 0.5 * $open)) @(0.33, 0.9, 0.28) @((28 + 15 * $open), 0, 0) 'tooth'
    HP @(($s * 1.6), 1.2, 2.5) @(0.8, 0.66, 0.6) @(0, 0, 0) 'eye'
    HP @(($s * 1.7), 1.95, 2.3) @(0.95, 0.3, 0.6) @(0, 0, ($s * 24)) 'fur' -0.3
    HP @(($s * 2.6), 2.5, -1.0) @(1.55, 1.4, 0.42) @(-25, ($s * 32), 0) 'ear'
  }
}
# Tail through the given points, tapering from 0.7 to 0.25.
function Tail($pts, [double]$r0 = 0.7, [double]$r1 = 0.25) {
  $n = $pts.Count - 1
  for ($k = 0; $k -le 60; $k++) {
    $t = $k / 60.0 * $n; $i = [Math]::Min($n - 1, [int][Math]::Floor($t)); $f = $t - $i
    $a = $pts[$i]; $b = $pts[$i + 1]; $r = $r0 - ($r0 - $r1) * $k / 60.0
    Ell @(($a[0] + ($b[0] - $a[0]) * $f), ($a[1] + ($b[1] - $a[1]) * $f), ($a[2] + ($b[2] - $a[2]) * $f)) @($r, $r, $r) @(0, 0, 0) 'pink'
  }
}
# Raised hackles at points along the top of the back, leaning backwards.
function Hackles($spine, [double]$h = 1.0) {
  $rng = [Random]::new(12)
  foreach ($p in $spine) { foreach ($x in @(-1.3, 0, 1.3)) {
    $xx = $p[0] + $x + ($rng.NextDouble() - 0.5) * 0.7
    Ell @($xx, ($p[1] - 0.35 * [Math]::Abs($x)), $p[2]) @(0.45, ((0.8 + $rng.NextDouble() * 0.8) * $h), 0.42) @((-50 - $rng.Next(0, 20)), 0, ($xx * -8)) 'fur' (-0.05 + $rng.NextDouble() * 0.08)
  } }
}

# --- Poses. Each sets the camera ($yaw, $pitch) and adds the parts.
$occ0 = 0.75; $occH = 4.0
$buildPose = {
switch ($Pose) {
  'fauchen' {
    # Square to the viewer, shoulders hunched, head up with the jaws wide,
    # front legs planted wide apart, tail lashing up behind.
    $yaw = -16; $pitch = 12
    Ell @(0, 4.6, -3.0) @(4.6, 4.4, 5.8) @(-10, 0, 0)
    Ell @(0, 4.8, 1.8) @(4.0, 4.4, 3.4) @(0, 0, 0)
    foreach ($s in -1, 1) {
      Ell @(($s * 2.6), 6.6, 1.0) @(2.4, 2.2, 2.6) @(0, 0, 0)
      Ell @(($s * 3.4), 3.6, -6.0) @(2.4, 3.2, 3.4) @(0, 0, 0)
      Limb @(($s * 3.0), 4.2, 2.6) @(($s * 5.0), 0.8, 4.6) 1.0
      Paw @(($s * 5.3), 0.45, 5.3) ($s * 25)
      Paw @(($s * 4.4), 0.45, -3.4) ($s * 10) 1.8
    }
    Head @(0, 6.4, 5.4) -12 0 1.0 1.2
    Hackles @(@(0, 9.0, 0.5), @(0, 9.0, -1.0), @(0, 8.9, -2.5), @(0, 8.6, -4.0), @(0, 8.0, -5.5)) 1.1
    Tail @(@(0, 3.5, -8.8), @(1.5, 6, -10.5), @(3.5, 10, -10), @(5, 12.5, -8), @(4.5, 14, -6))
  }
  'sprung' {
    # Front three-quarter, rump high, chest and head low, front legs splayed,
    # about to spring at the viewer.
    $yaw = -38; $pitch = 14
    Ell @(0, 5.0, -2.5) @(4.4, 4.0, 6.0) @(16, 0, 0)
    Ell @(0, 3.4, 2.6) @(3.8, 3.2, 3.2) @(0, 0, 0)
    foreach ($s in -1, 1) {
      Ell @(($s * 3.2), 6.2, -6.5) @(2.4, 3.0, 3.2) @(0, 0, 0)
      Limb @(($s * 3.6), 5.0, -7.0) @(($s * 4.0), 0.8, -5.0) 1.1
      Paw @(($s * 4.1), 0.45, -4.4) ($s * 10) 1.8
      Limb @(($s * 2.8), 2.8, 2.8) @(($s * 5.0), 0.7, 5.4) 0.95
      Paw @(($s * 5.2), 0.45, 6.1) ($s * 30)
    }
    Head @(0, 2.9, 6.6) 14 0 0.75 1.15
    Hackles @(@(0, 8.6, -6.0), @(0, 8.4, -4.5), @(0, 7.9, -3.0), @(0, 7.2, -1.5), @(0, 6.4, 0)) 1.0
    Tail @(@(0, 6.5, -9.6), @(0.5, 8.5, -12), @(1.5, 11, -13), @(2.5, 13.5, -12))
  }
  'aufrecht' {
    # Reared up on the hind legs, front paws raised with the claws spread,
    # jaws open, tail curled on the ground.
    $yaw = -24; $pitch = 8
    Ell @(0, 3.8, -1.5) @(4.2, 3.8, 3.8) @(0, 0, 0)
    Ell @(0, 8.5, 0.3) @(3.8, 5.0, 3.4) @(-12, 0, 0)
    foreach ($s in -1, 1) {
      Ell @(($s * 3.2), 3.2, -1.0) @(2.6, 3.2, 3.4) @(0, 0, 0)
      Paw @(($s * 3.4), 0.45, 1.6) ($s * 15) 1.8
      Limb @(($s * 2.8), 10.2, 1.8) @(($s * 5.2), 12.0, 4.2) 0.85
      Paw @(($s * 5.6), 12.8, 4.8) ($s * 20) -Up
    }
    Head @(0, 13.6, 2.4) 6 0 1.0 1.1
    Tail @(@(0, 1.0, -4.5), @(2.5, 0.8, -7.0), @(5.5, 0.8, -7.0), @(7.5, 1.4, -5.0), @(8.0, 3.2, -3.0))
  }
  'schnappen' {
    # Body low and stretched towards the viewer, head thrust forward and down
    # at the hero with the jaws wide, front legs mid-stride.
    $yaw = -30; $pitch = 16
    Ell @(0, 3.8, -3.5) @(4.4, 3.6, 6.5) @(4, 0, 0)
    Ell @(0, 5.2, -5.0) @(3.6, 2.8, 4.0) @(0, 0, 0)
    Ell @(0, 3.6, 2.4) @(3.6, 3.2, 3.2) @(0, 0, 0)
    Ell @(0, 3.6, 5.0) @(2.6, 2.6, 2.8) @(0, 0, 0)
    Limb @(2.6, 3.0, 3.0) @(3.6, 0.7, 7.0) 0.95; Paw @(3.7, 0.45, 7.6) 20
    Limb @(-2.6, 3.0, 2.5) @(-3.4, 0.7, 1.4) 0.95; Paw @(-3.5, 0.45, 2.0) -15
    foreach ($s in -1, 1) {
      Ell @(($s * 3.2), 3.2, -7.0) @(2.4, 3.0, 3.2) @(0, 0, 0)
      Paw @(($s * 3.8), 0.45, -4.8) ($s * 10) 1.8
    }
    Head @(0, 3.4, 8.0) 10 0 1.0 1.25
    Hackles @(@(0, 7.8, -6.0), @(0, 7.9, -4.5), @(0, 7.6, -3.0), @(0, 7.0, -1.5)) 1.0
    Tail @(@(0, 3.0, -10), @(1, 2.0, -13), @(3, 2.5, -15), @(5, 4.5, -15), @(6, 7, -13))
  }
  'buckel' {
    # Back arched high with the fur standing up, head low between the
    # shoulders, teeth bared, legs stiff, tail raised.
    $yaw = -20; $pitch = 12
    Ell @(0, 5.5, -2.5) @(4.4, 4.6, 5.6) @(-5, 0, 0)
    Ell @(0, 8.0, -3.0) @(3.8, 3.4, 4.2) @(0, 0, 0)
    Ell @(0, 4.2, 2.0) @(3.8, 3.6, 3.0) @(0, 0, 0)
    foreach ($s in -1, 1) {
      Limb @(($s * 2.8), 3.6, 2.4) @(($s * 3.4), 0.7, 4.2) 0.95
      Paw @(($s * 3.5), 0.45, 4.8) ($s * 15)
      Limb @(($s * 3.2), 4.5, -6.0) @(($s * 3.6), 0.7, -5.0) 1.1
      Paw @(($s * 3.7), 0.45, -4.3) ($s * 10) 1.8
    }
    Head @(0, 3.8, 5.4) 14 0 0.6 1.15
    Hackles @(@(0, 10.6, -1.0), @(0, 11.2, -2.5), @(0, 11.2, -4.0), @(0, 10.6, -5.5), @(0, 9.6, -7.0), @(0, 8.8, 0.3)) 1.8
    Tail @(@(0, 5.0, -8.0), @(-1.5, 7.5, -10), @(-1, 10.5, -10.5), @(1, 12.5, -9))
  }
  'hocken' {
    # Hunched forward in near profile (the user's reference pose): head high
    # at the front, level with the shoulders, face turned to the viewer and
    # tipped down with the teeth bared; the back runs flat from the neck and
    # rounds down to a big haunch; one foreleg reaches forward under the chin;
    # the tail lies along the ground in front of the whole body.
    $yaw = -60; $pitch = 15; $turn = 40; $tilt = 15; $occ0 = 0.45; $occH = 7.0
    if ($CamYaw -ne 999) { $yaw = $CamYaw }; if ($HeadTurn -ne 999) { $turn = $HeadTurn }
    Ell @(0, 7.5, -2.0) @(4.6, 5.5, 6.5) @(0, 0, 0)
    Ell @(0, 10.4, 3.6) @(3.4, 2.8, 3.4) @(0, 0, 0)
    # Animation offsets (all zero for the still pose): breathing, head
    # forward/up, jaw, near foreleg reach, tail sway, whole body shift.
    $br = $A.breath; $hz = $A.headZ; $hy = $A.headY; $jaw = 0.5 + $A.jaw; $arm = $A.arm; $tw = $A.tail; $bz = $A.bodyZ
    Ell @(0, (7.5 + 0.15 * $br), (-2.0 + $bz)) @(4.6, (5.5 + 0.18 * $br), 6.5) @(0, 0, 0)
    Ell @(0, (10.4 + 0.2 * $br + 0.3 * $hy), (3.6 + $bz + 0.4 * $hz)) @(3.4, 2.8, 3.4) @(0, 0, 0)
    Ell @(0, 7.0, (1.0 + $bz + 0.3 * $hz)) @(3.4, 4.2, 2.6) @(0, 0, 0)
    foreach ($s in -1, 1) {
      Ell @(($s * 3.2), 5.0, (-4.5 + $bz * 0.5)) @(2.4, 4.2, 4.0) @(0, 0, 0) 'fur' 0.08
      Paw @(($s * 3.5), 0.45, -1.8) ($s * 10) 1.9
    }
    Limb @(-2.2, 5.0, (1.4 + $bz * 0.5)) @(-2.4, 0.7, 2.2) 0.9; Paw @(-2.5, 0.45, 2.8) -15
    # Near foreleg raised under the chin; $arm swipes it forward and down.
    Limb @(2.4, 7.4, (2.4 + $bz)) @(2.6, (7.0 - 0.8 * $arm), (4.6 + $bz + 1.6 * $arm)) 0.9
    Ell @(2.6, (6.9 - 0.8 * $arm), (5.2 + $bz + 1.6 * $arm)) @(0.9, 0.55, 1.0) @(0, 0, 0) 'pink'
    for ($k = -1; $k -le 1; $k++) { Ell @((2.6 + $k * 0.45), (6.5 - 0.8 * $arm), (5.9 + $bz + 1.6 * $arm)) @(0.17, 0.5, 0.17) @(30, 0, 0) 'tooth' }
    Head @(0, (11.3 + 0.2 * $br + $hy), (6.6 + $bz + $hz)) ($tilt + $A.tilt) $turn $jaw 1.0
    Hackles @(@(0, (13.2 + 0.3 * $br), (1.5 + $bz)), @(0, (13.3 + 0.3 * $br), (0 + $bz)), @(0, (13.2 + 0.3 * $br), (-1.5 + $bz)), @(0, (12.8 + 0.2 * $br), (-3.0 + $bz)), @(0, 12.0, (-4.5 + $bz))) (0.7 + $A.hackles)
    Tail @(@(1.0, 2.0, -8.5), @(4.0, 0.9, -9.6), @(7.0, 0.9, -7.0), @(8.0, 0.9, -2.0), @((7.8 + 0.4 * $tw), 0.9, 3.0), @((7.0 + 1.0 * $tw), 0.9, 8.0), @((6.0 + 1.8 * $tw), (0.8 + 0.6 * [Math]::Abs($tw)), 12.0)) 0.95 0.4
  }
  default { throw "Unbekannte Pose: $Pose" }
}

}

# --- Ray tracing in C# (PowerShell alone needs minutes per frame).
if (-not ('RatTracer' -as [type])) {
  Add-Type -TypeDefinition @'
public class RatTracer {
  int n; double[] c, rot, rad, ld, sd, a, sa;
  public void Load(double[] centres, double[] rots, double[] radii) {
    n = centres.Length / 3; c = centres; rot = rots; rad = radii;
    ld = new double[n * 3]; sd = new double[n * 3]; a = new double[n]; sa = new double[n];
  }
  // Ray direction and shadow direction in each part's unit-sphere space.
  public void Prep(double[] dw, double[] sw) {
    for (int i = 0; i < n; i++) {
      for (int k = 0; k < 3; k++) {
        ld[i * 3 + k] = (rot[i * 9 + k] * dw[0] + rot[i * 9 + 3 + k] * dw[1] + rot[i * 9 + 6 + k] * dw[2]) / rad[i * 3 + k];
        sd[i * 3 + k] = (rot[i * 9 + k] * sw[0] + rot[i * 9 + 3 + k] * sw[1] + rot[i * 9 + 6 + k] * sw[2]) / rad[i * 3 + k];
      }
      a[i] = ld[i * 3] * ld[i * 3] + ld[i * 3 + 1] * ld[i * 3 + 1] + ld[i * 3 + 2] * ld[i * 3 + 2];
      sa[i] = sd[i * 3] * sd[i * 3] + sd[i * 3 + 1] * sd[i * 3 + 1] + sd[i * 3 + 2] * sd[i * 3 + 2];
    }
  }
  // Nearest part hit from o along the prepared direction: index (or -1) and t.
  public int Trace(double ox, double oy, double oz, bool shadow, out double best) {
    best = 1e9; int hit = -1;
    for (int i = 0; i < n; i++) {
      double dx = ox - c[i * 3], dy = oy - c[i * 3 + 1], dz = oz - c[i * 3 + 2];
      double l0 = (rot[i * 9] * dx + rot[i * 9 + 3] * dy + rot[i * 9 + 6] * dz) / rad[i * 3];
      double l1 = (rot[i * 9 + 1] * dx + rot[i * 9 + 4] * dy + rot[i * 9 + 7] * dz) / rad[i * 3 + 1];
      double l2 = (rot[i * 9 + 2] * dx + rot[i * 9 + 5] * dy + rot[i * 9 + 8] * dz) / rad[i * 3 + 2];
      double[] d = shadow ? sd : ld; double aa = shadow ? sa[i] : a[i];
      double b = 2 * (l0 * d[i * 3] + l1 * d[i * 3 + 1] + l2 * d[i * 3 + 2]);
      double cc = l0 * l0 + l1 * l1 + l2 * l2 - 1;
      double disc = b * b - 4 * aa * cc;
      if (disc < 0) continue;
      double t = (-b - System.Math.Sqrt(disc)) / (2 * aa);
      if (t > 0.001 && t < best) { best = t; hit = i; if (shadow) return i; }
    }
    return hit;
  }
}
'@
}
$tracer = [RatTracer]::new()

$build = {
  $parts.Clear()
  . $buildPose
  $script:View = MulM (Mat $pitch 0 0) (Mat 0 $yaw 0)
  $script:Lw = Norm (Mtv $View (Norm @(-0.6, 0.75, 0.55)))
  $script:Rw = Norm (Mtv $View (Norm @(0.75, 0.35, -0.55)))
  $script:Vw = Norm (Mtv $View @(0, 0, 1))
  $script:Dw = Mtv $View @(0, 0, -1)
  $script:Hw = Norm @(($Lw[0] + $Vw[0]), ($Lw[1] + $Vw[1]), ($Lw[2] + $Vw[2]))
  $script:Sw = Norm @(($Lw[0] * 0.4), 1, ($Lw[2] * 0.4))
  $cs = [Collections.Generic.List[double]]::new(); $rs = [Collections.Generic.List[double]]::new(); $ds = [Collections.Generic.List[double]]::new()
  foreach ($p in $parts) { $cs.AddRange([double[]]$p.c); $rs.AddRange([double[]]$p.rot); $ds.AddRange([double[]]$p.rad) }
  $tracer.Load($cs.ToArray(), $rs.ToArray(), $ds.ToArray())
  $tracer.Prep([double[]]$Dw, [double[]]$Sw)
}
function Trace($o, [bool]$shadow = $false) {
  $bt = 0.0
  $i = $tracer.Trace($o[0], $o[1], $o[2], $shadow, [ref]$bt)
  if ($i -lt 0) { return $null }
  if ($shadow) { return $parts[$i] }
  $best = $parts[$i]
  $hit = @(($o[0] + $Dw[0] * $bt), ($o[1] + $Dw[1] * $bt), ($o[2] + $Dw[2] * $bt))
  $lp = Mtv $best.rot @(($hit[0] - $best.c[0]), ($hit[1] - $best.c[1]), ($hit[2] - $best.c[2]))
  $nl = @(($lp[0] / ($best.rad[0] * $best.rad[0])), ($lp[1] / ($best.rad[1] * $best.rad[1])), ($lp[2] / ($best.rad[2] * $best.rad[2])))
  @{ t = $bt; p = $best; hit = $hit; n = (Norm (MatVec $best.rot $nl)) }
}
function RayAt([double]$sx, [double]$sy) { , (Mtv $View @($sx, $sy, 200)) }
# Screen-space bounding box of the current parts.
function Bounds($bb) {
  for ($sy = -30.0; $sy -le 34; $sy += 1) { for ($sx = -34.0; $sx -le 34; $sx += 1) {
    if (Trace (RayAt $sx $sy)) { $bb[0] = [Math]::Min($bb[0], $sx); $bb[1] = [Math]::Max($bb[1], $sx); $bb[2] = [Math]::Min($bb[2], $sy); $bb[3] = [Math]::Max($bb[3], $sy) }
  } }
}

# Renders the current parts into a Size x Size bitmap with the fixed framing.
function Render {
  $col = New-Object 'object[,]' $Size, $Size; $dep = New-Object 'double[,]' $Size, $Size; $mat = New-Object 'string[,]' $Size, $Size
  for ($py = 0; $py -lt $Size; $py++) { for ($px = 0; $px -lt $Size; $px++) {
    $sx = $ox + ($px + 0.5 - $Size / 2) / $scale; $sy = $oy - ($py + 0.5 - $Size / 2) / $scale
    $ro = RayAt $sx $sy
    $h = Trace $ro
    if (-not $h) {
      if ($Dw[1] -lt 0) {
        $tg = -$ro[1] / $Dw[1]; $gp = @(($ro[0] + $Dw[0] * $tg), 0.01, ($ro[2] + $Dw[2] * $tg))
        if (Trace $gp $true) { $col[$px, $py] = [Drawing.Color]::FromArgb(110, 8, 6, 10) }
      }
      $dep[$px, $py] = 1e9; continue
    }
    $n = $h.n; $m = $h.p.mat
    $diff = [Math]::Max(0.0, (Dot $n $Lw)); $rim = [Math]::Pow([Math]::Max(0.0, (Dot $n $Rw)), 1.5) * [Math]::Pow(1 - [Math]::Max(0.0, (Dot $n $Vw)), 1.2)
    $occ = $occ0 + (1 - $occ0) * [Math]::Min(1.0, $h.hit[1] / $occH)
    $lum = (0.08 + 0.72 * $diff) * $occ + 0.5 * $rim + $h.p.lift
    if ($Study -and $m -ne 'eye') { $m = 'study' }
    if ($m -eq 'fur') { $lum += 0.07 + (([Math]::Sin($h.hit[0] * 9.1 + $h.hit[2] * 3.7) * [Math]::Sin($h.hit[1] * 7.3 - $h.hit[2] * 5.1)) * 0.05) }
    if ($m -eq 'eye') { $lum = 0.45 + 0.4 * $diff }
    $ramp = $ramps[$m]
    $idx = [int][Math]::Floor([Math]::Max(0.0, [Math]::Min(0.999, $lum)) * $ramp.Count)
    $c = [Drawing.ColorTranslator]::FromHtml($ramp[$idx])
    if (($m -eq 'eye' -or $m -eq 'nose') -and [Math]::Pow([Math]::Max(0.0, (Dot $n $Hw)), 24) -gt 0.45) { $c = [Drawing.ColorTranslator]::FromHtml('#fff4e8') }
    $col[$px, $py] = $c; $dep[$px, $py] = $h.t; $mat[$px, $py] = $h.p.mat
  } }
  # Outline round the figure, darker lines where a near part overlaps a far one.
  $edge = @(); $outl = @()
  for ($py = 0; $py -lt $Size; $py++) { for ($px = 0; $px -lt $Size; $px++) {
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
      $qx = $px + $d[0]; $qy = $py + $d[1]
      if ($qx -lt 0 -or $qy -lt 0 -or $qx -ge $Size -or $qy -ge $Size -or $dep[$qx, $qy] -ge 1e8) { continue }
      if ($dep[$px, $py] -ge 1e8) { $outl += , @($px, $py); break }
      if ($dep[$px, $py] - $dep[$qx, $qy] -gt 2.2 -and $mat[$px, $py] -ne 'mouth' -and $mat[$px, $py] -ne 'eye') { $edge += , @($px, $py); break }
    }
  } }
  foreach ($e in $edge) { $col[$e[0], $e[1]] = [Drawing.ColorTranslator]::FromHtml('#120c10') }
  foreach ($e in $outl) { $col[$e[0], $e[1]] = [Drawing.ColorTranslator]::FromHtml('#0c0a10') }
  $bmp = [Drawing.Bitmap]::new($Size, $Size)
  for ($py = 0; $py -lt $Size; $py++) { for ($px = 0; $px -lt $Size; $px++) { $cc = $col[$px, $py]; if ($cc) { $bmp.SetPixel($px, $py, $cc) } } }
  $bmp
}
# Framing from a screen-space box: figure centred, feet on the bottom edge.
function Frame($bb) {
  $script:scale = ($Size - 3) / ([Math]::Max($bb[1] - $bb[0], $bb[3] - $bb[2]) + 2.5)
  $script:ox = ($bb[0] + $bb[1]) / 2; $script:oy = $bb[2] - 0.5 + ($Size / 2 - 1.5) / $scale
}

# Animation curves for the hunched pose, 8 frames each: offsets for $A.
$zero = @{ breath = 0.0; headZ = 0.0; headY = 0.0; jaw = 0.0; arm = 0.0; tail = 0.0; bodyZ = 0.0; tilt = 0.0; hackles = 0.0 }
function Keys([string]$anim, [int]$f) {
  $k = $zero.Clone()
  switch ($anim) {
    'idle' {
      # Slow breathing, the tail tip twitching, the jaw working a little.
      $p = $f / 8.0 * 2 * [Math]::PI
      $k.breath = [Math]::Sin($p); $k.headY = 0.15 * [Math]::Sin($p); $k.tail = 0.7 * [Math]::Sin($p + 1.2)
      $k.jaw = 0.1 * (1 + [Math]::Sin(2 * $p)) / 2
    }
    'angriff' {
      # Rear back with the hackles up, then lunge and bite, swiping the paw.
      $t = @(
        @(0, 0, 0, 0, 0, 0, 0),
        @(-0.5, -0.5, 0.4, -10, 0.2, 0, 0.4),
        @(-0.8, -0.8, 0.6, -15, 0.5, 0, 0.6),
        @(0.7, 1.4, -0.7, 14, 0.6, 1.0, 0.6),
        @(0.9, 1.6, -0.9, 18, -0.4, 1.0, 0.4),
        @(0.6, 1.0, -0.5, 10, 0.1, 0.6, 0.2),
        @(0.2, 0.4, -0.2, 4, 0.0, 0.2, 0.0),
        @(0, 0, 0, 0, 0, 0, 0))[$f]
      $k.bodyZ = $t[0]; $k.headZ = $t[1]; $k.headY = $t[2]; $k.tilt = $t[3]; $k.jaw = $t[4]; $k.arm = $t[5]; $k.hackles = $t[6]
    }
    'treffer' {
      # Knocked back, head thrown up, jaws open, tail lashing, then recover.
      $t = @(
        @(0, 0, 0, 0, 0, 0),
        @(-0.9, -1.3, 0.8, -24, 0.5, 0.9),
        @(-1.1, -1.5, 0.9, -28, 0.5, -0.7),
        @(-0.8, -1.1, 0.6, -20, 0.4, 0.5),
        @(-0.5, -0.7, 0.4, -12, 0.3, -0.3),
        @(-0.3, -0.4, 0.2, -6, 0.2, 0.2),
        @(-0.1, -0.1, 0.05, -2, 0.1, 0),
        @(0, 0, 0, 0, 0, 0))[$f]
      $k.bodyZ = $t[0]; $k.headZ = $t[1]; $k.headY = $t[2]; $k.tilt = $t[3]; $k.jaw = $t[4]; $k.tail = $t[5]
    }
  }
  $k
}

if (-not $Anim) {
  $A = $zero.Clone(); . $build
  $bb = @(1e9, -1e9, 1e9, -1e9); Bounds $bb; Frame $bb
  $bmp = Render
  $name = if ($Study) { "rat_${Pose}_studie.png" } else { "rat_$Pose.png" }
  $bmp.Save((Join-Path $Out $name)); $bmp.Dispose()
  return
}

# Animation sheets: one framing for all frames of all animations, so the rat
# does not jump between them.
$anims = if ($Anim -eq 'alle') { @('idle', 'angriff', 'treffer') } else { @($Anim) }
$bb = @(1e9, -1e9, 1e9, -1e9)
foreach ($an in 'idle', 'angriff', 'treffer') { for ($f = 0; $f -lt 8; $f++) { $A = Keys $an $f; . $build; Bounds $bb } }
Frame $bb
New-Item -ItemType Directory -Force $Out | Out-Null
foreach ($an in $anims) {
  $strip = [Drawing.Bitmap]::new($Size * 8, $Size)
  $g = [Drawing.Graphics]::FromImage($strip)
  for ($f = 0; $f -lt 8; $f++) {
    $A = Keys $an $f; . $build
    $bmp = Render; $g.DrawImageUnscaled($bmp, $f * $Size, 0); $bmp.Dispose()
  }
  $g.Dispose()
  $strip.Save((Join-Path $Out "rat_$an.png")); $strip.Dispose()
}
