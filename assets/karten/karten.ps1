# Card icons, 16x16, one per card id. Each icon is drawn from simple shapes in
# material letters; a shading pass lights edges facing the top left, darkens edges
# facing the bottom right, and adds a dark outline. Writes ui/assets/karten/<id>.png
# and an overview sheet. Helper names avoid PowerShell's one-letter aliases.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karten'), [string]$Sheet = (Join-Path $PSScriptRoot 'uebersicht.png'))
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null

# Material ramps: dark, base, light.
$ramps = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($line in @(
    'S #4a5466 #8d9aac #d8e2ec', 'G #8a5a1a #d8a038 #f8e08a', 'W #4e3020 #8a5a34 #c08a52',
    'L #3a2014 #6e4026 #a0683e', 'R #6a1418 #c43030 #ff7a5a', 'B #5a0a10 #a01820 #e04848',
    'P #1e5a1e #4ab03a #a8f070', 'Q #12301a #2e6a2e #5aa04a', 'U #3a1a5a #7a3ab8 #c08af0',
    'A #1a3a7a #3a7ad8 #8ac0ff', 'I #3a7ab0 #8ad0f0 #e8faff', 'F #a02010 #f07020 #ffb040',
    'Y #c09010 #f8d030 #fffac0', 'T #3a3a44 #6a6a78 #a8a8b4', 'O #8a7e66 #d8ccb0 #fff4dc',
    'H #9aa4b0 #dce4ec #ffffff', 'N #a08a5a #e0cc98 #fff4c8', 'K #1a1420 #2e2638 #4a4058')) {
  $p = $line.Split(' '); $ramps[$p[0]] = @(($p[1..3]) | ForEach-Object { [Drawing.ColorTranslator]::FromHtml($_) })
}
$outline = [Drawing.ColorTranslator]::FromHtml('#0c0a10')

$script:g = $null; $script:fix = $null; $script:MX = $false; $script:OX = 0; $script:OY = 0
function NewIcon { $script:g = New-Object 'char[,]' 16, 16; for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { $script:g[$x, $y] = '.' } }; $script:fix = @{}; $script:MX = $false; $script:OX = 0; $script:OY = 0 }
# Source coordinates -> grid, with optional mirror and offset.
function ToX($sx) { $x = $sx + $script:OX; if ($script:MX) { 15 - $x } else { $x } }
function SetS($sx, $sy, $m) { $x = ToX $sx; $y = $sy + $script:OY; if ($x -ge 0 -and $y -ge 0 -and $x -lt 16 -and $y -lt 16) { $script:g[[int]$x, [int]$y] = $m } }
function Px($x, $y, $m) { SetS $x $y $m }
function Fx($x, $y, $hex) { $xx = ToX $x; $yy = $y + $script:OY; $script:fix["$xx,$yy"] = [Drawing.ColorTranslator]::FromHtml($hex) }
function Ln($x0, $y0, $x1, $y1, $m) {
  $dx = [Math]::Abs($x1 - $x0); $dy = -[Math]::Abs($y1 - $y0); $sx = if ($x0 -lt $x1) { 1 } else { -1 }; $sy = if ($y0 -lt $y1) { 1 } else { -1 }; $err = $dx + $dy
  while ($true) { SetS $x0 $y0 $m; if ($x0 -eq $x1 -and $y0 -eq $y1) { break }; $e2 = 2 * $err; if ($e2 -ge $dy) { $err += $dy; $x0 += $sx }; if ($e2 -le $dx) { $err += $dx; $y0 += $sy } }
}
function Rc($x0, $y0, $x1, $y1, $m) { for ($y = $y0; $y -le $y1; $y++) { for ($x = $x0; $x -le $x1; $x++) { SetS $x $y $m } } }
# Shapes tested at source pixel centres.
function Shape($test, $m) { for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { if (& $test ($x + 0.5) ($y + 0.5)) { SetS $x $y $m } } } }
function El($cx, $cy, $rx, $ry, $m) { Shape { param($px, $py) $a = ($px - $cx - 0.5) / $rx; $b = ($py - $cy - 0.5) / $ry; $a * $a + $b * $b -le 1 }.GetNewClosure() $m }
function Arc($cx, $cy, $r, $w, $a0, $a1, $m) {
  Shape { param($px, $py) $dx = $px - $cx - 0.5; $dy = $py - $cy - 0.5; $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
    $ang = [Math]::Atan2($dy, $dx) * 180 / [Math]::PI; if ($ang -lt 0) { $ang += 360 }
    $in = if ($a0 -le $a1) { $ang -ge $a0 -and $ang -le $a1 } else { $ang -ge $a0 -or $ang -le $a1 }
    $d -ge $r - $w / 2 -and $d -le $r + $w / 2 -and $in }.GetNewClosure() $m
}
function Pg($pts, $m) {
  Shape { param($px, $py) $in = $false; $n = $pts.Count / 2
    for ($i = 0; $i -lt $n; $i++) { $j = ($i + $n - 1) % $n; $xi = $pts[2 * $i]; $yi = $pts[2 * $i + 1]; $xj = $pts[2 * $j]; $yj = $pts[2 * $j + 1]
      if ((($yi -gt $py) -ne ($yj -gt $py)) -and ($px -lt ($xj - $xi) * ($py - $yi) / ($yj - $yi) + $xi)) { $in = -not $in } }
    $in }.GetNewClosure() $m
}

