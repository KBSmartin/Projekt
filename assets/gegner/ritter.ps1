# Shared parts for the undead rulers of the frost fortress (knight, king).
function Add-UndeadRamps($s) {
  $s.Ramp('plate', '#0c0f18', '#222a3a', '#404c60', '#6e7e90', '#b0c0cc')
  $s.Ramp('trim', '#241a10', '#5c4420', '#98743a', '#d4b060', '#fff0b8')
  $s.Ramp('cloth', '#0c1024', '#1c2450', '#30407c', '#5068a8', '#88a4d0')
  $s.Ramp('fur', '#3c4458', '#70809a', '#a8b8c8', '#dce6ec', '#ffffff')
  $s.Ramp('bone', '#343a4c', '#6c7484', '#a8acac', '#d8d8cc', '#fbf8e8')
  $s.Ramp('ice', '#142a54', '#24589a', '#4a9cd4', '#9adcf2', '#f2feff')
  $s.Ramp('dark', '#05060c', '#0a0c16', '#101420')
  $s.Glow('glow', '#38b8ff', '#98ecff', '#f4ffff')
  $s.Contrast = 1.2; $s.EdgeDepth = 1.7; $s.EdgeSame = 5
}
function PB($s, [string]$m, [double]$x, [double]$y, [double]$z, [double]$a, [double]$b, [double]$c, [double]$rx = 0, [double]$ry = 0, [double]$rz = 0, [double]$r = 0.8) { $s.Group($m, 0.3); $s.Box($x, $y, $z, $a, $b, $c, $rx, $ry, $rz, $r, '') }
# Plated arm through shoulder, elbow, hand, with spiked layered pauldron.
function PArm($s, $p, [double]$side, [double]$k = 1) {
  $s.Group('plate', 0.5); $s.Cap($p[0], $p[1], $p[2], $p[3], $p[4], $p[5], 1.8 * $k, 1.6 * $k, ''); $s.Group('plate', 0.3); $s.Ball($p[3], $p[4], $p[5], 2.0 * $k, ''); $s.Cap($p[3], $p[4], $p[5], $p[6], $p[7], $p[8], 1.7 * $k, 2.0 * $k, ''); $s.Group('plate', 0.3); $s.Ball($p[6], $p[7], $p[8], 1.9 * $k, '')
  $s.Group('plate', 0.3); $s.Ell($p[0] + 0.2, $p[1] + 0.8, $p[2] + 0.8 * $side, 3.4 * $k, 2.8 * $k, 3.2 * $k, (-12 * $side), 0, 0, ''); $s.Group('trim', 0.2); $s.Ell($p[0] + 0.2, $p[1] - 0.8, $p[2] + 1.4 * $side, 3.3 * $k, 0.8, 3.1 * $k, (-12 * $side), 0, 0, '')
  $s.Group('ice', 0); $s.Cap($p[0] + 0.4, $p[1] + 2.6, $p[2] + 2.0 * $side, $p[0] + 1.0, $p[1] + 6.4, $p[2] + 3.6 * $side, 1.1, 0.4, ''); $s.Cap($p[0] + 1.8, $p[1] + 2.2, $p[2] + 0.4 * $side, $p[0] + 3.0, $p[1] + 5.0, $p[2] + 0.8 * $side, 1.0, 0.4, '')
}
function PLeg($s, [double]$hx, [double]$hy, [double]$z, [double]$kx, [double]$fx) { $s.Group('plate', 0.4); $s.Cap($hx, $hy, $z, $kx, $hy * 0.55, $z * 1.1, 2.4, 2.0, ''); $s.Group('plate', 0.3); $s.Ball($kx - 0.4, $hy * 0.55, $z * 1.1, 2.2, ''); $s.Cap($kx, $hy * 0.5, $z * 1.1, $fx, 2, $z * 1.15, 2.0, 2.1, ''); $s.Group('plate', 0.3); $s.Cap($fx, 1.2, $z * 1.15, $fx - 3.0, 0.9, $z * 1.15, 1.7, 1.2, '') }
# Breastplate, belt, tassets; origin at the hips.
function PTorso($s) {
  PB $s 'plate' 0 8.6 0 3.2 4.0 5.0 0 0 4 1.6; $s.Group('trim', 0.2); $s.Cap(-3.2, 11.6, -3, -3.6, 7.6, 0, 0.5, 0.5, ''); $s.Cap(-3.2, 11.6, 3, -3.6, 7.6, 0, 0.5, 0.5, ''); $s.Group('glow', 0); $s.Ball(-3.6, 9.2, 0, 0.9, '')
  PB $s 'plate' 0.2 3.6 0 2.6 1.8 3.8; PB $s 'trim' 0 1.4 0 2.8 0.8 4.0; foreach ($q in -1, 1) { PB $s 'plate' -1.4 -0.8 (2.6 * $q) 1.4 2.4 1.9 (8 * $q) 0 -10 0.6 }; PB $s 'cloth' -2.4 -2.4 0 0.8 4.0 1.5 0 0 -6 0.5
}
# Torn cape behind the shoulders.
function Cape($s, [double]$x, [double]$y, [double]$w, [double]$flow, [string]$m = 'cloth') { for ($i = 0; $i -lt 8; $i++) { $z = -$w + 2 * $w * $i / 7; $l = 1.0 + (($i * 5) % 4) * 1.1; $s.Group($m, 1.0); $s.Chain([double[]]@($x, $y, ($z * 0.8), ($x + 2.4 + $flow * 0.4), ($y * 0.5), $z, ($x + 3.4 + $flow), $l, ($z * 1.15)), 1.6, 1.3, '') } }
# Ice sword from the grip along (dx, dy).
function Sword($s, [double]$x, [double]$y, [double]$z, [double]$dx, [double]$dy, [double]$l, [double]$w = 1.6) {
  $a = -[Math]::Atan2($dx, $dy) * 180 / [Math]::PI; $s.Push($x, $y, $z, 0, 0, $a)
  $s.Group('dark', 0); $s.Cap(0, -2.4, 0, 0, 1.4, 0, 0.8, 0.8, ''); $s.Group('trim', 0); $s.Ball(0, -3.0, 0, 1.1, ''); $s.Cap(-3.2, 1.8, 0, 3.2, 1.8, 0, 0.9, 0.9, ''); $s.Group('ice', 0); $s.Gem(0, 2 + $l * 0.42, 0, $w, $l * 0.6, 0.9, 0, 0, 0, ''); $s.Gem(0, 4, 0, $w * 1.2, 3.4, 0.9, 0, 0, 0, '')
  $s.Pop()
}
