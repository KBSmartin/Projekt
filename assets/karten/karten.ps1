# Card icons, 8x8, hand-placed: one grid of palette letters per card id.
# Writes ui/assets/karten/<id>.png and an overview sheet. A card without an entry
# here stops the script, so new cards cannot ship without an icon.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karten'), [string]$Sheet = (Join-Path $PSScriptRoot 'uebersicht.png'))
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null

# Palette: one character per colour, '.' is transparent.
$palette = @'
0 #0c0a10 Schwarz
1 #4a5466 Stahl dunkel
2 #8d9aac Stahl
3 #d8e2ec Stahl hell
4 #8a5a1a Gold dunkel
5 #d8a038 Gold
6 #f8e08a Gold hell
7 #4e3020 Holz dunkel
8 #8a5a34 Holz
9 #c08a52 Holz hell
a #6a1418 Rot dunkel
b #c43030 Rot
c #ff7a5a Rot hell
d #1e5a1e Gift dunkel
e #4ab03a Gift
f #a8f070 Gift hell
g #3a1a5a Violett dunkel
h #7a3ab8 Violett
i #c08af0 Violett hell
j #1a3a7a Blau dunkel
k #3a7ad8 Blau
l #8ac0ff Blau hell
m #3a7ab0 Eis dunkel
n #8ad0f0 Eis
o #e8faff Eis hell
p #a02010 Feuer dunkel
q #f07020 Feuer
r #ffd040 Feuer gelb
s #d8ccb0 Knochen
t #8a7e66 Knochen dunkel
u #ffffff Weiss
v #6a6a78 Stein
w #3a3a44 Stein dunkel
x #e0cc98 Papier
y #6e4026 Leder
z #2e2638 Eisen
'@
$map = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($l in $palette.Split("`n")) { if ($l -match '^(\S) (#[0-9a-fA-F]{6})') { $map[$Matches[1]] = [Drawing.ColorTranslator]::FromHtml($Matches[2]) } }