# ---------- reusable parts ----------
function Sword { Ln 14 1 7 8 'S'; Ln 13 1 6 8 'S'; Ln 4 7 8 11 'G'; Ln 5 10 3 12 'W'; Rc 1 13 2 14 'G' }
function Shield($m = 'A') { Pg @(2, 1, 13, 1, 13, 8, 8, 15, 7, 15, 2, 8) 'S'; Pg @(4, 3, 11, 3, 11, 8, 7.5, 12.5, 4, 8) $m; Rc 7 4 8 10 'G'; Rc 5 6 10 7 'G' }
function Arrow { Ln 2 13 12 3 'W'; Pg @(15, 0, 10, 2, 13, 5) 'S'; Ln 0 12 2 10 'R'; Ln 2 14 4 12 'R'; Px 1 13 'R' }
function Flame($cx, $base, $h, $w) {
  Pg @($cx, ($base - $h), ($cx + $w), ($base - $h * 0.45), ($cx + $w * 0.8), ($base - 1), $cx, $base, ($cx - $w * 0.8), ($base - 1), ($cx - $w), ($base - $h * 0.45), ($cx - $w * 0.3), ($base - $h * 0.7)) 'F'
  Pg @($cx, ($base - $h * 0.55), ($cx + $w * 0.5), ($base - $h * 0.25), $cx, ($base - 1), ($cx - $w * 0.5), ($base - $h * 0.25)) 'Y'
}
function Skull($cx, $cy, $eye = '#ff3a2a') {
  El ($cx - 0.5) ($cy - 1) 4.5 4 'O'; Rc ($cx - 3) ($cy + 1) ($cx + 2) ($cy + 4) 'O'
  Rc ($cx - 3) ($cy) ($cx - 2) ($cy + 1) 'K'; Rc ($cx + 1) ($cy) ($cx + 2) ($cy + 1) 'K'
  Fx ($cx - 2) $cy $eye; Fx ($cx + 1) $cy $eye; Px ($cx - 1) ($cy + 2) 'K'; Px $cx ($cy + 2) 'K'
  foreach ($tx in @(($cx - 2), $cx, ($cx + 2))) { Px $tx ($cy + 4) 'K' }
}
function Tower($x0, $x1, $top) { Rc $x0 ($top + 2) $x1 14 'T'; for ($x = $x0; $x -le $x1; $x += 2) { Rc $x $top $x ($top + 1) 'T' } }
function Cloud($m) { El 4 8 3.5 3 $m; El 9 6 4.5 4 $m; El 8 9 5.5 3 $m; El 12 9 3 2.5 $m }
function Star4($m, $cx = 8, $cy = 8, $r = 7) { Ln $cx ($cy - $r) $cx ($cy + $r) $m; Ln ($cx - $r) $cy ($cx + $r) $cy $m; Pg @($cx, ($cy - 4), ($cx + 4), $cy, $cx, ($cy + 4), ($cx - 4), $cy) $m; Fx $cx $cy '#ffffff' }
function Dagger($tx, $ty, $bx, $by, $hx, $hy) { Ln $tx $ty $bx $by 'S'; Ln $bx $by $hx $hy 'L'; Px $bx $by 'G' }

