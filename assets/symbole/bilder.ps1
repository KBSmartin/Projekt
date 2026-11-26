# Pictures rendered like the enemies (gegner/sdf.ps1): relics 16x16 (shown 2x
# and 3x), events, regions, campfire and end screens 32x32 (shown 3x). Writes
# <Out>/<name>.png; -Only a,b renders just some of them.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\symbole'), [string]$Only = '')
. (Join-Path $PSScriptRoot '..\gegner\sdf.ps1')
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = [IO.Path]::GetFullPath($Out)

function Add-Ramps($s) {
  $s.Ramp('stone', '#17171d', '#35373c', '#5c5f5c', '#8c8e7e', '#c2c2a6')
  $s.Ramp('red', '#24060c', '#541018', '#8c2024', '#c04438', '#f08468')
  $s.Ramp('steel', '#14161e', '#343c4a', '#64707c', '#a0acb4', '#e4ecf0')
  $s.Ramp('gold', '#2c1a0a', '#704818', '#b8842c', '#e8bc4c', '#fff0a8')
  $s.Ramp('wood', '#1a120e', '#3c281c', '#664830', '#94704c', '#c49c70')
  $s.Ramp('bone', '#38322c', '#746a5c', '#b0a48c', '#dcd4bc', '#fffbe8')
  $s.Ramp('cloth', '#0c0a12', '#1e1a2a', '#342e44', '#524a64', '#7c7290')
  $s.Ramp('leaf', '#0c1c10', '#1c3c1c', '#346428', '#5c9438', '#a0cc58')
  $s.Ramp('sand', '#3a2414', '#74482a', '#b07c48', '#dcac70', '#f8dca0')
  $s.Ramp('snow', '#344a70', '#6c8cb4', '#a8c8e0', '#dceef8', '#ffffff')
  $s.Ramp('rock', '#101624', '#222e44', '#3c4c68', '#60748c', '#90a4b4')
  $s.Ramp('water', '#0e2c50', '#1c5890', '#3890c8', '#78c8e8', '#e0fcff')
  $s.Ramp('gem', '#3a0414', '#80081c', '#c81c2c', '#f85848', '#ffc0a0')
  $s.Ramp('tea', '#1c2c10', '#3c5418', '#64842c', '#98b850')
  $s.Ramp('dark', '#06060a', '#0c0c12', '#14141c')
  $s.Glow('glow', '#1890c8', '#5cdcff', '#e4ffff'); $s.Glow('eye', '#c81c1c', '#ff5c3c', '#ffd0a0'); $s.Glow('lamp', '#e08020', '#ffc848', '#fff0b0')
  $s.Fire('flame', '#701410', '#c8321a', '#f4681e', '#ffa62c', '#ffe070')
  $s.Contrast = 1.15; $s.EdgeDepth = 1.8
}
function Grp($s, [string]$m, [double]$k = 0.3) { $s.Group($m, $k) }
function Cone($s, [double]$x, [double]$y, [double]$z, [double]$h, [double]$r, [string]$m) { $s.Group($m, 0.4); $s.Cap($x, $y, $z, $x, ($y + $h), $z, $r, 0.4, '') }
# Ring of balls (horizontal): crown rims, wells, stone circles.
function Ring($s, [double]$x, [double]$y, [double]$z, [double]$r, [double]$b, [int]$n, [double]$squash = 1) { for ($i = 0; $i -lt $n; $i++) { $a = $i * 2 * [Math]::PI / $n; $s.Ell(($x + $r * [Math]::Cos($a)), $y, ($z + $r * [Math]::Sin($a)), $b, ($b * $squash), $b, 0, 0, 0, '') } }

