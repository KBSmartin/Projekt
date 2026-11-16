# Pixel-art forest background, 320x180: a misty fir forest at dusk with a stream
# winding out of the distance, mossy rune stones in the clearing and two ancient
# trunks framing the scene. Back to front: sky with a pale sun, three rows of firs
# separated by fog, ground and stream, stones, front trunks with branches and
# hanging moss, canopy along the top, ferns, glowing mushrooms, grass.
# Also writes the matching glow layer (stream glints, runes, mushrooms) for the
# animation. Deterministic (fixed seed).
param(
  [string]$Out = (Join-Path $PSScriptRoot 'wald.png'),
  [string]$Glow = (Join-Path $PSScriptRoot '..\..\ui\assets\hintergrund\fx\wald_glanz.png'),
  [int]$Seed = 11
)
. (Join-Path $PSScriptRoot 'pixel.ps1')
$glints = [Collections.Generic.List[object]]::new()

function Mix([string]$c0, [string]$c1, [double]$t) {
  $p = Clr $c0; $q = Clr $c1
  '#{0:x2}{1:x2}{2:x2}' -f [int]($p.R + ($q.R - $p.R) * $t), [int]($p.G + ($q.G - $p.G) * $t), [int]($p.B + ($q.B - $p.B) * $t)
}
# Fir drawn row by row: stacked tiers, each widening downwards, rough needle edge,
# lit pixels on the left.
function Fir([int]$x, [int]$base, [int]$h, [int]$w, [string]$col, [string]$lite) {
  $tiers = [Math]::Max(3, [int]($h / 11)); $th = $h / $tiers; $top = $base - $h
  for ($r = 0; $r -lt $h; $r++) {
    $ti = [Math]::Floor($r / $th); $loc = ($r - $ti * $th) / $th
    $half = [int](($w / 2) * (0.25 + 0.75 * ($ti + 1) / $tiers) * (0.35 + 0.65 * $loc))
    if ($loc -gt 0.55) { $half += Rnd 0 1 }
    if ($r -lt 2) { $half = 0 }
    Rect $col ($x - $half) ($top + $r) (2 * $half + 1) 1
    # Needle tips at the bottom of each tier catch the light (left half only).
    if ($lite -and $half -gt 1 -and $loc -gt 0.8) { Rect $lite ($x - $half) ($top + $r) ([Math]::Max(1, [int]($half * 0.6))) 1 }
  }
  Rect $col $x ($base - 1) 1 4
}
function FirRow([int]$base, [int]$hMin, [int]$hMax, [double]$ratio, [string]$col, [string]$lite, [int]$gapL, [int]$gapR, [int]$stepMin, [int]$stepMax) {
  for ($x = -8; $x -lt $ImgW + 8; $x += (Rnd $stepMin $stepMax)) {
    if ($x -gt $gapL -and $x -lt $gapR) { continue }
    $h = Rnd $hMin $hMax
    Fir $x ($base + (Rnd 0 3)) $h ([int]($h * $ratio)) $col $lite
  }
}
function FogBand([int]$y0, [int]$y1, [string]$col, [int]$amax) {
  for ($y = $y0; $y -le $y1; $y++) { Rect $col 0 $y $ImgW 1 ([int]($amax * [Math]::Sin(($y - $y0) / [double]($y1 - $y0) * [Math]::PI))) }
}
# Clump of leaves: dark base, mid tone, a few lit dabs top left.
function Blob([int]$x, [int]$y, [int]$r, [int]$n = 7) {
  for ($k = 0; $k -lt $n; $k++) { $s = Rnd ([int]($r * 0.7)) $r; Ell '#0a140e' ($x + (Rnd (-$r) $r) - $s / 2) ($y + (Rnd (-[int]($r / 2)) ([int]($r / 2))) - $s / 3) $s ([int]($s * 0.7)) }
  for ($k = 0; $k -lt [int]($n * 0.6); $k++) { $s = Rnd ([int]($r * 0.4)) ([int]($r * 0.7)); Ell '#15261a' ($x + (Rnd (-$r) ([int]($r / 3))) - $s / 2) ($y + (Rnd (-[int]($r / 2)) 0) - $s / 3) $s ([int]($s * 0.6)) }
  for ($k = 0; $k -lt [int]($n * 0.3); $k++) { $s = Rnd 2 4; Ell '#26402a' ($x + (Rnd (-$r) 0)) ($y + (Rnd (-[int]($r / 2)) 0)) $s ([Math]::Max(1, [int]($s * 0.6))) }
}
# Ancient trunk at the screen edge. $side -1 = left edge, 1 = right edge. Widens
# towards the roots, bark cracks, lit edge, moss patches.
function BigTree([int]$side, [int]$w0) {
  $cracks = for ($k = 0; $k -lt 6; $k++) { @{ f = 0.15 + $k * 0.13 + (Rnd 0 6) / 100.0; p = (Rnd 0 60) / 10.0 } }
  for ($y = 0; $y -lt 174; $y++) {
    $w = $w0 + [int]([Math]::Max(0, $y - 140) * [Math]::Max(0, $y - 140) / 70.0) + [int](1.5 * [Math]::Sin($y * 0.09))
    $xl = if ($side -lt 0) { -2 } else { $ImgW + 2 - $w }
    Rect '#2a1e17' $xl $y $w 1
    foreach ($c in $cracks) { Rect '#140e0a' ($xl + [int]($c.f * $w + 1.4 * [Math]::Sin($y * 0.15 + $c.p))) $y 1 1 }
    $inner = if ($side -lt 0) { $xl + $w } else { $xl }
    # Light comes from the clearing: the inner edge is lit, the outer side in shadow.
    if ($side -lt 0) { Rect '#4a3828' ($inner - 3) $y 2 1; Rect '#5e4834' ($inner - 1) $y 1 1 } else { Rect '#4a3828' ($inner + 1) $y 2 1; Rect '#5e4834' $inner $y 1 1 }
  }
  for ($k = 0; $k -lt 7; $k++) {
    $my = Rnd 20 160; $mw = Rnd 4 10; $mx = if ($side -lt 0) { Rnd 2 ($w0 - 6) } else { $ImgW - (Rnd 4 ($w0 - 2)) }
    Ell '#2c4626' $mx $my $mw ([int]($mw * 0.6)) 200; Rect '#466a34' ($mx + 1) $my ([Math]::Max(1, [int]($mw / 3))) 1 170
  }
  # Knot hole.
  $kx = if ($side -lt 0) { 12 } else { $ImgW - 18 }
  Ell '#0a0706' $kx 82 6 9; Rect '#4a3828' ($kx + 1) 81 4 1
}
# Branch from a trunk into the scene, thinning out, with moss strands hanging off it.
function Branch([double[]]$pts, [int]$thick) {
  for ($k = 0; $k -lt $pts.Count - 2; $k += 2) {
    $t = $k / [double]($pts.Count - 2); $th = [Math]::Max(1, [int]($thick * (1 - $t * 0.8)))
    Line '#24190f' $pts[$k] $pts[$k + 1] $pts[$k + 2] $pts[$k + 3] $th
    Line '#4a3828' $pts[$k] ($pts[$k + 1] - $th / 2) $pts[$k + 2] ($pts[$k + 3] - $th / 2) 1
  }
  for ($k = 0; $k -lt $pts.Count - 2; $k += 2) {
    for ($j = 0; $j -lt 3; $j++) {
      $u = (Rnd 0 100) / 100.0
      $sx = [int]($pts[$k] + ($pts[$k + 2] - $pts[$k]) * $u); $sy = [int]($pts[$k + 1] + ($pts[$k + 3] - $pts[$k + 1]) * $u) + 1
      $len = Rnd 5 16
      for ($s = 0; $s -lt $len; $s++) { Rect '#3a5a30' ($sx + [int]([Math]::Sin($s * 0.5 + $sx) * 0.8)) ($sy + $s) 1 1 ([int](220 * (1 - $s / [double]$len) + 30)) }
    }
  }
}
function Fern([int]$x, [int]$y, [int]$size, [string]$col, [string]$lite) {
  foreach ($a in @(0.35, 0.8, 1.25, 1.65, 2.05, 2.5, 2.8)) {
    $len = [int]($size * (0.7 + 0.3 * [Math]::Sin($a)))
    for ($t = 0; $t -lt $len; $t++) {
      $px = $x + [Math]::Cos($a) * $t; $py = $y - [Math]::Sin($a) * $t + $t * $t * 0.045
      Rect $col ([int]$px) ([int]$py) 1 1
      if ($t % 2 -eq 0 -and $t -gt 1) { Rect $col ([int]$px) ([int]$py + 1) 1 1; Rect $col ([int]$px - 1) ([int]$py) 1 1 }
      if ($t % 3 -eq 1 -and $a -lt 1.6) { Rect $lite ([int]$px) ([int]$py - 1) 1 1 }
    }
  }
}
function Mushroom([int]$x, [int]$y, [int]$s) {
  Rect '#b8c0b0' ($x + [int]($s / 2) - 1) ($y - $s) 2 $s
  Ell '#2a8a9a' $x ($y - $s - [int]($s * 0.6)) ($s * 2) ([Math]::Max(3, [int]($s * 1.1)))
  Rect '#7af0f0' ($x + 1) ($y - $s - [int]($s * 0.5)) ([Math]::Max(1, [int]($s / 2))) 1
  $glints.Add(@('halo', ($x + $s), ($y - $s), $s))
}

