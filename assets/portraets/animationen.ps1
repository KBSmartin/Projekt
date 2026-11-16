# Source of the hero portrait animations. Run it after changing basis\*.txt;
# it writes the sprite sheets into ui/assets/portraets and the frames as text grids into frames/.
# Portrait animations (idle, heal, hit, poison) for the three heroes, 16x16 each.
# Per hero: one sprite sheet per animation, the frames as text grids, plus one
# HTML preview that plays everything.
param([string]$Dir = (Join-Path $PSScriptRoot '..\..\ui\assets\portraets'), [string]$Frames = (Join-Path $PSScriptRoot 'frames'), [string]$PaletteFrom = (Join-Path $PSScriptRoot 'palette_quelle.txt'), [string]$Assets = (Join-Path $PSScriptRoot 'basis'))
Add-Type -AssemblyName System.Drawing
$lines = Get-Content -Encoding utf8 $PaletteFrom; $i = [Array]::IndexOf($lines, '---'); $palette = @($lines[1..($i - 1)])
$map = [Collections.Hashtable]::new([StringComparer]::Ordinal)
foreach ($pl in $palette) { if ($pl -match '^(\S) (#[0-9a-fA-F]{6})') { $map[$Matches[1]] = [Drawing.ColorTranslator]::FromHtml($Matches[2]) } }

function Ordinal($h) { $o = [Collections.Hashtable]::new([StringComparer]::Ordinal); foreach ($k in $h.Keys) { $o[$k] = $h[$k] }; $o }
function Grid($rows) { $g = New-Object 'char[][]' 16; for ($y = 0; $y -lt 16; $y++) { $g[$y] = $rows[$y].ToCharArray() }; , $g }
function Rows($g) { , @(0..15 | ForEach-Object { -join $g[$_] }) }
function Recolor($rows, $m, $from = 0, $to = 15) {
  $out = @($rows)
  for ($r = $from; $r -le $to; $r++) { $out[$r] = -join ($out[$r].ToCharArray() | ForEach-Object { $s = [string]$_; if ($m.ContainsKey($s)) { $m[$s] } else { $s } }) }
  , $out
}
function BreathDown($rows, $to) { $out = @($rows); for ($r = $to; $r -ge 1; $r--) { $out[$r] = $out[$r - 1] }; $out[0] = '.' * 16; , $out }
function ShiftX($rows, [int]$dx) {
  $out = @()
  foreach ($row in $rows) {
    if ($dx -gt 0) { $out += ('.' * $dx) + $row.Substring(0, 16 - $dx) }
    else { $n = [Math]::Abs($dx); $out += $row.Substring($n) + ('.' * $n) }
  }
  , $out
}
function Put($rows, $r, $c, $s) { $out = @($rows); $out[$r] = $out[$r].Substring(0, $c) + $s + $out[$r].Substring($c + $s.Length); , $out }
function PutAll($rows, $puts) { $x = $rows; foreach ($p in $puts) { $x = Put $x $p[0] $p[1] $p[2] }; , $x }
function Paint($rows, $pts) {
  $g = Grid $rows
  foreach ($p in $pts) {
    $xx = $p[0]; $yy = $p[1]
    if ($xx -lt 0 -or $yy -lt 0 -or $xx -gt 15 -or $yy -gt 15) { continue }
    if ($p[3] -or '.0'.Contains([string]$g[$yy][$xx])) { $g[$yy][$xx] = $p[2] }
  }
  Rows $g
}
function Sparkle($rows, $x, $y, $arm, $mid) {
  $pts = @(); $pts += , @($x, $y, $mid, $true)
  foreach ($d in @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))) { $pts += , @(($x + $d[0]), ($y + $d[1]), $arm, $false) }
  Paint $rows $pts
}
function Bubble($rows, $x, $y, $big) {
  $pts = @(); $pts += , @($x, $y, $(if ($big) { 'I' } else { 'H' }), $false)
  if ($big) { $pts += , @(($x + 1), $y, 'H', $false); $pts += , @($x, ($y + 1), 'H', $false); $pts += , @(($x + 1), ($y + 1), 'G', $false) }
  Paint $rows $pts
}
function Aura($rows, $c) { Recolor $rows (MapOf ('0' + $c)) }