$art = [ordered]@{
  # --- relics, 16x16 ---
  anchor = @{ n = 16; f = { param($s)
    $s.Yaw = 0; $s.Pitch = 4
    Grp $s 'steel'; $s.Cap(0, 2.4, 0, 0, 10, 0, 0.95, 0.95, ''); $s.Cap(-2.8, 8.6, 0, 2.8, 8.6, 0, 0.8, 0.8, '')
    foreach ($q in -1, 1) { $s.Chain([double[]]@(0, 1.8, 0, (2.6 * $q), 2.2, 0, (4.4 * $q), 3.8, 0, (5.2 * $q), 5.6, 0), 1.0, 0.7, ''); $s.Cap((5.2 * $q), 6.2, 0, (4.2 * $q), 4.6, 0, 0.5, 1.0, '') }
    Grp $s 'gold' 0.2; for ($i = 0; $i -lt 10; $i++) { $a = $i * 0.628; $s.Ball((1.7 * [Math]::Cos($a)), (12 + 1.7 * [Math]::Sin($a)), 0, 0.75, '') } } }
  ruby = @{ n = 16; f = { param($s)
    $s.Yaw = 24; $s.Pitch = 16; $s.Shadow = $false
    Grp $s 'gem' 0; $s.Gem(0, 6.4, 0, 5.4, 6.2, 5.4, 0, 12, 0, '') } }
  core = @{ n = 16; f = { param($s)
    $s.Yaw = 20; $s.Pitch = 12
    Grp $s 'steel'; $s.Cap(0, 0.9, -1.2, 0, 0.9, 1.2, 2.6, 2.6, ''); $s.Box(0, 1.0, 0, 3.6, 1.1, 3.6, 0, 0, 0, 0.5, ''); $s.Box(0, 11.6, 0, 3.6, 1.1, 3.6, 0, 0, 0, 0.5, '')
    foreach ($q in @(-2.9, -2.9), @(2.9, -2.9), @(-2.9, 2.9), @(2.9, 2.9)) { $s.Group('gold', 0); $s.Cap($q[0], 1.4, $q[1], $q[0], 11.2, $q[1], 0.7, 0.7, '') }
    Grp $s 'glow' 0; $s.Ball(0, 6.3, 0, 3.0, '') } }
  tea = @{ n = 16; f = { param($s)
    $s.Yaw = 16; $s.Pitch = 24; $s.Rough('bone', 0, 0.16); $s.Rough('tea', 0, 0.2)
    Grp $s 'bone' 0.5; $s.Cap(0, 3.0, 0, 0, 6.6, 0, 3.4, 4.6, ''); $s.Cut(0, 9.8, 0, 8, 4.0, 8, 0, 0, 0, 'bone'); $s.Cut(0, 6.8, 0, 3.5, 2.6, 3.5, 0, 0, 0, 'tea')
    Grp $s 'bone' 0.2; $s.Chain([double[]]@(4.0, 5.2, 0, 6.2, 5.0, 0, 6.4, 3.0, 0, 3.6, 2.4, 0), 0.8, 0.8, ''); Grp $s 'tea' 0; $s.Ell(0, 5.0, 0, 3.7, 0.5, 3.7, 0, 0, 0, '')
    Grp $s 'wood' 0.2; $s.Ell(0, 0.4, 0, 6, 0.6, 5, 0, 0, 0, ''); Grp $s 'leaf' 0.2; $s.Ell(-1.2, 5.7, 1.2, 1.6, 0.4, 0.9, 0, 30, 0, '') } }
  lens = @{ n = 16; f = { param($s)
    $s.Yaw = 0; $s.Pitch = 0; $s.Shadow = $false
    Grp $s 'wood' 0.3; $s.Cap(-5.4, 1.4, 0, -2.4, 4.6, 0, 1.4, 1.0, ''); Grp $s 'gold' 0.2; for ($i = 0; $i -lt 18; $i++) { $a = $i * 0.349; $s.Ball((2 + 4.4 * [Math]::Cos($a)), (8.6 + 4.4 * [Math]::Sin($a)), 0, 1.05, '') }
    Grp $s 'water' 0; $s.Ell(2, 8.6, 0, 4.0, 4.0, 0.9, 0, 0, 0, ''); $s.Mark(0.6, 10.2, 1, '.ww/w../', 'w=#f4ffff', $true) } }
  coin = @{ n = 16; f = { param($s)
    $s.Yaw = 0; $s.Pitch = 0; $s.Shadow = $false
    Grp $s 'gold' 0.2; $s.Ell(0, 6.4, 0, 6.2, 6.2, 1.2, 0, 0, 0, ''); for ($i = 0; $i -lt 24; $i++) { $a = $i * 0.2618; $s.Ball((5.4 * [Math]::Cos($a)), (6.4 + 5.4 * [Math]::Sin($a)), 0.6, 0.8, '') }
    # Four-leaf clover in relief.
    $s.Mark(0.2, 6.2, 2, 'gg.ll/gg.ll/..d../gg.gg/gg.dg/...d.', 'g=#346428,l=#7cb848,d=#1c3c1c', $true) } }
  # --- events, 32x32 ---
  altar = @{ n = 32; f = { param($s)
    $s.Yaw = 30; $s.Pitch = 16; $s.Crack('stone', 0.08, 5); $s.Rough('red', 0.05, 0.02)
    Grp $s 'stone' 0.2; $s.Box(0, 1.2, 0, 10, 1.4, 8, 0, 0, 0, 0.5, ''); Grp $s 'red' 0.2; $s.Box(0, 7, 0, 5.6, 5, 4.6, 0, 0, 0, 0.6, ''); Grp $s 'stone' 0.2; $s.Box(0, 13, 0, 8.6, 1.5, 6.8, 0, 0, 0, 0.5, '')
    Grp $s 'gold' 0.3; $s.Cap(0, 15, 0, 0, 16.4, 0, 2.0, 4.0, ''); $s.Cut(0, 19.6, 0, 9, 2.4, 9, 0, 0, 0, ''); Grp $s 'eye' 0; $s.Ell(0, 17.3, 0, 3.0, 0.5, 3.0, 0, 0, 0, '')
    Grp $s 'gem' 0; foreach ($q in @(-6.2, 5.2, 4), @(5.4, 6.2, 3), @(-8.0, -1, 2.6)) { $s.Cap($q[0], 12.4, $q[1], $q[0], (12.4 - $q[2]), $q[1], 0.9, 0.5, '') }
    $s.Mark(-4.2, 7.4, 4.7, '.kk./kyyk/.kk.', 'k=#24060c,y=#ff9c5c', $true)
    foreach ($q in -1, 1) { Grp $s 'bone' 0.2; $s.Cap((9.4 * $q), 2.6, 4.6, (9.4 * $q), 6, 4.6, 1.2, 1.1, ''); Grp $s 'flame' 0.4; $s.Cap((9.4 * $q), 7.4, 4.6, (9.6 * $q), 10.4, 4.6, 1.5, 0.4, '') } } }
  spring = @{ n = 32; f = { param($s)
    $s.Yaw = 24; $s.Pitch = 26; $s.Crack('stone', 0.06, 4)
    Grp $s 'leaf' 0.8; $s.Ell(0, 0, 0, 14, 1.0, 10, 0, 0, 0, ''); Grp $s 'stone' 0.3; Ring $s 0 1.6 0 9.6 2.4 13 0.8
    Grp $s 'water' 0; $s.Ell(0, 1.4, 0, 8.8, 1.0, 8.8, 0, 0, 0, '')
    Grp $s 'stone' 0.8; $s.Ell(3, 4.6, -7, 5.4, 6.0, 3.6, 0, 0, 0, ''); $s.Ell(-4, 3.6, -7.4, 4.6, 4.6, 3.2, 0, 0, 0, ''); $s.Ell(5, 10, -8, 3.2, 3.4, 2.6, 0, 0, 0, '')
    Grp $s 'water' 0.4; $s.Chain([double[]]@(2, 10.4, -5, 1, 8.8, -2.2, 0.4, 5, -1, 0.2, 2, -0.6), 1.2, 1.7, ''); Grp $s 'snow' 0.3; foreach ($q in @(-1.4, 0.6), @(1.8, 0.4), @(0.2, 1.6)) { $s.Ball($q[0], 2.4, $q[1], 0.9, '') }
    Grp $s 'leaf' 0.5; foreach ($q in @(-10, 4), @(10.4, 2), @(-8, -6)) { foreach ($d in -1, 0, 1) { $s.Cap($q[0], 1, $q[1], ($q[0] + 1.6 * $d), 5, $q[1], 0.9, 0.4, '') } } } }
  chest = @{ n = 32; f = { param($s)
    $s.Yaw = 34; $s.Pitch = 18; $s.Grain('wood', 0.06); $s.EdgeSame = 5
    Grp $s 'wood' 0.2; $s.Box(0, 5, 0, 10, 5, 6.4, 0, 0, 0, 0.5, ''); Grp $s 'wood' 0.2; $s.Cap(-9.4, 11, 0, 9.4, 11, 0, 5.4, 5.4, ''); $s.Cut(0, 11, 0, 0.01, 0.01, 0.01, 0, 0, 0, '')
    Grp $s 'dark' 0; $s.Box(0, 10.2, 0, 10.2, 0.5, 6.6, 0, 0, 0, 0.1, '')
    Grp $s 'steel' 0.2; foreach ($x in -8.4, 0, 8.4) { $s.Box($x, 5, 0, 1.0, 5.2, 6.8, 0, 0, 0, 0.3, ''); for ($i = 0; $i -le 8; $i++) { $a = $i * 0.3927; $s.Ball($x, (11 + 5.4 * [Math]::Sin($a)), (5.4 * [Math]::Cos($a)), 1.1, '') } }
    Grp $s 'gold' 0.2; $s.Box(0, 9.6, 6.8, 2.0, 2.4, 0.8, 0, 0, 0, 0.5, ''); $s.Mark(0, 9.4, 7.8, 'k/k', 'k=#0c0a10', $true)
    $s.Mark(-4.6, 12.4, 5.6, 'g.g/.g./ggg', 'g=#5cdcff', $true); $s.Mark(4.6, 12.4, 5.6, 'ggg/g../.gg', 'g=#5cdcff', $true) } }
  smith = @{ n = 32; f = { param($s)
    $s.Yaw = 16; $s.Pitch = 14; $s.Grain('wood', 0.05)
    Grp $s 'wood' 0.3; $s.Cap(0, 1.6, 0, 0, 6, 0, 5.2, 4.8, ''); Grp $s 'steel' 0.4; $s.Box(0, 9.2, 0, 4.6, 1.6, 3.2, 0, 0, 0, 0.5, ''); $s.Box(0, 11.2, 0, 3.0, 2, 2.4, 0, 0, 0, 0.5, ''); $s.Box(1, 14.4, 0, 7.4, 1.9, 3.6, 0, 0, 0, 0.5, ''); $s.Cap(-5.4, 14.4, 0, -12, 15.2, 0, 2.0, 0.5, '')
    # Hammer lying on the anvil, a glowing blank under it.
    Grp $s 'lamp' 0; $s.Cap(-4, 16.8, 1.4, 5, 16.8, 1.4, 0.9, 0.9, '')
    Grp $s 'wood' 0; $s.Cap(0.6, 20.4, 0, 11.4, 26, 0, 0.9, 0.9, ''); $s.Push(0.4, 20.4, 0, 0, 0, 28); Grp $s 'steel' 0.2; $s.Box(0, 0, 0, 2.2, 4.2, 2.2, 0, 0, 0, 0.5, ''); $s.Pop()
    Grp $s 'lamp' 0; foreach ($q in @(-5, 20), @(-7, 17.6), @(-3.4, 22.6)) { $s.Ball($q[0], $q[1], 2, 0.7, '') } } }
  dice = @{ n = 32; f = { param($s)
    $s.Yaw = 0; $s.Pitch = 22; $s.Shadow = $true
    Grp $s 'wood' 0.3; $s.Push(6, 4.0, -4, 0, 0, 62); $s.Cap(0, -4, 0, 0, 5, 0, 3.6, 4.8, ''); $s.Cut(0, 9.6, 0, 4.2, 6, 4.2, 0, 0, 0, 'dark'); Grp $s 'gold' 0.2; $s.Cap(0, -2, 0, 0, -1.6, 0, 4.2, 4.2, ''); $s.Pop()
    foreach ($q in @(-7.4, 4.0, 2.0, 28, '1'), @(1.6, 3.6, 7.0, -24, '2')) {
      $s.Push($q[0], $q[1], $q[2], 0, $q[3], 0); Grp $s 'bone' 0.3; $s.Box(0, 0, 0, 4.0, 4.0, 4.0, 0, 0, 0, 0.8, ''); $s.EdgeSame = 4
      if ($q[4] -eq '1') { foreach ($d in -2, 0, 2) { $s.Mark((1.0 * $d), (1.0 * $d), 4, 'k', 'k=#541018', $true) }; foreach ($d in -1.6, 1.6) { $s.Mark($d, 4, $d, 'k', 'k=#541018', $true) } }
      else { foreach ($d in @(-1.8, -1.8), @(1.8, 1.8), @(-1.8, 1.8), @(1.8, -1.8)) { $s.Mark($d[0], $d[1], 4, 'k', 'k=#541018', $true) }; $s.Mark(0, 4, 0, 'kk', 'k=#541018', $true) }
      $s.Pop() }
    Grp $s 'gold' 0.2; foreach ($q in @(-10, 8), @(-5, 10), @(9, 9)) { $s.Ell($q[0], 0.5, $q[1], 2.0, 0.6, 2.0, 0, 0, 0, '') } } }
  trader = @{ n = 32; f = { param($s)
    $s.Yaw = 22; $s.Pitch = 8
    Grp $s 'cloth' 1.6; $s.Cap(0, 4, 0, 0, 16, 0, 8, 5, ''); $s.Ell(0, 17, 0, 5.4, 3.4, 8.0, 0, 0, 0, ''); Grp $s 'cloth' 0.5; for ($i = 0; $i -lt 12; $i++) { $a = $i * 0.5236; $s.Cap((4 * [Math]::Cos($a)), 14, (5 * [Math]::Sin($a)), (8.6 * [Math]::Cos($a)), (0.8 + ($i % 3)), (8.6 * [Math]::Sin($a)), 1.2, 1.4, '') }
    $s.Push(-1, 22.4, 0, 0, 46, 6); Grp $s 'cloth' 1.0; $s.Ell(0, 0, 0, 4.6, 5.2, 4.6, 0, 0, 0, ''); $s.Cap(0.4, 3.6, 0, 3.6, 5.2, 0, 2.6, 0.8, ''); $s.Cut(-4.4, -0.8, 0, 3.4, 3.6, 3.0, 0, 0, 0, 'dark'); $s.Mark(-2.6, -0.4, 0, 'l...l', 'l=#ffc848', $true); $s.Pop()
    # One hand offers a glowing card.
    Grp $s 'cloth' 0.8; $s.Chain([double[]]@(-1, 17, 6, -5, 13, 9, -8.6, 13.4, 8), 2.4, 2.0, ''); Grp $s 'bone' 0.3; $s.Ball(-9.8, 13.6, 8, 1.4, '')
    $s.Push(-11.4, 17.6, 8.2, 0, 30, 14); Grp $s 'lamp' 0; $s.Box(0, 0, 0, 0.5, 4.2, 3.0, 0, 0, 0, 0.2, ''); $s.Mark(-0.6, 0, 0, '.p./ppp/.p.', 'p=#7a3ab8', $true); $s.Pop()
    Grp $s 'wood' 0.2; $s.Cap(5, 1, -8, 3.4, 27, -9, 0.9, 0.8, ''); Grp $s 'lamp' 0; $s.Ball(3.2, 28.2, -9, 1.8, '') } }
  # --- regions ---
  forest_bild = @{ n = 32; f = { param($s)
    $s.Yaw = 10; $s.Pitch = 10
    Grp $s 'leaf' 1.2; $s.Ell(0, 0, 0, 14, 1.6, 9, 0, 0, 0, '')
    foreach ($t in @(0, 0, 1.0), @(-9, -3, 0.72), @(9, -2, 0.8), @(-4.6, 6, 0.5), @(6, 6.4, 0.46)) { $k = $t[2]; Grp $s 'wood' 0.2; $s.Cap($t[0], 0, $t[1], $t[0], (6 * $k), $t[1], (1.6 * $k), (1.4 * $k), ''); foreach ($l in @(4, 6.4, 9), @(10.6, 5.2, 8), @(16.6, 3.8, 8.4)) { Cone $s $t[0] ($l[0] * $k + 2 * $k) $t[1] ($l[2] * $k) ($l[1] * $k) 'leaf' } }
    $s.Mark(-9, 5, 5, 'y.y', 'y=#ffd040', $true) } }
  desert_bild = @{ n = 32; f = { param($s)
    $s.Yaw = 8; $s.Pitch = 12; $s.Shadow = $false
    Grp $s 'lamp' 0; $s.Ball(6, 21, -14, 5.4, ''); Grp $s 'sand' 1.6; $s.Ell(-6, 0.6, -5, 12, 7, 6, 0, 0, 0, ''); $s.Ell(8, 0, -3, 10, 5.4, 6, 0, 0, 0, ''); Grp $s 'sand' 1.4; $s.Ell(0, -1, 5, 15, 4.4, 6, 0, 0, 0, '')
    Grp $s 'leaf' 0.5; $s.Cap(-5, 3, 7, -5, 14, 7, 1.7, 1.5, ''); $s.Chain([double[]]@(-5, 7, 7, -8.4, 7.4, 7, -8.4, 11, 7), 1.2, 1.1, ''); $s.Chain([double[]]@(-5, 9, 7, -2, 9.4, 7, -2, 12.4, 7), 1.1, 1.0, '')
    Grp $s 'bone' 0.5; $s.Ell(6, 4.0, 9, 2.6, 2.2, 2.2, 0, 0, 0, ''); $s.Box(6, 2.4, 9.8, 1.4, 1.0, 1.2, 0, 0, 0, 0.4, ''); $s.Mark(6, 3.8, 11.6, 'kk.kk/kk.kk/..k..', 'k=#0c0a10', $true); foreach ($q in -1, 1) { $s.Chain([double[]]@((6 + 2 * $q), 5, 9, (6 + 4.4 * $q), 5.6, 9, (6 + 5 * $q), 8, 9), 0.9, 0.4, '') } } }
  fortress_bild = @{ n = 32; f = { param($s)
    $s.Yaw = 20; $s.Pitch = 12; $s.Crack('rock', 0.06, 4)
    Grp $s 'snow' 1.6; $s.Ell(0, 0, 0, 14, 2.4, 10, 0, 0, 0, ''); Grp $s 'rock' 1.0; $s.Ell(0, 1, 0, 11, 5, 7, 0, 0, 0, '')
    Grp $s 'rock' 0.2; $s.Box(0, 9, 0, 8, 5, 4, 0, 0, 0, 0.3, ''); $s.Box(0, 13, -1, 3.4, 10, 3.4, 0, 0, 0, 0.3, ''); foreach ($x in -8.4, 8.4) { Grp $s 'rock' 0.2; $s.Cap($x, 3, 1, $x, 17, 1, 2.9, 2.7, '') }
    foreach ($q in @(-8.4, 17.4, 1, 6, 3.4), @(8.4, 17.4, 1, 6, 3.4), @(0, 22.6, -1, 7, 4.4)) { Cone $s $q[0] ($q[1] + 1.4) $q[2] $q[3] $q[4] 'snow' }
    Grp $s 'snow' 0.3; foreach ($x in -5, -2.4, 2.4, 5) { $s.Box($x, 14.6, 3.4, 0.9, 1.0, 0.8, 0, 0, 0, 0.3, '') }
    $s.Mark(0, 6.6, 4.2, '.kkk./kkkkk/kkkkk/kkkkk', 'k=#0c0a10', $true); $s.Mark(0, 18, 2.6, 'y/y', 'y=#ffd27a', $true); $s.Mark(-8.4, 12, 4, 'y/y', 'y=#8ad0f0', $true); $s.Mark(8.4, 12, 4, 'y/y', 'y=#8ad0f0', $true) } }
  # --- rest and end screens ---
  rast = @{ n = 32; f = { param($s)
    $s.Yaw = 14; $s.Pitch = 22
    Grp $s 'stone' 0.3; Ring $s 0 1.2 0 9.4 2.2 11 0.75
    Grp $s 'wood' 0.2; foreach ($a in 10, 70, 130) { $c = [Math]::Cos($a / 57.3); $d = [Math]::Sin($a / 57.3); $s.Cap((-7.4 * $c), 1.4, (-7.4 * $d), (4 * $c), 5.2, (4 * $d), 1.4, 1.2, '') }
    Grp $s 'flame' 1.4; $s.Ball(0, 6, 0, 4.4, ''); $s.Chain([double[]]@(0, 7, 0, -1.4, 12, 0, 1.0, 16.6, 0, 0.4, 20.6, 0), 4.0, 0.5, ''); $s.Chain([double[]]@(-2, 6, 1, -4.6, 10, 1, -4.0, 14, 1), 2.4, 0.4, ''); $s.Chain([double[]]@(2.4, 6, 1, 4.6, 9.6, 1, 4.0, 12.8, 1), 2.2, 0.4, '')
    Grp $s 'lamp' 0; foreach ($q in @(-6, 17), @(5.4, 18.4), @(2.8, 22.4)) { $s.Ball($q[0], $q[1], 0, 0.7, '') } } }
  sieg = @{ n = 32; f = { param($s)
    $s.Yaw = 0; $s.Pitch = 9; $s.EdgeSame = 9; $s.EdgeDepth = 4; $s.Rough('gold', 0, 0.06)
    Grp $s 'red' 1.0; $s.Ell(0, 1.6, 0, 13, 2.4, 10, 0, 0, 0, ''); foreach ($q in @(-12, 8), @(12, 8), @(-12, -8), @(12, -8)) { $s.Ball(($q[0] * 0.95), 1.4, ($q[1] * 0.9), 1.5, 'gold') }
    Grp $s 'gold' 0.8; Ring $s 0 5.4 0 9.2 1.5 30 0.8; Ring $s 0 8.4 0 9.0 1.1 30 2.2; Ring $s 0 11 0 9.0 1.0 30 1.6
    foreach ($a in 90, 28, 152, 332, 208, 270) { $c = [Math]::Cos($a / 57.3); $d = [Math]::Sin($a / 57.3); $s.Group('gold', 0.6); $s.Cap((9.0 * $c), 10.6, (9.0 * $d), (10.4 * $c), 19, (10.4 * $d), 3.0, 0.5, ''); $s.Group('red', 0); $s.Ball((10.5 * $c), 20, (10.5 * $d), 1.5, '') }
    $s.Mark(0, 8.4, 10, '.r./rhr/rrr/.r.', 'r=#c81c2c,h=#ffc0a0', $true); $s.Mark(-6.6, 8.6, 7, '.b/bh/.b', 'b=#3890c8,h=#e0fcff', $true); $s.Mark(6.6, 8.6, 7, 'b./hb/b.', 'b=#3890c8,h=#e0fcff', $true) } }
  grab = @{ n = 32; f = { param($s)
    $s.Yaw = 24; $s.Pitch = 14; $s.Crack('stone', 0.08, 6); $s.Rough('stone', 0.03, 0.02)
    Grp $s 'leaf' 1.2; $s.Ell(0, 0, 3, 13, 1.8, 10, 0, 0, 0, ''); Grp $s 'wood' 1.0; $s.Ell(0, 0.8, 7, 7, 1.8, 6, 0, 0, 0, '')
    $s.Push(0, 0, 0, -4, 0, -4); Grp $s 'stone' 0.4; $s.Box(0, 8, 0, 7, 8, 2.0, 0, 0, 0, 0.6, ''); $s.Cap(0, 15, -0.6, 0, 15, 0.6, 7, 7, ''); $s.Box(0, 1.4, 0, 8.6, 1.6, 3.2, 0, 0, 0, 0.5, '')
    $s.Mark(0, 14, 7, '..k../..k../kkkkk/..k../..k../..k..', 'k=#202028', $true); $s.Pop()
    # A sword stuck in the mound.
    Grp $s 'steel' 0; $s.Cap(8, 2, 8, 9, 11, 8, 0.9, 0.9, ''); Grp $s 'gold' 0; $s.Cap(6.4, 11.4, 8, 11.6, 10.8, 8, 0.8, 0.8, ''); Grp $s 'wood' 0; $s.Cap(9, 12, 8, 9.4, 15, 8, 0.8, 0.8, ''); Grp $s 'gold' 0; $s.Ball(9.5, 15.8, 8, 1.1, '')
    Grp $s 'leaf' 0.4; foreach ($q in @(-8, 6), @(-10, 2), @(4, 11)) { foreach ($d in -1, 0, 1) { $s.Cap($q[0], 0.6, $q[1], ($q[0] + 1.4 * $d), 4.2, $q[1], 0.8, 0.4, '') } } } }
}
foreach ($id in $art.Keys) {
  if ($Only -and $id -notin $Only.Split(',')) { continue }
  $a = $art[$id]
  $b = New-FittedSprite { param($s) Add-Ramps $s; & $a.f $s } $a.n $true
  $b.Save((Join-Path $Out "$id.png")); $b.Dispose()
}