$icons = [ordered]@{
  # neutral
  'focus'       = '...u....', '..r6r...', '.r656r.u', 'r65556r.', '.r656r..', '..r6r...', 'u..r....', '........'
  'dodge'       = '........', 'lllll...', '.....l..', '.kkk..l.', '....k.l.', 'llll.k..', '.....k..', '.kkkk...'
  'plan'        = '....8bb.', '....8b..', '....8...', 'xxxx8xx.', 'x99xxx9x', 'xx9xb9xx', 'x9xxx9xx', '.xxxxxx.'
  # warrior
  'strike'      = '...3....', '...32...', '...32...', '...32...', '...32...', '.45654..', '...87...', '...5....'
  'defend'      = '..1111..', '.198891.', '19882891', '19823891', '19882891', '.198891.', '..1111..', '........'
  'bash'        = '.11....r', '1981..r.', '19821rur', '19821.r.', '1981..r.', '.11....r', '........', '........'
  'twin'        = '....u..u', '...u3.u3', '..u3.u3.', '.u3.u3..', 'u3.u3...', '3.u3....', '.u3.....', '.3......'
  'kick'        = '.yy.....', '.yy.....', '.yy...r.', '.yy..rur', '.yyyyyr.', '.yyyyyy.', '.zzzzzz.', '........'
  'flank'       = '....222.', '...23332', '...23332', '....2282', '.....8..', '....8...', '...8....', '..8.....'
  'slam'        = '.11111..', '.18981..', '.19891..', '.18981..', '..181...', '...1....', 'v.v.v.v.', '.v.v.v..'
  'guard'       = 'v.v..v.v', 'vvvvvvvv', 'wvvwvvwv', 'vvwvvwvv', 'wvvwvvwv', 'vvwvvwvv', 'wvvwvvwv', 'wwwwwwww'
  'thorn'       = 's......s', '.s1221s.', '.123321.', 's122221s', '.123321.', 's122221s', '..1221..', '...ss...'
  'heavy'       = '.222222.', '.233332.', '.222222.', '...88...', '...88...', '...88...', '...88...', '..7777..'
  'warcry'      = '8bbbbb..', '8bcccb..', '8bb5bb..', '8bbbbb..', '8b.b.b..', '8.......', '8.......', '8.......'
  'leech'       = 'g......g', 'gg.hh.gg', 'ghhhhhhg', '.hbhhbh.', '..hhhh..', '...hh...', '....b...', '...bcb..'
  'cleave'      = '..uuuu..', '.u3333u.', 'u3....3u', '........', '.a..a..a', '.b..b..b', '.a..a..a', '........'
  'iron'        = '..2222..', '.233332.', '.232232.', '.200002.', '.232232.', '.233332.', '.222222.', '..1..1..'
  'fort'        = 'v.v..v.v', 'vvv..vvv', 'vvvvvvvv', 'vvv00vvv', 'vv0000vv', 'vv0000vv', 'vv0000vv', 'wwwwwwww'
  'finish'      = '.ssssss.', 'ssssssss', 's00ss00s', 's0css0cs', 'sss00sss', '.ssssss.', '.s.ss.s.', '........'
  # marksman
  'arrow'       = '........', '.....2..', 'bc...32.', '.b88883u', 'bc...32.', '.....2..', '........', '........'
  'cover'       = '........', '.888888.', '89999998', '.777777.', '.888888.', '89999998', '.777777.', '........'
  'venom'       = 'cb......', 'bb8.....', '..8.....', '...8....', '....8...', '.....ee.', '.....eff', '......fd'
  'double_shot' = '.....2..', 'bc888832', '.....2..', '........', '.....2..', 'bc888832', '.....2..', '........'
  'net'         = '9.9.9.9.', '.9.9.9.9', '9.9.9.9.', '.9.9.9.9', '9.9.9.9.', '.9.9.9.9', '9.9.9.9.', '2.....2.'
  'roll'        = '..llll..', '.l....l.', 'l......k', 'l.....kk', 'l.......', '.l......', '..lll...', '..v.v.v.'
  'knives'      = '........', 'yy23333.', '........', '.yy23333', '........', 'yy23333.', '........', '........'
  'cloud'       = '..eee...', '.effee..', 'eeffeeee', 'deeeeeed', '.dd.dd..', '.e...e..', '...e....', '........'
  'volley'      = 'b.......', '8..b....', '8..8..b.', '8..8..8.', '2..8..8.', '3..2..8.', '...3..2.', '......3.'
  'aimed'       = '...b....', '..uuuu..', '.uukkuu.', 'buk00kub', '.uukkuu.', '..uuuu..', '...b....', '........'
  'plague'      = '.eeeeee.', 'eeeeeeee', 'e00ee00e', 'e0fee0fe', 'eeee0eee', '.eeeeee.', '.e.ee.e.', 'd.d..d.d'
  'decay'       = '..b.....', '..b...b.', '.bcb..b.', '.bcbb.a.', 'bccbbb..', 'bcbbba..', '.bbaa...', '..aa....'
  'deadshot'    = '.bbbbb..', 'buuuuub.', 'bubbbub.', 'bubrb888', 'bubbbub.', 'buuuuub.', '.bbbbb..', '........'
  # mage
  'spark'       = '...r....', '...r....', '..r6r...', 'rr666rr.', '..r6r...', '...r....', '...r..r.', '.r......'
  'ward'        = '..hhhh..', '.h....h.', 'h..ii..h', 'h.iuui.h', 'h.iuui.h', 'h..ii..h', '.h....h.', '..hhhh..'
  'frostbolt'   = '......oo', '.....onn', '....onm.', '...onm..', '..onm...', '.onm....', 'onm.....', 'm.......'
  'chain'       = '....rr..', '...rr...', '..rr....', '.rrrrr..', '...rr...', '..rr....', '.rr.....', '.r......'
  'insight'     = '........', '.xx..xx.', 'xvvxxvvx', 'xxxxxxxx', 'xvvxxvvx', 'xxxxxxxx', '.yyyyyy.', '........'
  'mark'        = '...q....', '..qrq...', '.qrurq..', 'qru0urq.', '.qrurq..', '..qrq...', '...q....', '........'
  'icearmor'    = '...o....', '..ono...', '.onnno..', 'onnmnno.', '.onnno..', '..ono...', '...o....', '........'
  'fireball'    = '.....qr.', '....qrrq', '...qrrrq', '.pqqrrq.', 'pqq.qq..', 'pq......', 'p.......', '........'
  'meditate'    = '...r....', '..rqr...', '...q....', '..xxx...', '..xxx...', '..xxx...', '.45554..', '........'
  'arcane'      = '...i....', '..ihi...', '.ihhhi..', 'ihhhhhi.', '..hhh...', '..hhh...', '..ggg...', '........'
  'drain'       = '.bb.bb..', 'bcbbbbb.', 'bbbbbbb.', '.bbbbb..', '..bbb.h.', '...b.h..', '....h...', '...g....'
  'storm'       = 'qrrrrrq.', '.qrrrq..', '..qrrq..', '...qrq..', '..qrq...', '...qq...', '....q...', '...p....'
  'meteor'      = 'r.......', 'qr......', '.qr.....', '..qwww..', '..wvvvw.', '..wvwvw.', '..wvvvw.', '...www..'
  'barrier'     = '..kkkk..', '.kllllk.', 'kl....lk', 'kl.u..lk', 'kl....lk', 'kl....lk', 'kkkkkkkk', '........'
  # status
  'burn'        = '...q....', '..qq....', '..qrq.q.', '.qrrq.q.', '.qrrrqq.', 'qrr6rrq.', 'qr666rq.', '.qqqqq..'
  'frost'       = '...o....', '.o.o.o..', '..ooo...', 'ooooooo.', '..ooo...', '.o.o.o..', '...o....', '........'
  'curse'       = '.vvv....', 'v...v...', 'v...v...', '.vvv....', '..vvv...', '.v...v..', '.v...v..', '..vvv...'
}

