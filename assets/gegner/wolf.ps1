# Wolf (enemy "wolf"): sits and howls, muzzle to the sky; exactly pose 2 of the
# pose sheet (assets/probe/wolf_posen.ps1). Rendered with sdf.ps1; writes
# <Out>/wolf_heulen.png. -Anim writes the animation sheets into
# ui/assets/gegner: howling, the leap (pose 4 of the same sheet), hit.
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('fur', '#1a1c28', '#30374a', '#4d596e', '#728096', '#a3b0be')
  $s.Ramp('inear', '#3a2430', '#5c3844', '#7c5058')
  $s.Ramp('pale', '#3a3f4c', '#5f6673', '#8b929b', '#b9bec0', '#dfe0da')
  $s.Ramp('nose', '#0c0a10', '#1c1a22', '#34343e')
  $s.Ramp('mouth', '#22060c', '#4a1018', '#7c2430')
  $s.Ramp('tooth', '#9a9272', '#d8d0a8', '#f8f2d8')
  $s.Rough('fur', 0.06, 0)
}
$eye = 'Y=#ffd040,O=#e07818'

# Leg from the joint through the bend to the paw.
function Leg($s, $p, [double]$r = 1.5) {
  $s.Group('fur', 1.2)
  $s.Chain([double[]]($p[0..8]), $r, 0.85, '')
  $s.Ell($p[6] - 0.6, $p[7], $p[8], 1.4, 0.7, 1.0, 0, 0, 0, '')
}
# Head in its own frame, muzzle to -x. $open 0..1 opens the jaws.
function Head($s, $x, $y, $z, $ry, $rz, [double]$open, [double]$ear = 0) {
  $s.Push($x, $y, $z, 0, $ry, $rz)
  $s.Group('fur', 1.0)
  $s.Ell(0, 0, 0, 3.0, 2.7, 2.9, 0, 0, 0, '')
  $s.Cap(-1.8, 0.2, 0, -6.2, -0.4, 0, 1.6, 1.0, '')
  foreach ($d in -1, 1) { $s.Cap(0.4, -0.8, 2.0 * $d, 2.6, -3.0, 2.9 * $d, 1.5, 0.4, 'pale') }
  # Jaws: pale lower jaw hinged below the skull, red throat, long fangs.
  $s.Group('pale', 0.5)
  $s.Push(-0.8, -1.4, 0, 0, 0, 36 * $open); $s.Cap(0, 0, 0, -4.6, -0.2, 0, 1.0, 0.7, ''); $s.Pop()
  $s.Group('mouth', 0); $s.Ell(-2.8, -1.3 - 0.8 * $open, 0, 2.3, 0.4 + 1.1 * $open, 0.8, 0, 0, 14 * $open, '')
  $s.Group('tooth', 0)
  foreach ($d in -0.8, 0.8) {
    $s.Cap(-5.6, -1.2, $d, -5.8, -3.0, $d, 0.6, 0.3, ''); $s.Cap(-3.4, -1.2, $d * 1.3, -3.4, -2.4, $d * 1.3, 0.5, 0.3, '')
  }
  $s.Group('nose', 0); $s.Ball(-7.0, -0.1, 0, 0.95, '')
  $s.Group('fur', 0.3)
  foreach ($d in -1, 1) {
    $s.Cap(0.8, 1.6, 1.7 * $d, 1.6 + 2.6 * $ear, 6.2 - 2.0 * $ear, 2.7 * $d, 1.6, 0.45, '')
    $s.Cap(0.0, 2.6, 2.0 * $d, 0.9 + 2.4 * $ear, 4.8 - 1.8 * $ear, 2.8 * $d, 0.7, 0.3, 'inear')
  }
  $s.Mark(-2.4, 1.1, 1.8, 'YO', $eye, $false); $s.Mark(-2.4, 1.1, -1.8, 'Y', $eye, $false)
  $s.Pop()
}
function Hackles($s, $pts) {
  $s.Group('fur', 0.6)
  for ($i = 0; $i -lt $pts.Count; $i += 3) { $s.Cap($pts[$i], $pts[$i + 1], 0, $pts[$i] + 1.6, $pts[$i + 1] + $pts[$i + 2], 0, 1.2, 0.15, '') }
}
function Torso($s, $hip, $mid, $chest) {
  $s.Group('fur', 3.0)
  $s.Ell($hip[0], $hip[1], 0, $hip[2], $hip[3], 2.9, 0, 0, 0, '')
  $s.Ell($mid[0], $mid[1], 0, $mid[2], $mid[3], 2.6, 0, 0, 0, '')
  $s.Ell($chest[0], $chest[1], 0, $chest[2], $chest[3], 3.4, 0, 0, 0, '')
}

