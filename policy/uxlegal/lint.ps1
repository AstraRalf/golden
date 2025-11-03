\Stop='Stop'
function Get-StagedFiles {
  (git diff --name-only --cached) -split \"
\" | Where-Object { \ -and (Test-Path \) }
}
function Match-Rules([string]\){
  \=@(); if(\ -match 'SSN|Kreditkarte|Passport'){ \ += 'pii.generic' }
  return \
}
\ = Get-StagedFiles
\=@()
foreach(\ in \){
  if((Get-Item \).PSIsContainer){ continue }
  try{ \ = [IO.File]::ReadAllText(\) } catch { continue }
  \ = Match-Rules \
  foreach(\ in \){ \ += \"[\] \\" }
}
if(\.Count -gt 0){
  Write-Warning 'UXLegal Hinweise (advisory):'
  \ | ForEach-Object { Write-Host \" - \\" }
  exit 0
} else {
  Write-Host 'UXLegal: keine Hinweise.'
  exit 0
}
