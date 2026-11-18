# Graphics for the 2.5D world map, written to ui/assets/karte/:
#   symbol_<kind>.png      8x8 node icons (kampf, elite, ereignis, rast, haendler, boss)
#   (the hero pieces come from figuren.ps1)
#   boden_<region>.png     top-down ground per region (forest, desert, fortress)
#   deko_<name>.png        upright decoration sprites (trees, rocks, ...)
#   nebel.png              seamless fog texture
#   nebelballen.png        fog puff sprite
# Also writes uebersicht.png next to this script. Deterministic.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karte'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = [IO.Path]::GetFullPath($Out)

$pal = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($e in @(
    '0 #0c0a10', 'w #f4ecd8', 'l #c8c0b0', 'g #8a8478', 'd #4a4652',
    'r #c83a2a', 'R #ff6a3a', 'y #ffd040', 'Y #b88a20', 'b #6a3a20', 'B #a0642c',
    'p #8a5ac8', 'q #c8a0ff', 's #a8d0f0', 'S #5a88c0',
    'e #f0b088', 'a #c06a4e',
    '2 #34343e', '3 #5a5a66', '4 #8a8a98', '5 #c4c4d0', 'z #f4f8ff', 'x #c8d0dc',
    'i #5c1c20', 'j #962e24', 'L #2a1410', 'M #5a2c1c', 'N #8a4a2c',
    'J #12301e', 'K #24542e', 'O #3e8040', 'P #7ab858',
    'u #d0a848', 'v #f8e08a',
    'Q #1e1030', 'T #6a3a98', 'U #a070d0', 'V #f0c050', 'G #6af0a0', 'H #2a1838')) {
  $pal[$e.Substring(0, 1)] = [Drawing.ColorTranslator]::FromHtml($e.Substring(2))
}

# Grid of rows (one char per pixel, '.' transparent) to a bitmap; rows are padded
# to the widest. With -Outline every transparent pixel next to a filled one turns dark.
function GridBmp([string[]]$rows, [switch]$Outline, [int]$pad = 0) {
  $w = [int]($rows | Measure-Object -Property Length -Maximum).Maximum + 2 * $pad; $h = $rows.Count + 2 * $pad
  $c = New-Object 'char[,]' $w, $h
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $c[$x, $y] = '.' } }
  for ($y = 0; $y -lt $rows.Count; $y++) { for ($x = 0; $x -lt $rows[$y].Length; $x++) { $c[($x + $pad), ($y + $pad)] = $rows[$y][$x] } }
  if ($Outline) {
    $o = @()
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
      if ($c[$x, $y] -ne '.') { continue }
      foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { $xx = $x + $d[0]; $yy = $y + $d[1]; if ($xx -ge 0 -and $yy -ge 0 -and $xx -lt $w -and $yy -lt $h -and $c[$xx, $yy] -ne '.' -and $c[$xx, $yy] -ne '0') { $o += , @($x, $y); break } }
    } }
    foreach ($p in $o) { $c[$p[0], $p[1]] = '0' }
  }
  $b = [Drawing.Bitmap]::new($w, $h)
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $ch = [string]$c[$x, $y]; if ($ch -ne '.') { if (-not $pal.ContainsKey($ch)) { throw "Farbe '$ch' fehlt" }; $b.SetPixel($x, $y, $pal[$ch]) } } }
  $b
}
function Save($bmp, [string]$name) { $bmp.Save((Join-Path $Out "$name.png")); $bmp.Dispose() }

# ---------- 8x8 node icons ----------
$icons = [ordered]@{
  kampf    = @('w......w', '.l....l.', '..l..l..', '...ll...', '..YllY..', '.YbYYbY.', 'bb....bb', '........')
  elite    = @('r......r', '.r.ww.r.', '..wwww..', '.wwwwww.', '.wRwwRw.', '.wwwwww.', '..wwww..', '..gwgw..')
  ereignis = @('..qqqq..', '.qq..qq.', '.....qq.', '....qq..', '...qq...', '...qq...', '........', '...qq...')
  rast     = @('....R...', '...RR...', '...RyR..', '..RyyR..', '..RyyyR.', '...RyR..', '.bBbBbB.', 'Bb....bB')
  haendler = @('..b..b..', '...bb...', '..BBBB..', '.BByBBB.', 'BByyyBBb', 'BBByBBBb', '.BBBBBb.', '..bbbb..')
  boss     = @('y.y..y.y', 'yyyyyyyy', '.wwwwww.', '.RRwwRR.', '.wwwwww.', '..wwww..', '..w0w0..', '...ww...')
}
foreach ($k in $icons.Keys) { Save (GridBmp $icons[$k]) "symbol_$k" }

