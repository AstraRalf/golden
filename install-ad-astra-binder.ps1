[CmdletBinding()]
param(
  [string]$Model = 'llama3'
)

$base    = 'C:\Users\ralfb\golden'
$chorus  = Join-Path $base 'fab7-chorus.ps1'

# Profil-Inhalt (nur Binder-Funktion, nichts Auto-Startendes)
$profileBody = @"
# === FAB7 'ad astra+++' Binder (safe) ===
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function ad {
  param([Parameter(ValueFromRemainingArguments=`$true)][string[]]`$args)
  `$phrase = (`$args -join ' ').Trim()
  if (`$phrase -eq 'astra+++') {
    `$chorus = '$chorus'
    if (Test-Path `$chorus) {
      Write-Host '[OK] Dauerchat gestartet. Befehle: /exit beendet, /save archiviert.' -ForegroundColor Green
      & `$chorus -Model '$Model'
    } else {
      Write-Host ('[ERR] fehlt: {0}' -f `$chorus) -ForegroundColor Red
    }
  } else {
    Write-Host 'Tipp: Gib ''ad astra+++'' ein, um zu starten.' -ForegroundColor DarkGray
  }
}
# === Ende Binder ===
"@

# Ziel-Profile (Windows PowerShell + PowerShell 7)
$docRoot      = [Environment]::GetFolderPath('MyDocuments')
$profiles     = @(
  (Join-Path $docRoot 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
  (Join-Path $docRoot 'PowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($p in $profiles) {
  $dir = Split-Path $p -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (Test-Path $p) { Copy-Item $p ($p + '.bak_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) -Force }
  Set-Content -Path $p -Value $profileBody -Encoding UTF8
  Write-Host ("[OK] Binder installiert: {0}" -f $p) -ForegroundColor Green
}

Write-Host "[HINWEIS] Profil jetzt neu laden:  . `$PROFILE   und dann:  ad astra+++" -ForegroundColor Cyan