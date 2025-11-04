$ErrorActionPreference = "Stop"

function Get-ChangedFiles {
  $base = $env:GITHUB_BASE_REF
  if([string]::IsNullOrWhiteSpace($base)){ $base = "main" }
  try { git fetch origin $base --depth=1 2>$null | Out-Null } catch {}
  $range = "origin/$base...HEAD"
  $out = git --no-pager diff --name-only --diff-filter=ACMRT $range
  ($out -split "`n") | Where-Object { $_ -and (Test-Path $_) }
}

function Match-Rules([string]$text){
  $warn=@()
  if($text -match 'SSN|Kreditkarte|Passport'){ $warn += 'pii.generic' }
  return $warn
}

$files = Get-ChangedFiles
$hits = @()
foreach($f in $files){
  if((Get-Item $f).PSIsContainer){ continue }
  try{ $t = [IO.File]::ReadAllText($f) } catch { continue }
  $rules = Match-Rules $t
  foreach($r in $rules){ $hits += "[$r] $f" }
}

if($hits.Count -gt 0){
  Write-Warning "UXLegal (advisory) — Hinweise gefunden:"
  $hits | ForEach-Object { Write-Host " - $_" }
} else {
  Write-Host "UXLegal: keine Hinweise (diff-only)."
}
exit 0