# --- Sky: deep teal at the top, pale green glow on the horizon.
Gradient '#08141a' '#1c3a3c' 0 60
Gradient '#1c3a3c' '#6e927e' 61 108
Gradient '#6e927e' '#46645a' 109 179
# Pale misty sun low behind the trees.
Ell '#c8dcb8' 172 52 40 40 26; Ell '#d8e8c4' 180 60 24 24 70; Ell '#eef4d8' 185 65 14 14 170
# --- Three rows of firs, fog in between; the middle opens towards the clearing.
FirRow 108 18 30 0.42 '#5a7a6e' $null -999 -999 4 7
FogBand 92 116 '#9ab8a4' 120
FirRow 118 30 46 0.40 '#38564c' '#46665a' 150 182 5 8
FogBand 104 128 '#86a494' 110
Gradient '#3a5448' '#26382e' 122 134
Gradient '#26382e' '#121c16' 135 179
# Undergrowth along the far edge of the clearing breaks up the horizon line.
for ($x = -4; $x -lt $ImgW + 4; $x += (Rnd 3 6)) { $bw = Rnd 6 12; Ell '#2c4238' ($x - $bw / 2) (121 + (Rnd 0 3)) $bw (Rnd 3 6); Rect '#4a665a' ($x - 1) (122 + (Rnd 0 2)) 2 1 }
# --- Stream, widening towards the viewer.
for ($y = 123; $y -lt 180; $y++) {
  $t = ($y - 123) / 56.0
  $cx = 166 + 12 * [Math]::Sin($t * 3.4) - 14 * $t
  $half = 1.5 + $t * $t * 28 + $t * 4
  $xl = [int]($cx - $half); $wd = [int](2 * $half) + 1
  Rect '#0c1410' ($xl - 1) $y ($wd + 2) 1
  Rect (Mix '#8aac98' '#2a4844' $t) $xl $y $wd 1
  if ($y % 3 -eq 0) { $gx = $xl + (Rnd 0 ([Math]::Max(0, $wd - 4))); $gl = Rnd 1 ([Math]::Max(1, [int]($half / 2))); Rect (Mix '#c8e0c8' '#6a9488' $t) $gx $y $gl 1; $glints.Add(@('glint', $gx, $y, $gl)) }
}
# Grass tufts on the near ground.
for ($k = 0; $k -lt 160; $k++) {
  $gx = Rnd 0 319; $gy = Rnd 128 176; $col = @('#1e3426', '#2a4630', '#36563a', '#44683e')[(Rnd 0 3)]
  Rect $col $gx $gy 1 (Rnd 1 3); if ((Rnd 0 2) -eq 0) { Rect $col ($gx + 1) ($gy + 1) 1 2 }
}
# Moss carpet patches and a few small bushes on the clearing.
foreach ($mp in @(@(84, 140, 30), @(222, 142, 34), @(100, 156, 26), @(196, 160, 30))) { Ell '#2e4a30' $mp[0] $mp[1] $mp[2] 5 170; Ell '#3e6038' ($mp[0] + 4) $mp[1] ([int]($mp[2] / 2)) 2 150 }
# Front row of firs at the sides, leaving the clearing open.
FirRow 136 48 68 0.42 '#1a2e28' '#28423a' 112 214 7 11
FogBand 122 150 '#7a988a' 70
# --- Rune stones in the clearing.
foreach ($st in @(@(120, 150, 8, 18), @(206, 154, 10, 24), @(222, 152, 6, 12))) {
  $sx = $st[0]; $sb = $st[1]; $sw = $st[2]; $sh = $st[3]
  Ell '#0a120e' ($sx - 3) ($sb - 2) ($sw + 6) 4 160
  Poly '#3a4440' @($sx, $sb, ($sx + 1), ($sb - $sh + 2), ($sx + 3), ($sb - $sh), ($sx + $sw - 2), ($sb - $sh + 1), ($sx + $sw), ($sb - $sh + 4), ($sx + $sw), $sb)
  Rect '#56625a' ($sx + 1) ($sb - $sh + 3) 1 ($sh - 4); Rect '#26302c' ($sx + $sw - 2) ($sb - $sh + 5) 2 ($sh - 5)
  Rect '#3e5a32' ($sx + 2) ($sb - $sh + 1) ([int]($sw / 2)) 1; Rect '#3e5a32' ($sx + $sw - 3) ($sb - 4) 2 3
  # Rune: a vertical stroke with two ticks; drawn dark here, the glow layer lights it.
  $rx = $sx + [int]($sw / 2); $ry = $sb - $sh + 5
  foreach ($p in @(@(0, 0), @(0, 1), @(0, 2), @(0, 3), @(0, 4), @(1, 1), @(-1, 3))) { if ($sh -ge 14 -or $p[1] -lt 3) { Rect '#1e4a40' ($rx + $p[0]) ($ry + $p[1]) 1 1; $glints.Add(@('rune', ($rx + $p[0]), ($ry + $p[1]), 1)) } }
}
# --- Front trunks, branches with moss, canopy along the top.
BigTree (-1) 30
BigTree 1 32
Branch @(26, 52, 50, 44, 76, 38, 102, 30, 118, 28) 6
Branch @(292, 40, 266, 34, 240, 30, 218, 24) 5
Branch @(28, 112, 44, 106, 58, 104) 3
for ($x = -12; $x -lt $ImgW + 12; $x += 9) {
  $edge = [Math]::Min($x, $ImgW - $x)
  $depth = if ($edge -lt 60) { 18 } elseif ($edge -lt 120) { 9 } else { 4 }
  Blob $x ((Rnd (-6) 0) + [int]($depth / 3)) ([int]($depth / 2) + 8) 6
}
foreach ($tip in @(@(116, 24), @(104, 28), @(220, 20), @(232, 26), @(12, 30), @(306, 28))) { Blob $tip[0] $tip[1] 9 6 }
# Roots spreading into the ground.
foreach ($rt in @(@(30, 170, 60, 176), @(24, 166, 46, 158), @(290, 168, 258, 176), @(294, 162, 272, 156))) {
  Line '#24190f' $rt[0] $rt[1] $rt[2] $rt[3] 4; Line '#4a3828' $rt[0] ($rt[1] - 2) $rt[2] ($rt[3] - 2) 1
}
# --- Foreground: rocks, ferns, mushrooms, grass silhouettes.
foreach ($rk in @(@(70, 168, 14, 8), @(242, 170, 16, 9), @(100, 174, 9, 5))) {
  Ell '#2a3230' $rk[0] $rk[1] $rk[2] $rk[3]; Ell '#3e4844' ($rk[0] + 2) ($rk[1] + 1) ([int]($rk[2] / 2)) 2; Rect '#2e4a26' ($rk[0] + 3) $rk[1] ([int]($rk[2] / 2)) 1
}
Fern 54 174 22 '#1e3a22' '#4a7a40'
Fern 92 178 15 '#1a3220' '#3e6a3a'
Fern 266 174 23 '#1e3a22' '#4a7a40'
Fern 230 178 14 '#1a3220' '#3e6a3a'
Mushroom 40 168 4; Mushroom 49 171 3; Mushroom 64 166 2
Mushroom 276 169 4; Mushroom 266 172 3; Mushroom 118 172 2
for ($x = 0; $x -lt $ImgW; $x += 2) { $gh = Rnd 2 7; if ($x -gt 130 -and $x -lt 200) { $gh = Rnd 1 3 }; Rect '#060c08' $x (180 - $gh) 1 $gh }
Finish $Out 4 10 8

# --- Glow layer for the animation, aligned 1:1 with the background.
$bmp = [Drawing.Bitmap]::new($ImgW, $ImgH)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'None'; $g.PixelOffsetMode = 'Half'
foreach ($gl in $glints) {
  switch ($gl[0]) {
    'glint' { Rect '#e8fff0' $gl[1] $gl[2] $gl[3] 1 200 }
    'rune' { Rect '#8affd8' $gl[1] $gl[2] 1 1 255; Rect '#8affd8' ($gl[1] - 1) $gl[2] 3 1 60; Rect '#8affd8' $gl[1] ($gl[2] - 1) 1 3 60 }
    'halo' { Ell '#6ae8f0' ($gl[1] - $gl[3] * 2) ($gl[2] - $gl[3] * 2) ($gl[3] * 4) ($gl[3] * 3) 50; Rect '#c8ffff' ($gl[1] - 1) ($gl[2] - $gl[3]) 2 1 200 }
  }
}
New-Item -ItemType Directory -Force (Split-Path $Glow) | Out-Null
$g.Dispose(); $bmp.Save([IO.Path]::GetFullPath($Glow), [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
