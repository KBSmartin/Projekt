# Faces sculpted into a body (not stamped): brow ridges, hollow eyes with a
# glow inside, a carved mouth with teeth. Call while the body's group is the
# current one; the face looks along -x and sits at distance R from the axis.
function Add-Face($s, [hashtable]$f) {
  $d = @{ R = 5; eyeY = 0; dist = 2.4; slant = 24; eye = 1.0; brow = 1.0; mouthY = -5; mouthW = 3.4; mouthH = 1.6; teeth = 4; tooth = 'tooth'; dark = 'dark'; glow = 'glow'; curve = 0; nose = $true; inner = $false; low = $true }
  foreach ($k in $f.Keys) { $d[$k] = $f[$k] }
  [double]$R = $d.R; [double]$e = $d.eye
  $ex = [Math]::Sqrt([Math]::Max(0.5, $R * $R - $d.dist * $d.dist))
  # Brows: thick ridges, low at the nose and rising outwards.
  foreach ($q in -1, 1) { $s.Cap(-$R - 0.5, $d.eyeY + 0.9 * $e, 0.5 * $q, -$ex + 0.1, $d.eyeY + 1.5 * $e + 0.05 * $d.slant, ($d.dist * 1.5 * $q), 1.05 * $d.brow, 0.7 * $d.brow, '') }
  if ($d.nose) { $s.Cap(-$R - 0.2, $d.eyeY - 0.2, 0, -$R - 0.9, $d.eyeY - 2.0 * $e, 0, 0.7, 1.05, '') }
  foreach ($q in -1, 1) { $s.Cut(-$ex - 0.4, $d.eyeY - 0.3 * $e, ($d.dist * $q), 1.8, 1.15 * $e, 1.75 * $e, (-$d.slant * $q), 0, 0, $d.dark) }
  $mx = -$R
  if ($d.mouthH -gt 0) {
    $s.Cut($mx, $d.mouthY, 0, 2.6, $d.mouthH, $d.mouthW, 0, 0, 0, $d.dark)
    if ($d.curve -ne 0) { foreach ($q in -1, 1) { $s.Cut($mx + 0.8, $d.mouthY + $d.curve, ($d.mouthW * 0.8 * $q), 2.4, $d.mouthH * 0.65, $d.mouthW * 0.4, (-28 * $q * [Math]::Sign($d.curve)), 0, 0, $d.dark) } }
  }
  $s.Group($d.glow, 0)
  foreach ($q in -1, 1) { $s.Ell(-$ex + 0.5, $d.eyeY - 0.5 * $e, ($d.dist * 0.92 * $q), 0.9, 0.62 * $e, 1.0 * $e, (-$d.slant * $q), 0, 0, '') }
  if ($d.inner) { $s.Ell($mx + 2.4, $d.mouthY - $d.mouthH * 0.35, 0, 1.0, $d.mouthH * 0.55, $d.mouthW * 0.6, 0, 0, 0, '') }
  if ($d.teeth -gt 0 -and $d.mouthH -gt 0) {
    $s.Group($d.tooth, 0.1)
    for ($i = 0; $i -lt $d.teeth; $i++) {
      $t = if ($d.teeth -eq 1) { 0 } else { -0.82 + 1.64 * $i / ($d.teeth - 1) }
      $z = $t * $d.mouthW; $h = $d.mouthH * [Math]::Sqrt([Math]::Max(0.1, 1 - $t * $t)); $x = -[Math]::Sqrt([Math]::Max(1, $R * $R - $z * $z)) + 0.3; $c = $d.curve * [Math]::Abs($t)
      $l = 0.75 + 0.5 * (($i * 3) % 2)
      $s.Cap($x, $d.mouthY + $h + $c, $z, $x - 0.2, $d.mouthY + $h + $c - $l * $d.mouthH * 0.8, $z, 0.75, 0.25, '')
      if ($d.low -and $i -lt $d.teeth - 1) { $z2 = ($t + 0.82 / ($d.teeth - 1)) * $d.mouthW; $s.Cap($x, $d.mouthY - $h + $c, $z2, $x - 0.2, $d.mouthY - $h + $c + $d.mouthH * 0.7, $z2, 0.65, 0.25, '') }
    }
  }
}
