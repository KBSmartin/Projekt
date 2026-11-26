# Ember scorpion (enemy "scorp"): claw snapping forward; pose 4 of
# assets/probe/scorp_posen.ps1 with a clearer head. Writes <Out>/scorp.png;
# -Anim writes the animation sheets into ui/assets/gegner (tail swaying, sting
# over the head, hit, rolls onto its back).
param([string]$Out = (Join-Path $PSScriptRoot '..\probe'), [switch]$Anim)
. (Join-Path $PSScriptRoot 'sdf.ps1')
. (Join-Path $PSScriptRoot 'gesicht.ps1')
. (Join-Path $PSScriptRoot 'anim.ps1')
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('shell', '#1c0c14', '#4c1c26', '#883430', '#c0583a', '#f0985c')
  $s.Ramp("claw", "#34141a", "#74302a", "#b8563a", "#ee9252", "#ffd08c"); $s.Ramp("leg", "#12080c", "#2c141a", "#4e2224", "#7a362c")
  $s.Ramp('fang', '#7c5c40', '#c8a878', '#f8e8c0'); $s.Ramp('under', '#2a1410', '#5c2c1c', '#94502c', '#cc8448')
  $s.Glow('lava', '#d8421a', '#ff8c2a', '#ffd860', '#fff4b8')

  $s.Contrast = 1.2; $s.EdgeDepth = 1.8; $s.EdgeSame = 5
}
$eye = 'y=#ffd860,w=#fff4b8,r=#ff6a2a'
# Leg with knee up and out; $a is where it points, $side the body side.
function Leg($s, [double]$x, [double]$y, [double]$side, [double]$fx, [double]$fz) {
  $s.Group("leg", 0.5); $s.Chain([double[]]@($x, $y, (3.0 * $side), (($x + $fx) / 2), ($y + 2.2), (($fz * 0.62) * $side), $fx, 0.5, ($fz * $side)), 1.2, 0.55, '')
}
# Claw: upper arm, forearm, bulb and two fingers opening along (dx, dy).
function Claw($s, $p, [double]$dx, [double]$dy, [double]$open, [double]$k = 1) {
  $k = $k * 1.4
  $s.Group("shell", 0.6); $s.Chain([double[]]$p, (1.1 * $k), (1.0 * $k), "")
  $n = $p.Count; [double]$x = $p[$n - 3]; [double]$y = $p[$n - 2]; [double]$z = $p[$n - 1]
  $a = [Math]::Atan2($dy, $dx) * 180 / [Math]::PI
  $s.Push($x, $y, $z, 0, 0, $a)
  $s.Group("claw", 0.8); $s.Ell(1.4 * $k, 0, 0, 2.4 * $k, 2.2 * $k, 1.9 * $k, 0, 0, 0, '')
  $s.Push(3.0 * $k, 1.3 * $k, 0, 0, 0, 22 * $open); $s.Chain([double[]]@(0, 0, 0, (2.2 * $k), (1.1 * $k), 0, (4.4 * $k), (0.9 * $k), 0, (6.2 * $k), (-0.8 * $k), 0), (1.0 * $k), 0.5, ""); $s.Pop()
  $s.Push(3.0 * $k, -1.3 * $k, 0, 0, 0, -22 * $open); $s.Chain([double[]]@(0, 0, 0, (2.0 * $k), (-1.0 * $k), 0, (4.0 * $k), (-0.8 * $k), 0, (5.6 * $k), (0.7 * $k), 0), (0.9 * $k), 0.5, ""); $s.Pop()
  $s.Pop()
}
# Tail: segments along the points, stinger bulb and a glowing sting.
function Tail($s, $pts, [double]$sx, [double]$sy) {
  $n = $pts.Count / 3
  for ($i = 0; $i -lt $n; $i++) { $s.Group('shell', 0.2); $r = 2.3 - 0.8 * $i / $n; $s.Ell($pts[$i * 3], $pts[$i * 3 + 1], $pts[$i * 3 + 2], $r, $r, $r, 0, 0, 0, '') }
  for ($i = 1; $i -lt $n; $i++) { $s.Group("lava", 0); $s.Ball(($pts[$i * 3] + $pts[$i * 3 - 3]) / 2, ($pts[$i * 3 + 1] + $pts[$i * 3 - 2]) / 2, ($pts[$i * 3 + 2] + $pts[$i * 3 - 1]) / 2, 1.5, "") }
  [double]$x = $pts[$pts.Count - 3]; [double]$y = $pts[$pts.Count - 2]; [double]$z = $pts[$pts.Count - 1]
  $s.Group('shell', 0.4); $s.Ell($x + $sx * 1.6, $y + $sy * 1.6, $z, 2.2, 2.2, 2.0, 0, 0, 0, '')
  $s.Group('lava', 0.3); $s.Chain([double[]]@(($x + $sx * 2.8), ($y + $sy * 2.8), $z, ($x + $sx * 4.6 - 0.4), ($y + $sy * 4.6 - 0.8), $z, ($x + $sx * 5.6 - 1.4), ($y + $sy * 5.6 - 2.4), $z), 1.2, 0.5, '')
}
function Body($s, [double]$hy, [double]$ry) {
  $s.Group('shell', 0.3)
  foreach ($q in @(6.6, 4.2, 3.0, 2.3), @(3.8, 4.6, 3.6, 2.7), @(0.8, 4.8, 3.9, 2.9)) { $s.Group('shell', 0.3); $s.Ell($q[0], $q[1] + $hy * 0.2, 0, 2.6, $q[3], $q[2], 0, 0, 0, '') }
  # Head shield raised clear of the claws, turned to the viewer: brow plate,
  # two eyes in dark sockets, pale mandibles.
  $s.Push(-3.0, 8.4 + $hy, 0.6, 0, ($ry + 24), 4); $s.Group('shell', 0.8); $s.Ell(2.2, -1.6, 0, 3.8, 3.4, 3.8, 0, 0, 0, ''); $s.Group('claw', 0.8); $s.Ell(0, 0, 0, 4.4, 3.2, 4.6, 0, 0, 0, ''); $s.Ell(-2.2, -1.0, 0, 2.6, 2.2, 3.6, 0, 0, 0, '')
  foreach ($d in -1, 1) { $s.Cap(-3.6, 1.4, 0.8 * $d, -2.4, 2.8, 3.0 * $d, 0.9, 0.6, '') }
  $s.Group('fang', 0.2); foreach ($d in -1, 1) { $s.Cap(-4.0, -2.2, 1.7 * $d, -5.0, -4.2, 0.9 * $d, 1.0, 0.5, '') }
  $s.Mark(-4.0, 0.4, 0, 'ykk.kky/kyk.kyk/.k...k.', 'k=#140608,y=#ffd850', $true)
  $s.Pop()
}
function Legs($s) { foreach ($q in @(-1.4, -4.4, 8.4), @(1.0, -0.4, 9.6), @(3.6, 5.0, 9.4), @(6.0, 9.6, 8.0)) { foreach ($d in -1, 1) { Leg $s $q[0] 4.2 $d $q[1] $q[2] } } }

