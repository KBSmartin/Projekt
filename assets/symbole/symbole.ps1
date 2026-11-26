# Small symbols, 8x8, hand-placed (shown 2x in text): status effects, enemy
# intents, HP, gold, sound, regions and characters. One grid of palette letters
# per symbol; writes <Out>/<name>.png. Larger pictures: bilder.ps1.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\symbole'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = [IO.Path]::GetFullPath($Out)

# Same palette as the card icons (karten.ps1); '.' is transparent.
$palette = @'
0 #0c0a10
1 #4a5466
2 #8d9aac
3 #d8e2ec
4 #8a5a1a
5 #d8a038
6 #f8e08a
7 #4e3020
8 #8a5a34
9 #c08a52
a #6a1418
b #c43030
c #ff7a5a
d #1e5a1e
e #4ab03a
f #a8f070
g #3a1a5a
h #7a3ab8
i #c08af0
j #1a3a7a
k #3a7ad8
l #8ac0ff
m #3a7ab0
n #8ad0f0
o #e8faff
p #a02010
q #f07020
r #ffd040
s #d8ccb0
t #8a7e66
u #ffffff
v #6a6a78
w #3a3a44
x #f0c8a0
'@
$map = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($l in $palette.Split("`n")) { if ($l -match '^(\S) (#[0-9a-fA-F]{6})') { $map[$Matches[1]] = [Drawing.ColorTranslator]::FromHtml($Matches[2]) } }

$icons = [ordered]@{
  # status effects and intents
  'staerke'    = '..x9....', '.xx98...', '.x9.....', '.x9..x9.', '.x9.xx98', '.xxxxx98', '..999988', '...888..'
  'schwaeche'  = '......33', '.....332', '....3.2.', '...2....', '.5..3...', '..533...', '..85....', '.8..5...'
  'verwundbar' = '..bbbb..', '.buuuub.', 'bubbbbub', 'bubuubub', 'bubuubub', 'bubbbbub', '.buuuub.', '..bbbb..'
  'gift'       = '..8998..', '...ss...', '..s..s..', '.s.ff.s.', 'sefeefes', 'seefeees', 'sdeeeeds', '.ssssss.'
  'blutung'    = '...b....', '...bb...', '..bcb...', '..bcbb..', '.bccbbb.', '.bcbbba.', '.bbbbaa.', '..aaaa..'
  'dornen'     = '...f....', 'e..e..e.', '.e.e.e..', '..efd...', 'feefdeef', '..edd...', '.e.e.e..', 'e..e..e.'
  'block'      = '11222211', '13llkk21', '13lkkk21', '13kkkj21', '13kkjj21', '.13kj21.', '..1221..', '...11...'
  'angriff'    = 'u......u', '33....33', '.32..23.', '..3223..', '...22...', '.52..25.', '..5..5..', '.8....8.'
  'heilung'    = '..eeee..', '..effe..', 'eeeffeee', 'effffffe', 'effffffe', 'eeeffeed', '..effd..', '..eedd..'
  'brand'      = '...p....', '..pq..p.', '..pqp.p.', '.pqrqqp.', '.pqrrqqp', 'pqrrurqp', '.pqruqp.', '..pppp..'
  'frost'      = 'n..oo..n', '.n.oo.n.', '..nuun..', 'oouuuuoo', 'oouuuuoo', '..nuun..', '.n.oo.n.', 'n..oo..n'
  # values
  'leben'      = '.bb..bb.', 'bccbbbba', 'bcbbbbba', 'bbbbbbba', '.bbbbba.', '..bbba..', '...ba...', '........'
  'gold'       = '..5555..', '.566654.', '56644554', '56465554', '56465554', '56544554', '.555554.', '..4444..'
  # sound
  'ton_an'     = '...3....', '..33..l.', '2333.l.l', '2333...l', '2333...l', '2333.l.l', '..33..l.', '...3....'
  'ton_aus'    = '...3....', '..33....', '2333b..b', '2333.bb.', '2333.bb.', '2333b..b', '..33....', '...3....'
  # regions
  'forest'     = '...f....', '..fee...', '..eee...', '.feeed..', '..eee...', '.feeedd.', 'feeeeedd', '...78...'
  'desert'     = '.....66.', '....6rr6', '....6rr6', '..99.66.', '.99988..', '99988899', '99888988', '88888888'
  'fortress'   = '...u....', '..uun..u', '..unn.un', '.unnnmnm', '.nnmmmmj', 'nnmmmmjj', 'nmmmmjjj', 'mmmjjjjj'
  # characters
  'warrior'    = '...bb...', '..1222..', '.132221.', '13222221', '10000001', '13202221', '.1.21221', '...1221.'
  'marksman'   = '..99....', '..s.9...', '..s..9..', 'b888888u', 'b888888u', '..s..9..', '..s.9...', '..99....'
  'mage'       = '....hh..', '...hih..', '...hhh..', '..hihh..', '..hhhhg.', '..55655.', 'ghhhhhhg', '.gggggg.'
  # debug panel
  'debug'      = 'd......d', '.d.ff.d.', '..feef..', 'ddfeefdd', '..feef..', 'ddfeefdd', '.dfeefd.', 'd..ff..d'
}
foreach ($id in $icons.Keys) {
  $rows = $icons[$id]
  if ($rows.Count -ne 8 -or @($rows | Where-Object { $_.Length -ne 8 }).Count) { throw "${id}: kein 8x8-Raster" }
  $bmp = [Drawing.Bitmap]::new(8, 8)
  for ($y = 0; $y -lt 8; $y++) { for ($x = 0; $x -lt 8; $x++) {
    $c = [string]$rows[$y][$x]; if ($c -eq '.') { continue }
    if (-not $map.ContainsKey($c)) { throw "${id}: Farbe '$c' fehlt" }
    $bmp.SetPixel($x, $y, $map[$c])
  } }
  $bmp.Save((Join-Path $Out "$id.png")); $bmp.Dispose()
}
Write-Host "$($icons.Count) Symbole"
