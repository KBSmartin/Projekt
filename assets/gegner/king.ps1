# Frost king (enemy "king", boss, 48 x 48): dead king on his throne, staff in
# hand; exactly pose 6 of assets/probe/king_posen2.ps1. Writes <Out>/king.png;
# -Anim writes the animation sheets into ui/assets/gegner (breathing, strikes the
# floor with the staff so ice breaks out, hit, shatters with the throne).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
. (Join-Path $PSScriptRoot 'ritter.ps1')
$Out = [IO.Path]::GetFullPath($Out)

# Skull with crown of ice, sunken eyes and an icicle beard.
function KHead($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz) {
  $s.Push($x, $y, $z, 0, $ry, $rz); $s.Group('bone', 0.8); $s.Ell(0, 0.2, 0, 3.8, 4.0, 3.7, 0, 0, 0, ''); $s.Box(-1.2, -2.8, 0, 1.8, 1.3, 2.1, 0, 0, 0, 0.6, '')
  $s.Group('trim', 0.2); for ($i = 0; $i -lt 10; $i++) { $a = $i * 0.628; $s.Ball(0.2 + 3.6 * [Math]::Cos($a), 3.8, 3.6 * [Math]::Sin($a), 1.25, '') }
  $s.Group('crown', 0); for ($i = 0; $i -lt 8; $i++) { $a = $i * 0.785 + 0.2; $h = 4.4 + 2.4 * ($i % 2); $s.Gem(0.2 + 3.5 * [Math]::Cos($a), 4.0 + $h * 0.5, 3.5 * [Math]::Sin($a), 1.2, $h * 0.75, 1.2, (-8 * [Math]::Sin($a)), 0, (8 * [Math]::Cos($a)), '') }
  $s.Group('ice', 0.2); foreach ($q in @(-2.6, 0, 6.4), @(-2.2, 1.4, 5.0), @(-2.2, -1.4, 5.0), @(-1.2, 2.5, 3.6), @(-1.2, -2.5, 3.6)) { $s.Cap($q[0], -3.2, $q[1], $q[0] - 0.4, -3.2 - $q[2], $q[1] * 0.8, 1.1, 0.4, '') }
  $s.Mark(-3.2, 0.4, 0, 'kbbbbbk/kkbbbkk/kckbkck/bkkbkkb/bbbkbbb/.bkbkb./.bbbbb.', 'k=#080a14,c=#98ecff,b=#d8d8cc', $true); $s.Pop()
}
# Heavy cloak with a fur collar.
function Mantle($s, [double]$x, [double]$y, [double]$w, [double]$flow) { Cape $s ($x + 1.6) ($y - 1) $w $flow 'cloth'; $s.Group('fur', 0.9); for ($i = 0; $i -lt 11; $i++) { $a = 0.4 + $i * 0.55; $s.Ball($x + 3.4 * [Math]::Cos($a), $y + 0.6 * [Math]::Cos($a * 2), 6.4 * [Math]::Sin($a), 2.2, '') }; $s.Group('fur', 0.4); for ($i = 0; $i -lt 11; $i++) { $a = 0.4 + $i * 0.55; $s.Cap($x + 3.8 * [Math]::Cos($a), $y, 7.0 * [Math]::Sin($a), $x + 4.2 * [Math]::Cos($a), $y - 3.0, 7.6 * [Math]::Sin($a), 1.2, 0.5, '') } }
# Long robe under the cloak.
function Skirt($s, [double]$x, [double]$y, [double]$w) { $s.Group('cloth', 1.4); $s.Cap($x, $y, 0, $x + 0.8, 3, 0, 4.0, $w * 0.8, ''); for ($i = 0; $i -lt 13; $i++) { $a = $i * 0.483; $s.Cap($x + 3.4 * [Math]::Cos($a), $y - 2, 3.4 * [Math]::Sin($a), $x + 0.8 + $w * [Math]::Cos($a), 1.2, $w * [Math]::Sin($a), 1.0, 1.5, '') }; $s.Group('fur', 0.4); for ($i = 0; $i -lt 18; $i++) { $a = $i * 0.349; $s.Ball($x + 0.8 + ($w + 0.4) * [Math]::Cos($a), 1.2, ($w + 0.4) * [Math]::Sin($a), 1.3, '') } }
function Staff($s, [double]$x, [double]$z, [double]$y1) { $s.Group('trim', 0); $s.Cap($x, 0.6, $z, $x, $y1, $z, 0.9, 0.9, ''); $s.Group('ice', 0); $s.Gem($x, $y1 + 3.4, $z, 2.2, 4.6, 2.2, 0, 20, 0, ''); foreach ($q in -1, 1) { $s.Gem($x + 0.4, $y1 + 2.0, $z + 2.2 * $q, 1.0, 3.6, 1.0, (24 * $q), 0, 0, '') }; $s.Group('glow', 0); $s.Ball($x - 1.2, $y1 + 3, $z + 1, 1.1, '') }
function BoneHand($s, [double]$x, [double]$y, [double]$z, [double]$dx, [double]$dy, [double]$k = 1) { $s.Group('bone', 0.2); foreach ($q in -1.4, -0.5, 0.5, 1.4) { $s.Chain([double[]]@($x, $y, $z, ($x + 2.0 * $k * $dx - 1.0 * $k * $q * $dy), ($y + 2.0 * $k * $dy + 1.0 * $k * $q * $dx), ($z + 0.6 * $q), ($x + 4.4 * $k * $dx - 1.2 * $k * $q * $dy), ($y + 4.4 * $k * $dy + 1.2 * $k * $q * $dx), ($z + 0.7 * $q)), 0.8, 0.5, '') } }
function Add-Ramps($s) {
  Add-UndeadRamps $s
  $s.Ramp('crown', '#2c6ca0', '#62b4dc', '#b0e6f8', '#eefcff', '#ffffff')
  $s.Ramp('throne', '#0c1834', '#18325e', '#2a568e', '#5488bc', '#98c8e4')
  $s.Ramp('robe', '#140c24', '#2c1c48', '#4a3272', '#70549c', '#a488c8')
}
# High-backed ice throne with armrests.
function Throne($s) {
  PB $s 'throne' 5.6 5 0 4.4 5 8.4 0 0 0 0.8; PB $s 'throne' 8.6 17 0 1.8 13 7.6 0 0 -4 0.8
  foreach ($q in @(-8, 12), @(-4.4, 17), @(0, 22), @(4.4, 17), @(8, 12)) { $s.Group('throne', 0); $s.Gem(9.4, 21 + $q[1] * 0.45, $q[0], 1.6, $q[1] * 0.62, 2.0, 0, 0, -4, '') }
  foreach ($q in -1, 1) { PB $s 'throne' 1.0 9.4 (8.4 * $q) 5.0 1.3 1.6; PB $s 'throne' -3.4 5 (8.4 * $q) 1.2 5 1.4; $s.Group('crown', 0); $s.Gem(-4.4, 11.6, (8.4 * $q), 1.5, 2.4, 1.5, 0, 0, 0, '') }
  PB $s 'throne' -4 0.8 0 7 1.0 10 0 0 0 0.4
}
# Robe of a seated figure: lap, knees, long fall to the floor with a fur hem.
function SeatedRobe($s) {
  $s.Group('robe', 1.8); $s.Cap(2.4, 10, 0, -3.6, 10.6, 2.6, 4.0, 3.4, ''); $s.Cap(2.4, 10, 0, -3.6, 10.6, -2.6, 4.0, 3.4, ''); foreach ($q in -1, 1) { $s.Cap(-4.2, 10, (2.8 * $q), -6.6, 3.0, (3.6 * $q), 3.2, 4.0, '') }
  $s.Group('robe', 0.5); for ($i = 0; $i -lt 9; $i++) { $z = -6.4 + 1.6 * $i; $s.Chain([double[]]@(-5.6, 11.4, ($z * 0.6), (-7.6 + [Math]::Abs($z) * 0.2), 6, ($z * 0.9), (-9.4 + [Math]::Abs($z) * 0.4), 1.8, ($z * 1.1)), 0.9, 1.3, '') }
  $s.Group('fur', 0.5); for ($i = 0; $i -lt 13; $i++) { $z = -8 + 1.33 * $i; $s.Ball((-9.8 + [Math]::Abs($z) * 0.45), 1.5, $z, 1.5, '') }
  $s.Group('trim', 0.2); foreach ($q in -1.1, 1.1) { $s.Chain([double[]]@(-5.6, 13.0, $q, -8.0, 9, $q, -10.2, 3, ($q * 1.2)), 0.5, 0.5, '') }
}

