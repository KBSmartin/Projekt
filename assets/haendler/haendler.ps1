# The merchant, 32x32 pixel art: a figure in a black hooded robe, nothing of the
# face visible but two red eyes in the darkness of the hood. Light from the left.
# Three animations with 8 frames each, written as sprite sheets (frames side by
# side, 256x32) to ui/assets/haendler/:
#   idle     - breathing, robe hem swaying, eyes glowing up and down (loops)
#   gruss    - greets the adventurer: bows slightly and raises a bony hand
#   abschied - says goodbye: eyes narrow, an almost devilish grin opens in the
#              dark, the hand waves; the last frame is held
# Also writes uebersicht.png (all frames 6x) next to this script.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\haendler'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = [IO.Path]::GetFullPath($Out)
$N = 32

$pal = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($e in @(
    '0 #060408', '1 #100d16', '2 #1a1622', '3 #262030', '4 #362e44', '5 #4e4562',
    'k #000000', 'h #08060c',
    'r #3a0608', 'R #a81616', 'E #ff4a2a', 'W #ffd4a8',
    'm #6a0e12', 't #d8ccb0',
    's #6e6858', 'y #a49c88', 'z #2a2420')) {
  $pal[$e.Substring(0, 1)] = [Drawing.ColorTranslator]::FromHtml($e.Substring(2))
}

function NewGrid { $g = New-Object 'char[,]' $N, $N; for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $g[$x, $y] = '.' } }; , $g }
function Px($g, [double]$x, [double]$y, [char]$ch) { $xi = [int][Math]::Floor($x); $yi = [int][Math]::Floor($y); if ($xi -ge 0 -and $yi -ge 0 -and $xi -lt $N -and $yi -lt $N) { $g[$xi, $yi] = $ch } }
# Fills a polygon (pixel centres inside, even-odd rule).
function Poly($g, [double[]]$p, [char]$ch) {
  $np = $p.Count / 2
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) {
    $cx = $x + 0.5; $cy = $y + 0.5; $in = $false; $j = $np - 1
    for ($i = 0; $i -lt $np; $i++) {
      $xi = $p[2 * $i]; $yi = $p[2 * $i + 1]; $xj = $p[2 * $j]; $yj = $p[2 * $j + 1]
      if ((($yi -gt $cy) -ne ($yj -gt $cy)) -and ($cx -lt ($xj - $xi) * ($cy - $yi) / ($yj - $yi) + $xi)) { $in = -not $in }
      $j = $i
    }
    if ($in) { $g[$x, $y] = $ch }
  } }
}
function Ell($g, [double]$cx, [double]$cy, [double]$rx, [double]$ry, [char]$ch) {
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $u = ($x + 0.5 - $cx) / $rx; $v = ($y + 0.5 - $cy) / $ry; if ($u * $u + $v * $v -le 1) { $g[$x, $y] = $ch } } }
}
# Shades every placeholder 'B' row by row: lit on the left, dark on the right.
function ShadeCloth($g) {
  for ($y = 0; $y -lt $N; $y++) {
    $l = -1; $r = -1
    for ($x = 0; $x -lt $N; $x++) { if ($g[$x, $y] -eq 'B') { if ($l -lt 0) { $l = $x }; $r = $x } }
    if ($l -lt 0) { continue }
    for ($x = $l; $x -le $r; $x++) {
      if ($g[$x, $y] -ne 'B') { continue }
      $f = ($x - $l) / [Math]::Max(1, $r - $l)
      $g[$x, $y] = if ($x -eq $l) { '5' } elseif ($f -lt 0.3) { '4' } elseif ($f -lt 0.58) { '3' } elseif ($f -lt 0.84) { '2' } else { '1' }
    }
  }
}
function Outline($g) {
  $out = @()
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) {
    if ($g[$x, $y] -ne '.') { continue }
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
      $xx = $x + $d[0]; $yy = $y + $d[1]
      if ($xx -ge 0 -and $yy -ge 0 -and $xx -lt $N -and $yy -lt $N -and $g[$xx, $yy] -ne '.' -and $g[$xx, $yy] -ne '0') { $out += , @($x, $y); break }
    }
  } }
  foreach ($o in $out) { $g[$o[0], $o[1]] = '0' }
}
# Bony hand from a template, top left at (hx, hy): spread fingers with dark
# claw tips, thumb to the right; $tilt shifts the finger tips (wave).
$handRows = @('z.z.z.', 'y.y.y.', 'yyssss', 'ysss..', '.ss...')
function Hand($g, [int]$hx, [int]$hy, [int]$tilt) {
  for ($r = 0; $r -lt $handRows.Count; $r++) {
    $dx = if ($r -lt 2) { $tilt } else { 0 }
    for ($c = 0; $c -lt 6; $c++) { $ch = $handRows[$r][$c]; if ($ch -ne '.') { Px $g ($hx + $c + $dx) ($hy + $r) $ch } }
  }
}
# Sleeve as its own shape so the arm stands out from the robe: lit edge on the
# top and left, dark contour on the bottom and right, dark cuff opening.
function Sleeve($g, [double[]]$pts, [double]$cx, [double]$cy) {
  $m = NewGrid; Poly $m $pts 'A'
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) {
    if ($m[$x, $y] -ne 'A') { continue }
    $in = { param($a, $b) $a -ge 0 -and $b -ge 0 -and $a -lt $N -and $b -lt $N -and $m[$a, $b] -eq 'A' }
    $g[$x, $y] = if (-not (& $in ($x + 1) $y) -or -not (& $in $x ($y + 1))) { '0' } elseif (-not (& $in ($x - 1) $y) -or -not (& $in $x ($y - 1))) { '4' } elseif ((& $in ($x - 2) $y) -and (& $in ($x + 2) $y)) { '2' } else { '3' }
  } }
  Ell $g $cx $cy 1.7 1.0 'h'
}

