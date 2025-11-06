[CmdletBinding()]
param(
  [string]$Model   = 'llama3',
  [string]$UriBase = 'http://127.0.0.1:11434'
)

# ===== Console/Paths =====
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Base    = 'C:\Users\ralfb\golden'
$FabPath = Join-Path $Base 'llama-fab7'
$Agents  = @('arin','argus','axel','lydia','vega','kayros','orion')

# ===== Helpers: REST & Retry =====
function Invoke-Json {
  param([string]$Method,[string]$Url,[string]$Body,[int]$TimeoutSec=240)
  Invoke-RestMethod -Uri $Url -Method $Method -ContentType 'application/json' `
    -Body $Body -TimeoutSec $TimeoutSec -Headers @{ 'Connection'='close' }
}
function Invoke-WithRetry {
  param([scriptblock]$Do,[int]$Tries=3)
  for($i=1;$i -le $Tries;$i++){
    try { return (& $Do) } catch { if($i -eq $Tries){ throw } ; Start-Sleep -Seconds ([int][math]::Pow(2,$i-1)) }
  }
}

# ===== Ollama =====
function Test-Ollama {
  try { Invoke-RestMethod -Uri ($UriBase + '/api/tags') -Method Get -TimeoutSec 5 | Out-Null ; $true } catch { $false }
}
function Warmup-Model {
  $body = @{ model=$Model; prompt='ping'; stream=$false } | ConvertTo-Json -Compress
  Invoke-WithRetry { Invoke-Json -Method 'POST' -Url ($UriBase + '/api/generate') -Body $body } | Out-Null
}

function Invoke-OllamaGenerate {
  param([string]$Prompt)
  $body = @{
    model=$Model; prompt=$Prompt; stream=$false; keep_alive='5m'; options=@{ temperature=0.2 }
  } | ConvertTo-Json -Depth 8 -Compress
  Invoke-WithRetry { Invoke-Json -Method 'POST' -Url ($UriBase + '/api/generate') -Body $body }
}
function Invoke-OllamaChat {
  param([string]$System,[string]$User)
  $messages = @(@{role='system';content=$System}, @{role='user';content=$User})
  $body = @{
    model=$Model; messages=$messages; stream=$false; keep_alive='5m'; options=@{ temperature=0.2 }
  } | ConvertTo-Json -Depth 8 -Compress
  Invoke-WithRetry { Invoke-Json -Method 'POST' -Url ($UriBase + '/api/chat') -Body $body }
}

# ===== Memory helpers =====
function Get-Scalar {
  param([string]$text,[string[]]$keys)
  foreach($k in $keys){
    $pat = ('(?mi)^\s*{0}\s*:\s*"?([^\r\n"]+)"?\s*$' -f ([regex]::Escape($k)))
    $m = [regex]::Match($text,$pat)
    if($m.Success){ return $m.Groups[1].Value.Trim() }
  } ; return ''
}
function Get-ListStrict {
  param([string]$text,[string]$blockKey)
  $pat = ('(?msi)^\s*{0}\s*:\s*(?<b>.*?)(?=^\s*[\p{{L}}\p{{N}}_.-]+\s*:|\Z)' -f ([regex]::Escape($blockKey)))
  $m = [regex]::Match($text,$pat)
  if(-not $m.Success){ return @() }
  return [regex]::Matches($m.Groups['b'].Value,'(?m)^\s*-\s+([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
}
function Get-VisionBlock {
  param([string]$text)
  $m = [regex]::Match($text,'(?msi)^\s*vision_anchor\s*:\s*(?<b>.*?)(?=^\s*[\p{L}\p{N}_.-]+\s*:|\Z)')
  if(-not $m.Success){ return @{} }
  $b = $m.Groups['b'].Value
  return @{
    ziel_1satz = Get-Scalar $b @('ziel_1satz')
    leitstern  = Get-Scalar $b @('leitstern')
    motivation = Get-Scalar $b @('motivation')
  }
}
function Remove-VisionAnchorBlock {
  param([string]$text)
  [regex]::Replace($text,'(?ms)^\s*vision_anchor\s*:\s*.*?(?=^\s*[\p{L}\p{N}_.-]+\s*:|\Z)','')
}
function Get-AgentGate {
  param([string]$Agent)
  $mem = Join-Path (Join-Path $FabPath $Agent) 'memory.yaml'
  if(-not (Test-Path $mem)){ return [pscustomobject]@{Agent=$Agent;READY=$false;RISK=$null;Gate='STOP (memory fehlt)'} }
  $t = Get-Content $mem -Raw -Encoding UTF8
  $ready = $false; if($t -match '(?mi)^\s*READY\s*:\s*true\b'){ $ready=$true }
  $risk = $null
  if     ($t -match '(?mi)^\s*RISK\s*:\s*true\b') { $risk=$true }
  elseif ($t -match '(?mi)^\s*RISK\s*:\s*false\b'){ $risk=$false }
  $gate = if($ready -and ($risk -eq $false)){'GO'}else{'STOP'}
  [pscustomobject]@{Agent=$Agent;READY=$ready;RISK=$risk;Gate=$gate}
}

# ===== Orion Vision-Anchor (Auto-Fix) =====
function Ensure-VisionAnchors {
  $anchors = @{
    arin = @{ ziel_1satz='Alle Eingaben sind so praezise und messbar, dass Entscheidungen sofort moeglich sind.'
              leitstern ='Erhoeht dieser Schritt die Entscheidungsfaehigkeit (READY)?'
              motivation='Klarheit spart Schleifen und verhindert Fehlstarts.' }
    axel = @{ ziel_1satz='Klarheit wird in einen testbaren Einzelschritt mit sofortigem Ergebnis verwandelt.'
              leitstern ='Liefert der naechste Schritt ein Pass/Fail in <= 1 Iteration?'
              motivation='Fortschritt in kleinsten, sicheren Inkrementen.' }
    argus=@{ ziel_1satz='Jedes Risiko ist vor Ausfuehrung sichtbar, bewertet und mit Fallback abgesichert.'
              leitstern ='Ist die Ampel gruen oder existiert ein klares Fallback?'
              motivation='Frueh erkannte Risiken sind billig.' }
    lydia=@{ ziel_1satz='Rohinformation ist in klaren Strukturen in bis zu drei Ebenen verstaendlich.'
              leitstern ='Ist die Struktur in <= 3 Ebenen und in 3 Sekunden erfassbar?'
              motivation='Gute Struktur halbiert die Denkzeit.' }
    vega = @{ ziel_1satz='Passende Tools und lauffaehige Snippets stellen die Technik sofort bereit.'
              leitstern ='Laeuft das Snippet im aktuellen Setup (Compat-Check)?'
              motivation='Laeuft vor Schoen.' }
    kayros=@{ ziel_1satz='Reihenfolge, Zeitfenster und Puffer machen die Umsetzung realistisch machbar.'
              leitstern ='Ist das jetzt dran und korrekt sequenziert?'
              motivation='Timing schlaegt Tempo.' }
    orion=@{ ziel_1satz='Ein klarer Leitstern richtet alle Schritte auf das gewuenschte Zielbild aus.'
              leitstern ='Bringt uns dieser Schritt messbar naeher ans Zielbild?'
              motivation='Ausrichtung verhindert Drift.' }
  }
  $fixed=@()
  foreach($a in $Agents){
    $file = Join-Path (Join-Path $FabPath $a) 'memory.yaml'
    if(-not (Test-Path $file)){ continue }
    $raw = Get-Content $file -Raw -Encoding UTF8
    $v = Get-VisionBlock $raw
    if(-not $v.ziel_1satz -or -not $v.leitstern -or -not $v.motivation){
      $t = Remove-VisionAnchorBlock $raw
      $an = $anchors[$a]
      $block = @"
vision_anchor:
  ziel_1satz: "$($an.ziel_1satz)"
  leitstern: "$($an.leitstern)"
  motivation: "$($an.motivation)"

"@
      ($t.TrimEnd() + "`r`n`r`n" + $block) | Set-Content -Path $file -Encoding UTF8
      $fixed += $a
    }
  }
  if($fixed.Count -gt 0){ Write-Host ("[FIX] vision_anchor aktualisiert fuer: {0}" -f ($fixed -join ', ')) -ForegroundColor Yellow }
}

# ===== Completeness Check =====
function Check-Completeness {
  param([string]$Agent)
  $mem = Join-Path (Join-Path $FabPath $Agent) 'memory.yaml'
  $miss=@()
  if(-not (Test-Path $mem)){ return @('memory.yaml fehlt') }
  $t = Get-Content $mem -Raw -Encoding UTF8
  foreach($c in @('ziel','rolle','auftrag')){
    if($t -notmatch ('(?mi)^\s*{0}\s*:\s*\S+' -f $c)){ $miss += $c }
  }
  if($t -notmatch '(?mi)^\s*(zustaendigkeit|zuständigkeit)\s*:\s*\S+'){ $miss += 'zustaendigkeit' }
  if((Get-ListStrict $t 'skills').Count -lt 1){ $miss += 'skills' }
  if((Get-ListStrict $t 'zusatz_kis').Count -lt 1){ $miss += 'zusatz_kis' }
  if((Get-ListStrict $t 'deep_facts').Count -lt 1){ $miss += 'deep_facts' }
  $vb = Get-VisionBlock $t
  foreach($k in @('ziel_1satz','leitstern','motivation')){ if(-not $vb[$k]){ $miss += "vision_anchor.$k" } }
  return $miss
}

# ===== Presentation =====
function Print-Status {
  $rows = foreach($a in $Agents){ Get-AgentGate -Agent $a }
  foreach($r in $rows){
    $riskText = if($r.RISK -eq $true){'true'} elseif ($r.RISK -eq $false){'false'} else {'n/a'}
    $fg = if ($r.Gate -eq 'GO') {'Green'} else {'Red'}
    Write-Host ("{0,-7} | READY={1,-5} | RISK={2,-5} | Gate={3}" -f $r.Agent,$r.READY,$riskText,$r.Gate) -ForegroundColor $fg
  }
}
function Get-Greeting {
  param([string]$Agent)
  $mem = Join-Path (Join-Path $FabPath $Agent) 'memory.yaml'
  if(-not (Test-Path $mem)){ return ("[{0}] memory.yaml fehlt." -f $Agent) }
  $t = Get-Content $mem -Raw -Encoding UTF8
  $rolle = (Get-Scalar $t @('rolle')); if(-not $rolle){ $rolle='Agent' }
  $gate  = Get-AgentGate -Agent $Agent
  ("[{0}] {1} - Gate={2}" -f $Agent,$rolle,$gate.Gate)
}

# ===== Conversation =====
function Get-SystemBlock {
@"
### SPRACHE
Antworte ausschliesslich auf Deutsch. Du-Form. Kurz (max. 2 Saetze). Kein Englisch.

### ROLLE & PERSONA
(Du bist einer der FAB7. Bleibe strikt in deiner Rolle. Keine Antworten fuer andere Agenten.)

### CONTEXT: persona.yaml & memory.yaml werden unten eingefuegt.
"@
}

function Ask-Model {
  param([string]$Agent,[string]$UserText)
  $dir = Join-Path $FabPath $Agent
  $persona = Join-Path $dir 'persona.yaml'
  $memory  = Join-Path $dir 'memory.yaml'
  $p = if(Test-Path $persona){ Get-Content $persona -Raw -Encoding UTF8 } else { '' }
  $m = if(Test-Path $memory ){ Get-Content $memory  -Raw -Encoding UTF8 } else { '' }

  $system = (Get-SystemBlock) + "`r`n### PERSONA ($Agent)`r`n$p`r`n### MEMORY`r`n$m"
  $user   = $UserText + "`r`n(Hinweis: Antworte NUR auf Deutsch. Max. 2 Saetze.)"

  try {
    $r = Invoke-OllamaChat -System $system -User $user
    if($r -and $r.message -and $r.message.content){ return ($r.message.content -replace "`r?`n","`r`n") }
    $g = Invoke-OllamaGenerate -Prompt ($system + "`r`n### USER`r`n" + $user)
    if($g -and $g.response){ return ($g.response -replace "`r?`n","`r`n") }
    return ("[{0}] (keine Antwort vom Modell)" -f $Agent)
  } catch {
    return ("[{0}] Modellfehler: {1}" -f $Agent, $_.Exception.Message)
  }
}

# ====== Main ======
if(-not (Test-Ollama)){ Write-Host ("[ERR] Ollama API nicht erreichbar: {0}" -f $UriBase) -ForegroundColor Red; exit 1 }
Warmup-Model

Write-Host ("=== FAB7 Chorus (Model: {0}) ===" -f $Model) -ForegroundColor Cyan
Write-Host "Tippe 'ad astra+++' fuer Handshake. Kommandos: /status, /check, /all, /only <agent>, /save, /quit" -ForegroundColor DarkGray
Write-Host ""

$targets = $Agents
$transcript = New-Object System.Collections.Generic.List[string]

while($true){
  $inp = Read-Host 'Du'

  if($inp -eq 'ad astra+++'){
    Ensure-VisionAnchors
    Write-Host '[HANDSHAKE] Gate-Status:' -ForegroundColor Cyan
    Print-Status
    Write-Host ""
    Write-Host '[HANDSHAKE] Kurzbegruessung:' -ForegroundColor Cyan
    foreach($a in $Agents){ Write-Host (Get-Greeting -Agent $a) }
    Write-Host ""
    Write-Host '[HANDSHAKE] Vollstaendigkeits-Check:' -ForegroundColor Cyan
    foreach($a in $Agents){
      $miss = Check-Completeness -Agent $a
      if($miss.Count -eq 0){ Write-Host ("[CHECK] {0}: OK" -f $a) -ForegroundColor Green }
      else { Write-Host ("[CHECK] {0}: NICHT OK -> {1}" -f $a, ($miss -join ', ')) -ForegroundColor Yellow }
    }
    continue
  }

  if($inp -eq '/status'){ Print-Status; Write-Host ''; continue }
  if($inp -eq '/check'){
    foreach($a in $Agents){
      $miss = Check-Completeness -Agent $a
      if($miss.Count -eq 0){ Write-Host ("[CHECK] {0}: OK" -f $a) -ForegroundColor Green }
      else { Write-Host ("[CHECK] {0}: NICHT OK -> {1}" -f $a, ($miss -join ', ')) -ForegroundColor Yellow }
    }
    Write-Host ''; continue
  }
  if($inp -eq '/all'){ $targets=$Agents; Write-Host '[OK] Zielmenge: alle'; continue }
  if($inp -like '/only *'){
    $name = ($inp -replace '^/only\s+','').Trim().ToLower()
    if($Agents -contains $name){ $targets=@($name); Write-Host ("[OK] Zielmenge: {0}" -f $name) } else { Write-Host '[WARN] Unbekannter Agent' -ForegroundColor Yellow }
    continue
  }
  if($inp -in @('/quit','/exit')){ Write-Host '[BYE] Ende.'; break }
  if($inp -eq '/save'){
    $logDir = Join-Path $Base 'llama-shared\logs'
    if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $log = Join-Path $logDir ('chorus_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
    $transcript | Set-Content -Path $log -Encoding UTF8
    Write-Host ("[OK] Log gespeichert: {0}" -f $log) -ForegroundColor Green
    continue
  }

  foreach($a in $targets){
    Write-Host ("[{0}] …" -f $a) -ForegroundColor DarkGray
    $ans = Ask-Model -Agent $a -UserText $inp
    $lineU = 'Du: ' + $inp
    $lineB = ("{0}: {1}" -f $a, $ans)
    $transcript.Add($lineU) | Out-Null
    $transcript.Add($lineB) | Out-Null
    Write-Host $lineB
    Write-Host ''
  }
}

