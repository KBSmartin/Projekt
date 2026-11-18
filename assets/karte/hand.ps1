# The hand that sets a piece on the board, as plain pixel art: back of the hand
# towards the viewer, the bare wrist leaving at the top (left once mirrored), index
# finger (left) and thumb (right) forming an oval and pinching the piece head,
# the middle finger curled behind the index. Few skin tones, dark outline.
# Writes ui/assets/karte/hand.png (28x28), mirrored. The pinch point (between the finger
# tips) is pixel (14.7, 24) after mirroring; the CSS places it on the piece head.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karte\hand.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$N = 28
$pal = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($e in @('0 #140c0c', 'k #ffd8b4', 'e #f2ae84', 'c #d8885e', 'n #a85238', '2 #241e2c', '3 #3a3246', '4 #50465e', 'l #c8a060', 'L #8a6a3a')) {
  $pal[$e.Substring(0, 1)] = [Drawing.ColorTranslator]::FromHtml($e.Substring(2))
}
$g = New-Object 'char[,]' $N, $N
for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $g[$x, $y] = '.' } }
function Px([double]$x, [double]$y, [char]$ch) { $xi = [int][Math]::Floor($x); $yi = [int][Math]::Floor($y); if ($xi -ge 0 -and $yi -ge 0 -and $xi -lt $N -and $yi -lt $N) { $g[$xi, $yi] = $ch } }
function Poly([double[]]$p, [char]$ch) {
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
function Ell([double]$cx, [double]$cy, [double]$rx, [double]$ry, [char]$ch) {
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $u = ($x + 0.5 - $cx) / $rx; $v = ($y + 0.5 - $cy) / $ry; if ($u * $u + $v * $v -le 1) { $g[$x, $y] = $ch } } }
}
# Thick stroke along a polyline: discs stamped along the path.
function Stroke([double[]]$p, [double]$r, [char]$ch) {
  for ($k = 0; $k -lt $p.Count - 2; $k += 2) {
    $len = [Math]::Max(1, [Math]::Sqrt([Math]::Pow($p[$k + 2] - $p[$k], 2) + [Math]::Pow($p[$k + 3] - $p[$k + 1], 2)))
    for ($s = 0; $s -le $len * 3; $s++) { $t = $s / ($len * 3); Ell ($p[$k] + ($p[$k + 2] - $p[$k]) * $t) ($p[$k + 1] + ($p[$k + 3] - $p[$k + 1]) * $t) $r $r $ch }
  }
}

# Each part gets its own dark outline (a wider stroke underneath), so fingers
# read separately where they overlap the hand, as in hand-drawn pixel art.
function Part([double[]]$p, [double]$r, [char]$fill) { Stroke $p ($r + 0.85) '0'; Stroke $p $r $fill }
# Just the wrist, ending in a rounded cut at the top right (no sleeve).
Part @(24.5, 2.2, 15.5, 9.5) 3.1 'e'
Stroke @(25.2, 3.2, 19.2, 8.0) 1.0 'c'
# Back of the hand.
Poly @(7.2, 6.4, 15.6, 3.6, 21.6, 9.0, 20.2, 15.6, 10.0, 16.8, 4.0, 12.4) '0'
Poly @(8, 7, 15.4, 4.6, 20.6, 9.2, 19.4, 14.8, 10.2, 15.8, 5, 12.2) 'e'
Poly @(17.6, 9.5, 20.6, 9.2, 19.4, 14.8, 14.5, 15.4) 'c'
Poly @(8.6, 7.6, 14.4, 5.6, 15.8, 6.8, 10.4, 9.0) 'k'
# Middle finger curled behind the index, darker.
Part @(6.8, 9.6, 4.8, 14.0, 6.2, 18.4, 8.6, 19.6) 1.45 'c'
# Index finger curving down to the left side of the pinch.
Part @(9.0, 10.0, 7.8, 15.0, 9.0, 20.0, 10.9, 23.4) 1.6 'e'
Stroke @(7.4, 13.0, 7.6, 17.0, 8.6, 20.6) 0.55 'c'
# Thumb coming down on the right.
Part @(18.2, 12.0, 18.2, 17.4, 17.0, 21.4, 15.6, 23.4) 1.6 'e'
Stroke @(19.2, 13.5, 19.0, 17.4, 17.9, 20.8) 0.55 'c'
# The oval between index finger and thumb stays open.
Ell 13.3 18.4 1.9 3.4 '.'
# Finger nails at the tips.
Px 10 23 'k'; Px 11 23 'k'; Px 15 23 'k'; Px 16 23 'k'

# Cut the wrist off with a straight edge across its direction.
$ex = 21.6; $ey = 4.6; $dx = 0.78; $dy = -0.63
for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { if ((($x + 0.5 - $ex) * $dx + ($y + 0.5 - $ey) * $dy) -gt 0) { $g[$x, $y] = '.' } } }

# Dark outline around everything, including the open oval.
$o = @()
for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) {
  if ($g[$x, $y] -ne '.') { continue }
  foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { $xx = $x + $d[0]; $yy = $y + $d[1]; if ($xx -ge 0 -and $yy -ge 0 -and $xx -lt $N -and $yy -lt $N -and $g[$xx, $yy] -ne '.' -and $g[$xx, $yy] -ne '0') { $o += , @($x, $y); break } }
} }
foreach ($p in $o) { $g[$p[0], $p[1]] = '0' }
$bmp = [Drawing.Bitmap]::new($N, $N)
for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $ch = [string]$g[$x, $y]; if ($ch -ne '.') { $bmp.SetPixel($x, $y, $pal[$ch]) } } }
# Drawn reaching in from the right, saved mirrored so it comes from the left.
$bmp.RotateFlip([Drawing.RotateFlipType]::RotateNoneFlipX)
$bmp.Save([IO.Path]::GetFullPath($Out)); $bmp.Dispose()
