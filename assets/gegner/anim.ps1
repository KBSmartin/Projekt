# Animation sheets for the enemies (dot-source after sdf.ps1): idle, angriff,
# treffer and tod, 8 frames each. The art keeps its size (32 or 48); every frame
# has a margin of 8 pixels left and right and 16 on top, so nothing is cut off
# when the enemy lunges. Frame 0 is always exactly the still.
#
# A build block gets the scene and the hashtable $A with:
#   anim, f      animation name and frame
#   phase, s     0..1 through the loop and its sine (idle)
#   wind, act    0..1 drawing back and striking (angriff)
#   hit          0..1 knocked back (treffer, start of tod)
#   die          0..1 going down (tod)
#   px, py       whole-pixel offset of the figure
# The body warp comes from $cfg: breath, sway, windBend, actBend, hitBend,
# windPx, actPx, hitPx, y0, y1 (warp starts / is full), pivot.
# Death ($cfg.tod): rx/rz turn the figure about (pvX, pvY, pvZ), squash is the
# height left, bend, px, py; fx 'chunks' or 'ash' (tod.ps1) with its settings
# breaks up the frame from frame `from` on.
. (Join-Path $PSScriptRoot 'tod.ps1')
$script:wind = 0, 0.6, 1, 0.1, 0, 0, 0, 0
$script:act = 0, 0, 0, 0.85, 1, 0.75, 0.3, 0
$script:hit = 0, 1, 0.9, 0.65, 0.4, 0.2, 0.08, 0
$script:dieHit = 0, 1, 0.8, 0.5, 0.25, 0.1, 0, 0
$script:die = 0, 0.05, 0.3, 0.65, 0.95, 1.0, 1.0, 1.0