function Build($s, $A) {
  $s.Yaw = 42; $s.Pitch = 12; $u = 0.22 * $A.s
  $up = 5.0 * $A.wind - 0.4 * $A.act
  Throne $s; SeatedRobe $s; $s.Push(2.2, (10.4 + 0.5 * $u), 0, 0, 0, (2 - 4 * $A.wind + 6 * $A.act - 5 * $A.hit)); PTorso $s; $s.Pop(); Mantle $s (1.8 - 1.0 * $A.act + 0.6 * $A.hit) (21.8 + $u) 7 0
  # The free hand lifts from the armrest and points at the hero.
  $n = Get-Mix @(0.6, 21, 6, 0.8, 15.4, 9, -3.4, 12.4, 9) @(-0.4, 21, 6, -2.4, 17, 9.4, -7.4, 18, 8.6) $A.act
  PArm $s $n 1; BoneHand $s ($n[6] - 0.6) ($n[7] - 0.4) 9 (-0.8 - 0.2 * $A.act) (-0.5 + 0.6 * $A.act)
  PArm $s @((0.2 - 0.6 * $A.act), (21 + $u), -6, -3.4, (16.6 + 0.5 * $up), -8.6, -7, (16 + $up), -10) -1
  if ($up -ne 0) { $s.Push(0, $up, 0, 0, 0, 0) }; Staff $s -7.6 -10.4 29; if ($up -ne 0) { $s.Pop() }
  KHead $s (-0.8 - 1.0 * $A.act + 0.8 * $A.hit) (26.6 + $u) 0 12 (6 - 4 * $A.wind + 6 * $A.act - 12 * $A.hit)
  if ($A.spikes) { $s.Group('crown', 0); foreach ($e in $A.spikes) { $s.Gem($e[0], ($e[2] * 0.5), $e[1], 1.5, ($e[2] * 0.62), 1.5, 0, 0, $e[3], '') } }
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.45; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 48
$bmp.Save((Join-Path $Out 'king.png'))
if ($Anim) {
  $keys = { param($A) $A.spikes = $null; if ($A.anim -eq 'angriff' -and $A.f -ge 3 -and $A.f -le 6) { $h = @(0.4, 1.0, 0.85, 0.35)[$A.f - 3]; $A.spikes = @(@(-13.4, 3, (9 * $h), 14), @(-15.6, -2, (13 * $h), 22), @(-14.4, 8, (7 * $h), 18), @(-16, -8, (9 * $h), 26)) } }
  Save-Sheets 'king' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.45; Build $s $A } 48 (Get-Fit $still 48) @{ breath = 0.0; windBend = 0; actBend = 0; hitBend = 0; actPx = 0; windPx = 0; hitPx = 2; tod = @{ fx = 'chunks'; cell = 7; seed = 9; spread = 0.5; pile = 0.2; from = 2; marksUntil = 3 } } (Get-GameDir) $keys
}