# Colour maps for every palette letter except the outline.
# "ab cd" means a -> b, c -> d (case-sensitive, unlike PowerShell hash literals).
function MapOf($s) { $o = [Collections.Hashtable]::new([StringComparer]::Ordinal); foreach ($p in $s.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) { $o[[string]$p[0]] = [string]$p[1] }; $o }
$red = MapOf 'zm yl xk 9l fk 6i em dl ck bj ai Vm rk gl wm nj 8i 7i 2i 3j 4k 5l ul vm tk qi sj hi ii Ok Pl Kj Ji Li Mj Nk'
$white = MapOf 'zz yz xy 9z fy 6x ez dz cy by ax Vz ry gz wz ny 8x 7x 2x 3x 4y 5z uz vz ty qx sy hx ix Oy Pz Ky Jx Lx My Ny'
$orange = MapOf 'zm yl em dl vm ul wm'
$sick = MapOf 'eI dH cG bF'
$bright = MapOf 'de cd'
function Animate($h) {
  $base = $h.base
  $idle = @()
  foreach ($k in 0..7) {
    $x = $base
    if ($h.sway -and ($k -eq 2 -or $k -eq 3)) { $x = & $h.sway $x }
    if ($k -eq 3 -or $k -eq 4) { $x = BreathDown $x $h.breathTo }
    $idle += , $x
  }

  $heal = @()
  $sp = @(@(1, 0), @(14, 3), @(2, 5), @(13, 1))
  for ($f = 0; $f -lt 8; $f++) {
    $x = $base
    if ($f -ge 1 -and $f -le 6) { $x = PutAll $x $h.healEyes }
    if ($f -ge 2 -and $f -le 5) { $x = Recolor $x $bright $h.face[0] $h.face[1]; $x = Aura $x $(if ($f % 2 -eq 0) { 'K' } else { 'O' }) }
    foreach ($s in $sp) {
      $t = $f - $s[1]; if ($t -lt 0 -or $t -gt 4) { continue }
      $x = Sparkle $x $s[0] (14 - 3 * $t) $(if ($t -ge 3) { 'K' } else { 'g' }) $(if ($t -ge 3) { 'g' } else { 'z' })
    }
    $heal += , $x
  }

  $squint = PutAll $base $h.squint
  $hit = @()
  $hit += , (Recolor $base $white)
  $hit += , (Recolor (ShiftX $squint (-1)) $red)
  $hit += , (ShiftX (Recolor $squint $orange) 1)
  $hit += , (ShiftX $squint (-1))
  $hit += , (ShiftX $squint 1)
  $hit += , $squint
  $hit += , $squint
  $hit += , $base

  $poison = @()
  $bub = @(@(1, 0, $true), @(13, 2, $true), @(3, 4, $false), @(12, 1, $false), @(2, 5, $true))
  for ($f = 0; $f -lt 8; $f++) {
    $x = $base
    if ($f -ge 1 -and $f -le 6) { $x = Recolor $x $sick $h.face[0] $h.face[1] }
    if ($f -ge 2 -and $f -le 5) { $x = PutAll $x $h.sickSquint; $x = Aura $x $(if ($f % 2 -eq 0) { 'F' } else { 'G' }) }
    if ($f -eq 3) { $x = ShiftX $x 1 }
    if ($f -eq 5) { $x = ShiftX $x (-1) }
    foreach ($b in $bub) {
      $t = $f - $b[1]; if ($t -lt 0 -or $t -gt 4) { continue }
      $x = Bubble $x $b[0] (14 - 3 * $t) ($b[2] -and $t -lt 3)
    }
    $poison += , $x
  }
  [ordered]@{
    'idle' = @{ t = 'Idle'; f = $idle; ms = 180 }
    'heilung' = @{ t = 'Heilung'; f = $heal; ms = 110 }
    'schaden' = @{ t = 'Schaden'; f = $hit; ms = 90 }
    'gift' = @{ t = 'Vergiftung'; f = $poison; ms = 140 }
  }
}

function Load($path) { $l = Get-Content -Encoding utf8 $path; $k = [Array]::IndexOf($l, '---'); , @($l[($k + 1)..($k + 16)]) }
$heroes = [ordered]@{
  'krieger' = @{ t = 'Krieger (Veteran)'; base = (Load (Join-Path $Assets 'krieger.txt')); breathTo = 10; face = @(4, 8)
    healEyes = @(, @(6, 5, 'g')); squint = @(, @(6, 5, 'h')); sickSquint = @(, @(6, 5, 'h')) }
  'schuetze' = @{ t = "Sch$([char]0xFC)tze (Elfe)"; base = (Load (Join-Path $Assets 'schuetze.txt')); breathTo = 10; face = @(4, 10)
    healEyes = @(@(6, 6, 'z'), @(6, 9, 'z')); squint = @(, @(6, 5, 'dqedqd')); sickSquint = @(, @(6, 5, 'HqIHqH')) }
  'magier' = @{ t = 'Magier (Spitzhut)'; base = (Load (Join-Path $Assets 'magier.txt')); breathTo = 12; face = @(8, 10)
    healEyes = @(@(9, 6, 'g'), @(9, 9, 'g')); squint = @(, @(9, 4, 'ydhddhdy')); sickSquint = @(, @(9, 4, 'yHhHHhHy'))
    sway = { param($rows) $out = @($rows); $out[0] = '...........00...'; $out[1] = '..........0f60..'; $out[2] = '.........0f60...'; , $out } }
}

