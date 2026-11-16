# Pixel-art forest background, 320x180 (shown scaled up with nearest neighbour).
# Layers back to front: sky and fog, far pines, mid trunks and canopy, light rays,
# ground with path, big front trunks with roots, front canopy, mushrooms and ferns,
# vignette. Deterministic (fixed seed). Helper names avoid PowerShell's one-letter aliases.
param([string]$Out = (Join-Path $PSScriptRoot 'wald.png'), [int]$Seed = 7)
Add-Type -AssemblyName System.Drawing
$ImgW = 320; $ImgH = 180
$bmp = [Drawing.Bitmap]::new($ImgW, $ImgH)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'None'; $g.PixelOffsetMode = 'Half'; $g.InterpolationMode = 'NearestNeighbor'
$rng = [Random]::new($Seed)
function Clr($hex, $a = 255) { $c = [Drawing.ColorTranslator]::FromHtml($hex); [Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B) }
function Brs($hex, $a = 255) { [Drawing.SolidBrush]::new((Clr $hex $a)) }
function Rnd($a, $b) { $rng.Next($a, $b + 1) }
function Rect($hex, $x, $y, $w, $h, $a = 255) { $br = Brs $hex $a; $g.FillRectangle($br, $x, $y, $w, $h); $br.Dispose() }
function Ell($hex, $x, $y, $w, $h, $a = 255) { $br = Brs $hex $a; $g.FillEllipse($br, $x, $y, $w, $h); $br.Dispose() }
function Poly($hex, $pts, $a = 255) {
  $br = Brs $hex $a
  $p = for ($k = 0; $k -lt $pts.Count; $k += 2) { [Drawing.PointF]::new($pts[$k], $pts[$k + 1]) }
  $g.FillPolygon($br, [Drawing.PointF[]]$p); $br.Dispose()
}
# Leaf cluster: dark base, mid tone, a few lit dabs towards the top left.
function Foliage($x, $y, $r, $dark, $mid, $lite, $n = 9) {
  for ($k = 0; $k -lt $n; $k++) { $s = Rnd ([int]($r * 0.6)) $r; Ell $dark ($x + (Rnd (-$r) $r)) ($y + (Rnd ([int](-$r / 2)) ([int]($r / 2)))) $s ([int]($s * 0.7)) }
  for ($k = 0; $k -lt [int]($n * 0.7); $k++) { $s = Rnd ([int]($r * 0.4)) ([int]($r * 0.8)); Ell $mid ($x + (Rnd (-$r) ([int]($r / 2)))) ($y + (Rnd (-$r) 0)) $s ([int]($s * 0.6)) }
  for ($k = 0; $k -lt [int]($n * 0.4); $k++) { $s = Rnd 2 ([int]([Math]::Max(3, $r * 0.35))); Ell $lite ($x + (Rnd (-$r) 0)) ($y + (Rnd (-$r) ([int](-$r / 3)))) $s ([int]([Math]::Max(1, $s * 0.6))) }
}
# Trunk with bark stripes and a light edge on the left.
function Trunk($x, $top, $bottom, $w, $base, $dark, $lite, $roots) {
  Rect $base $x $top $w ($bottom - $top)
  for ($k = 0; $k -lt [int]($w / 3); $k++) { $bx = $x + (Rnd 1 ($w - 2)); $sy = $top + (Rnd 0 20); Rect $dark $bx $sy 1 ([Math]::Max(1, $bottom - $sy - (Rnd 4 30))) }
  Rect $lite $x $top ([Math]::Max(1, [int]($w / 6))) ($bottom - $top)
  Rect $dark ($x + $w - [Math]::Max(1, [int]($w / 5))) $top ([Math]::Max(1, [int]($w / 5))) ($bottom - $top)
  if ($roots) {
    Poly $base @(($x - $w * 0.6), $bottom, $x, ($bottom - $w * 0.9), ($x + $w * 0.3), $bottom)
    Poly $base @(($x + $w * 0.7), $bottom, ($x + $w), ($bottom - $w * 0.9), ($x + $w * 1.6), $bottom)
    Poly $dark @(($x + $w * 1.0), $bottom, ($x + $w), ($bottom - $w * 0.6), ($x + $w * 1.6), $bottom)
  }
}

