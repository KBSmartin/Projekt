# Game emblem without the name (the name is not settled yet), 64x64, shown 4x.
# Every part is a layer of filled shapes, bevelled and outlined like the logo
# letters (logo.ps1). Chosen: 5, the broken shield. -Final renders it at 64, 32
# and 16 pixels into ui/assets/logo (start screen, favicon) and writes the
# program icon launcher/zeichen.ico (16, 32, 48 = 16 x 3, 256 = 64 x 4).
# -Variant 1..5 are the drafts:
#   1 siegel   round seal of the three regions, a sword behind it
#   2 karte    a card pierced by a sword
#   3 landkarte torn map with a path and a compass star
#   4 tor      stone arch, through it the three lands one behind the other
#   5 scherben shield broken into three shards, one per region
# Writes <Out>/zeichen_<n>.png.
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [int[]]$Variant = @(1, 2, 3, 4, 5), [switch]$Final)
$zOut = [IO.Path]::GetFullPath($Out); $zVariant = $Variant; $zFinal = $Final.IsPresent
. (Join-Path $PSScriptRoot 'logo.ps1') -Variant @()
# Shapes are given on a 64 grid; $script:K scales them to the size rendered.
$N = 64; $script:SS = 4; $script:K = 1.0
$sym = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\ui\assets\symbole'))