$cards = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '..\..\data\cards.json') | ConvertFrom-Json
$missing = @($cards | Where-Object { -not $icons.Contains($_.id) } | ForEach-Object { $_.id })
if ($missing.Count) { throw "Kein Symbol fuer: $($missing -join ', ')" }

$cols = 10; $rows = [Math]::Ceiling($cards.Count / $cols)
$sheetBmp = [Drawing.Bitmap]::new($cols * 84 + 10, $rows * 96 + 10)
$sg = [Drawing.Graphics]::FromImage($sheetBmp); $sg.Clear([Drawing.ColorTranslator]::FromHtml('#2a2420'))
$sg.InterpolationMode = 'NearestNeighbor'; $sg.PixelOffsetMode = 'Half'
$font = [Drawing.Font]::new('Segoe UI', 7.5); $br = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#e8dcc0'))
$k = 0
foreach ($c in $cards) {
  $grid = $icons[$c.id]
  if ($grid.Count -ne 8) { throw "$($c.id): $($grid.Count) Zeilen statt 8" }
  $bmp = [Drawing.Bitmap]::new(8, 8)
  for ($y = 0; $y -lt 8; $y++) {
    if ($grid[$y].Length -ne 8) { throw "$($c.id) Zeile $y hat Laenge $($grid[$y].Length)" }
    for ($x = 0; $x -lt 8; $x++) {
      $ch = [string]$grid[$y][$x]
      if ($ch -eq '.') { $bmp.SetPixel($x, $y, [Drawing.Color]::Transparent) }
      elseif ($map.ContainsKey($ch)) { $bmp.SetPixel($x, $y, $map[$ch]) }
      else { throw "$($c.id): unbekanntes Zeichen '$ch'" }
    }
  }
  $bmp.Save((Join-Path $Out "$($c.id).png"))
  $x0 = 10 + ($k % $cols) * 84; $y0 = 10 + [Math]::Floor($k / $cols) * 96
  $sg.DrawImage($bmp, $x0 + 10, $y0, 64, 64); $sg.DrawString($c.name, $font, $br, $x0, $y0 + 68)
  $bmp.Dispose(); $k++
}
$sheetBmp.Save($Sheet)
