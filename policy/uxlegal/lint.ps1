#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

$ErrorActionPreference="Stop"
function Get-StagedFiles { (git diff --name-only --cached) -split "`n" | Where-Object { $_ -and (Test-Path $_) } }
. "$PSScriptRoot\ci_lint.ps1"  # Re-use Functions (Get-ChangedFiles wird ignoriert)
# Minimaler Adapter: staged Files statt diff-range
$files = Get-StagedFiles
$waivers = Load-Waivers "docs/audit/WAIVER-UXLEGAL.yml"
$all=@()
foreach($f in $files){
  if((Get-Item $f).PSIsContainer){ continue }
  try{ $t=[IO.File]::ReadAllText($f) }catch{ continue }
  $hits=Match-Rules $t $f
  foreach($h in $hits){ if(-not (Is-Waived $h.id $h.file $waivers)){ $all += ("[{0}] {1} - {2}" -f $h.id,$h.file,$h.detail) } }
}
if($all.Count -gt 0){ Write-Warning "UXLegal (advisory, staged):"; $all | Sort-Object | ForEach-Object{ Write-Host " - $_" } } else { Write-Host "UXLegal: keine Hinweise." }
exit 0

