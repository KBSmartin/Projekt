# Moss golem (enemy "moss", elite): classic stone golem, pose 21 of
# assets/probe/moss_posen5.ps1. Writes <Out>/moss_<Size>.png; -Anim writes the
# animation sheets into ui/assets/gegner (breathing, both fists slam, hit).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [int]$Size = 48, [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('stone', '#17171d', '#35373c', '#5c5f5c', '#8c8e7e', '#c2c2a6')
  $s.Ramp('dirt', '#17120f', '#3a2f26', '#65543f', '#957f5e', '#c8b388')
  $s.Ramp('moss', '#0e1c0e', '#20401a', '#3c6c22', '#6ea034', '#b4d860')
  $s.Ramp('dark', '#06070a', '#0c0f12', '#14181c')
  $s.Glow('glow', '#12a070', '#40f0a8', '#dcfff0')
  $s.Rough('stone', 0.03, 0.06); $s.Rough('dirt', 0.03, 0.06); $s.Rough('moss', 0.12, 0.02); $s.Crack('stone', 0.08, 6.5); $s.Crack('dirt', 0.08, 6.5)
  $s.Contrast = 1.15; $s.EdgeDepth = 1.8; $s.EdgeSame = 6
}
$script:mat = 'stone'
function Block($s, [double]$x, [double]$y, [double]$z, [double]$a, [double]$b, [double]$c, [double]$rx = 0, [double]$ry = 0, [double]$rz = 0, [double]$r = 0.9) { $s.Group($script:mat, 0.2); $s.Box($x, $y, $z, $a, $b, $c, $rx, $ry, $rz, $r, '') }
function Moss($s, $list) { $s.Group('moss', 0.9); foreach ($m in $list) { $s.Ell($m[0], $m[1], $m[2], $m[3], $m[4], $m[5], 0, 0, 0, '') } }
function Hang($s, $list) { $s.Group('moss', 0.4); foreach ($h in $list) { $s.Cap($h[0], $h[1], $h[2], $h[0] - 0.3, $h[1] - $h[3], $h[2], 1.3, 0.5, '') } }
function Fist($s, [double]$x, [double]$y, [double]$z, [double]$r, [double]$rz = 0) {
  $s.Push($x, $y, $z, 0, 0, $rz); $s.Group($script:mat, 0.2); $s.Box(0, 0, 0, $r, $r * 0.95, $r, 0, 0, 0, $r * 0.3, '')
  foreach ($d in -1, 0, 1) { $s.Box(-$r * 0.85, -$r * 0.25, $d * $r * 0.66, $r * 0.4, $r * 0.62, $r * 0.29, 0, 0, 0, 0.35, '') }
  $s.Pop()
}
# Straight arm from the shoulder: upper arm, elbow gap, big forearm, fist.
# $rz swings it forward (negative) or back, $bend bends the elbow forward.
function Arm($s, [double]$x, [double]$y, [double]$z, [double]$rx, [double]$rz, [double]$bend, [double]$k = 1) {
  $s.Push($x, $y, $z, $rx, 0, $rz)
  Block $s 0 -3.2 0 (2.1 * $k) 3.4 (2.1 * $k)
  $s.Push(0, -6.8, 0, 0, 0, $bend)
  Block $s 0 -3.6 0 (2.8 * $k) 4.0 (2.8 * $k) 0 0 0 1.0
  Fist $s -0.4 -9.2 0 (3.1 * $k)
  $s.Pop(); $s.Pop()
}
function Leg($s, [double]$x, [double]$z, [double]$rz, [double]$lift = 0) {
  $s.Push($x, 8.6, $z, 0, 0, $rz); Block $s 0 -2.0 0 2.7 2.6 2.5; $s.Pop()
  $fx = $x - 6.0 * [Math]::Sin(-$rz * [Math]::PI / 180)
  Block $s $fx (3.6 + $lift) $z 3.0 2.4 2.8 0 0 0 0.8; Block $s ($fx - 1.0) (1.2 + $lift) $z 3.8 1.4 3.1 0 0 0 0.7
}
# Small head sunk between the shoulders: brow slab, dark eye slit, heavy jaw.
function Head($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz, [double]$k = 1, [double]$jaw = 0) {
  $s.Push($x, $y, $z, 0, $ry, $rz)
  $s.Group($script:mat, 0.4); $s.Box(0.4 * $k, 0.6 * $k, 0, 3.2 * $k, 3.2 * $k, 3.3 * $k, 0, 0, 0, 0.9, ''); $s.Box(-1.0 * $k, 2.1 * $k, 0, 2.9 * $k, 1.2 * $k, 3.7 * $k, 0, 0, 8, 0.5, '')
  $s.Cut(-3.4 * $k, 0.3 * $k, 0, 1.9 * $k, 1.15 * $k, 3.1 * $k, 0, 0, 0, 'dark')
  $s.Box(-1.0 * $k, (-2.5 - $jaw) * $k, 0, 2.9 * $k, 1.3 * $k, 3.0 * $k, 0, 0, -4, 0.6, '')
  if ($jaw -gt 0) { $s.Group('dark', 0); $s.Box(-0.8 * $k, -1.6 * $k, 0, 2.2 * $k, 0.9 + $jaw * 0.4, 2.5 * $k, 0, 0, 0, 0.3, '') }
  # Both eyes are one stamp in the dark slit: same height, angry slant.
  if ($script:big) { $s.Mark(-2.9 * $k, 0.4 * $k, 0, '.kkkkkkk./kgkkkkggk/.khgkghk./...kkk...', 'k=#06070a,g=#40f0a8,h=#b8ffe0', $true) }
  else { $s.Mark(-2.9 * $k, 0.4 * $k, 0, 'kgkkkgk/kkhkhkk', 'k=#06070a,g=#40f0a8,h=#b8ffe0', $true) }
  $s.Pop()
}
# Chest of two breast slabs on a narrower waist; rune seam glowing between.
function Chest($s, [double]$w, [bool]$rune) {
  Block $s 0.6 0 0 3.6 2.0 3.8; Block $s 0.2 4.0 0 4.0 2.6 4.8
  Block $s 0 9.8 ($w * 0.46) 4.8 4.0 ($w * 0.46) 0 4 4 1.1; Block $s 0 9.8 (-$w * 0.46) 4.8 4.0 ($w * 0.46) 0 -4 4 1.1
  if ($rune) { $s.Group('glow', 0); $s.Cap(-4.6, 12.0, 0, -4.8, 6.4, 0, 0.55, 0.55, ''); $s.Cap(-4.6, 10.6, 0, -4.6, 12.2, 2.4, 0.5, 0.5, ''); $s.Cap(-4.6, 10.6, 0, -4.6, 12.2, -2.4, 0.5, 0.5, '') }
}

