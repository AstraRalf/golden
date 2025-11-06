#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

$ErrorActionPreference = "Stop"

function Get-ChangedFiles {
  $base = $env:GITHUB_BASE_REF
  if([string]::IsNullOrWhiteSpace($base)){ $base = "main" }
  try { git fetch origin $base --depth=1 2>$null | Out-Null } catch {}
  $range = "origin/$base...HEAD"
  $out = git --no-pager diff --name-only --diff-filter=ACMRT $range
  ($out -split "`n") | Where-Object { $_ -and (Test-Path $_) }
}

function Test-Luhn([string]$pan){
  $s = ($pan -replace '[^\d]','')
  if($s.Length -lt 13 -or $s.Length -gt 19){ return $false }
  $sum = 0; $alt = $false
  for($i=$s.Length-1; $i -ge 0; $i--){
    $n = [int]$s[$i].ToString()
    if($alt){ $n *= 2; if($n -gt 9){ $n -= 9 } }
    $sum += $n; $alt = -not $alt
  }
  return ($sum % 10 -eq 0)
}

function Load-Waivers([string]$path){
  $result = @()
  if(-not (Test-Path $path)){ return $result }
  $lines = [IO.File]::ReadAllLines($path)
  $cur = @{}
  foreach($raw in $lines){
    $line = $raw.Trim()
    if($line -match '^-+\s*$'){ continue }
    if($line -match '^\s*-\s*id\s*:\s*(\S+)\s*$'){ if($cur.Count -gt 0){ $result += [pscustomobject]$cur }; $cur=@{ id=$matches[1]; file=''; reason=''; expires='' }; continue }
    if($line -match '^\s*id\s*:\s*(\S+)\s*$'){ if($cur.Count -eq 0){ $cur=@{} }; $cur.id=$matches[1]; continue }
    if($line -match '^\s*file\s*:\s*(.+)$'){ $cur.file=$matches[1].Trim(); continue }
    if($line -match '^\s*reason\s*:\s*(.+)$'){ $cur.reason=$matches[1].Trim(); continue }
    if($line -match '^\s*expires\s*:\s*(.+)$'){ $cur.expires=$matches[1].Trim(); continue }
  }
  if($cur.Count -gt 0){ $result += [pscustomobject]$cur }
  return $result
}

function Is-Waived($ruleId, $filePath, $waivers){
  foreach($w in $waivers){
    if([string]::IsNullOrWhiteSpace($w.id) -or [string]::IsNullOrWhiteSpace($w.file)){ continue }
    $okRule = ($w.id -eq $ruleId)
    $okFile = ($filePath -like $w.file)
    if($okRule -and $okFile){
      if(-not [string]::IsNullOrWhiteSpace($w.expires)){
        try{
          $exp = [DateTime]::Parse($w.expires)
          if($exp -lt (Get-Date)){ continue }
        } catch { }
      }
      return $true
    }
  }
  return $false
}

function Match-Rules([string]$text,[string]$file){
  $hits=@()

  # Emails
  $reEmail = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'
  if([Text.RegularExpressions.Regex]::IsMatch($text,$reEmail)){ $hits += @{ id='pii.email'; file=$file; detail='email-like' } }

  # IBAN DE (heuristisch)
  $reIban = '\bDE\d{20}\b'
  if([Text.RegularExpressions.Regex]::IsMatch($text,$reIban)){ $hits += @{ id='pii.iban.de'; file=$file; detail='IBAN-like' } }

  # Credit Card (Luhn)
  $reCC = '(?:\b\d[ -]*){13,19}\b'
  $m = [Text.RegularExpressions.Regex]::Matches($text,$reCC)
  foreach($mm in $m){
    if(Test-Luhn $mm.Value){ $hits += @{ id='pii.cc'; file=$file; detail='luhn-pass' }; break }
  }

  # Secrets
  if([Text.RegularExpressions.Regex]::IsMatch($text,'\bAKIA[0-9A-Z]{16}\b')){ $hits += @{ id='secrets.aws_access_key'; file=$file; detail='AKIA*' } }
  if($text -match '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'){ $hits += @{ id='secrets.private_key'; file=$file; detail='private-key marker' } }

  # License/header (informational)
  if($file -match '\.(ps1|psm1|md|txt)$'){
    $hasHeader = ($text -match 'Copyright|MIT|Apache|BSD|License')
    if(-not $hasHeader){ $hits += @{ id='license.header'; file=$file; detail='consider adding license/header notice' } }
  }

  # Third-party (informational)
  if($text -match '©|Copyright' -and $text -match 'http'){ $hits += @{ id='thirdparty.notice'; file=$file; detail='3rd-party mention' } }

  return $hits
}

$waivers = Load-Waivers "docs/audit/WAIVER-UXLEGAL.yml"
$files = Get-ChangedFiles
$all=@()

foreach($f in $files){
  if((Get-Item $f).PSIsContainer){ continue }
  try{ $t = [IO.File]::ReadAllText($f) } catch { continue }
  $hits = Match-Rules $t $f
  foreach($h in $hits){
    if(-not (Is-Waived $h.id $h.file $waivers)){
      $all += ("[{0}] {1} - {2}" -f $h.id,$h.file,$h.detail)
    }
  }
}

if($all.Count -gt 0){
  Write-Warning "UXLegal (advisory; diff-only) — Hinweise:"
  $all | Sort-Object | ForEach-Object { Write-Host " - $_" }
} else {
  Write-Host "UXLegal: keine Hinweise (diff-only, waivers berücksichtigt)."
}
exit 0