# ---------- decoration sprites (stand upright on the map) ----------
$deko = [ordered]@{
  tanne       = @('....O....', '...POK...', '..POOKK..', '...POK...', '..POOOKK.', '.POOOOKKK', '..POOOKK.', '.POOOOOKK', 'POOOOOKKK', '...JbJ...', '....b....')
  baum        = @('...OOOK...', '..POOOOKK.', '.POOPOOOKK', '.POOOOOOKK', 'POOOOOOOKK', '.KOOOOOKKJ', '..KKKKKJJ.', '....bb....', '....bb....', '...bbbb...')
  busch       = @('..POOK..', '.POOOOK.', 'POOOOKKJ', '.KKKKJJ.')
  stein       = @('..lgg..', '.llggd.', 'lgggggd', '.ddddd.')
  pilz        = @('.rrr.', 'rwrwr', '..w..', '..w..')
  kaktus      = @('...PO...', '...POK..', '.P.POK..', '.P.POK.K', '.PPPOK.K', '...POKKK', '...POK..', '...POK..', '...POK..')
  fels        = @('...BBb....', '..BBBbbN..', '.BBNBBbbN.', 'BBBBBbbbNN', '.NNNNNNNN.')
  totbaum     = @('b...b..b', '.b.b..b.', '..bb.b..', '...bb...', '...bb...', '...Bb...', '..BBbb..')
  knochen     = @('w..w..ww', 'lwwwwll.', 'w..w..w.')
  schneetanne = @('....w....', '...wsK...', '..wwOKK..', '...wOK...', '..wwOOKK.', '.wwOOOKKK', '..wwOOKK.', '.wwOOOOKK', 'wwOOOOKKK', '...JbJ...', '....b....')
  eis         = @('...s....', '..ssS...', '.wsSS..s', '.wsSS.sS', 'wssSSSsS', 'SSSSSSSS')
  schneefels  = @('...www....', '..wwwlg...', '.wwlggdd..', 'lgggggddd.', '.dddddddd.')
  birke       = @('..PPOO...', '.PPPOOK..', 'PPPOOOKK.', '.POOOKKK.', '..OKKK...', '...wd....', '...ww....', '...dw....', '...ww....', '..wwd....')
  stumpf      = @('.BlllB.', 'BlBBlBb', 'BBBBBBb', 'bBBBBbb', 'b.bb..b')
  palme       = @('.OO...PP....', 'O..OPPOOP...', '....OOO.OK..', '...KOBO...K.', '..K..B......', '.....B......', '......B.....', '......B.....', '......Bb....', '.....BBb....')
  saeule      = @('.l.ll.', 'lllggd', '.llgd.', '.llgd.', '.llgd.', '.lggd.', '.llgd.', '.llgd.', 'lllggd', 'gggddd')
  schaedel    = @('..wwww....', '.wwwwwwl..', 'ww0ww0wl..', 'wwwwwwwl..', '.w0w0wl...', '..wwwl....')
  eiszapfen   = @('..w.....', '..s...w.', '.wsS..s.', '.wsS.wsS', 'wssSswsS', 'SSSSSSSS')
  banner      = @('brrrrr', 'brrirr', 'briiir', 'brrir.', 'brr.r.', 'b.....', 'b.....', 'b.....', 'b.....', 'bb....')
  mauer       = @('...l........', '..lgl..l....', '.lggdllgl...', 'lglgdlggdl..', 'lggdlggdlgd.', 'ddddddddddd.')
}
foreach ($k in $deko.Keys) { Save (GridBmp $deko[$k] -Outline -pad 1) "deko_$k" }