function Build($s, [double]$z, $A) {
  $s.Yaw = 50; $s.Zoom = 0.84 * $z; $s.OffX = 0.6 * $z
  Leg $s 1 4.6 0; Leg $s 2 -4.6 0
  $s.Push(1.4, 11.2, 0, 3, 0, 8)
  Chest $s 8.4 $false
  Block $s 0.4 12.4 10.6 3.8 3.4 3.4 0 8 6 1.1; Block $s 0.4 12.4 -10.6 3.8 3.4 3.4 0 -8 6 1.1
  # Both arms go up over the head and slam down in front.
  Arm $s 0.4 (10.6 + 0.2 * $A.s) 11.6 -6 (-4 - 1.5 * $A.s - 128 * $A.wind - 46 * $A.act + 14 * $A.hit) (-14 - 14 * $A.wind - 10 * $A.act); Arm $s 0.4 (10.6 + 0.2 * $A.s) -11.6 6 (-10 - 1.5 * $A.s - 128 * $A.wind - 46 * $A.act + 14 * $A.hit) (-16 - 14 * $A.wind - 10 * $A.act)
  Head $s (-2.8 + 0.6 * $A.hit) (17.4 + 0.25 * $A.s) 0 6 (-2 - 6 * $A.wind + 4 * $A.act - 10 * $A.hit) 1.15
  Moss $s @(@(0.4, 16, 10.6, 3.6, 1.2, 3.2), @(0.4, 16, -10.6, 3.2, 1.1, 3.0), @(2.4, 14.2, 4, 2.6, 1.2, 3.4)); Hang $s @(@(-3.4, 15.6, 11, 4.6), @(-3.2, 15.4, -9, 3.4), @(-1.4, 15.6, 13.4, 5))
  $s.Pop()
}
$script:big = $Size -ge 48
$still = @{ s = 0.0; wind = 0.0; act = 0.0; hit = 0.0 }
$s = New-Scene; Add-Ramps $s; Build $s ($Size / 32.0) $still
$bmp = New-Sprite $s $Size; $bmp.Save((Join-Path $Out "moss_$Size.png"))
if ($Anim) { Save-Sheets 'moss' { param($s, $A) Add-Ramps $s; Build $s ($Size / 32.0) $A } $Size $null @{ breath = 0.008; y0 = 8; y1 = 15; windBend = -8; actBend = 17; actPx = -1; windPx = 1; hitBend = -8; hitPx = 2; pivX = 1.4; pivY = 11.0; tod = @{ fx = 'chunks'; cell = 7; spread = 0.7; pile = 0.2; from = 2 } } (Get-GameDir) }