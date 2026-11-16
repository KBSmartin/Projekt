# Shared drawing helpers for the 320x180 backgrounds. Dot-source after setting $Seed.
# Helper names avoid PowerShell's one-letter aliases.
Add-Type -AssemblyName System.Drawing
$ImgW = 320; $ImgH = 180
$bmp = [Drawing.Bitmap]::new($ImgW, $ImgH)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'None'; $g.PixelOffsetMode = 'Half'; $g.InterpolationMode = 'NearestNeighbor'
$rng = [Random]::new($Seed)
function Clr($hex, $a = 255) { $c = [Drawing.ColorTranslator]::FromHtml($hex); [Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B) }
function Brs($hex, $a = 255) { [Drawing.SolidBrush]::new((Clr $hex $a)) }
function Rnd($a, $b) { $rng.Next($a, $b + 1) }
function Rect($hex, $x, $y, $w, $h, $a = 255) { $br = Brs $hex $a; $g.FillRectangle($br, $x, $y, $w, $h); $br.Dispose() }
function Ell($hex, $x, $y, $w, $h, $a = 255) { $br = Brs $hex $a; $g.FillEllipse($br, $x, $y, $w, $h); $br.Dispose() }
function Poly($hex, $pts, $a = 255) {
  $br = Brs $hex $a
  $p = for ($k = 0; $k -lt $pts.Count; $k += 2) { [Drawing.PointF]::new($pts[$k], $pts[$k + 1]) }
  $g.FillPolygon($br, [Drawing.PointF[]]$p); $br.Dispose()
}
function Line($hex, $x0, $y0, $x1, $y1, $w = 1, $a = 255) { $pen = [Drawing.Pen]::new((Clr $hex $a), $w); $g.DrawLine($pen, $x0, $y0, $x1, $y1); $pen.Dispose() }
# Vertical colour gradient between two hex colours over rows y0..y1.
function Gradient($top, $bottom, $y0, $y1) {
  $a = Clr $top; $b = Clr $bottom
  for ($y = $y0; $y -le $y1; $y++) {
    $t = ($y - $y0) / [Math]::Max(1, $y1 - $y0)
    $c = [Drawing.Color]::FromArgb([int]($a.R + ($b.R - $a.R) * $t), [int]($a.G + ($b.G - $a.G) * $t), [int]($a.B + ($b.B - $a.B) * $t))
    $br = [Drawing.SolidBrush]::new($c); $g.FillRectangle($br, 0, $y, $ImgW, 1); $br.Dispose()
  }
}
# A band of hills: top edge from summed sine waves, filled down to y = 180.
function Hills($hex, $base, $amp, $freq, $phase) {
  $pts = @(0, 180)
  for ($x = 0; $x -le $ImgW; $x += 4) { $pts += $x; $pts += $base - $amp * [Math]::Sin($x * $freq + $phase) - $amp * 0.4 * [Math]::Sin($x * $freq * 2.7 + $phase * 1.3) }
  $pts += $ImgW; $pts += 180
  Poly $hex $pts
}
# Darken slightly, add a vignette and write the PNG.
function Finish($Out, $r, $gg, $b) {
  Rect '#000000' 0 0 $ImgW $ImgH 40
  for ($k = 0; $k -lt 26; $k++) {
    $a = [int](110 * (1 - $k / 26.0))
    $br = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb($a, $r, $gg, $b))
    $g.FillRectangle($br, $k, 0, 1, $ImgH); $g.FillRectangle($br, $ImgW - 1 - $k, 0, 1, $ImgH)
    if ($k -lt 18) { $g.FillRectangle($br, 0, $ImgH - 1 - $k, $ImgW, 1) }
    $br.Dispose()
  }
  $g.Dispose(); $bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