# One frame. $bob/$bow move hood and eyes down, $sway moves the hem, $eyes is
# dim|norm|bright|slit, $grin 0..4, $raise 0..3 lifts the left hand, $wave tilts it.
function Frame([int]$bob, [int]$bow, [int]$sway, [string]$eyes, [int]$grin, [int]$raise, [int]$wave) {
  $g = NewGrid
  $o = $bob + $bow
  # Robe from the shoulders down, ragged hem that sways.
  Poly $g @(8, 15, 24, 15, 27, 22, (29 + $sway), 31, (3 + $sway), 31, 5, 22) 'B'
  for ($x = 2; $x -lt 31; $x++) { if ((($x + $sway) % 3) -eq 0) { Px $g $x 30.5 '.' } }
  # Hood: pointed tip falling back, wide around the shoulders.
  Poly $g @(14, (2 + $o), 18, (1 + $o), 21, (5 + $o), 23, (9 + $o), 24, (13 + $o), 25, (16 + $o), 7, (16 + $o), 8, (13 + $o), 9, (9 + $o), 11, (5 + $o)) 'B'
  ShadeCloth $g
  # Folds in the lower robe.
  foreach ($fx in 11, 16, 21) { for ($y = 23; $y -lt 31; $y++) { $xx = $fx + [int](($y - 23) * ($fx - 16) / 14.0) + [int]($sway * ($y - 23) / 8.0); if ($g[$xx, $y] -match '[2-5]') { $g[$xx, $y] = '1' } } }
  # Hood edge catching the light, and the dark opening.
  Ell $g 16 (11.5 + $o) 5 5.2 'h'
  Ell $g 16 (11.6 + $o) 4.2 4.4 'k'
  for ($y = 6; $y -lt 17; $y++) { $yy = $y + $o; foreach ($x in 10, 11) { if ($yy -lt $N -and $g[$x, $yy] -eq 'h') { $g[$x, $yy] = '4' } } }
  # Arms: the right one (viewer's right) always rests in front; the left one
  # either meets it (hands folded) or is raised with an open hand.
  Sleeve $g @(25, 16, 21, 16, 15.5, 21, 15.5, 24.5, 20, 24.5, 24.5, 21) 17.4 23
  if ($raise -eq 0) {
    Sleeve $g @(7, 16, 11, 16, 16.5, 21, 16.5, 24.5, 12, 24.5, 7.5, 21) 14.6 23
    Px $g 14 24 'y'; Px $g 15 24 's'; Px $g 16 24 'y'; Px $g 17 24 's'; Px $g 15 25 'z'; Px $g 17 25 'z'
  } else {
    Px $g 17 24 'y'; Px $g 18 24 's'; Px $g 18 25 'z'
    $hx = @(0, 10, 6, 4)[$raise] + [int]($wave * 0.5); $hy = @(0, 15, 11, 7)[$raise]
    Sleeve $g @(6, 17, 11.5, 18, ($hx + 5.5), ($hy + 7.5), ($hx - 0.5), ($hy + 6.5)) ($hx + 2.6) ($hy + 6.4)
    Hand $g $hx $hy $wave
  }
  # Eyes in the dark: a dim halo, then the glow.
  $ey = 11 + $o
  switch ($eyes) {
    'dim'    { foreach ($x in 13, 14, 18, 19) { Px $g $x $ey 'r' }; Px $g 14 $ey 'R'; Px $g 18 $ey 'R' }
    'norm'   { foreach ($x in 12, 15, 17, 20) { Px $g $x $ey 'r' }; Px $g 13 $ey 'R'; Px $g 14 $ey 'E'; Px $g 18 $ey 'E'; Px $g 19 $ey 'R' }
    'bright' { foreach ($p in @(@(13, -1), @(14, -1), @(18, -1), @(19, -1), @(13, 1), @(14, 1), @(18, 1), @(19, 1))) { Px $g $p[0] ($ey + $p[1]) 'r' }
               foreach ($x in 12, 15, 17, 20) { Px $g $x $ey 'R' }; Px $g 13 $ey 'E'; Px $g 14 $ey 'W'; Px $g 18 $ey 'W'; Px $g 19 $ey 'E' }
    'slit'   { Px $g 12 ($ey - 1) 'r'; Px $g 20 ($ey - 1) 'r'; Px $g 13 ($ey - 1) 'R'; Px $g 14 $ey 'E'; Px $g 15 $ey 'R'; Px $g 19 ($ey - 1) 'R'; Px $g 18 $ey 'E'; Px $g 17 $ey 'R' }
  }
  # The grin opens wider and wider, teeth glinting in a dull red glow.
  $gy = 14 + $o
  if ($grin -ge 1) { foreach ($x in 15, 16, 17) { Px $g $x $gy 'm' } }
  if ($grin -ge 2) { Px $g 14 $gy 'm'; Px $g 18 $gy 'm'; Px $g 13 ($gy - 1) 'm'; Px $g 19 ($gy - 1) 'm' }
  if ($grin -ge 3) { foreach ($x in 14, 16, 18) { Px $g $x $gy 't' }; Px $g 13 ($gy - 1) 'R'; Px $g 19 ($gy - 1) 'R' }
  if ($grin -ge 4) { Px $g 12 ($gy - 2) 'R'; Px $g 20 ($gy - 2) 'R'; Px $g 13 ($gy - 1) 'm'; Px $g 19 ($gy - 1) 'm'; foreach ($x in 15, 16, 17) { Px $g $x ($gy + 1) 'm' }; Px $g 16 ($gy + 1) 'r' }
  Outline $g
  , $g
}