# ---------- icons ----------
$icons = [ordered]@{}
$icons['strike'] = { Sword }
$icons['defend'] = { Shield }
$icons['bash'] = { $script:OX = -2; Shield; $script:OX = 0; Ln 12 2 12 10 'Y'; Ln 9 6 15 6 'Y'; Ln 10 3 14 9 'Y'; Ln 10 9 14 3 'Y'; Fx 12 6 '#ffffff' }
$icons['twin'] = { Sword; $script:MX = $true; Sword; $script:MX = $false }
$icons['kick'] = { Rc 6 1 10 9 'L'; Pg @(6, 9, 15, 9, 15, 13, 6, 13) 'L'; Rc 6 14 15 14 'K'; Rc 6 4 10 5 'W'; Ln 1 4 3 4 'H'; Ln 0 8 3 8 'H'; Ln 1 12 3 12 'H' }
$icons['flank'] = { Ln 3 14 11 4 'W'; Ln 4 14 12 4 'W'; Pg @(10, 2, 13, 0, 15, 4, 14, 9, 11, 6) 'S'; Arc 8 10 7 1 200 250 'H' }
$icons['slam'] = { $script:OX = -1; Shield 'R'; $script:OX = 0; Arc 8 9 7.5 1 20 80 'H'; Arc 8 9 6 1 30 70 'H' }
$icons['guard'] = { Tower 4 11 1; Rc 6 10 9 14 'K'; Px 7 6 'K'; Px 8 6 'K' }
$icons['thorn'] = { Shield 'P'; foreach ($s in @(@(1, 0, 3, 2), @(14, 0, 12, 2), @(0, 6, 2, 6), @(15, 6, 13, 6), @(3, 13, 5, 11), @(12, 13, 10, 11))) { Ln $s[0] $s[1] $s[2] $s[3] 'O' } }
$icons['heavy'] = { Rc 7 6 8 15 'W'; Rc 3 1 12 6 'S'; Rc 3 1 4 6 'K'; Rc 11 1 12 6 'K'; foreach ($p in @(@(1, 9), @(14, 9), @(2, 12), @(13, 12), @(0, 7), @(15, 7))) { Px $p[0] $p[1] 'Y' } }
$icons['warcry'] = { Pg @(1, 11, 3, 8, 9, 4, 13, 2, 15, 1, 15, 6, 11, 7, 5, 11, 3, 13) 'O'; Ln 8 4 9 7 'G'; Ln 9 4 10 7 'G'; Rc 1 11 2 13 'G'; Px 11 10 'H'; Px 13 9 'H'; Px 12 12 'H'; Px 14 12 'H' }
$icons['leech'] = { El 7.5 8 2 3 'K'; Pg @(6, 7, 0, 4, 2, 8, 0, 11, 6, 10) 'U'; Pg @(9, 7, 15, 4, 13, 8, 15, 11, 9, 10) 'U'; Px 6 4 'K'; Px 9 4 'K'; Fx 7 7 '#ff3a2a'; Fx 8 7 '#ff3a2a'; El 7.5 13.5 1 1.5 'B' }
$icons['cleave'] = { Ln 2 14 10 6 'W'; Ln 3 14 11 6 'W'; Pg @(9, 4, 12, 1, 15, 5, 13, 9, 10, 7) 'S'; Arc 9 10 6.5 1 170 260 'H'; Arc 9 10 5 1 180 240 'H' }
$icons['iron'] = { Rc 4 3 11 10 'S'; Rc 5 11 10 14 'T'; foreach ($fx in @(6, 8, 10)) { Ln $fx 3 $fx 6 'K' }; Ln 4 7 11 7 'K'; Px 3 6 'S'; Px 3 7 'S' }
$icons['fort'] = { Tower 1 4 2; Tower 11 14 2; Rc 4 7 11 14 'T'; for ($x = 5; $x -le 10; $x += 2) { Px $x 6 'T' }; Rc 6 10 9 14 'K'; Ln 2 0 2 2 'W'; Rc 3 0 5 1 'R' }
$icons['finish'] = { Ln 15 0 9 6 'S'; Ln 14 0 8 6 'S'; Skull 7 8 }
$icons['arrow'] = { Arrow }
$icons['cover'] = { foreach ($px in @(2, 6, 10)) { Rc $px 3 ($px + 2) 14 'W'; Px ($px + 1) 2 'W' }; Rc 1 6 14 7 'L'; Rc 1 11 14 12 'L' }
$icons['venom'] = { Ln 2 13 12 3 'W'; Pg @(15, 0, 10, 2, 13, 5) 'P'; Ln 0 12 2 10 'R'; Ln 2 14 4 12 'R'; Px 14 7 'P'; Px 14 8 'P'; Px 12 9 'P' }
$icons['double_shot'] = { $script:OX = -2; $script:OY = -2; Arrow; $script:OX = 1; $script:OY = 1; Arrow; $script:OX = 0; $script:OY = 0 }
$icons['net'] = { Shape { param($px, $py) $dx = $px - 8; $dy = $py - 8; ($dx * $dx + $dy * $dy -le 49) -and ((([int][Math]::Floor($px) + [int][Math]::Floor($py)) % 4 -eq 0) -or ((([int][Math]::Floor($px) - [int][Math]::Floor($py)) + 16) % 4 -eq 0)) } 'N'; foreach ($p in @(@(8, 1), @(1, 8), @(14, 8), @(8, 14))) { Px $p[0] $p[1] 'T' } }
$icons['roll'] = { Arc 8 10 5.5 2 180 360 'I'; Pg @(12, 9, 15, 9, 13.5, 13) 'I'; El 3 13 2 1.5 'T'; El 6 14 1.5 1 'T' }
$icons['knives'] = { Dagger 3 1 6 10 7 13; Dagger 8 0 8 10 8 14; Dagger 13 1 10 10 9 13 }
$icons['cloud'] = { Cloud 'P'; Px 4 13 'P'; Px 8 14 'P'; Px 12 13 'P' }
$icons['volley'] = { foreach ($a in @(@(3, 0), @(8, 2), @(13, 0))) { $x = $a[0]; $o = $a[1]; Ln $x (1 + $o) $x (9 + $o) 'W'; Pg @(($x - 1), (9 + $o), ($x + 2), (9 + $o), ($x + 0.5), (12.5 + $o)) 'S'; Px ($x - 1) ($o) 'R'; Px ($x + 1) ($o) 'R' } }
$icons['aimed'] = { Arc 7.5 7.5 6 1 0 360 'R'; Ln 8 0 8 4 'R'; Ln 8 12 8 15 'R'; Ln 0 8 4 8 'R'; Ln 12 8 15 8 'R'; Fx 8 8 '#ffffff' }
$icons['plague'] = { Cloud 'Q'; Skull 8 7 '#a8f070' }
$icons['decay'] = { Rc 7 1 8 1 'W'; Rc 7 2 8 4 'H'; El 7.5 10 5 4.5 'P'; Fx 5 8 '#e8ffe0'; Px 8 9 'Q'; Px 10 11 'Q'; Px 6 12 'Q' }
$icons['deadshot'] = { El 6.5 9 6 6 'R'; El 6.5 9 4 4 'H'; El 6.5 9 2 2 'R'; Ln 14 1 8 8 'W'; Ln 13 0 15 2 'R'; Px 15 0 'R'; Fx 7 9 '#ffe060' }
$icons['spark'] = { Star4 'Y'; Px 2 2 'Y'; Px 13 13 'Y'; Px 13 2 'Y' }
$icons['ward'] = { El 7.5 7 6 6 'U'; El 6 5 2 1.5 'H'; Rc 4 14 11 15 'G' }
$icons['frostbolt'] = { Pg @(15, 0, 11, 2, 3, 11, 1, 15, 5, 13, 13, 4) 'I'; Px 4 4 'I'; Px 13 10 'I'; Px 9 13 'I' }
$icons['chain'] = { Pg @(10, 0, 3, 8, 7, 8, 4, 15, 13, 6, 9, 6, 12, 0) 'Y'; Px 1 3 'Y'; Px 14 11 'Y'; Px 2 13 'Y' }
$icons['insight'] = { Pg @(0, 4, 7, 5, 7, 14, 0, 13) 'N'; Pg @(15, 4, 8, 5, 8, 14, 15, 13) 'N'; Rc 7 5 8 14 'L'; foreach ($ly in @(7, 9, 11)) { Ln 2 $ly 5 ($ly + 0.0) 'T'; Ln 10 $ly 13 $ly 'T' }; Ln 0 14 15 14 'A' }
$icons['mark'] = { Arc 7.5 9 6 1 0 360 'R'; Flame 8 14 12 4 }
$icons['icearmor'] = { Pg @(8, 0, 14, 4, 14, 11, 8, 15, 2, 11, 2, 4) 'I'; Ln 8 1 8 14 'H'; Ln 3 5 13 10 'H' }
$icons['fireball'] = { Pg @(0, 15, 5, 7, 8, 5, 11, 8, 9, 11, 2, 15) 'F'; El 10 5 4 4 'F'; El 10 5 2.5 2.5 'Y'; Fx 10 5 '#ffffff' }
$icons['meditate'] = { Rc 6 7 9 14 'N'; El 7 3 1.5 2.5 'F'; Px 7 4 'Y'; Px 8 4 'Y'; Rc 3 14 12 15 'G'; Px 8 6 'K' }
$icons['arcane'] = { Star4 'U' 8 8 7; Ln 3 3 13 13 'U'; Ln 13 3 3 13 'U'; Fx 8 8 '#ffffff' }
$icons['drain'] = { El 5 5.5 3 3 'B'; El 10 5.5 3 3 'B'; Pg @(2, 6, 14, 6, 8, 13) 'B'; Px 12 12 'U'; Px 13 14 'U'; Px 3 12 'U' }
$icons['storm'] = { Flame 4 15 9 3; Flame 12 15 9 3; Flame 8 15 14 4 }
$icons['meteor'] = { Pg @(0, 0, 4, 0, 11, 7, 7, 11, 0, 4) 'F'; Pg @(1, 1, 3, 1, 9, 7, 7, 9, 1, 3) 'Y'; El 10 10 4.5 4.5 'T'; Px 9 9 'K'; Px 12 12 'K' }
$icons['barrier'] = { Pg @(8, 0, 15, 8, 8, 15, 1, 8) 'A'; Pg @(8, 3, 12, 8, 8, 12, 4, 8) 'I'; Fx 8 8 '#ffffff' }
$icons['focus'] = { El 7.5 7.5 5 5 'G'; El 6 6 1.5 1.5 'Y'; Px 8 0 'Y'; Px 8 15 'Y'; Px 0 8 'Y'; Px 15 8 'Y'; Px 2 2 'Y'; Px 13 13 'Y' }
$icons['dodge'] = { Ln 0 4 10 4 'H'; Arc 10 6 2 1 270 90 'H'; Ln 2 8 13 8 'H'; Arc 13 10 2 1 270 90 'H'; Ln 0 12 8 12 'H' }
$icons['plan'] = { Rc 3 3 12 12 'N'; Rc 2 1 13 2 'W'; Rc 2 13 13 14 'W'; Ln 5 5 7 7 'R'; Ln 7 5 5 7 'R'; Px 8 9 'L'; Px 9 10 'L'; Px 10 9 'L'; Ln 4 10 6 10 'L' }
$icons['burn'] = { Flame 8 15 14 5 }
$icons['frost'] = { Rc 3 5 12 14 'I'; Pg @(3, 5, 6, 2, 15, 2, 12, 5) 'H'; Ln 12 5 15 2 'I'; Rc 13 3 15 11 'A' }
$icons['curse'] = { El 10 10.5 4.5 4.5 'K'; foreach ($c in @(@(2, 2), @(4, 4), @(6, 6))) { Arc $c[0] $c[1] 1.5 1 0 360 'S' }; Fx 9 9 '#6a6080' }

