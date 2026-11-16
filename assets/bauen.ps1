# Rebuilds every generated graphic and copies the results into ui/assets.
# Windows PowerShell 5.1 (System.Drawing).
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
& (Join-Path $here 'karten\karten.ps1')
& (Join-Path $here 'portraets\animationen.ps1')
$bg = Join-Path $here '..\ui\assets\hintergrund'
New-Item -ItemType Directory -Force $bg | Out-Null
foreach ($n in 'wald', 'wueste', 'festung') {
  & (Join-Path $here "hintergrund\$n.ps1")
  Copy-Item (Join-Path $here "hintergrund\$n.png") (Join-Path $bg "$n.png") -Force
}
Write-Host 'Grafiken neu erzeugt.'
