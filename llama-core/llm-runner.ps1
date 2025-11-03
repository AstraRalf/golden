[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
param(
  [Parameter(Mandatory=$true)][string]$AgentName,
  [string]$Model = "llama3",
  [Parameter(Mandatory=$true)][string]$RoleFile,
  [string]$MemoryFile,
  [string]$UserPrompt
)

$ErrorActionPreference = "Stop"

# --- Inhalte laden (fehlertolerant) ---
$persona = if (Test-Path $RoleFile)       { Get-Content $RoleFile   -Raw -Encoding UTF8 } else { "" }
$context = if ($MemoryFile -and (Test-Path $MemoryFile)) { Get-Content $MemoryFile -Raw -Encoding UTF8 } else { "" }

$fullPrompt = @"
### SYSTEM PERSONA ($AgentName)
$persona

### CONTEXT
$context

### USER
$UserPrompt
"@

function Invoke-OllamaWithRetry {
  param(
    [string]$Model,
    [string]$Prompt,
    [int]$Tries = 5
  )
  for ($i=1; $i -le $Tries; $i++) {
    # Prompt in Tempdatei (stabiler als direkte Pipe bei langen Strings)
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $Prompt -Encoding UTF8

    # Ausführung (über cmd type -> vermeidet Edge-Cases beim PS-Pipe-Exitcode)
    cmd /c "type `"$tmp`" | ollama run $Model"
    $code = $LASTEXITCODE
    Remove-Item $tmp -ErrorAction SilentlyContinue

    if ($code -eq 0) { return $true }

    $delay = [int][math]::Min(20, 1 * [math]::Pow(2, ($i - 1)))  # 1,2,4,8,16
    Write-Host ("[RETRY] ollama exit={0}. Warte {1}s und versuche erneut ({2}/{3})..." -f $code,$delay,$i,$Tries) -ForegroundColor Yellow
    Start-Sleep -Seconds $delay
  }
  Write-Host "[FAIL] ollama run wiederholt fehlgeschlagen." -ForegroundColor Red
  return $false
}

Write-Host ("💡 Starte {0} für Agent {1}..." -f $Model, $AgentName) -ForegroundColor Cyan
$ok = Invoke-OllamaWithRetry -Model $Model -Prompt $fullPrompt -Tries 5

if ($ok) {
  Write-Host "`n[Beende mit STRG+C] oder [Fenster schließen]" -ForegroundColor DarkGray
  Start-Sleep -Seconds 86400
} else {
  # Fenster offen lassen, damit Fehlermeldung sichtbar bleibt
  Write-Host "`n[Runner beendet mit Fehler] – Fenster bleibt 60s offen." -ForegroundColor Red
  Start-Sleep -Seconds 60
}