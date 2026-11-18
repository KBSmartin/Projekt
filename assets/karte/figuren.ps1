# Board-game pieces for the world map, one per hero, rendered from 3D shapes
# (ellipsoids, like a turned wooden chess pawn) to pixel art: camera slightly
# from above, key light from the upper left, rim light, colour ramps per
# material, dark outline. Writes ui/assets/karte/figur_<hero>.png (24x32).
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karte'), [int]$W = 24, [int]$H = 32)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$Out = [IO.Path]::GetFullPath($Out)
$deg = [Math]::PI / 180

function Mat([double]$rx, [double]$ry, [double]$rz) {
  $a = $rx * $deg; $b = $ry * $deg; $c = $rz * $deg
  $X = @(1, 0, 0, 0, [Math]::Cos($a), -[Math]::Sin($a), 0, [Math]::Sin($a), [Math]::Cos($a))
  $Y = @([Math]::Cos($b), 0, [Math]::Sin($b), 0, 1, 0, -[Math]::Sin($b), 0, [Math]::Cos($b))
  $Z = @([Math]::Cos($c), -[Math]::Sin($c), 0, [Math]::Sin($c), [Math]::Cos($c), 0, 0, 0, 1)
  MulM (MulM $Z $Y) $X
}
function MulM($A, $B) {
  $o = New-Object double[] 9
  for ($i = 0; $i -lt 3; $i++) { for ($j = 0; $j -lt 3; $j++) { $o[$i * 3 + $j] = $A[$i * 3] * $B[$j] + $A[$i * 3 + 1] * $B[3 + $j] + $A[$i * 3 + 2] * $B[6 + $j] } }
  , $o
}
function MatVec($A, $v) { , @(($A[0] * $v[0] + $A[1] * $v[1] + $A[2] * $v[2]), ($A[3] * $v[0] + $A[4] * $v[1] + $A[5] * $v[2]), ($A[6] * $v[0] + $A[7] * $v[1] + $A[8] * $v[2])) }
function Mtv($A, $v) { , @(($A[0] * $v[0] + $A[3] * $v[1] + $A[6] * $v[2]), ($A[1] * $v[0] + $A[4] * $v[1] + $A[7] * $v[2]), ($A[2] * $v[0] + $A[5] * $v[1] + $A[8] * $v[2])) }
function Norm($v) { $l = [Math]::Sqrt($v[0] * $v[0] + $v[1] * $v[1] + $v[2] * $v[2]); , @(($v[0] / $l), ($v[1] / $l), ($v[2] / $l)) }
function Dot($a, $b) { $a[0] * $b[0] + $a[1] * $b[1] + $a[2] * $b[2] }

$gold = @('#5a3c0c', '#8a6018', '#c08a28', '#e8b848', '#fff0a0')
$pieces = [ordered]@{
  krieger  = @{ body = @('#1e222c', '#2e3440', '#444c5c', '#5e6878', '#7c8698', '#a0aabc', '#c8d0de', '#f0f4fa'); acc = @('#4a1014', '#7e1c1e', '#b8322a', '#e2604a', '#ff9a78') }
  schuetze = @{ body = @('#0e2014', '#16301e', '#20442a', '#2c5a36', '#3a7446', '#509058', '#70ae72', '#a0d098'); acc = $gold }
  magier   = @{ body = @('#140c26', '#20143c', '#302058', '#442e78', '#5c4298', '#785cb8', '#9a7ed4', '#c4aaf0'); acc = $gold }
}
$dark = @('#08080c', '#16141c', '#24202c')