# Mask from shapes drawn by $draw into a GraphicsPath, in pixel units; what
# $minus draws is cut out again.
function Get-Mask([scriptblock]$draw, [scriptblock]$minus = $null) {
  $m = [Drawing.Drawing2D.Matrix]::new(); $m.Scale([single]($script:SS * $script:K), [single]($script:SS * $script:K))
  $b = [Drawing.Bitmap]::new($N * $script:SS, $N * $script:SS); $g = [Drawing.Graphics]::FromImage($b); $g.CompositingMode = 'SourceCopy'
  foreach ($part in @(@($draw, [Drawing.Color]::White), @($minus, [Drawing.Color]::Transparent))) {
    if (-not $part[0]) { continue }
    $p = [Drawing.Drawing2D.GraphicsPath]::new(); $p.FillMode = 'Winding'; & $part[0] $p; $p.Transform($m)
    $g.FillPath([Drawing.SolidBrush]::new($part[1]), $p)
  }
  $g.Dispose()
  $d = $b.LockBits([Drawing.Rectangle]::new(0, 0, $b.Width, $b.Height), 'ReadOnly', 'Format32bppArgb'); $raw = [int[]]::new($b.Width * $b.Height); [Runtime.InteropServices.Marshal]::Copy($d.Scan0, $raw, 0, $raw.Length); $b.UnlockBits($d); $b.Dispose()
  $mask = [bool[]]::new($N * $N)
  for ($y = 0; $y -lt $N; $y++) { for ($x = 0; $x -lt $N; $x++) { $cnt = 0; for ($j = 0; $j -lt $script:SS; $j++) { $o = ($y * $script:SS + $j) * $N * $script:SS + $x * $script:SS; for ($i = 0; $i -lt $script:SS; $i++) { if ($raw[$o + $i] -ne 0) { $cnt++ } } }; if ($cnt -ge 8) { $mask[$y * $N + $x] = $true } } }
  , $mask
}
# Shades a layer and lays it over $img (only its own pixels).
function Add-Layer([int[]]$img, [scriptblock]$draw, $ramp, [double]$bevel = 2, [int]$depth = 1, [string]$side = '#1a1010', [int]$mode = 0, [scriptblock]$minus = $null) {
  $mask = Get-Mask $draw $minus; $px = [int[]]::new($N * $N)
  [LogoFx]::Letters($px, $mask, $N, $N, @(, $ramp), $mode, [Math]::Max(0.9, $bevel * $script:K), [Math]::Max([Math]::Min(1, $depth), [int][Math]::Round($depth * $script:K)), (C '#0c0a10'), (C $side), 7)
  for ($i = 0; $i -lt $px.Length; $i++) { if ($px[$i] -ne 0) { $img[$i] = $px[$i] } }
}
function Poly($p, [double[]]$xy) { $p.AddPolygon([Drawing.PointF[]]@(for ($i = 0; $i -lt $xy.Count; $i += 2) { [Drawing.PointF]::new($xy[$i], $xy[$i + 1]) })) }
# Pixel symbol from ui/assets/symbole, scaled k times, centred on (cx, cy).
function Add-Icon([int[]]$img, [string]$name, [int]$cx, [int]$cy, [int]$k = 2) {
  $b = [Drawing.Bitmap]::FromFile((Join-Path $sym "$name.png")); $w = $b.Width * $k
  for ($y = 0; $y -lt $w; $y++) { for ($x = 0; $x -lt $w; $x++) { $c = $b.GetPixel([int][Math]::Floor($x / $k), [int][Math]::Floor($y / $k)); $tx = $cx - $w / 2 + $x; $ty = $cy - $w / 2 + $y; if ($c.A -gt 128 -and $tx -ge 0 -and $ty -ge 0 -and $tx -lt $N -and $ty -lt $N) { $img[$ty * $N + $tx] = $c.ToArgb() } } }
  $b.Dispose()
}
function Set-Px([int[]]$img, [int]$x, [int]$y, [string]$c) { if ($x -ge 0 -and $y -ge 0 -and $x -lt $N -and $y -lt $N) { $img[$y * $N + $x] = C $c } }
# Sword along the y axis, turned by $a degrees about (cx, cy): pommel, grip, guard, blade.
function Add-Sword([int[]]$img, [double]$cx, [double]$cy, [double]$a, [double]$len = 50, [double]$top = -25) {
  $t = { param($p, $xy) $m = [Drawing.Drawing2D.Matrix]::new(); $m.RotateAt($a, [Drawing.PointF]::new($cx, $cy)); $pts = [Drawing.PointF[]]@(for ($i = 0; $i -lt $xy.Count; $i += 2) { [Drawing.PointF]::new($cx + $xy[$i], $cy + $xy[$i + 1]) }); $m.TransformPoints($pts); $p.AddPolygon($pts) }
  $g0 = $top + 9
  Add-Layer $img { param($p) & $t $p @(-2.6, ($g0 + 1), 2.6, ($g0 + 1), 2.6, ($top + $len - 6), 0, ($top + $len), -2.6, ($top + $len - 6)) } $steel 1.4 1 '#1c2434'
  Add-Layer $img { param($p) & $t $p @(-1.6, ($top + 3), 1.6, ($top + 3), 1.6, ($g0 - 1), -1.6, ($g0 - 1)) } (Ramp '#1c0c10', '#4c1c20', '#80302c', '#b05040') 1 0
  Add-Layer $img { param($p) & $t $p @(-9, ($g0 - 1.6), 9, ($g0 - 1.6), 10.4, $g0, 9, ($g0 + 1.8), -9, ($g0 + 1.8), -10.4, $g0); & $t $p @(-2.6, ($top - 0.4), 2.6, ($top - 0.4), 3.2, ($top + 2.4), 0, ($top + 4.4), -3.2, ($top + 2.4)) } $gold 1.2 1 '#4c2408'
}
$ember = Ramp '#3a1410', '#7c2c1c', '#c05a26', '#f0a040', '#ffe08a'; $forestR = Ramp '#0c1e10', '#1c3c1c', '#346428', '#5c9438', '#a0cc58'; $iceR = Ramp '#16284c', '#2a5590', '#4a8cc8', '#8ac8ec', '#e8faff'
$stone = Ramp '#16151c', '#33313a', '#57535a', '#85807c', '#bdb6a4'; $paper = Ramp '#4a3420', '#8a6a44', '#c4a474', '#e8d4a4', '#fff4d4'; $wine = Ramp '#20060c', '#4c1018', '#7c2028', '#a83c38'

