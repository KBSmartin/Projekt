# Game logo "Verlorene Lande": own letter shapes (polygons), bevelled and
# snapped to pixels. -Variant 1..5 are the drafts to choose from:
#   1 lande   letters of the three regions (moss, embers, ice)
#   2 schwert gold letters, a sword between the lines
#   3 wappen  steel letters under a shield with the three regions
#   4 karten  bone letters in front of three fanned cards
#   5         letters of 1 with the sword of 2
# Writes <Out>/logo_<variant>.png.
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [int[]]$Variant = @(1, 2, 3, 4, 5))
. (Join-Path $PSScriptRoot '..\gegner\sdf.ps1')
$Out = [IO.Path]::GetFullPath($Out)
if (-not ('LogoFx' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
public static class LogoFx {
  static double H(int x, int y, int w) { uint h = (uint)(x*374761393 + y*668265263 + w*974711); h = (h ^ (h >> 13)) * 1274126177u; return ((h ^ (h >> 16)) & 0xffff) / 65535.0; }
  static double Vn(double x, double y, int w) { int ix = (int)Math.Floor(x), iy = (int)Math.Floor(y); double u = x-ix, v = y-iy; u = u*u*(3-2*u); v = v*v*(3-2*v); return (H(ix,iy,w)*(1-u)+H(ix+1,iy,w)*u)*(1-v) + (H(ix,iy+1,w)*(1-u)+H(ix+1,iy+1,w)*u)*v; }
  static double Seam(double x, double y, int w) { int ix = (int)Math.Floor(x), iy = (int)Math.Floor(y); double f1 = 9, f2 = 9; for (int i = -1; i <= 1; i++) for (int j = -1; j <= 1; j++) { double dx = ix+i+H(ix+i,iy+j,w)-x, dy = iy+j+H(ix+i,iy+j,w+1)-y, d = Math.Sqrt(dx*dx+dy*dy); if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d; } return f2-f1; }
  // m: mask, ramps[k][tone]; mode 0 one ramp, 1 three ramps from left to right
  // (moss, embers with glowing seams in ramp 3, ice), 2 one ramp with scratches.
  public static void Letters(int[] px, bool[] m, int W, int Ht, int[][] ramps, int mode, double bevel, int depth, int line, int side, int seed) {
    double[] d = new double[W*Ht]; int R = (int)Math.Ceiling(bevel)+1;
    for (int y = 0; y < Ht; y++) for (int x = 0; x < W; x++) { if (!m[y*W+x]) continue; double best = R; for (int j = -R; j <= R; j++) for (int i = -R; i <= R; i++) { int a = x+i, b = y+j; bool s = a >= 0 && b >= 0 && a < W && b < Ht && m[b*W+a]; if (!s) best = Math.Min(best, Math.Sqrt(i*i+j*j)); } d[y*W+x] = Math.Min(best, bevel); }
    int[] res = new int[W*Ht];
    for (int y = 0; y < Ht; y++) for (int x = 0; x < W; x++) { int I = y*W+x; if (!m[I]) continue;
      double gx = 0, gy = 0; for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) { int a = Math.Min(W-1, Math.Max(0, x+i)), b = Math.Min(Ht-1, Math.Max(0, y+j)); gx += i*d[b*W+a]; gy += j*d[b*W+a]; }
      gx /= 6; gy /= 6; double l = 0.56 - 0.34*(-gx*0.6 - gy*0.8) ; l = 0.56 + 0.36*(gx*0.6 + gy*0.8);
      if (d[I] >= bevel) l = 0.60;
      l += 0.10*(Vn(x*0.35, y*0.35, seed)-0.5);
      int[] r = ramps[0];
      if (mode == 1) {
        double t = (double)x/W*3 + 0.34*(Vn(x*0.12, y*0.16, seed+2)-0.5)*2 + 0.16*(H(x,y,seed+4)-0.5);
        int k = t < 1 ? 0 : t < 2 ? 1 : 2; r = ramps[k];
        double sm = Seam(x/7.0, y/7.0, seed+6);
        if (k == 1 && sm < 0.13) { r = ramps[3]; l = 0.4 + 0.5*Vn(x*0.2, y*0.2, seed+8); }
        else if (k == 0 && Vn(x*0.22, y*0.3, seed+9) > 0.52 + 0.0*y) { r = ramps[4]; l += 0.1*(H(x,y,seed+5)-0.3); }
        else if (k == 2 && sm < 0.10) l += 0.25; else if (sm < 0.10) l -= 0.16;
      } else if (mode == 2 && H(x/3, y, seed+3) > 0.93) l -= 0.14;
      l = Math.Max(0, Math.Min(0.999, l)); res[I] = r[(int)(l*r.Length)];
    }
    // Thickness below, then the outline round everything.
    bool[] ext = (bool[])m.Clone(); int[] low = new int[W*Ht];
    for (int k = 1; k <= depth; k++) for (int y = Ht-1; y >= k; y--) for (int x = 0; x < W; x++) if (m[(y-k)*W+x] && !m[y*W+x]) { ext[y*W+x] = true; low[y*W+x] = side; }
    for (int y = 0; y < Ht; y++) for (int x = 0; x < W; x++) { int I = y*W+x;
      if (m[I]) { px[I] = res[I]; continue; } if (ext[I]) { px[I] = low[I]; continue; }
      bool e = false; for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) { int a = x+i, b = y+j; if (a >= 0 && b >= 0 && a < W && b < Ht && ext[b*W+a]) e = true; }
      if (e) px[I] = line; }
  }
}
'@
}
function C([string]$h) { [Drawing.ColorTranslator]::FromHtml($h).ToArgb() }
function Ramp([string[]]$h) { , [int[]]@($h | ForEach-Object { C $_ }) }

