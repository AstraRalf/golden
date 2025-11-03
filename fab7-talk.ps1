# In PS C:\Users\ralfb\golden ausfÃ¼hren:
$path = "C:\Users\ralfb\golden\fab7-talk.ps1"
@'
<#
 FAB7 Talk â€“ Interaktive Session mit einem Agenten (Arin fÃ¼hrt)
 Ort:  PS C:\Users\ralfb\golden  (von hier ausfÃ¼hren)

 Aufruf-Beispiele:
   .\fab7-talk.ps1 -Agent arin
   .\fab7-talk.ps1 -Agent vega -Model llama3
 Beenden: /quit
 Specials: /load <datei>   (Dateiinhalt als Prompt senden)
          /multi           (mehrzeilig, Abschluss mit Zeile: END)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('arin','argus','axel','lydia','vega','kayros','orion')]
  [string]$Agent,
  [string]$Model = 'llama3'
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Pfade
$Base     = 'C:\Users\ralfb\golden'
$FabPath  = Join-Path $Base 'llama-fab7'
$AgentDir = Join-Path $FabPath $Agent
$Persona  = Join-Path $AgentDir 'persona.yaml'
$Memory   = Join-Path $AgentDir 'memory.yaml'

if (-not (Test-Path $Persona)) { Write-Host ("[ERR] persona.yaml fehlt: {0}" -f $Persona) -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Memory))  { Write-Host ("[ERR] memory.yaml fehlt:  {0}" -f $Memory)  -ForegroundColor Red; exit 1 }

function Ensure-Ollama {
  $svc = Get-Service -Name 'Ollama' -ErrorAction SilentlyContinue
  if ($null -ne $svc -and $svc.Status -ne 'Running') {
    Write-Host "[INFO] Starte Dienst 'Ollama'..." -ForegroundColor Yellow
    Start-Service -Name 'Ollama'
    Start-Sleep -Seconds 2
  }
  for ($i=0; $i -lt 10; $i++) {
    try {
      Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -Method Get -TimeoutSec 5 | Out-Null
      return $true
    } catch {
      Start-Sleep -Seconds 1
    }
  }
  Write-Host "[ERR] Ollama API nicht erreichbar (127.0.0.1:11434)." -ForegroundColor Red
  return $false
}

if (-not (Ensure-Ollama)) { exit 1 }

# Laden von Persona + Memory als Text
$personaText = Get-Content $Persona -Raw -Encoding UTF8
$memoryText  = Get-Content $Memory  -Raw -Encoding UTF8

Write-Host ""
Write-Host ("=== FAB7 Talk â€“ {0} (Model: {1}) ===" -f $Agent, $Model) -ForegroundColor Cyan
Write-Host "Befehle: /quit | /load <datei> | /multi (Abschluss mit Zeile: END)" -ForegroundColor DarkGray
Write-Host ""

while ($true) {
  $first = Read-Host -Prompt 'Du'
  if ($first -eq '/quit') { break }

  $userText = ''

  if ($first -like '/load *') {
    $p = $first.Substring(6).Trim()
    if (-not (Test-Path $p)) {
      Write-Host ("[WARN] Datei nicht gefunden: {0}" -f $p) -ForegroundColor Yellow
      continue
    }
    $userText = Get-Content $p -Raw -Encoding UTF8
  }
  elseif ($first -eq '/multi') {
    Write-Host "Mehrzeiliger Modus. Beenden mit einer einzelnen Zeile: END" -ForegroundColor DarkGray
    $buf = @()
    while ($true) {
      $l = Read-Host
      if ($l -eq 'END') { break }
      $buf += $l
    }
    $userText = ($buf -join "`n")
  }
  else {
    $userText = $first
  }

  if ([string]::IsNullOrWhiteSpace($userText)) { continue }

  $fullPrompt = @"
### SYSTEM PERSONA ($Agent)
$personaText

### CONTEXT
$memoryText

### USER
$userText
"@

  # In Temp-Datei schreiben, dann stabil an ollama pipen
  $tmp = [System.IO.Path]::GetTempFileName()
  Set-Content -Path $tmp -Value $fullPrompt -Encoding UTF8

  try {
    cmd /c "type `"$tmp`" | ollama run $Model"
    $exit = $LASTEXITCODE
  } finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
  }

  if ($exit -ne 0) {
    Write-Host ("[ERR] ollama run exit code {0}" -f $exit) -ForegroundColor Red
  }

  Write-Host ""
}

Write-Host "Session beendet." -ForegroundColor Cyan
'@ | Set-Content -Path $path -Encoding UTF8
Write-Host ("[OK] fab7-talk.ps1 gespeichert: {0}" -f $path) -ForegroundColor Green