# ---------- shading, outline, output ----------
function Render {
  $bmp = [Drawing.Bitmap]::new(16, 16)
  for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) {
    $m = [string]$script:g[$x, $y]
    if ($m -eq '.') {
      $near = $false
      foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { $nx = $x + $d[0]; $ny = $y + $d[1]; if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt 16 -and $ny -lt 16 -and $script:g[$nx, $ny] -ne '.') { $near = $true } }
      $bmp.SetPixel($x, $y, $(if ($near) { $outline } else { [Drawing.Color]::Transparent })); continue
    }
    $edge = { param($nx, $ny) $nx -lt 0 -or $ny -lt 0 -or $nx -gt 15 -or $ny -gt 15 -or [string]$script:g[$nx, $ny] -ne $m }
    $lit = (& $edge $x ($y - 1)) -or (& $edge ($x - 1) $y)
    $shade = (& $edge $x ($y + 1)) -or (& $edge ($x + 1) $y)
    $i = if ($lit -and -not $shade) { 2 } elseif ($shade -and -not $lit) { 0 } else { 1 }
    $bmp.SetPixel($x, $y, $ramps[$m][$i])
  } }
  foreach ($k in $script:fix.Keys) { $p = $k.Split(','); $x = [int]$p[0]; $y = [int]$p[1]; if ($x -ge 0 -and $y -ge 0 -and $x -lt 16 -and $y -lt 16) { $bmp.SetPixel($x, $y, $script:fix[$k]) } }
  $bmp
}