# ---------- flat decals (lie on the board) ----------
# Ellipse of $fill with an $edge ring and a highlight streak, optional extra dots.
function FlatGrid([int]$w, [int]$h, [char]$fill, [char]$edge, [char]$lite, [string]$dots, [int]$seed) {
  $r = [Random]::new($seed); $rows = @()
  for ($y = 0; $y -lt $h; $y++) {
    $row = ''
    for ($x = 0; $x -lt $w; $x++) {
      $u = ($x + 0.5 - $w / 2) / ($w / 2); $v = ($y + 0.5 - $h / 2) / ($h / 2); $d = $u * $u + $v * $v
      $ch = if ($d -gt 1) { '.' } elseif ($d -gt 0.68) { $edge } elseif ($v -lt -0.2 -and $u -lt 0 -and $u -gt -0.6 -and $y % 2 -eq 0) { $lite } else { $fill }
      if ($ch -eq $fill -and $dots -and $r.Next(0, 9) -eq 0) { $ch = $dots[$r.Next(0, $dots.Length)] }
      $row += $ch
    }
    $rows += $row
  }
  , $rows
}
Save (GridBmp (FlatGrid 22 10 'S' 'K' 's' '' 1)) 'flach_teich'
Save (GridBmp (FlatGrid 12 6 'O' '.' 'P' 'yrqw' 2)) 'flach_blumen'
Save (GridBmp (FlatGrid 20 9 'S' 'O' 's' '' 3)) 'flach_oase'
Save (GridBmp (FlatGrid 14 6 'B' '.' 'v' 'wl' 4)) 'flach_knochenfeld'
Save (GridBmp (FlatGrid 24 10 's' 'w' 'z' 'S' 5)) 'flach_eissee'
Save (GridBmp (FlatGrid 14 6 'z' '.' 'w' 'x' 6)) 'flach_verwehung'

# ---------- value noise (tileable) ----------
function NoiseGrid([int]$w, [int]$h, [int]$cell, [int]$seed) {
  $r = [Random]::new($seed); $gw = [int]($w / $cell); $gh = [int]($h / $cell)
  $lat = New-Object 'double[,]' $gw, $gh
  for ($y = 0; $y -lt $gh; $y++) { for ($x = 0; $x -lt $gw; $x++) { $lat[$x, $y] = $r.NextDouble() } }
  $n = New-Object 'double[,]' $w, $h
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
    $fx = $x / $cell; $fy = $y / $cell; $x0 = [int][Math]::Floor($fx) % $gw; $y0 = [int][Math]::Floor($fy) % $gh
    $x1 = ($x0 + 1) % $gw; $y1 = ($y0 + 1) % $gh
    $tx = $fx - [Math]::Floor($fx); $ty = $fy - [Math]::Floor($fy); $tx = $tx * $tx * (3 - 2 * $tx); $ty = $ty * $ty * (3 - 2 * $ty)
    $a = $lat[$x0, $y0] + ($lat[$x1, $y0] - $lat[$x0, $y0]) * $tx
    $b = $lat[$x0, $y1] + ($lat[$x1, $y1] - $lat[$x0, $y1]) * $tx
    $n[$x, $y] = $a + ($b - $a) * $ty
  } }
  , $n
}

