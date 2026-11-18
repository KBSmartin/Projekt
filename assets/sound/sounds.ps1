# Retro sound effects, synthesised (no recordings): 16-bit mono WAV, 22050 Hz,
# written to ui/assets/sound/. Deterministic (fixed seeds for the noise).
#   klick    button press: two short square blips
#   heben    piece lifted: soft rising whoosh
#   setzen   piece set down on the board: wooden tock
#   wisch    screen wipe: falling filtered noise sweep
#   karte    card played: short paper swish
#   muenze   gold gained or spent: two-tone coin
#   treffer  something takes damage: thump with noise
#   block    block gained: short metallic clink
#   heilung  healing: rising arpeggio
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\sound'))
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = [IO.Path]::GetFullPath($Out)
$Rate = 22050

function WriteWav([string]$name, [double[]]$s) {
  $path = Join-Path $Out "$name.wav"
  $fs = [IO.File]::Create($path); $bw = [IO.BinaryWriter]::new($fs)
  $data = $s.Count * 2
  $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([int](36 + $data)); $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
  $bw.Write([Text.Encoding]::ASCII.GetBytes('fmt ')); $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
  $bw.Write([int]$Rate); $bw.Write([int]($Rate * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
  $bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([int]$data)
  foreach ($v in $s) { $bw.Write([int16][Math]::Round([Math]::Max(-1.0, [Math]::Min(1.0, $v)) * 32000)) }
  $bw.Close(); $fs.Close()
}
# Builds a sound of $sec seconds; $f gets the time t and the sample index.
function Synth([double]$sec, [scriptblock]$f) {
  $n = [int]($sec * $Rate); $s = New-Object double[] $n
  for ($i = 0; $i -lt $n; $i++) { $s[$i] = & $f ($i / $Rate) $i }
  # Short fade at the end so nothing clicks.
  $fade = [Math]::Min(200, $n); for ($i = 0; $i -lt $fade; $i++) { $s[$n - 1 - $i] *= $i / $fade }
  , $s
}
function Square([double]$t, [double]$hz) { if ([Math]::Sin(2 * [Math]::PI * $hz * $t) -ge 0) { 1.0 } else { -1.0 } }
function Sine([double]$t, [double]$hz) { [Math]::Sin(2 * [Math]::PI * $hz * $t) }
$rng = [Random]::new(7)
function Noise { $rng.NextDouble() * 2 - 1 }

WriteWav 'klick' (Synth 0.05 { param($t) $hz = if ($t -lt 0.018) { 1046 } else { 1568 }; 0.22 * (Square $t $hz) * [Math]::Exp(-$t * 55) })

$script:lp = 0.0
WriteWav 'heben' (Synth 0.3 { param($t)
  $a = 0.05 + 0.25 * $t / 0.3; $script:lp += $a * ((Noise) - $script:lp)
  $en = [Math]::Pow([Math]::Sin([Math]::PI * $t / 0.3), 2)
  0.55 * $en * $script:lp + 0.08 * $en * (Sine $t (260 + 500 * $t)) })

WriteWav 'setzen' (Synth 0.16 { param($t)
  0.5 * (Sine $t 210) * [Math]::Exp(-$t * 38) + 0.3 * (Sine $t 590) * [Math]::Exp(-$t * 60) +
  0.14 * (Sine $t 1230) * [Math]::Exp(-$t * 95) + 0.45 * (Noise) * [Math]::Exp(-$t * 700) })

$script:lp = 0.0
WriteWav 'wisch' (Synth 0.55 { param($t)
  $a = 0.35 * (1 - $t / 0.55) + 0.02; $script:lp += $a * ((Noise) - $script:lp)
  $en = [Math]::Sin([Math]::PI * [Math]::Min(1.0, $t / 0.55)) * [Math]::Exp(-$t * 1.5)
  0.5 * $en * $script:lp })

$script:prev = 0.0
WriteWav 'karte' (Synth 0.13 { param($t)
  $x = Noise; $hp = $x - $script:prev; $script:prev = $x
  0.22 * $hp * [Math]::Sin([Math]::PI * [Math]::Min(1.0, $t / 0.13)) * [Math]::Exp(-$t * 12) })

WriteWav 'muenze' (Synth 0.34 { param($t) $hz = if ($t -lt 0.07) { 988 } else { 1319 }; 0.16 * (Square $t $hz) * [Math]::Exp(-$t * 7) })

$script:lp = 0.0
WriteWav 'treffer' (Synth 0.2 { param($t)
  $script:lp += 0.3 * ((Noise) - $script:lp)
  0.55 * $script:lp * [Math]::Exp(-$t * 22) + 0.5 * (Sine $t (120 - 220 * $t)) * [Math]::Exp(-$t * 16) })

WriteWav 'block' (Synth 0.28 { param($t)
  $m = (Sine $t 1180) * 0.5 + (Sine $t 1710) * 0.3 + (Sine $t 2430) * 0.2
  0.32 * $m * [Math]::Exp(-$t * 15) + 0.25 * (Noise) * [Math]::Exp(-$t * 500) })

WriteWav 'heilung' (Synth 0.48 { param($t)
  $notes = @(523, 659, 784, 1047); $k = [Math]::Min(3, [int][Math]::Floor($t / 0.1)); $lt = $t - $k * 0.1
  $tri = 2 / [Math]::PI * [Math]::Asin((Sine $t $notes[$k]))
  0.24 * $tri * [Math]::Min(1.0, $lt * 80) * [Math]::Exp(-$lt * 9) })
