# Ice knight (enemy "knight", elite, 48 x 48): undead knight; exactly pose 1
# of assets/probe/knight_posen.ps1. Writes <Out>/knight.png; -Anim writes the
# animation sheets into ui/assets/gegner (breathing, sword blow, hit, armour
# falls apart).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
. (Join-Path $PSScriptRoot 'ritter.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) { Add-UndeadRamps $s }
# Closed great helm, cracked: slit with two cold eyes, ice crest.
function Helm($s, [double]$x, [double]$y, [double]$z, [double]$ry, [double]$rz) {
  $s.Push($x, $y, $z, 0, $ry, $rz); $s.Group('plate', 0.7); $s.Ell(0, 0.6, 0, 3.4, 3.8, 3.3, 0, 0, 0, ''); $s.Cap(-1.8, -1.6, 0, -2.6, -3.0, 0, 1.9, 1.4, ''); $s.Cut(-3.4, 0.4, 0, 1.6, 0.8, 2.6, 0, 0, 0, 'dark')
  $s.Group('trim', 0.2); $s.Cap(-3.4, 3.2, 0, -4.2, -2.6, 0, 0.6, 0.6, ''); $s.Group('ice', 0.3); foreach ($q in @(-1.0, 5.0), @(0.8, 6.4), @(2.4, 5.4), @(3.6, 3.4)) { $s.Cap($q[0] * 0.7, 3.2, 0, $q[0] * 1.2 + 0.6, 3.2 + $q[1] * 0.7, 0, 1.1, 0.4, '') }
  $s.Mark(-3.2, 0.3, 0, 'kcckcck', 'k=#06080e,c=#98ecff', $true); $s.Pop()
}

# Hands (x, y, how far out the elbows go) and blade angle per frame of the blow;
# the sword rests with its tip on the ground.
$script:blow = @(@(-5.2, 15.6, -1.4, 17.6, -90), @(-6.4, 20, -3, 19.4, -160), @(-3, 26.5, -3.4, 23.6, -300), @(-8.6, 20.4, -4.6, 20.6, -182), @(-8.8, 17.4, -4.4, 18.8, -158), @(-8, 16.4, -3.6, 18.2, -138), @(-6.2, 15.8, -2.2, 17.8, -108), @(-5.2, 15.6, -1.4, 17.6, -90))
function Build($s, $A) {
  $s.Yaw = 48; $u = 0.2 * $A.s
  $b = if ($A.anim -eq 'angriff') { $script:blow[$A.f] } else { $script:blow[0] }; $a = $b[4] * [Math]::PI / 180
  Cape $s 3 21 5 (1 + 0.8 * $A.s + 2 * $A.act); PLeg $s 1.4 11.4 2.8 0.8 0.8; PLeg $s 1.8 11.4 -2.8 1.4 2
  $s.Push(1.6, 12, 0, 0, 0, 4); PTorso $s; $s.Pop()
  PArm $s @(0.4, (23 + $u), -6.4, $b[2], $b[3], -7.4, $b[0], $b[1], -1.6) -1; PArm $s @(0.4, (23 + $u), 6.4, $b[2], $b[3], 7.4, $b[0], $b[1], 1.6) 1
  Sword $s ($b[0] - 1.0) ($b[1] - 0.6) 0 ([Math]::Round([Math]::Cos($a), 9)) ([Math]::Sin($a)) 16 1.9; Helm $s -0.4 (27.4 + $u) 0 8 (6 - 4 * $A.wind + 4 * $A.act - 12 * $A.hit)
}
$still = { param($s) Add-Ramps $s; $s.Zoom = 1.45; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 48 $true
$bmp.Save((Join-Path $Out 'knight.png'))
if ($Anim) { Save-Sheets 'knight' { param($s, $A) Add-Ramps $s; $s.Zoom = 1.45; Build $s $A } 48 (Get-Fit $still 48) @{ breath = 0.0; y0 = 9; y1 = 16; windBend = -5; actBend = 10; actPx = -2; windPx = 3; hitBend = -8; hitPx = 2; pivX = 1.6; pivY = 11.0; tod = @{ fx = 'chunks'; cell = 6.5; seed = 6; spread = 0.8; pile = 0.2; from = 2; marksUntil = 3 } } (Get-GameDir) }