$draft = [ordered]@{}
$draft["1"] = { $img = [int[]]::new($N * $N)
  # Two crossed swords behind a smaller seal.
  Add-Sword $img 32 33 135 60 -28; Add-Sword $img 32 33 -135 60 -28
  Add-Layer $img { param($p) $p.AddEllipse(14, 14, 36, 36) } $gold 2.2 2 '#4c2408'
  foreach ($q in @(150, $forestR), @(270, $iceR), @(30, $ember)) { $a0 = $q[0]; Add-Layer $img { param($p) $p.AddPie(17.6, 17.6, 28.8, 28.8, $a0, 120) } $q[1] 1.6 0 }
  Add-Icon $img 'forest' 25 28; Add-Icon $img 'fortress' 39 28; Add-Icon $img 'desert' 32 40
  Add-Layer $img { param($p) foreach ($a in 270, 30, 150) { $r = $a * [Math]::PI / 180; $c = [Math]::Cos($r); $s = [Math]::Sin($r); Poly $p @((32 + 1.1 * $s), (32 - 1.1 * $c), (32 + 15.4 * $c + 1.1 * $s), (32 + 15.4 * $s - 1.1 * $c), (32 + 15.4 * $c - 1.1 * $s), (32 + 15.4 * $s + 1.1 * $c), (32 - 1.1 * $s), (32 + 1.1 * $c)) }; $p.AddEllipse(28.5, 28.5, 7, 7) } $gold 1 0
  Add-Layer $img { param($p) $p.AddEllipse(30, 30, 4, 4) } (Ramp '#3a0414', '#80081c', '#c81c2c', '#f85848', '#ffc0a0') 1.4 0
  $img }
$draft["2"] = { $img = [int[]]::new($N * $N)
  $card = { param($p, [double]$e) $m = [Drawing.Drawing2D.Matrix]::new(); $m.RotateAt(-10, [Drawing.PointF]::new(30, 34)); $pts = [Drawing.PointF[]]@([Drawing.PointF]::new(14 + $e, 12 + $e), [Drawing.PointF]::new(46 - $e, 12 + $e), [Drawing.PointF]::new(46 - $e, 56 - $e), [Drawing.PointF]::new(14 + $e, 56 - $e)); $m.TransformPoints($pts); $p.AddPolygon($pts) }
  Add-Layer $img { param($p) & $card $p 0 } $gold 2 3 '#4c2408'
  Add-Layer $img { param($p) & $card $p 3.4 } $wine 1.6 0
  Add-Icon $img 'forest' 23 27; Add-Icon $img 'fortress' 37 25; Add-Icon $img 'desert' 31 41
  # The sword runs in at the top right and out at the bottom left.
  Add-Sword $img 33 31 48 60 -32
  $img }
$draft["3"] = { $img = [int[]]::new($N * $N)
  Add-Layer $img { param($p) Poly $p @(6, 14, 12, 11, 19, 13, 26, 9, 33, 12, 41, 10, 48, 13, 55, 11, 57, 18, 54, 26, 58, 33, 55, 41, 57, 49, 51, 52, 43, 50, 36, 54, 28, 51, 20, 54, 13, 51, 7, 53, 9, 45, 5, 37, 8, 29, 5, 21) } $paper 2.4 2 '#3a2414'
  # Dotted path from the forest over the desert to the fortress, the goal marked.
  $path = @(14, 44, 17, 41, 20, 39, 24, 38, 27, 36, 29, 33, 32, 31, 35, 30, 38, 28, 40, 25, 43, 23)
  for ($i = 0; $i -lt $path.Count; $i += 2) { Set-Px $img $path[$i] $path[$i + 1] '#6a3a1c'; Set-Px $img ($path[$i] + 1) $path[$i + 1] '#6a3a1c' }
  Add-Icon $img 'forest' 13 46 1; Add-Icon $img 'desert' 30 41 1; Add-Icon $img 'fortress' 47 20 1
  foreach ($d in -2, -1, 0, 1, 2) { Set-Px $img (47 + $d) (28 + $d) '#a01818'; Set-Px $img (47 + $d) (28 - $d) '#a01818' }
  # Compass star over the lower right corner.
  Add-Layer $img { param($p) Poly $p @(49, 38, 51, 45, 58, 47, 51, 49, 49, 57, 47, 49, 40, 47, 47, 45) } $gold 1.4 1 '#4c2408'
  Add-Layer $img { param($p) $p.AddEllipse(47.4, 45.4, 3.4, 3.4) } (Ramp '#3a0414', '#80081c', '#c81c2c', '#f85848') 1 0
  $img }