# ---------- top-down ground per region, 192x160 ----------
function Ground([string]$name, [string[]]$shades, [string[]]$specks, [string]$special, [int]$seed) {
  $w = 192; $h = 160
  $n1 = NoiseGrid $w $h 16 $seed; $n2 = NoiseGrid $w $h 4 ($seed + 1)
  $bmp = [Drawing.Bitmap]::new($w, $h); $r = [Random]::new($seed + 2)
  $cols = $shades | ForEach-Object { [Drawing.ColorTranslator]::FromHtml($_) }
  for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
    $nv = $n1[$x, $y]; $v = $nv * 0.75 + $n2[$x, $y] * 0.25
    if ($special -match 'duenen') { $v = $v * 0.6 + 0.4 * (0.5 + 0.5 * [Math]::Sin($x * 0.22 + $y * 0.08 + 6 * $nv)) }
    $i = [Math]::Max(0, [Math]::Min($cols.Count - 1, [int][Math]::Floor($v * $cols.Count)))
    $bmp.SetPixel($x, $y, $cols[$i])
  } }
  # Small details: flowers, pebbles, ice glints.
  $sc = $specks | ForEach-Object { [Drawing.ColorTranslator]::FromHtml($_) }
  for ($k = 0; $k -lt 260; $k++) { $bmp.SetPixel($r.Next(0, $w), $r.Next(0, $h), $sc[$r.Next(0, $sc.Count)]) }
  if ($special -match 'risse') {
    $dark = [Drawing.ColorTranslator]::FromHtml('#7a5634')
    for ($k = 0; $k -lt 14; $k++) { $x = $r.Next(0, $w); $y = $r.Next(0, $h); for ($s = 0; $s -lt 8; $s++) { $x = ($x + $r.Next(-1, 2) + $w) % $w; $y = ($y + 1) % $h; $bmp.SetPixel($x, $y, $dark) } }
  }
  if ($special -eq 'eis') {
    $ice = [Drawing.ColorTranslator]::FromHtml('#9cc0e4'); $ice2 = [Drawing.ColorTranslator]::FromHtml('#c4dcf4')
    for ($k = 0; $k -lt 9; $k++) { $cx = $r.Next(0, $w); $cy = $r.Next(0, $h); $rx = $r.Next(5, 12); $ry = $r.Next(3, 6)
      for ($y = -$ry; $y -le $ry; $y++) { for ($x = -$rx; $x -le $rx; $x++) { if (($x * $x) / ($rx * $rx) + ($y * $y) / ($ry * $ry) -le 1) { $bmp.SetPixel((($cx + $x + $w) % $w), (($cy + $y + $h) % $h), $(if ($y -lt -$ry / 2 -and $x -lt 0) { $ice2 } else { $ice })) } } } }
  }
  Save $bmp "boden_$name"
}
Ground 'forest' @('#203a22', '#284a28', '#2f5630', '#386234', '#41703a') @('#d8c860', '#e8e0f0', '#b080d0', '#1a2c1a', '#5a8a40') 'moos' 11
Ground 'desert' @('#9a7444', '#a88050', '#b48c58', '#c49a60', '#d0a86c') @('#e0c088', '#6a4a2c', '#8a6a44', '#f0d8a0') 'duenen,risse' 21
Ground 'fortress' @('#a8b8cc', '#b8c6d8', '#c8d4e2', '#d8e2ee', '#e8eef6') @('#ffffff', '#7a8698', '#9cb4d0') 'eis' 31

# ---------- fog ----------
$fw = 96; $fn1 = NoiseGrid $fw $fw 24 41; $fn2 = NoiseGrid $fw $fw 8 42
$fog = [Drawing.Bitmap]::new($fw, $fw)
$fc = @('#4a4658', '#625e74', '#7c788e', '#9894aa', '#b4b0c4') | ForEach-Object { [Drawing.ColorTranslator]::FromHtml($_) }
for ($y = 0; $y -lt $fw; $y++) { for ($x = 0; $x -lt $fw; $x++) {
  $v = $fn1[$x, $y] * 0.7 + $fn2[$x, $y] * 0.3; $c = $fc[[Math]::Min(4, [int]($v * 5))]
  $fog.SetPixel($x, $y, [Drawing.Color]::FromArgb(242, $c.R, $c.G, $c.B))
} }
Save $fog 'nebel'

Save (GridBmp @(
    '.......gggg.............', '....gggllllgg...gggg....', '..ggllllllllgggglllllg..', '.gllllwwllllllllllwwllg.',
    'glllwwwwlllllllllwwwlllg', 'gllllllllllllllllllllllg', '.ggllllllggggglllllllgg.', '...gggggg.....ggggggg...') -pad 1) 'nebelballen'

# ---------- overview ----------
$files = Get-ChildItem $Out -Filter *.png | Sort-Object Name
$ov = [Drawing.Bitmap]::new(1400, 900); $g = [Drawing.Graphics]::FromImage($ov)
$g.Clear([Drawing.ColorTranslator]::FromHtml('#1a1622')); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = [Drawing.Font]::new('Segoe UI', 8); $br = [Drawing.SolidBrush]::new([Drawing.Color]::Gainsboro)
$x = 10; $y = 10; $rowH = 0
foreach ($f in $files) {
  $img = [Drawing.Bitmap]::new($f.FullName)
  $sc = if ($img.Width -ge 96) { 2 } else { 4 }
  $w = $img.Width * $sc; $h = $img.Height * $sc
  if ($x + $w -gt 1390) { $x = 10; $y += $rowH + 22; $rowH = 0 }
  $g.DrawImage($img, $x, $y, $w, $h); $g.DrawString($f.BaseName, $font, $br, $x, $y + $h + 2)
  $x += [Math]::Max($w, 80) + 12; $rowH = [Math]::Max($rowH, $h); $img.Dispose()
}
$ov.Save((Join-Path $PSScriptRoot 'uebersicht.png')); $g.Dispose(); $ov.Dispose()