function Get-AnimKeys([string]$anim, [int]$f, [hashtable]$cfg) {
  $c = @{ breath = 0.018; sway = 0.0; windBend = -7.0; actBend = 13.0; hitBend = -10.0; windPx = 1; actPx = -5; hitPx = 3; y0 = 2.0; y1 = 12.0; pivX = 0.0; pivY = 3.0; bob = 0 }
  foreach ($k in $cfg.Keys) { $c[$k] = $cfg[$k] }
  $A = @{ anim = $anim; f = $f; phase = 0.0; wind = 0.0; act = 0.0; hit = 0.0; die = 0.0; px = 0; py = 0; bend = 0.0; stretch = 1.0; sway = 0.0; s = 0.0; y0 = $c.y0; y1 = $c.y1; pivX = $c.pivX; pivY = $c.pivY; rx = 0.0; rz = 0.0; pvX = 0.0; pvY = 0.0; pvZ = 0.0; tod = $null; brk = 0.0; noMarks = $false }
  switch ($anim) {
    'idle' { $A.phase = $f / 8.0; $A.s = [Math]::Sin($f * [Math]::PI / 4); $A.stretch = 1 + $c.breath * $A.s; $A.sway = $c.sway * [Math]::Sin($f * [Math]::PI / 4); $A.py = [int][Math]::Round($c.bob * [Math]::Sin($f * [Math]::PI / 4)) }
    'angriff' { $A.wind = $script:wind[$f]; $A.act = $script:act[$f]; $A.bend = $c.windBend * $A.wind + $c.actBend * $A.act; $A.px = [int][Math]::Round($c.windPx * $A.wind + $c.actPx * $A.act) }
    'treffer' { $A.hit = $script:hit[$f]; $A.bend = $c.hitBend * $A.hit; $A.px = [int][Math]::Round($c.hitPx * $A.hit) }
    'tod' {
      $d = @{ rx = 0.0; rz = 0.0; pvX = 0.0; pvY = 0.0; pvZ = 0.0; squash = 1.0; bend = 0.0; px = 0; py = 0; fx = ''; from = 2; marksUntil = 3 }
      if ($c.tod) { foreach ($k in $c.tod.Keys) { $d[$k] = $c.tod[$k] } }
      $A.tod = $d; $A.hit = $script:dieHit[$f]; $A.die = $script:die[$f]
      $A.bend = $c.hitBend * $A.hit * (1 - $A.die) + $d.bend * $A.die; $A.stretch = 1 + ($d.squash - 1) * $A.die
      $A.px = [int][Math]::Round($c.hitPx * $A.hit * (1 - $A.die) + $d.px * $A.die); $A.py = [int][Math]::Round($d.py * $A.die)
      $A.rx = $d.rx * $A.die; $A.rz = $d.rz * $A.die; $A.pvX = $d.pvX; $A.pvY = $d.pvY; $A.pvZ = $d.pvZ
      if ($f -ge $d.from) { $A.brk = ($f - $d.from + 1) / (8.0 - $d.from) }
      $A.noMarks = $f -gt $d.marksUntil
    }
  }
  $A
}
# Points between $p (t = 0) and $q (t = 1); $A.wind and $A.act both as weights.
function Get-Mix($p, $q, [double]$t) { $r = [double[]]::new($p.Count); for ($i = 0; $i -lt $r.Length; $i++) { $r[$i] = $p[$i] + ($q[$i] - $p[$i]) * $t }; , $r }
function Get-Swing($rest, $back, $strike, $A) { , (Get-Mix (Get-Mix $rest $back $A.wind) $strike $A.act) }
function Get-Still { @{ anim = 'idle'; f = 0; phase = 0.0; s = 0.0; wind = 0.0; act = 0.0; hit = 0.0; die = 0.0 } }
# Breaks up a finished frame, see tod.ps1.
function Invoke-DeathFx($bmp, $d, [double]$t) {
  if (-not $d.fx -or $t -le 0) { return $bmp }
  $n = $bmp.Width; $px = [int[]]::new($n * $n)
  for ($i = 0; $i -lt $px.Length; $i++) { $px[$i] = $bmp.GetPixel($i % $n, [int][Math]::Floor($i / $n)).ToArgb() }
  if ($d.fx -eq 'chunks') {
    $o = @{ cell = 6.0; seed = 5; spread = 0.5; pile = 0.5 }; foreach ($k in @($o.Keys)) { if ($d.ContainsKey($k)) { $o[$k] = $d[$k] } }
    $px = [EnemyFx]::Chunks($px, $n, $t, $o.cell, $o.seed, $o.spread, $o.pile)
  } else {
    $o = @{ seed = 5; rise = 14.0; wind = 5.0; keep = 0.0; down = 0.7 }; foreach ($k in @($o.Keys)) { if ($d.ContainsKey($k)) { $o[$k] = $d[$k] } }
    $ember = [int[]]@($d.ember | ForEach-Object { [Drawing.ColorTranslator]::FromHtml($_).ToArgb() })
    $px = [EnemyFx]::Ash($px, $n, $t, $o.seed, $ember, $o.rise, $o.wind, $o.keep, $o.down)
  }
  $res = [Drawing.Bitmap]::new($n, $n)
  for ($i = 0; $i -lt $px.Length; $i++) { if (($px[$i] -shr 24) -band 255) { $res.SetPixel($i % $n, [int][Math]::Floor($i / $n), [Drawing.Color]::FromArgb($px[$i])) } }
  $bmp.Dispose(); $res
}
# One frame on a canvas of size + 16. $fit (from Get-Fit) or $null when the build
# block sets its own framing.
function New-AnimFrame([scriptblock]$build, [hashtable]$A, [int]$size, $fit) {
  $s = New-Scene
  $s.WBend = $A.bend; $s.WStretch = $A.stretch; $s.WSway = $A.sway; $s.WY0 = $A.y0; $s.WY1 = $A.y1; $s.WPivX = $A.pivX; $s.WPivY = $A.pivY; $s.NoMarks = $A.noMarks
  $turned = $A.rx -ne 0 -or $A.rz -ne 0
  if ($turned) { $s.Push($A.pvX, $A.pvY, $A.pvZ, $A.rx, 0, $A.rz); $s.Push(-$A.pvX, -$A.pvY, -$A.pvZ, 0, 0, 0) }
  & $build $s $A
  if ($turned) { $s.Pop(); $s.Pop() }
  if ($fit) { $s.Zoom = $fit.zoom; $s.OffX = $fit.ox; $s.OffY = $fit.oy }
  $s.OffX += $A.px; $s.OffY += $A.py
  $b = New-Sprite $s ($size + 16)
  if ($A.tod) { $b = Invoke-DeathFx $b $A.tod $A.brk }
  $b
}
# Writes <Out>/<id>_{idle,angriff,treffer,tod}.png. $keys (optional) may change
# $A; the environment variable VL_ANIM (comma separated) limits the run to some
# animations.
function Save-Sheets([string]$id, [scriptblock]$build, [int]$size, $fit, [hashtable]$cfg, [string]$Out, [scriptblock]$keys = $null) {
  New-Item -ItemType Directory -Force $Out | Out-Null; $w = $size + 16
  foreach ($anim in 'idle', 'angriff', 'treffer', 'tod') {
    if ($env:VL_ANIM -and $anim -notin $env:VL_ANIM.Split(',')) { continue }
    $strip = [Drawing.Bitmap]::new($w * 8, $w); $g = [Drawing.Graphics]::FromImage($strip)
    for ($f = 0; $f -lt 8; $f++) {
      $A = Get-AnimKeys $anim $f $cfg; if ($keys) { & $keys $A }
      $b = New-AnimFrame $build $A $size $fit; $g.DrawImageUnscaled($b, $f * $w, 0); $b.Dispose()
    }
    $g.Dispose(); $strip.Save((Join-Path $Out "${id}_$anim.png")); $strip.Dispose()
  }
}
function Get-GameDir { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\ui\assets\gegner')) }