$draft["4"] = { $img = [int[]]::new($N * $N)
  # Sky, then far snowy peaks, dunes, forest in front: one land behind the other.
  for ($y = 12; $y -lt 54; $y++) { for ($x = 14; $x -lt 50; $x++) {
    $c = if ($y -lt 26) { @('#1c1430', '#2c1c44', '#48284c', '#7c3c44')[[int][Math]::Min(3, [Math]::Floor(($y - 12) / 3.6))] } else { '#7c3c44' }
    $pk = [Math]::Min(19 + [Math]::Abs($x - 25) * 1.3, 24 + [Math]::Abs($x - 41) * 1.1)
    if ($y -ge $pk) { $c = if ($y -lt $pk + 3) { '#e8faff' } elseif ((($x + $y) % 4) -eq 0) { '#4a8cc8' } else { '#2a5590' } }
    $du = 39 + 2.4 * [Math]::Sin($x * 0.3)
    if ($y -ge $du) { $c = if ($y -lt $du + 1.5) { '#f0a040' } else { '#c05a26' } }
    $tr = 48 - 4 * [Math]::Max(0.0, 1 - [Math]::Abs((($x % 5) - 2) / 2.5)) - (($x * 7) % 3)
    if ($y -ge $tr) { $c = if ((($x + $y) % 3) -eq 0) { '#5c9438' } else { '#1c3c1c' } }
    if ($y -ge 50) { $c = '#2c2018' }
    $img[$y * $N + $x] = C $c } }
  Set-Px $img 22 15 '#fff4d4'; Set-Px $img 41 18 '#fff4d4'; Set-Px $img 33 14 '#c8b8e8'
  Add-Layer $img { param($p) $p.AddRectangle([Drawing.RectangleF]::new(5, 22, 54, 34)); $p.AddEllipse(5, 3, 54, 40) } $stone 2.6 2 '#0c0c12' 2 { param($p) $p.AddRectangle([Drawing.RectangleF]::new(14, 23, 36, 33)); $p.AddEllipse(14, 11, 36, 26) }
  # Block seams in the arch.
  foreach ($a in 200, 235, 270, 305, 340) { $r = $a * [Math]::PI / 180; for ($k = 18; $k -le 26; $k++) { Set-Px $img ([int](32 + $k * [Math]::Cos($r))) ([int](23 + $k * [Math]::Sin($r))) '#16151c' } }
  foreach ($y in 31, 40, 49) { foreach ($x in @(6..12) + @(52..57)) { Set-Px $img $x $y '#16151c' } }
  Add-Layer $img { param($p) $p.AddRectangle([Drawing.RectangleF]::new(2, 55, 60, 6)) } $stone 1.4 1 '#0c0c12'
  Add-Layer $img { param($p) Poly $p @(28.5, 2, 35.5, 2, 37, 6, 32, 12, 27, 6) } (Ramp '#3a0414', '#80081c', '#c81c2c', '#f85848', '#ffc0a0') 1.4 1
  $img }
