# Pixel frames for the card types, 12x12 each, used as CSS border-image with
# slice 4 and shown 2x. Rings from outside in: black outline, light (top/left)
# or dark (bottom/right) edge, base colour, black inner line. The corner shape
# differs per type: attack bevelled, skill rounded, power with gold studs,
# status chipped.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\karten'))
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
function Hex($h) { [Drawing.ColorTranslator]::FromHtml($h) }
$black = Hex '#0a0809'
$types = @{
  'a' = @{ base = '#c43030'; light = '#ff7a5a'; dark = '#6a1418'; cut = 3; stud = $false; chip = $false }
  's' = @{ base = '#3a7ad8'; light = '#8ac0ff'; dark = '#1a3a7a'; cut = 2; stud = $false; chip = $false }
  'p' = @{ base = '#7a3ab8'; light = '#c08af0'; dark = '#3a1a5a'; cut = 1; stud = $true; chip = $false }
  'x' = @{ base = '#6a6a78'; light = '#a8a8b4'; dark = '#3a3a44'; cut = 2; stud = $false; chip = $true }
}
foreach ($t in $types.Keys) {
  $d = $types[$t]
  $bmp = [Drawing.Bitmap]::new(12, 12)
  for ($y = 0; $y -lt 12; $y++) { for ($x = 0; $x -lt 12; $x++) {
    $cx = [Math]::Min($x, 11 - $x); $cy = [Math]::Min($y, 11 - $y)
    $corner = $cx + $cy
    $ring = [Math]::Min($cx, $cy)
    $col = [Drawing.Color]::Transparent
    if ($corner -lt $d.cut) { $col = [Drawing.Color]::Transparent }
    elseif ($ring -eq 0 -or $corner -eq $d.cut) { $col = $black }
    elseif ($ring -eq 1 -or $corner -eq $d.cut + 1) {
      $lit = ($y -lt 6 -and $cy -le $cx) -or ($x -lt 6 -and $cx -le $cy)
      $col = if ($lit) { Hex $d.light } else { Hex $d.dark }
    }
    elseif ($ring -eq 2) { $col = Hex $d.base }
    elseif ($ring -eq 3) { $col = $black }
    if ($d.stud -and $cx -ge 1 -and $cx -le 2 -and $cy -ge 1 -and $cy -le 2) { $col = if ($cx -eq 1 -and $cy -eq 1) { Hex '#f8e08a' } else { Hex '#d8a038' } }
    if ($d.chip -and (($x -eq 5 -and $y -eq 1) -or ($x -eq 1 -and $y -eq 7) -or ($x -eq 10 -and $y -eq 4))) { $col = $black }
    $bmp.SetPixel($x, $y, $col)
  } }
  $bmp.Save((Join-Path $Out "rahmen_$t.png")); $bmp.Dispose()
}
