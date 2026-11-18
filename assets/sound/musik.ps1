# Title music, medieval style, synthesised: D dorian, 3/4 at 96 bpm, about
# a minute, looping seamlessly (the reverb and string tails of the end are
# folded back into the start). Voices: plucked lute arpeggios (Karplus-Strong),
# a recorder-like flute melody with vibrato, a hurdy-gurdy style drone on D and
# A, a frame drum, and a light hall. Writes ui/assets/sound/titel.wav
# (16-bit mono, 22050 Hz). Deterministic.
# Form: 2 bars intro, A, A' (ends on the tonic), B, A'.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\ui\assets\sound\titel.wav'))
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class Musik {
    const int SR = 22050;
    static double Hz(int midi) { return 440.0 * Math.Pow(2, (midi - 69) / 12.0); }

    // Lute chords: four notes each, arpeggiated in eighths.
    static readonly Dictionary<string, int[]> Chords = new Dictionary<string, int[]> {
        { "Dm", new[] { 50, 57, 62, 65 } }, { "C", new[] { 48, 55, 60, 64 } },
        { "Am", new[] { 45, 52, 57, 60 } }, { "F", new[] { 41, 48, 53, 57 } },
        { "G", new[] { 43, 50, 55, 59 } },
    };
    static readonly string[] Intro = { "Dm", "Dm" };
    static readonly string[] A = { "Dm", "C", "Dm", "Am", "Dm", "F", "C", "Dm" };
    static readonly string[] B = { "Dm", "G", "Dm", "C", "F", "C", "Am", "Dm" };
    // Melodies as (midi, eighths); -1 is a rest. Eight bars of six eighths.
    static readonly int[,] MelA = {
        {69,2},{74,2},{72,1},{71,1}, {72,3},{67,2},{69,1}, {65,2},{67,1},{69,1},{65,1},{64,1}, {64,3},{69,3},
        {74,2},{72,1},{74,1},{76,2}, {72,2},{69,2},{65,2}, {67,2},{64,1},{67,1},{72,2}, {71,2},{69,1},{67,1},{69,2} };
    static readonly int[,] MelA2 = {
        {69,2},{74,2},{72,1},{71,1}, {72,3},{67,2},{69,1}, {65,2},{67,1},{69,1},{65,1},{64,1}, {64,3},{69,3},
        {74,2},{72,1},{74,1},{76,2}, {72,2},{69,2},{65,2}, {67,2},{64,1},{67,1},{64,2}, {62,6} };
    static readonly int[,] MelB = {
        {74,2},{76,2},{74,1},{72,1}, {71,3},{67,2},{71,1}, {69,2},{65,1},{69,1},{74,2}, {72,2},{76,2},{72,2},
        {69,3},{72,2},{69,1}, {67,2},{64,2},{67,2}, {69,2},{72,1},{71,1},{69,2}, {69,4},{-1,2} };

    static Random rnd = new Random(3);
    static double Noise() { return rnd.NextDouble() * 2 - 1; }

    // Plucked string: a noise burst circulating in a short, damped delay line.
    static void Pluck(double[] o, double start, int midi, double amp) {
        double f = Hz(midi); int n = Math.Max(2, (int)Math.Round(SR / f));
        var buf = new double[n]; double lp = 0;
        for (int i = 0; i < n; i++) { lp += 0.5 * (Noise() - lp); buf[i] = lp; }
        int s0 = (int)(start * SR), len = (int)(2.2 * SR); int idx = 0;
        for (int i = 0; i < len && s0 + i < o.Length; i++) {
            double v = buf[idx];
            buf[idx] = 0.5 * (buf[idx] + buf[(idx + 1) % n]) * 0.9965;
            idx = (idx + 1) % n;
            double fade = i > len - 2000 ? (len - i) / 2000.0 : 1;
            o[s0 + i] += v * amp * fade;
        }
    }

    // Recorder: sine with soft overtones, breath noise, vibrato after the attack.
    static void Flute(double[] o, double start, int midi, double dur, double amp) {
        double f = Hz(midi), ph = 0; int s0 = (int)(start * SR), len = (int)((dur + 0.08) * SR);
        for (int i = 0; i < len && s0 + i < o.Length; i++) {
            double t = (double)i / SR;
            double vib = 1 + 0.006 * Math.Sin(2 * Math.PI * 5.2 * t) * Math.Min(1, t / 0.25);
            ph += 2 * Math.PI * f * vib / SR;
            double s = Math.Sin(ph) + 0.22 * Math.Sin(2 * ph) + 0.07 * Math.Sin(3 * ph) + 0.03 * Noise();
            double env = Math.Min(1, t / 0.05);
            if (t > dur) env *= Math.Max(0, 1 - (t - dur) / 0.08);
            o[s0 + i] += s * env * amp;
        }
    }

    // Frame drum: pitched thump with a little skin noise.
    static void Drum(double[] o, double start, double amp) {
        int s0 = (int)(start * SR), len = (int)(0.35 * SR); double ph = 0;
        for (int i = 0; i < len && s0 + i < o.Length; i++) {
            double t = (double)i / SR; ph += 2 * Math.PI * (95 - 45 * Math.Min(1, t / 0.12)) / SR;
            o[s0 + i] += amp * (Math.Sin(ph) * Math.Exp(-t * 11) + 0.25 * Noise() * Math.Exp(-t * 60));
        }
    }

    static void Melody(double[] o, double start, int[,] mel, double eighth) {
        double t = start;
        for (int k = 0; k < mel.GetLength(0); k++) {
            int m = mel[k, 0]; double d = mel[k, 1] * eighth;
            if (m > 0) Flute(o, t, m, d * 0.95, 0.2);
            t += d;
        }
    }

    public static short[] Render() {
        double beat = 60.0 / 96, eighth = beat / 2, bar = 3 * beat;
        var bars = new List<string>(); bars.AddRange(Intro);
        bars.AddRange(A); bars.AddRange(A); bars.AddRange(B); bars.AddRange(A);
        int len = (int)(bars.Count * bar * SR), tail = 3 * SR;
        var o = new double[len + tail];
        int[] pattern = { 0, 1, 2, 3, 2, 1 };
        for (int b = 0; b < bars.Count; b++) {
            double t0 = b * bar; var ch = Chords[bars[b]];
            for (int e = 0; e < 6; e++) Pluck(o, t0 + e * eighth, ch[pattern[e]], e == 0 ? 0.32 : 0.22);
            Drum(o, t0, 0.32); Drum(o, t0 + 4 * eighth, 0.12); Drum(o, t0 + 5 * eighth, 0.1);
        }
        double mt = Intro.Length * bar;
        Melody(o, mt, MelA, eighth); Melody(o, mt + 8 * bar, MelA2, eighth);
        Melody(o, mt + 16 * bar, MelB, eighth); Melody(o, mt + 24 * bar, MelA2, eighth);
        // Drone on D2 and A2, a soft filtered saw with a slow swell.
        double p1 = 0, p2 = 0, lp = 0;
        for (int i = 0; i < len; i++) {
            double t = (double)i / SR;
            p1 = (p1 + Hz(38) / SR) % 1; p2 = (p2 + Hz(45) / SR) % 1;
            double saw = (p1 * 2 - 1) + 0.8 * (p2 * 2 - 1);
            lp += 0.04 * (saw - lp);
            o[i] += lp * 0.11 * (0.8 + 0.2 * Math.Sin(2 * Math.PI * t / 7.5));
        }
        // Light hall: a few feedback echoes.
        foreach (double d in new[] { 0.089, 0.131, 0.177 }) {
            int ds = (int)(d * SR);
            for (int i = ds; i < o.Length; i++) o[i] += o[i - ds] * 0.22;
        }
        // Fold the tail into the start, so the loop has no seam.
        for (int i = 0; i < tail; i++) o[i] += o[len + i];
        double peak = 1e-9; for (int i = 0; i < len; i++) peak = Math.Max(peak, Math.Abs(o[i]));
        var pcm = new short[len];
        for (int i = 0; i < len; i++) pcm[i] = (short)Math.Round(o[i] / peak * 0.85 * 32000);
        return pcm;
    }
}
'@

$pcm = [Musik]::Render()
$Out = [IO.Path]::GetFullPath($Out)
$fs = [IO.File]::Create($Out); $bw = [IO.BinaryWriter]::new($fs)
$data = $pcm.Length * 2
$bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([int](36 + $data)); $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
$bw.Write([Text.Encoding]::ASCII.GetBytes('fmt ')); $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
$bw.Write([int]22050); $bw.Write([int](22050 * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
$bw.Write([Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([int]$data)
foreach ($v in $pcm) { $bw.Write($v) }
$bw.Close(); $fs.Close()
'{0:n1} s, {1:n0} KB' -f ($pcm.Length / 22050), ((Get-Item $Out).Length / 1KB)