$cards = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '..\..\data\cards.json') | ConvertFrom-Json
$missing = @($cards | Where-Object { -not $icons.Contains($_.id) } | ForEach-Object { $_.id })
if ($missing.Count) { throw "Kein Symbol fuer: $($missing -join ', ')" }
$cols = 10; $rows = [Math]::Ceiling($cards.Count / $cols)
$sheetBmp = [Drawing.Bitmap]::new($cols * 84 + 10, $rows * 104 + 10)
$sg = [Drawing.Graphics]::FromImage($sheetBmp); $sg.Clear([Drawing.ColorTranslator]::FromHtml('#1f262a'))
$sg.InterpolationMode = 'NearestNeighbor'; $sg.PixelOffsetMode = 'Half'
$font = [Drawing.Font]::new('Segoe UI', 7.5); $br = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#c8c4d8'))
$k = 0
foreach ($c in $cards) {
  NewIcon; & $icons[$c.id]; $bmp = Render
  $bmp.Save((Join-Path $Out "$($c.id).png"))
  $x0 = 10 + ($k % $cols) * 84; $y0 = 10 + [Math]::Floor($k / $cols) * 104
  $sg.DrawImage($bmp, $x0 + 10, $y0, 64, 64); $sg.DrawString($c.name, $font, $br, $x0, $y0 + 68)
  $bmp.Dispose(); $k++
}
$sheetBmp.Save($Sheet)