# --- letters: polygons on a grid 24 high; holes are extra polygons (alternate fill)
# Flared serif stem from x to x+w.
function Stem([double]$x, [double]$w) { , @(($x - 2), 0, ($x + $w + 2), 0, ($x + $w), 3, ($x + $w), 21, ($x + $w + 2), 24, ($x - 2), 24, $x, 21, $x, 3) }
$glyphs = @{
  V = @{ w = 22; p = @(, @(0, 0, 9, 0, 7.6, 2.4, 11.6, 15.5, 15.4, 2.4, 14, 0, 22, 0, 19.6, 3, 12.4, 24, 9.6, 24, 2.4, 3)) }
  E = @{ w = 16; p = @((Stem 2 5), @(6, 0, 15, 0, 15.6, 5.6, 12.6, 3.6, 6, 3.6), @(6, 10, 11, 10, 13, 8, 13, 15.4, 11, 13.4, 6, 13.4), @(6, 20.4, 12.8, 20.4, 16, 17.6, 15.2, 24, 6, 24)) }
  R = @{ w = 19; p = @((Stem 2 5), @(6, 0, 12, 0, 17, 3, 17, 9, 13.4, 12.6, 6, 13.6, 6, 10.4, 11, 9.6, 12.2, 8, 12.2, 5, 10.6, 3.4, 6, 3.4), @(7.4, 12.6, 12.6, 11.6, 16.4, 20, 19.6, 22.2, 18.4, 24, 13.6, 24)) }
  L = @{ w = 16; p = @((Stem 2 5), @(6, 20.2, 12.4, 20.2, 15.8, 16.4, 15.2, 24, 6, 24)) }
  O = @{ w = 21; p = @(@(10.5, -0.6, 17.6, 4, 20.6, 12, 17.6, 20, 10.5, 24.6, 3.4, 20, 0.4, 12, 3.4, 4), @(10.5, 4.2, 13.6, 7, 15, 12, 13.6, 17, 10.5, 19.8, 7.4, 17, 6, 12, 7.4, 7)) }
  N = @{ w = 22; p = @((Stem 2 4), (Stem 16 4), @(0, 0, 6.6, 0, 18, 18, 18, 24, 15.4, 24, 5, 7, 2.6, 4)) }
  A = @{ w = 22; p = @(@(9.4, -0.6, 12.8, -0.6, 20, 20.6, 22, 24, 13, 24, 14.8, 21.6, 13.8, 18, 8.0, 18, 6.8, 21.6, 8.4, 24, 0, 24, 2.2, 20.6), @(10.9, 6.6, 8.9, 14.8, 12.9, 14.8)) }
  D = @{ w = 20; p = @((Stem 2 5), @(6, 0, 12, 0, 18, 4.4, 19.6, 12, 18, 19.6, 12, 24, 6, 24, 6, 20.4, 10.8, 20.4, 13.6, 17.4, 14.6, 12, 13.6, 6.6, 10.8, 3.6, 6, 3.6)) }
}
function TextWidth([string]$t, [double]$k, [double]$gap) { $w = 0.0; foreach ($ch in $t.ToCharArray()) { $w += $glyphs["$ch"].w * $k + $gap }; $w - $gap }
# Adds the word to the mask (supersampled 4x, half coverage counts).
function Add-Word([bool[]]$mask, [int]$W, [int]$H, [string]$t, [double]$x0, [double]$y0, [double]$k, [double]$gap) {
  $q = 4; $b = [Drawing.Bitmap]::new($W * $q, $H * $q); $g = [Drawing.Graphics]::FromImage($b); $x = $x0
  foreach ($ch in $t.ToCharArray()) {
    $gl = $glyphs["$ch"]
    $path = [Drawing.Drawing2D.GraphicsPath]::new(); $path.FillMode = if ("$ch" -in 'O', 'A') { 'Alternate' } else { 'Winding' }
    foreach ($p in $gl.p) { $pts = [Drawing.PointF[]]@(for ($i = 0; $i -lt $p.Count; $i += 2) { [Drawing.PointF]::new(($x + $p[$i] * $k) * $q, ($y0 + $p[$i + 1] * $k) * $q) }); if ("$ch" -in 'O', 'A') { $path.AddPolygon($pts) } else { $g.FillPolygon([Drawing.Brushes]::White, $pts) } }
    if ("$ch" -in 'O', 'A') { $g.FillPath([Drawing.Brushes]::White, $path) }
    $x += $gl.w * $k + $gap
  }
  $g.Dispose(); $d = $b.LockBits([Drawing.Rectangle]::new(0, 0, $b.Width, $b.Height), 'ReadOnly', 'Format32bppArgb'); $raw = [int[]]::new($b.Width * $b.Height); [Runtime.InteropServices.Marshal]::Copy($d.Scan0, $raw, 0, $raw.Length); $b.UnlockBits($d); $b.Dispose()
  for ($y = 0; $y -lt $H; $y++) { for ($xx = 0; $xx -lt $W; $xx++) { $n = 0; for ($j = 0; $j -lt $q; $j++) { $o = ($y * $q + $j) * $W * $q + $xx * $q; for ($i = 0; $i -lt $q; $i++) { if ($raw[$o + $i] -ne 0) { $n++ } } }; if ($n -ge 8) { $mask[$y * $W + $xx] = $true } } }
}
function To-Bitmap([int[]]$px, [int]$W, [int]$H) { $b = [Drawing.Bitmap]::new($W, $H); for ($i = 0; $i -lt $px.Length; $i++) { if ($px[$i] -ne 0) { $b.SetPixel($i % $W, [int][Math]::Floor($i / $W), [Drawing.Color]::FromArgb($px[$i])) } }; $b }
# Both lines, centred; returns the bitmap with the letters only.
function New-Title([int]$W, [int]$H, [double]$y1, [double]$k1, [double]$y2, [double]$k2, [int[][]]$ramps, [int]$mode, [string]$side, [double]$gap2 = 4) {
  $mask = [bool[]]::new($W * $H)
  Add-Word $mask $W $H 'VERLORENE' (($W - (TextWidth 'VERLORENE' $k1 1.5)) / 2) $y1 $k1 1.5
  Add-Word $mask $W $H 'LANDE' (($W - (TextWidth 'LANDE' $k2 $gap2)) / 2) $y2 $k2 $gap2
  $px = [int[]]::new($W * $H); [LogoFx]::Letters($px, $mask, $W, $H, $ramps, $mode, 2.6, 3, (C '#0c0a10'), (C $side), 11)
  To-Bitmap $px $W $H
}
function Draw($dst, $src, [int]$x, [int]$y) { $g = [Drawing.Graphics]::FromImage($dst); $g.DrawImageUnscaled($src, $x, $y); $g.Dispose() }
function Scene([scriptblock]$b, [int]$n) { $s = New-Scene; $s.Shadow = $false; & $b $s; New-Sprite $s $n }
function SwordRamps($s) { $s.Ramp('steel', '#1c2434', '#46566c', '#8496a8', '#c4d2dc', '#ffffff'); $s.Ramp('gold', '#2c1a0a', '#704818', '#b8842c', '#e8bc4c', '#fff0a8'); $s.Ramp('grip', '#1c0c10', '#4c1c20', '#80302c', '#b05040'); $s.Ramp('gem', '#3a0414', '#80081c', '#c81c2c', '#f85848', '#ffc0a0') }

