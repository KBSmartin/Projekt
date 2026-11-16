# Builds the standalone versions of the game into out/:
#   out/Verlorene-Lande.exe        release build (optimized WASM)
#   out/Verlorene-Lande-Debug.exe  debug build (debug panel, debug WASM, readable panics)
# Each exe contains the whole web build and needs nothing else.
# Usage: .\build.ps1            both versions
#        .\build.ps1 -Only debug
param([ValidateSet('both', 'release', 'debug')][string]$Only = 'both')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:Path = "$env:USERPROFILE\.cargo\bin;" + $env:Path
New-Item -ItemType Directory -Force out | Out-Null

function Build-Variant($name, $exe, [string[]]$trunkArgs) {
  $web = "target/web/$name"
  Write-Host "== ${name}: trunk build" -ForegroundColor Cyan
  & trunk build @trunkArgs --dist $web
  if ($LASTEXITCODE -ne 0) { throw "trunk build ($name) fehlgeschlagen" }
  Write-Host "== ${name}: Startprogramm" -ForegroundColor Cyan
  $env:VL_WEB_DIR = (Resolve-Path $web).Path
  $env:VL_VARIANT = $name
  try {
    & cargo build --release -p launcher
    if ($LASTEXITCODE -ne 0) { throw "cargo build launcher ($name) fehlgeschlagen" }
  } finally {
    Remove-Item Env:VL_WEB_DIR, Env:VL_VARIANT -ErrorAction SilentlyContinue
  }
  Copy-Item target/release/verlorene-lande.exe "out/$exe" -Force
  $size = [Math]::Round((Get-Item "out/$exe").Length / 1MB, 1)
  Write-Host "   -> out/$exe ($size MB)" -ForegroundColor Green
}

if ($Only -in 'both', 'release') { Build-Variant 'release' 'Verlorene-Lande.exe' @('--release') }
if ($Only -in 'both', 'debug') { Build-Variant 'debug' 'Verlorene-Lande-Debug.exe' @() }
