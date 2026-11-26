# Poison mushroom (enemy "shroom"): an upright fly agaric with a face in its
# stem; exactly pose 16 of the pose sheet (assets/probe/shroom_posen4.ps1).
# Writes <Out>/shroom.png; -Anim writes the animation sheets into
# ui/assets/gegner (swaying, headbutt with a spore cloud, hit).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('red', '#2c0a14', '#62121c', '#9c2424', '#cc4632', '#f08a5c')
  $s.Ramp('green', '#141c10', '#34461c', '#5e7428', '#92a63c', '#d0d878')
  $s.Ramp('ink', '#14121c', '#2c2838', '#504858', '#86787c', '#c0b0a4')
  $s.Ramp('violet', '#1e0f2a', '#40205a', '#6c3a8a', '#9c62b4', '#d09cd8')
  $s.Ramp('wart', '#746654', '#b4a488', '#e8dcb8', '#fffbe4')
  $s.Ramp('gill', '#1e1416', '#4a342e', '#826650', '#b89a78')
  $s.Ramp('stem', '#30262a', '#645450', '#a08e7a', '#d2c4a4', '#f6eed2')
  $s.Ramp('dark', '#080506', '#12080c', '#200e14')
  $s.Ramp('tooth', '#8c8468', '#d0c8a0', '#fbf6dc')
  $s.Ramp('earth', '#14100c', '#2c2216', '#483822', '#685234')
  $s.Glow('glow', '#58b020', '#a8f048', '#f0ffc0')
  $s.Contrast = 1.15
}
function Earth($s, [double]$x) { $s.Group('earth', 1.2); $s.Ell($x, 0.1, 0, 6.6, 1.0, 5.6, 0, 0, 0, ''); $s.Ell($x - 4.6, 0.3, 3, 2.6, 1.2, 2.4, 0, 0, 0, ''); $s.Ell($x + 5, 0.3, 2, 2.8, 1.3, 2.4, 0, 0, 0, '') }
function Ring($s, [double]$x, [double]$y, [double]$r, [double]$rz = 0) {
  $s.Push($x, $y, 0, 0, 0, $rz); $s.Group('stem', 0.6)
  for ($i = 0; $i -lt 12; $i++) { $a = $i * [Math]::PI / 6; $s.Cap($r * [Math]::Cos($a), 0.4, $r * [Math]::Sin($a), ($r + 1.4) * [Math]::Cos($a), -1.4 - 0.7 * ($i % 2), ($r + 1.4) * [Math]::Sin($a), 0.7, 0.5, '') }
  $s.Pop()
}
# Cap: dome (width, height), flat underside with gills, warts as [azimuth, elevation, size].
function Hat($s, [string]$m, [double]$x, [double]$y, [double]$z, [double]$rx, [double]$rz, [double]$w, [double]$h, $warts, [string]$wm = 'wart') {
  $s.Push($x, $y, $z, $rx, 0, $rz)
  $s.Group($m, 1.2); $s.Ell(0, 0, 0, $w, $h, $w, 0, 0, 0, ''); $s.Cut(0, -$h - 0.5, 0, $w * 1.5, $h, $w * 1.5, 0, 0, 0, 'gill')
  $s.Group('gill', 0); for ($i = 0; $i -lt 24; $i++) { $a = $i * [Math]::PI / 12; $s.Cap(2 * [Math]::Cos($a), -0.8, 2 * [Math]::Sin($a), $w * 0.9 * [Math]::Cos($a), -0.4, $w * 0.9 * [Math]::Sin($a), 0.3, 0.35, '') }
  if ($warts) {
    $s.Group($wm, 0.3)
    foreach ($q in $warts) {
      $a = $q[0] * [Math]::PI / 180; $b = $q[1] * [Math]::PI / 180; $u = $q[2]
      $s.Ell($w * [Math]::Cos($b) * [Math]::Sin($a), $h * [Math]::Sin($b), $w * [Math]::Cos($b) * [Math]::Cos($a), $u, $u * 0.55, $u, 0, 0, 0, '')
    }
  }
  $s.Pop()
}
$warts = @(@(-70, 30, 1.5), @(-30, 56, 1.4), @(-16, 18, 1.5), @(22, 40, 1.6), @(56, 18, 1.4), @(76, 48, 1.4), @(-48, 8, 1.0))