function Build($s, $A) {
  $s.Yaw = 30; $s.Pitch = 16
  if ($A.die -gt 0.6) { $s.Douse('lava', '#3a1418', '#642420', '#883430') }
  Body $s 0 10; Legs $s
  # The tail whips forward over the head to sting.
  $t = Get-Swing @(9, 5, 0, 12, 7.4, -1, 14, 11, -1, 14, 15.4, -1, 11.6, 19, -1, 8, 21, -1) @(9, 5, 0, 12.4, 7.4, -1, 15.4, 11, -1, 16.4, 15.4, -1, 15, 19.6, -1, 11.6, 22, -1) @(8.4, 5, 0, 10.4, 9, -1, 9.6, 14, -1, 5.4, 17.6, -1, -0.4, 18.4, -1, -5.6, 16.6, -1) $A
  for ($i = 1; $i -lt 6; $i++) { $t[$i * 3] += 0.28 * $i * $A.s; $t[$i * 3 + 1] += 0.06 * $i * $A.s }
  Tail $s $t (-0.8 + 0.1 * $A.act) (0.3 - 0.9 * $A.act)
  Claw $s @((-3.4), 5, -4.2, (-7 + 0.8 * $A.wind - 1.2 * $A.act), (7.0 + 0.2 * $A.s), -8, (-10 + 1.4 * $A.wind - 2.0 * $A.act), (8.0 + 0.3 * $A.s), -8) -0.95 0.25 (1.2 + 0.25 * $A.s + 0.6 * $A.wind - 1.0 * $A.act + 0.5 * $A.hit) 1.25; Claw $s @(0, 4.0, 4.4, 3.4, 4.8, 9.6, (2.4 - 1.4 * $A.act), 3.2, 12.4) -0.97 -0.04 (0.8 - 0.2 * $A.s + 0.6 * $A.wind - 0.6 * $A.act + 0.4 * $A.hit) 0.8
}
$still = { param($s) Add-Ramps $s; Build $s (Get-Still) }
$bmp = New-FittedSprite $still 32 $true
$bmp.Save((Join-Path $Out 'scorp.png'))
if ($Anim) { Save-Sheets 'scorp' { param($s, $A) Add-Ramps $s; Build $s $A } 32 (Get-Fit $still 32) @{ breath = 0.01; y0 = 2; y1 = 10; windBend = -4; actBend = 4; actPx = -4; windPx = 2; hitBend = -10; hitPx = 3; tod = @{ rx = -172; pvY = 5.4; py = 1; marksUntil = 2 } } (Get-GameDir) }