$draft["5"] = { $img = [int[]]::new($N * $N)
  # Heater shield, split at (32, 30) into three shards that drift apart.
  $shield = @(@(9, 9), @(20, 6), @(32, 5), @(44, 6), @(55, 9), @(55, 30), @(50, 45), @(32, 59), @(14, 45), @(9, 30))
  $cut = @(@(@(-1, -1), @(31, -1), @(29, 12), @(33, 18), @(29, 25), @(32, 31), @(23, 33), @(16, 37), @(-1, 40)), @(@(31, -1), @(65, -1), @(65, 40), @(48, 36), @(40, 33), @(32, 31), @(29, 25), @(33, 18), @(29, 12)), @(@(-1, 40), @(16, 37), @(23, 33), @(32, 31), @(40, 33), @(48, 36), @(65, 40), @(65, 65), @(-1, 65)))
  $shift = @(@(-2.6, -1.6), @(2.6, -1.6), @(0, 2.6)); $ramps = @($forestR, $iceR, $ember); $icons = @('forest', 'fortress', 'desert'); $at = @(@(19, 21), @(44, 21), @(32, 45))
  for ($k = 0; $k -lt 3; $k++) {
    $sx = $shift[$k][0]; $sy = $shift[$k][1]; $poly = $cut[$k]
    $clip = { param($p, [double]$inset) $r = [Drawing.Region]::new(); $sp = [Drawing.Drawing2D.GraphicsPath]::new(); $c = 32; $cy = 33; $sp.AddPolygon([Drawing.PointF[]]@($shield | ForEach-Object { [Drawing.PointF]::new($c + ($_[0] - $c) * (1 - $inset) + $sx, $cy + ($_[1] - $cy) * (1 - $inset) + $sy) })); $cp = [Drawing.Drawing2D.GraphicsPath]::new(); $cp.AddPolygon([Drawing.PointF[]]@($poly | ForEach-Object { [Drawing.PointF]::new($_[0] + $sx, $_[1] + $sy) })); $r = [Drawing.Region]::new($sp); $r.Intersect($cp); $bm = [Drawing.Bitmap]::new(1, 1); $gg = [Drawing.Graphics]::FromImage($bm); foreach ($rc in $r.GetRegionScans([Drawing.Drawing2D.Matrix]::new())) { $p.AddRectangle($rc) }; $gg.Dispose(); $bm.Dispose() }
    Add-Layer $img { param($p) & $clip $p 0 } $gold 2.2 2 '#4c2408'
    Add-Layer $img { param($p) & $clip $p ([Math]::Max(0.17, 1.3 / (23 * $script:K))) } $ramps[$k] 1.8 0
    if ($script:K -ge 1) { Add-Icon $img $icons[$k] ($at[$k][0] + [int]$sx) ($at[$k][1] + [int]$sy) }
    elseif ($script:K -ge 0.5) { Add-Icon $img $icons[$k] ([int](($at[$k][0] + $sx) * $script:K)) ([int](($at[$k][1] + $sy) * $script:K)) 1 }
  }
  $img }
if ($zFinal) {
  $dir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\ui\assets\logo')); New-Item -ItemType Directory -Force $dir | Out-Null
  $png = @{}
  foreach ($size in 64, 32, 16) {
    $N = $size; $script:K = $size / 64.0; $b = To-Bitmap (& $draft['5']) $size $size; $b.Save((Join-Path $dir "zeichen_$size.png"))
    $png[$size] = $b
  }
  # Program icon: PNG images in an .ico, the large ones scaled up whole-numbered.
  $images = foreach ($q in @(16, 16, 1), @(32, 32, 1), @(48, 16, 3), @(256, 64, 4)) {
    $src = $png[$q[1]]; $b = [Drawing.Bitmap]::new($q[0], $q[0]); $g = [Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'; $g.DrawImage($src, 0, 0, $q[0], $q[0]); $g.Dispose()
    $ms = [IO.MemoryStream]::new(); $b.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); , @($q[0], $ms.ToArray())
  }
  $ico = [IO.MemoryStream]::new(); $w = [IO.BinaryWriter]::new($ico)
  $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$images.Count); $off = 6 + 16 * $images.Count
  foreach ($im in $images) { $s = $im[0] % 256; $w.Write([byte]$s); $w.Write([byte]$s); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$im[1].Length); $w.Write([uint32]$off); $off += $im[1].Length }
  foreach ($im in $images) { $w.Write([byte[]]$im[1]) }
  $w.Flush(); [IO.File]::WriteAllBytes([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\launcher\zeichen.ico')), $ico.ToArray())
  return
}
New-Item -ItemType Directory -Force $zOut | Out-Null
foreach ($dv in $zVariant) { $img = & $draft["$dv"]; (To-Bitmap $img 64 64).Save((Join-Path $zOut "zeichen_$dv.png")) }
