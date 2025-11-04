Param()
$ErrorActionPreference='Stop'
Write-Host '[sandbox] smoke start'
if(-not (Test-Path '..\fixtures')){ Write-Warning 'Keine fixtures/ gefunden.' }
Write-Host '[sandbox] OK'
exit 0