$html = [Text.StringBuilder]::new(); $css = [Text.StringBuilder]::new()
[void]$html.Append(@'
<!doctype html><html lang="de"><head><meta charset="utf-8"><title>Helden-Animationen</title>
<style>
body { background: #161826; color: #c8c4d8; font: 15px "Segoe UI", sans-serif; margin: 24px; }
h1 { font-size: 20px; font-weight: 600; } h2 { font-size: 16px; font-weight: 600; margin: 28px 0 10px; }
.row { display: flex; gap: 40px; flex-wrap: wrap; }
.anim { display: flex; flex-direction: column; gap: 8px; }
.player { width: 128px; height: 128px; image-rendering: pixelated; background-size: auto 128px; background-repeat: no-repeat; }
.small { width: 48px; height: 48px; background-size: auto 48px; }
.strip { image-rendering: pixelated; height: 48px; align-self: flex-start; }
.note { color: #7c7890; font-size: 13px; }
</style></head><body><h1>Helden-Portr&auml;ts: Animationen (16&times;16)</h1>
'@)
$sheetAll = [Drawing.Bitmap]::new(8 * 16 * 4 + 20, 12 * 74 + 20)
$ga = [Drawing.Graphics]::FromImage($sheetAll); $ga.Clear([Drawing.ColorTranslator]::FromHtml('#161826')); $ga.InterpolationMode = 'NearestNeighbor'; $ga.PixelOffsetMode = 'Half'
$rowY = 10
foreach ($hn in $heroes.Keys) {
  $h = $heroes[$hn]; $anims = Animate $h
  [void]$html.Append("<h2>$($h.t)</h2><div class=`"row`">")
  foreach ($n in $anims.Keys) {
    $a = $anims[$n]; $count = $a.f.Count; $id = "$hn-$n"
    $sheet = [Drawing.Bitmap]::new(16 * $count, 16)
    $txt = @("# $($h.t), Animation $n, $count Frames zu 16x16, $($a.ms) ms je Frame") + $palette
    for ($k = 0; $k -lt $count; $k++) {
      $rows = $a.f[$k]; $txt += "--- Frame $($k + 1)"; $txt += $rows
      for ($y = 0; $y -lt 16; $y++) {
        if ($rows[$y].Length -ne 16) { throw "$id Frame $k Zeile $y Laenge $($rows[$y].Length): $($rows[$y])" }
        for ($x = 0; $x -lt 16; $x++) {
          $ch = [string]$rows[$y][$x]
          $col = if ($ch -eq '.') { [Drawing.Color]::Transparent } elseif ($map.ContainsKey($ch)) { $map[$ch] } else { throw "$id Frame $k unbekanntes Zeichen '$ch'" }
          $sheet.SetPixel($k * 16 + $x, $y, $col)
        }
      }
    }
    $png = Join-Path $Dir "${hn}_$n.png"; $sheet.Save($png)
    $ga.DrawImage($sheet, 10, $rowY, $sheet.Width * 4, 64); $rowY += 74
    $sheet.Dispose()
    $txt | Set-Content -Encoding utf8 (Join-Path $Frames "${hn}_$n.txt")
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($png)); $dur = $count * $a.ms
    [void]$css.Append(".p-$id { background-image: url(data:image/png;base64,$b64); animation: a-$id ${dur}ms steps($count) infinite; }`n")
    [void]$css.Append("@keyframes a-$id { from { background-position: 0 0; } to { background-position: -$(128 * $count)px 0; } }`n")
    [void]$css.Append(".small.p-$id { animation-name: s-$id; } @keyframes s-$id { from { background-position: 0 0; } to { background-position: -$(48 * $count)px 0; } }`n")
    [void]$html.Append("<div class=`"anim`"><b>$($a.t)</b><div class=`"player p-$id`"></div><div class=`"player small p-$id`"></div>")
    [void]$html.Append("<img class=`"strip`" src=`"data:image/png;base64,$b64`" alt=`"Frames`"><span class=`"note`">$count Frames, $($a.ms) ms</span></div>")
  }
  [void]$html.Append('</div>')
}
[void]$html.Append('<p class="note">Je Animation: 8-fach, darunter 3-fach (Spielgr&ouml;&szlig;e), darunter alle Frames.</p>')
[void]$html.Append("<style>$($css.ToString())</style></body></html>")
[IO.File]::WriteAllText((Join-Path $Frames 'animationen.html'), $html.ToString(), [Text.UTF8Encoding]::new($false))
$sheetAll.Save((Join-Path $Frames 'uebersicht.png'))