foreach ($name in $pieces.Keys) {
  $parts = [Collections.Generic.List[object]]::new()
  function Part($c, $rad, $rot, [string]$mat) { $parts.Add(@{ c = $c; rad = $rad; rot = (Mat $rot[0] $rot[1] $rot[2]); mat = $mat }) }
  # Turned pawn: two base rings, a bulging body, collar, round head.
  Part @(0, 0.8, 0) @(4.6, 0.8, 4.6) @(0, 0, 0) 'body'
  Part @(0, 1.9, 0) @(3.9, 0.7, 3.9) @(0, 0, 0) 'body'
  Part @(0, 3.4, 0) @(3.1, 1.5, 3.1) @(0, 0, 0) 'body'
  Part @(0, 6.0, 0) @(2.4, 3.6, 2.4) @(0, 0, 0) 'body'
  Part @(0, 9.1, 0) @(2.9, 0.55, 2.9) @(0, 0, 0) 'body'
  switch ($name) {
    'krieger' {
      Part @(0, 11.3, 0) @(2.4, 2.3, 2.4) @(0, 0, 0) 'body'            # helmet
      Part @(0, 11.0, 2.05) @(1.5, 0.28, 0.5) @(0, 0, 0) 'dark'         # visor slit
      Part @(0, 13.9, -0.4) @(0.95, 1.9, 2.6) @(-10, 0, 0) 'acc'        # plume
      Part @(0, 12.2, -2.6) @(0.6, 1.4, 0.9) @(30, 0, 0) 'acc'
    }
    'schuetze' {
      Part @(0, 11.2, 0) @(2.5, 2.4, 2.5) @(0, 0, 0) 'body'            # hooded head
      Part @(0, 10.9, 1.75) @(1.45, 1.55, 0.7) @(0, 0, 0) 'dark'        # face in the hood
      Part @(0, 13.5, -1.2) @(1.4, 1.5, 1.9) @(-50, 0, 0) 'body'        # hood tip falling back
      Part @(1.9, 13.6, -0.4) @(0.4, 1.7, 0.3) @(0, 0, -28) 'acc'       # feather
    }
    'magier' {
      Part @(0, 11.0, 0) @(2.3, 2.2, 2.3) @(0, 0, 0) 'body'            # head
      Part @(0, 10.7, 1.9) @(1.3, 0.9, 0.5) @(0, 0, 0) 'dark'           # shadowed face
      Part @(0, 12.6, 0) @(3.3, 0.42, 3.3) @(0, 0, 0) 'body'            # brim
      Part @(0, 13.1, 0) @(2.25, 0.38, 2.25) @(0, 0, 0) 'acc'           # hat band
      for ($k = 0; $k -le 8; $k++) {
        $r = 2.1 * (1 - $k / 9.5) + 0.2
        Part @((-0.05 * $k * $k / 8), (13.4 + $k * 0.85), (-0.06 * $k * $k)) @($r, 0.55, $r) @(0, 0, 0) 'body'
      }
      Part @(-0.6, 21.0, -4.0) @(0.45, 0.45, 0.45) @(0, 0, 0) 'acc'      # star at the tip
    }
  }

  # Camera from slightly above, light from the upper left.
  $View = Mat 22 0 0
  $Lw = Norm (Mtv $View (Norm @(-0.6, 0.75, 0.55)))
  $Rw = Norm (Mtv $View (Norm @(0.8, 0.3, -0.5)))
  $Vw = Norm (Mtv $View @(0, 0, 1))
  $Dw = Mtv $View @(0, 0, -1)
  $Hw = Norm @(($Lw[0] + $Vw[0]), ($Lw[1] + $Vw[1]), ($Lw[2] + $Vw[2]))
  foreach ($p in $parts) { $p.ld = Mtv $p.rot $Dw; $p.ld = @(($p.ld[0] / $p.rad[0]), ($p.ld[1] / $p.rad[1]), ($p.ld[2] / $p.rad[2])); $p.a = Dot $p.ld $p.ld }
  function Trace($o) {
    $best = $null; $bt = 1e9
    foreach ($p in $parts) {
      $lo = Mtv $p.rot @(($o[0] - $p.c[0]), ($o[1] - $p.c[1]), ($o[2] - $p.c[2])); $lo = @(($lo[0] / $p.rad[0]), ($lo[1] / $p.rad[1]), ($lo[2] / $p.rad[2]))
      $b = 2 * (Dot $lo $p.ld); $c = (Dot $lo $lo) - 1; $disc = $b * $b - 4 * $p.a * $c
      if ($disc -lt 0) { continue }
      $t = (-$b - [Math]::Sqrt($disc)) / (2 * $p.a)
      if ($t -gt 0.001 -and $t -lt $bt) { $bt = $t; $best = $p }
    }
    if (-not $best) { return $null }
    $hit = @(($o[0] + $Dw[0] * $bt), ($o[1] + $Dw[1] * $bt), ($o[2] + $Dw[2] * $bt))
    $lp = Mtv $best.rot @(($hit[0] - $best.c[0]), ($hit[1] - $best.c[1]), ($hit[2] - $best.c[2]))
    $nl = @(($lp[0] / ($best.rad[0] * $best.rad[0])), ($lp[1] / ($best.rad[1] * $best.rad[1])), ($lp[2] / ($best.rad[2] * $best.rad[2])))
    @{ t = $bt; p = $best; n = (Norm (MatVec $best.rot $nl)) }
  }
  function RayAt([double]$sx, [double]$sy) { , (Mtv $View @($sx, $sy, 100)) }
  # Fit the piece into the frame (same scale for every hero, standing on the bottom).
  $scale = ($H - 3) / 22.5
  $col = New-Object 'object[,]' $W, $H; $hitm = New-Object 'bool[,]' $W, $H
  for ($py = 0; $py -lt $H; $py++) { for ($px = 0; $px -lt $W; $px++) {
    $sx = ($px + 0.5 - $W / 2) / $scale; $sy = ($H - 2 - $py - 0.5) / $scale + 0.2
    $hit1 = Trace (RayAt $sx $sy)
    if (-not $hit1) { continue }
    $n = $hit1.n; $m = $hit1.p.mat
    $ramp = switch ($m) { 'body' { $pieces[$name].body } 'acc' { $pieces[$name].acc } default { $dark } }
    $diff = [Math]::Max(0.0, (Dot $n $Lw)); $rim = [Math]::Pow([Math]::Max(0.0, (Dot $n $Rw)), 1.5) * [Math]::Pow(1 - [Math]::Max(0.0, (Dot $n $Vw)), 1.2)
    $spec = [Math]::Pow([Math]::Max(0.0, (Dot $n $Hw)), 20)
    $lum = 0.12 + 0.7 * $diff + 0.45 * $rim + 0.35 * $spec
    $idx = [int][Math]::Floor([Math]::Max(0.0, [Math]::Min(0.999, $lum)) * $ramp.Count)
    $col[$px, $py] = [Drawing.ColorTranslator]::FromHtml($ramp[$idx]); $hitm[$px, $py] = $true
  } }
  $bmp = [Drawing.Bitmap]::new($W, $H); $ol = [Drawing.ColorTranslator]::FromHtml('#0a080c')
  for ($py = 0; $py -lt $H; $py++) { for ($px = 0; $px -lt $W; $px++) {
    $cc = $col[$px, $py]
    if ($cc) { $bmp.SetPixel($px, $py, $cc); continue }
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
      $qx = $px + $d[0]; $qy = $py + $d[1]
      if ($qx -ge 0 -and $qy -ge 0 -and $qx -lt $W -and $qy -lt $H -and $hitm[$qx, $qy]) { $bmp.SetPixel($px, $py, $ol); break }
    }
  } }
  $bmp.Save((Join-Path $Out "figur_$name.png")); $bmp.Dispose()
}