function Wolf($s, $A) {
  $s.Yaw = 24; $s.OffX = -1; $s.OffY = -0.5
  Torso $s @(6, 8, 4.4, 5) @(3, 12, 3.8, 4.2) @(-1, 15, 4.0, 4.6)
  $s.Group('fur', 2); $s.Cap(-2, 17, 0, -3.5, 21.5, 0, 3.4, 2.5, 'pale')
  Leg $s @(7, 6, 2.8, 3, 4.2, 3.2, 6, 0.8, 3.2) 2.4
  Leg $s @(7, 6, -2.8, 3, 4.2, -3.2, 6, 0.8, -3.2) 2.4
  Leg $s @(-2, 12, 2.2, -3.4, 6, 2.4, -3.6, 0.7, 2.4) 1.7
  Leg $s @(-2, 12, -2.2, -5.4, 6, -2.4, -6.2, 0.7, -2.4) 1.6
  $s.Group('fur', 1); $s.Chain([double[]]@(9, 4, 0, 12.5, (1.6 + 0.4 * $A.s), 1, (14 + 0.3 * $A.s), (2.4 + 1.2 * $A.s), (3 - 1.4 * $A.s)), 2.2, 1.0, '')
  Hackles $s @(0.5, 19.4, 1.6, 3, 17, 1.8, 5.4, 14.4, 1.6)
  Head $s -4.4 (22.4 + 0.2 * $A.s) 0 6 (-50 - 3 * $A.s + 16 * $A.wind - 10 * $A.hit) (0.6 + 0.22 * $A.s + 0.4 * $A.hit) 0.6
}
# Stalking and leaping, for the attack.
function Stalk($s) {
  $s.Yaw = 26; $s.OffX = -0.5; $s.Zoom = 0.94
  Torso $s @(7, 11.5, 4, 3.6) @(2, 11.5, 4.5, 2.8) @(-3.5, 12.2, 4.4, 4.2)
  $s.Group('fur', 2); $s.Cap(-5, 13, 0, -9, 9.5, 0, 3.2, 2.4, '')
  Leg $s @(8, 10, 2.2, 10.2, 6, 2.4, 8.2, 0.7, 2.6) 2.2; Leg $s @(8, 10, -2.2, 12, 6, -2.4, 11, 0.7, -2.6) 2.0
  Leg $s @(-4, 9.5, 2.6, -2.6, 5, 2.8, -5.0, 0.7, 2.8) 1.7; Leg $s @(-5, 9.5, -2.6, -9, 6, -2.6, -11, 0.7, -2.8) 1.5
  $s.Group('fur', 1); $s.Chain([double[]](10.5, 12, 0, 13, 10, 0, 14.0, 5.5, 0), 2.2, 1.0, '')
  Hackles $s @(-6, 15.4, 2.2, -3.5, 16, 2.4, -0.8, 15, 1.8, 2, 14, 1.2)
  Head $s -9.6 9.0 0.5 16 10 0.5 0.35
}
function Leap($s) {
  $s.Yaw = 26; $s.OffX = -0.5; $s.Zoom = 0.94
  Torso $s @(6.5, 11, 4.2, 3.4) @(1.5, 13.4, 4.6, 2.9) @(-3.5, 16, 4.4, 4.0)
  $s.Group('fur', 2); $s.Cap(-5, 17.4, 0, -8, 18.4, 0, 3.1, 2.4, '')
  Leg $s @(8, 9.5, 2.2, 11, 5.6, 2.6, 13.2, 1.4, 2.6) 2.1; Leg $s @(7, 9.5, -2.2, 8.6, 5, -2.6, 10.6, 0.8, -2.6) 2.1
  Leg $s @(-5, 14, 2.6, -8.6, 11, 3, -12.4, 9.8, 3) 1.6; Leg $s @(-4, 14, -2.6, -6.6, 9, -3, -10, 6.6, -3) 1.6
  $s.Group('fur', 1); $s.Chain([double[]](9.6, 13, 0, 12.4, 15.4, 0, 14.6, 16, 0), 2.1, 0.9, '')
  Hackles $s @(-5.5, 20, 1.8, -2.8, 19.6, 1.8, 0, 17.4, 1.4)
  Head $s -8 18.6 0.4 12 4 1.0 0.5
}
$still = @{ s = 0.0; wind = 0.0; act = 0.0; hit = 0.0 }
$s = New-Scene; Add-Ramps $s; Wolf $s $still
$bmp = New-Sprite $s; $bmp.Save((Join-Path $Out 'wolf_heulen.png'))
if ($Anim) {
  $build = { param($s, $A) Add-Ramps $s; if ($A.pose -eq 'stalk') { Stalk $s } elseif ($A.pose -eq 'leap') { Leap $s } else { Wolf $s $A } }
  $keys = { param($A)
    $A.pose = 'howl'
    if ($A.anim -eq 'angriff') {
      $A.bend = 0.0; $A.pose = @('howl', 'stalk', 'stalk', 'leap', 'leap', 'leap', 'stalk', 'howl')[$A.f]
      $A.px = @(0, 1, 3, -2, -6, -7, -3, 0)[$A.f]; $A.py = @(0, 0, -1, 2, 4, 1, 0, 0)[$A.f]
    }
  }
  Save-Sheets 'wolf' $build 32 $null @{ breath = 0.012; y0 = 3; y1 = 16; hitBend = -14; hitPx = 3; tod = @{ rx = -82; pvZ = -3.4; px = -1; marksUntil = 2 } } (Get-GameDir) $keys
}