function Shroom($s, $A) {
  $s.Yaw = 20
  Earth $s 1
  $s.Group('stem', 1.8); $s.Ell(1, 2.6, 0, 5.4, 3.0, 5.2, 0, 0, 0, ''); $s.Cap(1, 3, 0, (1 - 2 * $A.die), (18 - 13 * $A.die), 0, 4.0, 4.2, '')
  $s.Push(1, (11.4 - 9.4 * $A.die), 0, 0, 34, 0)
  $s.Ell(0, 0.6, 0, 4.7, 5.6, 4.7, 0, 0, 0, '')
  Add-Face $s @{ R = 4.6; eyeY = 2.8; dist = 2.2; slant = 30; eye = 1.25; brow = 0.75; mouthY = -2.6; mouthW = 3.0; mouthH = (1.6 + 0.9 * $A.act + 0.4 * $A.hit); teeth = 4; nose = $false; curve = -0.4 }
  $s.Pop()
  if ($A.die -lt 0.5) { Ring $s 1 (5.8 - 4 * $A.die) 4.0 }
  Hat $s 'red' (1 - 2 * $A.die) (19.4 + 0.15 * $A.s - 14.6 * $A.die) 0 4 (4 - 5 * $A.wind + 6 * $A.act - 5 * $A.hit + 12 * $A.die) 11.4 (7.6 - 0.12 * $A.s - 1.6 * $A.die) $warts
  # Spores burst from under the cap when it strikes.
  if ($A.puff) { $s.Group('glow', 0); foreach ($q in $A.puff) { $s.Ball($q[0], $q[1], $q[2], $q[3], '') } }
}
$still = @{ s = 0.0; wind = 0.0; act = 0.0; hit = 0.0; die = 0.0; puff = $null }
$s = New-Scene; Add-Ramps $s; Shroom $s $still
$bmp = New-Sprite $s; $bmp.Save((Join-Path $Out 'shroom.png'))
if ($Anim) {
  $keys = { param($A)
    $A.puff = $null
    if ($A.anim -eq 'tod' -and $A.f -ge 3 -and $A.f -le 6) { $k = $A.f - 3; $r = 1.5 - 0.3 * $k; $A.puff = @(@((-10 - 2 * $k), (8 + 2.2 * $k), 6, $r), @((-5 - $k), (12 + 3 * $k), 7, ($r * 0.8)), @((8 + 1.6 * $k), (9 + 2.4 * $k), 6, ($r * 0.9)), @((2 + 0.6 * $k), (13 + 3.4 * $k), 5, ($r * 0.7))) }
    if ($A.anim -eq 'angriff' -and $A.f -ge 4 -and $A.f -le 6) { $k = $A.f - 4; $r = 1.5 - 0.4 * $k; $A.puff = @(@((-13 - 2.4 * $k), (13 + 1.0 * $k), 5, $r), @((-11 - 2.0 * $k), (9 - 0.6 * $k), 7, ($r * 0.8)), @((-14 - 2.6 * $k), (9 + 0.4 * $k), 1, ($r * 0.9)), @((-9 - 1.6 * $k), (17 + 1.4 * $k), 7, ($r * 0.7))) }
  }
  Save-Sheets 'shroom' { param($s, $A) Add-Ramps $s; Shroom $s $A } 32 $null @{ breath = 0.02; sway = 0.7; y0 = 1.5; y1 = 10; windBend = -10; actBend = 24; actPx = -3; hitBend = -14; hitPx = 2; pivX = 1.0; pivY = 2.0 } (Get-GameDir) $keys
}