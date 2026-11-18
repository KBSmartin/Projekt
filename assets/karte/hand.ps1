# The hand that sets a piece on the board: simple pixel art after the
# reference (flat skin, one shadow tone, dark outline). Back of the hand with
# the wrist at the top, curled fingers on one side, index finger and thumb
# forming an open oval and pinching the piece head at the bottom.
# Drawn reaching in from the right, saved mirrored so it comes from the left.
# Writes ui/assets/karte/hand.png (24x24). After mirroring the pinch point is
# (14, 22.5); the CSS places it on the piece head.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karte\hand.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$pal = @{ '0' = '#1a1010'; 'e' = '#ffae82'; 'c' = '#f58a5c'; 'n' = '#e8584a' }
$rows = @(
  '.............00000000000',
  '...........0eeeeeeeeeee0',
  '..........0eeeeeeeeeeee0',
  '.........0eeeeeeeeeeeee0',
  '........0eeeeeeeeeccccc0',
  '.......0eeeeeeeeeeccccc0',
  '......0eeeeeeeeeeeccccc0',
  '.....0eeeeeeeeeeeeccccc0',
  '....0eeeeeeeeeeee0000000',
  '...0eeeeeeeeeeeee0......',
  '..0eneeeeeeeeeeee0......',
  '.0eneeeeeeeeeeeee0......',
  '0ee0eeee00000eeee0......',
  '0en0eee0.....0eee0......',
  '0ee0eee0.....0eee0......',
  '0ee0eee0.....0eee0......',
  '0ee0eee0.....0eec0......',
  '0ee0eee0.....0ec0.......',
  '0ee0eee0.....0ec0.......',
  '.0e0eee0.....0e0........',
  '..00eee0....0e0.........',
  '....0eee0..0e0..........',
  '.....0ee0..0c0..........',
  '......00....00..........')
$w = 24; $h = $rows.Count
$bmp = [Drawing.Bitmap]::new($w, $h)
for ($y = 0; $y -lt $h; $y++) {
  if ($rows[$y].Length -ne $w) { throw "Zeile $y hat $($rows[$y].Length) Zeichen" }
  for ($x = 0; $x -lt $w; $x++) {
    $ch = [string]$rows[$y][$x]
    if ($ch -ne '.') { $bmp.SetPixel($x, $y, [Drawing.ColorTranslator]::FromHtml($pal[$ch])) }
  }
}
$bmp.RotateFlip([Drawing.RotateFlipType]::RotateNoneFlipX)
$bmp.Save([IO.Path]::GetFullPath($Out)); $bmp.Dispose()