# Sky: pale light in the middle, darker towards the edges.
for ($y = 0; $y -lt 120; $y++) {
  $t = $y / 120.0
  $r = [int](150 + 50 * $t); $gg = [int](178 + 30 * $t); $b = [int](170 + 20 * $t)
  $br = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($r, $gg, $b)); $g.FillRectangle($br, 0, $y, $ImgW, 1); $br.Dispose()
}
# Far pine silhouettes in fog, two rows.
foreach ($row in @(@{ y = 112; c = '#8fa49c'; h = 30 }, @{ y = 122; c = '#6f877e'; h = 38 })) {
  for ($x = -6; $x -lt $ImgW + 6; $x += (Rnd 5 9)) {
    $h = $row.h + (Rnd -8 10); $w = [int]($h * 0.32)
    Poly $row.c @($x, ($row.y - $h), ($x - $w), ($row.y + 4), ($x + $w), ($row.y + 4))
  }
  Rect $row.c 0 ($row.y + 2) $ImgW 30
}
# Mid trunks, faded by fog.
foreach ($t in @(@(40, 9), @(78, 7), @(112, 6), @(196, 6), @(228, 8), @(262, 9), @(140, 4), @(176, 4))) {
  Trunk $t[0] 30 140 $t[1] '#5e5a4c' '#4a473c' '#7a7562' $false
}
# Fog bands over the mid layer.
for ($fy = 90; $fy -lt 140; $fy++) { Rect '#c0ccc2' 0 $fy $ImgW 1 ([int](110 * [Math]::Sin(($fy - 90) / 50.0 * [Math]::PI))) }
# Mid canopy.
for ($k = 0; $k -lt 14; $k++) { Foliage (Rnd 20 300) (Rnd 18 52) (Rnd 14 22) '#2f4a33' '#3f6340' '#6a8f4c' 8 }
# Light rays from the top middle.
foreach ($ray in @(@(150, 118, 0.0), @(172, 100, 0.0), @(196, 128, 0.0), @(132, 86, 0.0))) {
  Poly '#f4f0c8' @($ray[0], 0, ($ray[0] + 14), 0, ($ray[1] + 22), 170, ($ray[1] - 6), 170) 34
}
# Ground.
Rect '#22351f' 0 138 $ImgW 42
for ($y = 138; $y -lt 180; $y++) { Rect '#2c4527' 0 $y $ImgW 1 ([int](80 * (1 - ($y - 138) / 42.0))) }
# Path towards the vanishing point.
Poly '#6b4a2c' @(150, 138, 170, 138, 205, 180, 115, 180)
Poly '#8a6236' @(154, 140, 166, 140, 190, 180, 130, 180)
for ($k = 0; $k -lt 40; $k++) { $py = Rnd 141 178; $half = 4 + ($py - 138) * 0.9; Rect '#a07440' (160 + (Rnd ([int](-$half)) ([int]$half))) $py (Rnd 1 3) 1 }
# Sunlit grass patches beside the path.
foreach ($p in @(@(118, 150, 26), @(190, 152, 28), @(96, 166, 22), @(214, 168, 24))) { Ell '#5f8a35' $p[0] $p[1] $p[2] 6 150 }
# Front trunks, big and dark, with roots.
Trunk 22 0 168 26 '#3f2c20' '#2a1c14' '#5e4430' $true
Trunk 274 0 170 28 '#3f2c20' '#2a1c14' '#5e4430' $true
Trunk 88 20 150 12 '#4a3626' '#33251a' '#6a4c34' $true
Trunk 226 18 152 13 '#4a3626' '#33251a' '#6a4c34' $true
# Front canopy along the top.
for ($k = 0; $k -lt 26; $k++) { Foliage (Rnd -10 330) (Rnd -8 22) (Rnd 16 28) '#16261a' '#24402a' '#3e6a38' 9 }
for ($k = 0; $k -lt 6; $k++) { Foliage (Rnd 120 200) (Rnd 2 18) (Rnd 10 16) '#2a4a2c' '#4f7a3c' '#a8c860' 7 }
# Ferns and grass blades.
for ($k = 0; $k -lt 70; $k++) {
  $x = Rnd 0 $ImgW; $y = Rnd 150 179; if ($x -gt 125 -and $x -lt 195) { continue }
  $col = @('#2f5a2a', '#3e7432', '#5c9a3e')[(Rnd 0 2)]
  $h = Rnd 3 9; for ($j = 0; $j -lt $h; $j++) { Rect $col ($x + [int]($j * ((Rnd -1 1) * 0.5))) ($y - $j) 1 1 }
}
# Mushrooms.
foreach ($m in @(@(70, 164), @(84, 170), @(238, 165), @(250, 171), @(132, 158))) {
  Rect '#e8dcc0' ($m[0] + 2) ($m[1] - 3) 2 4
  Ell '#c8602e' $m[0] ($m[1] - 7) 7 5
  Rect '#f0b080' ($m[0] + 1) ($m[1] - 6) 2 1
}
# Darken the whole scene a little and add a vignette so the UI stays readable.
Rect '#08100c' 0 0 $ImgW $ImgH 70
for ($k = 0; $k -lt 26; $k++) {
  $a = [int](110 * (1 - $k / 26.0))
  $br = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($a, 6, 10, 8))
  $g.FillRectangle($br, $k, 0, 1, $ImgH); $g.FillRectangle($br, $ImgW - 1 - $k, 0, 1, $ImgH)
  if ($k -lt 18) { $g.FillRectangle($br, 0, $ImgH - 1 - $k, $ImgW, 1) }
  $br.Dispose()
}
$g.Dispose()
$bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