# ---------- the hand that sets a piece on the board ----------
# Same scale and camera as the pieces, so the pinch sits on the piece head
# (head centre at y = 11.2). Index finger on the left and thumb on the right
# pinch the head, the other fingers are curled into a loose fist, wrist and a
# dark sleeve above. Frame 40x40; y = 9 lies on row 38 and x = 0 on column 20
# (the CSS aligns it with the piece).
$parts = [Collections.Generic.List[object]]::new()
function Part($c, $rad, $rot, [string]$mat) { $parts.Add(@{ c = $c; rad = $rad; rot = (Mat $rot[0] $rot[1] $rot[2]); mat = $mat }) }
# Ellipsoid from point a to point b with radius r across.
function Limb($a, $b, [double]$r, [string]$mat) {
  $dx = $a[0] - $b[0]; $dy = $a[1] - $b[1]; $dz = $a[2] - $b[2]
  $len = [Math]::Sqrt($dx * $dx + $dy * $dy + $dz * $dz)
  $ang = [Math]::Atan2($dz, $dy) / $deg; $roll = -[Math]::Atan2($dx, $dy) / $deg
  Part @((($a[0] + $b[0]) / 2), (($a[1] + $b[1]) / 2), (($a[2] + $b[2]) / 2)) @($r, ($len / 2 + $r * 0.45), $r) @($ang, 0, $roll) $mat
  Part $b @($r, $r, $r) @(0, 0, 0) $mat
}
# The hand is built in its own space, then scaled up 1.5x around the pinch and
# tilted so the arm comes from the upper right (like a player reaching in).
$pinch = @(0.0, 11.6, 0.0); $hs = 1.5; $tilt = Mat 0 0 (-25)
function T($p) { $q = MatVec $tilt @((($p[0] - $pinch[0]) * $hs), (($p[1] - $pinch[1]) * $hs), (($p[2] - $pinch[2]) * $hs)); , @(($q[0] + $pinch[0]), ($q[1] + $pinch[1]), ($q[2] + $pinch[2])) }
function HPart($c, $rad, $rot, [string]$mat) { Part (T $c) @(($rad[0] * $hs), ($rad[1] * $hs), ($rad[2] * $hs)) @($rot[0], $rot[1], ($rot[2] - 25)) $mat }
function HLimb($a, $b, [double]$r, [string]$mat) { Limb (T $a) (T $b) ($r * $hs) $mat }
# Back of the hand and wrist, sleeve with a cuff.
HPart @(0.2, 18.0, -0.4) @(3.0, 2.4, 1.5) @(-10, 0, 0) 'skin'
HLimb @(0.4, 19.4, -0.6) @(0.8, 22.6, -1.0) 1.7 'skin'
HLimb @(0.8, 23.4, -1.0) @(1.3, 36.0, -1.6) 2.45 'cloth'
HPart @(0.8, 22.6, -0.9) @(2.4, 0.6, 2.2) @(0, 0, 0) 'cuff'
# Index finger: knuckle, bent joint, tip against the left of the piece head.
HLimb @(-1.6, 16.4, 0.4) @(-3.0, 14.6, 0.5) 0.8 'skin'
HLimb @(-3.0, 14.6, 0.5) @(-2.7, 12.2, 0.2) 0.74 'skin'
HPart @(-2.75, 12.3, 0.85) @(0.42, 0.55, 0.2) @(0, 0, 0) 'nail'
# Thumb on the right side of the head.
HLimb @(2.4, 15.2, 0.2) @(3.0, 13.6, 0.4) 0.84 'skin'
HLimb @(3.0, 13.6, 0.4) @(2.7, 12.0, 0.2) 0.78 'skin'
HPart @(2.75, 12.1, 0.85) @(0.42, 0.55, 0.2) @(0, 0, 0) 'nail'
# Middle, ring and little finger curled into the palm, above the head.
foreach ($f in @(@(-0.5, 0.72), @(0.6, 0.7), @(1.6, 0.6))) {
  HLimb @($f[0], 16.8, 0.6) @($f[0], 15.8, 1.3) $f[1] 'skin'
  HLimb @($f[0], 15.8, 1.3) @($f[0], 15.5, 0.3) ($f[1] * 0.95) 'skin'
}
$handRamps = @{
  skin  = @('#3a1a14', '#6a3424', '#9a5438', '#c4785a', '#e09e7c', '#f4c4a2', '#ffe2cc')
  nail  = @('#c89888', '#e8b8a8', '#f8dcd0', '#fff4ee')
  cloth = @('#0c0a10', '#1a1622', '#2a2434', '#3e3648', '#544a62')
  cuff  = @('#4a3018', '#6a4a2c', '#9a7040', '#c89a58', '#e8c47a')
}
$View = Mat 22 0 0
$Lw = Norm (Mtv $View (Norm @(-0.6, 0.75, 0.55)))
$Rw = Norm (Mtv $View (Norm @(0.8, 0.3, -0.5)))
$Vw = Norm (Mtv $View @(0, 0, 1))
$Dw = Mtv $View @(0, 0, -1)
$Hw = Norm @(($Lw[0] + $Vw[0]), ($Lw[1] + $Vw[1]), ($Lw[2] + $Vw[2]))
foreach ($p in $parts) { $p.ld = Mtv $p.rot $Dw; $p.ld = @(($p.ld[0] / $p.rad[0]), ($p.ld[1] / $p.rad[1]), ($p.ld[2] / $p.rad[2])); $p.a = Dot $p.ld $p.ld }
$HW = 40; $HH = 40; $scale = ($H - 3) / 22.5
$col = New-Object 'object[,]' $HW, $HH; $hitm = New-Object 'bool[,]' $HW, $HH
for ($py = 0; $py -lt $HH; $py++) { for ($px = 0; $px -lt $HW; $px++) {
  $sx = ($px + 0.5 - $HW / 2) / $scale; $sy = ($HH - 2 - $py - 0.5) / $scale + 9.0
  $hit1 = Trace (RayAt $sx $sy)
  if (-not $hit1) { continue }
  $n = $hit1.n; $ramp = $handRamps[$hit1.p.mat]
  $diff = [Math]::Max(0.0, (Dot $n $Lw)); $rim = [Math]::Pow([Math]::Max(0.0, (Dot $n $Rw)), 1.5) * [Math]::Pow(1 - [Math]::Max(0.0, (Dot $n $Vw)), 1.2)
  $spec = [Math]::Pow([Math]::Max(0.0, (Dot $n $Hw)), 20)
  $lum = 0.14 + 0.7 * $diff + 0.4 * $rim + 0.2 * $spec
  $idx = [int][Math]::Floor([Math]::Max(0.0, [Math]::Min(0.999, $lum)) * $ramp.Count)
  $col[$px, $py] = [Drawing.ColorTranslator]::FromHtml($ramp[$idx]); $hitm[$px, $py] = $true
} }
$bmp = [Drawing.Bitmap]::new($HW, $HH); $ol = [Drawing.ColorTranslator]::FromHtml('#0a080c')
for ($py = 0; $py -lt $HH; $py++) { for ($px = 0; $px -lt $HW; $px++) {
  $cc = $col[$px, $py]
  if ($cc) { $bmp.SetPixel($px, $py, $cc); continue }
  foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
    $qx = $px + $d[0]; $qy = $py + $d[1]
    if ($qx -ge 0 -and $qy -ge 0 -and $qx -lt $HW -and $qy -lt $HH -and $hitm[$qx, $qy]) { $bmp.SetPixel($px, $py, $ol); break }
  }
} }
$bmp.Save((Join-Path $Out 'hand.png')); $bmp.Dispose()
