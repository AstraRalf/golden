# Sandbox (offline-first)
- Zweck: sichere Experimente, deterministische Smoke-Tests, keine Deploys.
- Start: pwsh .\sandbox\harness\smoke.ps1
"@

  Write-NormFile -RelPath 'sandbox/harness/smoke.ps1' -Content @"
Param()
\Stop='Stop'
Write-Host '[sandbox] smoke start'
# Beispielprüfung: Fixtures vorhanden?
if(-not (Test-Path '..\fixtures')){ Write-Warning 'Keine fixtures/ gefunden.' }
Write-Host '[sandbox] OK'
exit 0