$anims = [ordered]@{
  idle     = @(
    @(0, 0, 0, 'norm', 0, 0, 0), @(0, 0, 0, 'norm', 0, 0, 0), @(0, 0, 1, 'bright', 0, 0, 0), @(1, 0, 1, 'bright', 0, 0, 0),
    @(1, 0, 0, 'norm', 0, 0, 0), @(1, 0, 0, 'norm', 0, 0, 0), @(0, 0, -1, 'dim', 0, 0, 0), @(0, 0, -1, 'dim', 0, 0, 0))
  gruss    = @(
    @(0, 0, 0, 'norm', 0, 0, 0), @(0, 1, 0, 'bright', 0, 1, 0), @(0, 2, 0, 'bright', 0, 2, 0), @(0, 2, 1, 'bright', 0, 3, 0),
    @(0, 1, 1, 'bright', 0, 3, 0), @(0, 0, 0, 'norm', 0, 3, 0), @(0, 0, 0, 'norm', 0, 2, 0), @(0, 0, -1, 'norm', 0, 1, 0))
  abschied = @(
    @(0, 0, 0, 'norm', 0, 0, 0), @(0, 0, 0, 'norm', 1, 1, 0), @(0, 0, 0, 'slit', 2, 2, 0), @(0, 0, 1, 'slit', 3, 3, -1),
    @(0, 0, 1, 'slit', 4, 3, 1), @(0, 0, 0, 'slit', 4, 3, -1), @(0, 0, -1, 'slit', 4, 3, 1), @(0, 0, 0, 'slit', 4, 3, 0))
}

function ToBitmap($g) {
  $b = [Drawing.Bitmap]::new($N, $N)
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $ch = [string]$g[$x, $y]; if ($ch -ne '.') { $b.SetPixel($x, $y, $pal[$ch]) } } }
  $b
}
$sheets = [ordered]@{}
foreach ($name in $anims.Keys) {
  $sheet = [Drawing.Bitmap]::new($N * 8, $N)
  $sg = [Drawing.Graphics]::FromImage($sheet)
  for ($k = 0; $k -lt 8; $k++) {
    $f = $anims[$name][$k]
    $bmp = ToBitmap (Frame $f[0] $f[1] $f[2] $f[3] $f[4] $f[5] $f[6])
    $sg.DrawImageUnscaled($bmp, $k * $N, 0); $bmp.Dispose()
  }
  $sg.Dispose()
  $sheet.Save((Join-Path $Out "$name.png"))
  $sheets[$name] = $sheet
}
# Overview: every frame 6x on a dark background.
$S = 6
$ov = [Drawing.Bitmap]::new(8 * ($N * $S + 8) + 8, 3 * ($N * $S + 8) + 8)
$og = [Drawing.Graphics]::FromImage($ov)
$og.Clear([Drawing.ColorTranslator]::FromHtml('#1a1622')); $og.InterpolationMode = 'NearestNeighbor'; $og.PixelOffsetMode = 'Half'
$row = 0
foreach ($name in $sheets.Keys) {
  for ($k = 0; $k -lt 8; $k++) {
    $og.DrawImage($sheets[$name], [Drawing.Rectangle]::new(8 + $k * ($N * $S + 8), 8 + $row * ($N * $S + 8), $N * $S, $N * $S), [Drawing.Rectangle]::new($k * $N, 0, $N, $N), 'Pixel')
  }
  $row++
}
$ov.Save((Join-Path $PSScriptRoot 'uebersicht.png'))
$og.Dispose(); $ov.Dispose(); foreach ($s in $sheets.Values) { $s.Dispose() }