New-Item -ItemType Directory -Force $Out | Out-Null
$moss = Ramp '#14180f', '#2c3624', '#4e5a3e', '#7e8662', '#b4b890'; $leaf = Ramp '#16301a', '#2a5a22', '#4c8c2c', '#84bc44', '#c4e878'
$coal = Ramp '#1c0e10', '#40202a', '#703432', '#a8542c', '#e89048'; $lava = Ramp '#c8321a', '#ff7c24', '#ffc850', '#fff4b8'
$ice = Ramp '#142a54', '#24589a', '#4a9cd4', '#9adcf2', '#f2feff'; $gold = Ramp '#3c2008', '#84541a', '#c8902c', '#f0c850', '#fff6b8'
$steel = Ramp '#1c2434', '#46566c', '#7c90a4', '#b8c8d4', '#f4fbff'; $bone = Ramp '#4c3a2c', '#88705a', '#c4ac88', '#ecdcb8', '#fffaea'

# Letters of the three regions: icicles under the right part, moss strands under
# the left one.
function New-Lands([int]$W, [int]$H, [double]$y1, [double]$y2) {
  $b = New-Title $W $H $y1 1.0 $y2 1.45 @($moss, $coal, $ice, $lava, $leaf) 1 '#241a22' 5
  $rng = [Random]::new(4)
  for ($x = 4; $x -lt $W - 4; $x++) {
    $left = $x -lt 62; $right = $x -gt 140; if (-not ($left -or $right) -or $rng.NextDouble() -gt 0.3) { continue }
    for ($y = $H - 3; $y -gt 30; $y--) { $c = $b.GetPixel($x, $y); if ($c.A -eq 255 -and $c.R -eq 12 -and $c.G -eq 10 -and $b.GetPixel($x, $y - 1).R -ne 12) {
        $l = 2 + $rng.Next(0, 5); for ($i = 0; $i -lt $l -and $y + $i + 1 -lt $H; $i++) { $col = if ($left) { @('#4c8c2c', '#2a5a22')[[int]($i -gt $l / 2)] } else { @('#f2feff', '#9adcf2')[[int]($i -gt $l / 2)] }; $b.SetPixel($x, $y + $i, [Drawing.ColorTranslator]::FromHtml($col)); foreach ($d in -1, 1) { if ($x + $d -gt 0 -and $x + $d -lt $W -and $b.GetPixel($x + $d, $y + $i).A -eq 0) { $b.SetPixel($x + $d, $y + $i, [Drawing.Color]::FromArgb(255, 12, 10, 16)) } }; if ($i -eq $l - 1 -and $b.GetPixel($x, $y + $i + 1).A -eq 0) { $b.SetPixel($x, $y + $i + 1, [Drawing.Color]::FromArgb(255, 12, 10, 16)) } }
        break } }
  }
  $b
}
if (1 -in $Variant) { (New-Lands 200 88 4 36).Save((Join-Path $Out 'logo_1.png')) }
if (2 -in $Variant -or 5 -in $Variant) {
  $W = 200; $H = 96
  # Sword lying between the lines, hilt on the left.
  $sw = Scene { param($s) SwordRamps $s; $s.Yaw = 0; $s.Pitch = 0; $s.OffY = 90; $s.Group('steel', 0); $s.Gem(8, 0, 0, 84, 5.4, 3, 0, 0, 0, ''); $s.Group('gold', 0.3); $s.Cap(-66, -11, 0, -66, 11, 0, 2.6, 2.6, ''); $s.Ball(-66, 12, 0, 3.2, ''); $s.Ball(-66, -12, 0, 3.2, ''); $s.Group('grip', 0); $s.Cap(-69, 0, 0, -84, 0, 0, 2.4, 2.2, ''); $s.Group('gold', 0); foreach ($x in -73, -77, -81) { $s.Cap($x, -2.4, 1, ($x - 1), 2.4, 1, 0.7, 0.7, '') }; $s.Ball(-88, 0, 0, 4.0, ''); $s.Group('gem', 0); $s.Ball(-88, 0, 3.4, 1.8, ''); $s.Ball(-66, 0, 2.4, 2.2, '') } 200
  if (2 -in $Variant) { $o = [Drawing.Bitmap]::new($W, $H); Draw $o $sw 0 (37 - 108); Draw $o (New-Title $W $H 2 1.0 46 1.45 @(, $gold) 2 '#4c2408' 5) 0 0; $o.Save((Join-Path $Out 'logo_2.png')) }
  if (5 -in $Variant) { $o = [Drawing.Bitmap]::new($W, $H + 4); Draw $o $sw 0 (38 - 108); Draw $o (New-Lands $W ($H + 4) 2 48) 0 0; $o.Save((Join-Path $Out 'logo_5.png')) }
}
if (3 -in $Variant) {
  $W = 200; $H = 146; $o = [Drawing.Bitmap]::new($W, $H)
  $n = 80; $sh = [int[]]::new($n * $n); $mask = [bool[]]::new($n * $n)
  $inside = { param([double]$x, [double]$y, [double]$e) $u = [Math]::Abs($x - 39.5); $hw = if ($y -lt 34) { 27.0 } else { 27.0 * [Math]::Sqrt([Math]::Max(0.0, 1.0 - [Math]::Pow(($y - 34) / 36.0, 2))) }; $y -ge 6 + $e + 0.05 * [Math]::Abs($u - 13) -and $u -le $hw - $e -and $y -le 70 - 1.2 * $e }
  $rng = [Random]::new(3)
  for ($y = 0; $y -lt $n; $y++) { for ($x = 0; $x -lt $n; $x++) {
    if (& $inside $x $y 4) {
      # Three fields: forest left, desert right, snowy peaks below.
      $c = if ($y -gt 38) { $r = 38 + 16 - [Math]::Abs(($x - 39.5)) * 0.85; $r2 = 38 + 24 - [Math]::Abs(($x - 52)) * 1.3; $top = 64 - $y; $pk = [Math]::Max(26 - [Math]::Abs($x - 38) * 1.15, 17 - [Math]::Abs($x - 55) * 1.1); $pk = [Math]::Max($pk, 16 - [Math]::Abs($x - 25) * 1.1); if ($top -lt $pk - 7 + (($x * 7) % 5)) { if (($x -lt 38 -and $x -gt 30) -or $x -lt 24) { '#4a7cb0' } else { '#2c4c80' } } elseif ($top -lt $pk) { '#f2feff' } else { '#16284c' } }
      elseif ($x -lt 39) { $tr = $false; foreach ($q in @(19, 1.0), @(28, 1.25), @(35, 0.8)) { $hy = $y - (38 - 22 * $q[1]); if ($hy -gt 0 -and [Math]::Abs($x - $q[0]) -lt (($hy % 8) * 0.42 + $hy * 0.1) * $q[1]) { $tr = $true } }; if ($tr) { if (($x + $y) % 5 -lt 2) { '#5c9438' } else { '#346428' } } else { '#14301c' } }
      else { $dd = [Math]::Sqrt(($x - 53) * ($x - 53) + ($y - 20) * ($y - 20)); if ($y -gt 33 + 2 * [Math]::Sin($x * 0.3)) { '#dca058' } elseif ($y -gt 29 + 2.5 * [Math]::Sin($x * 0.2 + 1)) { '#b06c34' } elseif ($dd -lt 6) { '#fff0a8' } elseif ($dd -lt 8) { '#ffb03a' } else { '#7c2c1c' } }
      if (($x -eq 39 -and $y -le 38) -or $y -eq 38) { $c = '#e8bc4c' }
      $sh[$y * $n + $x] = C $c
    } elseif (& $inside $x $y 0) { $mask[$y * $n + $x] = $true }
  } }
  [LogoFx]::Letters($sh, $mask, $n, $n, @(, $gold), 0, 2.0, 2, (C '#0c0a10'), (C '#4c2408'), 5)
  $fix = [int[]]::new($n * $n); for ($y = 0; $y -lt $n; $y++) { for ($x = 0; $x -lt $n; $x++) { $fix[$y * $n + $x] = $sh[$y * $n + $x] } }
  # Two crossed swords behind the shield.
  $sw = Scene { param($s) SwordRamps $s; $s.Yaw = 0; $s.Pitch = 0; $s.OffY = 46; foreach ($q in -1, 1) { $s.Push(0, 0, (-3 * $q), 0, 0, (52 * $q)); $s.Group('steel', 0); $s.Gem(0, 12, 0, 3.8, 46, 2, 0, 0, 0, ''); $s.Group('gold', 0.3); $s.Cap(-8, -26, 0, 8, -26, 0, 2.0, 2.0, ''); $s.Group('grip', 0); $s.Cap(0, -28, 0, 0, -37, 0, 1.9, 1.8, ''); $s.Group('gold', 0); $s.Ball(0, -40, 0, 3.0, ''); $s.Pop() } } 110
  Draw $o $sw 45 -18; Draw $o (To-Bitmap $fix $n $n) 60 -4
  Draw $o (New-Title $W $H 72 0.96 101 1.4 @(, $steel) 2 '#1c2434' 5) 0 0; $o.Save((Join-Path $Out 'logo_3.png'))
}
if (4 -in $Variant) {
  $W = 200; $H = 132; $o = [Drawing.Bitmap]::new($W, $H)
  # Three cards fanned out behind the title, each with the symbol of a region.
  $cards = @(@('forest', '#1c3c1c', '#5c9438', -24, 62), @('fortress', '#16284c', '#4a9cd4', 24, 138), @('desert', '#5c2414', '#e08020', 0, 100))
  foreach ($cd in $cards) {
    $q = 4; $big = [Drawing.Bitmap]::new($W * $q, $H * $q); $g = [Drawing.Graphics]::FromImage($big); $g.TranslateTransform($cd[4] * $q, (54 + [Math]::Abs($cd[3]) * 0.25) * $q); $g.RotateTransform($cd[3]); $g.ScaleTransform($q, $q)
    $br = { param($c) [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($c)) }
    $g.FillRectangle((& $br '#0c0a10'), -24, -50, 48, 82); $g.FillRectangle((& $br '#e8bc4c'), -23, -49, 46, 80); $g.FillRectangle((& $br '#84541a'), -21, -47, 42, 76); $g.FillRectangle((& $br $cd[1]), -20, -46, 40, 74)
    $sym = [Drawing.Bitmap]::FromFile([IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\ui\assets\symbole\$($cd[0])_bild.png"))); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'; $g.DrawImage($sym, -16, -44, 32, 32); $g.Dispose()
    for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) { $c = $big.GetPixel($x * $q + 2, $y * $q + 2); if ($c.A -gt 128) { $o.SetPixel($x, $y, [Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B)) } } }; $big.Dispose()
  }
  Draw $o (New-Title $W $H 50 1.0 82 1.45 @(, $bone) 2 '#4c2018' 5) 0 0; $o.Save((Join-Path $Out 'logo_4.png'))
}
