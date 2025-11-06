<#
 FAB7 Console â€“ Orchestrator (inkl. Schritt A/Mandat)
 Ort:  PS C:\Users\ralfb\golden  (von hier ausfÃ¼hren)

 Aufrufe:
   .\fab7-console.ps1 warmup
   .\fab7-console.ps1 audit
   .\fab7-console.ps1 overview
   .\fab7-console.ps1 status
   .\fab7-console.ps1 start -Model llama3 -StaggerSeconds 8
   .\fab7-console.ps1 stop
   .\fab7-console.ps1 mandate        # <â€” NEU: schreibt A. Mandat (Scope) in alle memory.yaml
#>

[CmdletBinding()]
param(
  [Parameter(Position=0, Mandatory=$true)]
  [ValidateSet('warmup','audit','overview','start','status','stop','mandate','hydrateA')]
  [string]$Command,

  [string]$Model = 'llama3',
  [int]$StaggerSeconds = 8
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Pfade
$Base    = 'C:\Users\ralfb\golden'
$FabPath = Join-Path $Base 'llama-fab7'
$Runner  = Join-Path $Base 'llama-core\llm-runner.ps1'
$Reports = Join-Path $Base 'llama-shared\reports'
$Agents  = @('arin','argus','axel','lydia','vega','kayros','orion')
if (-not (Test-Path $Reports)) { New-Item -Path $Reports -ItemType Directory -Force | Out-Null }

# â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Test-Ollama {
  try { Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -Method Get -TimeoutSec 5 | Out-Null; $true }
  catch { $false }
}

function Start-OllamaServiceIfPresent {
  $svc = Get-Service -Name 'Ollama' -ErrorAction SilentlyContinue
  if ($null -ne $svc -and $svc.Status -ne 'Running') {
    Write-Host "[INFO] Starte Windows-Dienst 'Ollama'..." -ForegroundColor Yellow
    Start-Service -Name 'Ollama'
    Start-Sleep -Seconds 2
  }
}

function Warmup {
  param([string]$Model)
  Start-OllamaServiceIfPresent
  $apiOk = $false
  for ($i=0; $i -lt 10; $i++) { if (Test-Ollama) { $apiOk = $true; break } else { Start-Sleep -Seconds 1 } }
  if (-not $apiOk) { throw 'Ollama API (127.0.0.1:11434) nicht erreichbar.' }

  try {
    $body = @{ model=$Model; prompt='ping'; stream=$false } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/generate' `
                      -Method Post -ContentType 'application/json' `
                      -Body $body -TimeoutSec 120 | Out-Null
    Write-Host ("[OK] Warmup fuer Modell '{0}' erfolgreich." -f $Model) -ForegroundColor Green
  } catch { throw ("Warmup fehlgeschlagen: {0}" -f $_.Exception.Message) }
}

# --- READY-Check (robust & mit Diagnose) ---
function Update-Ready {
  param([string]$MemPath)

  if (-not (Test-Path $MemPath)) { return @{ Ok=$false; Missing=@('memory.yaml fehlt') } }

  $text = Get-Content $MemPath -Raw -Encoding UTF8
  $missing = @()

  $checks = @(
    @{ Name='ziel'           ; Pat='(?mi)^\s*ziel\s*:\s*\S+' },
    @{ Name='rolle'          ; Pat='(?mi)^\s*rolle\s*:\s*\S+' },
    @{ Name='auftrag'        ; Pat='(?mi)^\s*auftrag\s*:\s*\S+' },
    # akzeptiert zustaendigkeit / zustÃ¤ndigkeit
    @{ Name='zustaendigkeit' ; Pat='(?mi)^\s*zust(ae|Ã¤)ndigkeit\s*:\s*\S+' }
  )
  foreach ($c in $checks) { if ($text -notmatch $c.Pat) { $missing += $c.Name } }

  $listChecks = @(
    @{ Name='skills'      ; Pat='(?msi)^\s*skills\s*:\s*(?:\r?\n\s*-\s*\S.*)+' },
    @{ Name='zusatz_kis'  ; Pat='(?msi)^\s*zusatz_kis\s*:\s*(?:\r?\n\s*-\s*\S.*)+' },
    @{ Name='deep_facts'  ; Pat='(?msi)^\s*deep_facts\s*:\s*(?:\r?\n\s*-\s*\S.*)+' }
  )
  foreach ($c in $listChecks) { if ($text -notmatch $c.Pat) { $missing += $c.Name } }

  $ok   = ($missing.Count -eq 0)
  $line = 'READY: ' + $(if($ok){'true'}else{'false'})

  if ($text -match '(?mi)^\s*READY\s*:') {
    $text = [regex]::Replace($text,'(?mi)^\s*READY\s*:\s*\S+', $line)
  } else {
    $text = $text.TrimEnd() + "`r`n" + $line + "`r`n"
  }
  Set-Content -Path $MemPath -Value $text -Encoding UTF8
  return @{ Ok=$ok; Missing=$missing }
}

function Get-AgentGate {
  param([string]$Agent)
  $memFile = Join-Path (Join-Path $FabPath $Agent) 'memory.yaml'
  if (-not (Test-Path $memFile)) {
    return [pscustomobject]@{ Agent=$Agent; READY=$false; RISK=$null; Gate='STOP (memory fehlt)' }
  }
  $t = Get-Content $memFile -Raw -Encoding UTF8
  $ready = $false; if ($t -match '(?mi)^\s*READY\s*:\s*true\b') {$ready=$true}
  $risk  = $null
  if     ($t -match '(?mi)^\s*RISK\s*:\s*true\b')  { $risk = $true }
  elseif ($t -match '(?mi)^\s*RISK\s*:\s*false\b') { $risk = $false }
  $gate = if ($ready -and ($risk -eq $false)) { 'GO' } else { 'STOP' }
  [pscustomobject]@{ Agent=$Agent; READY=$ready; RISK=$risk; Gate=$gate }
}

function Cmd-Status {
  $rows = foreach ($a in $Agents) { Get-AgentGate -Agent $a }
  foreach ($r in $rows) {
    $riskText = if ($r.RISK -eq $true) {'true'} elseif ($r.RISK -eq $false){'false'} else {'n/a'}
    $fg = if ($r.Gate -eq 'GO') {'Green'} else {'Red'}
    Write-Host ("{0,-7} | READY={1,-5} | RISK={2,-5} | Gate={3}" -f $r.Agent, $r.READY, $riskText, $r.Gate) -ForegroundColor $fg
  }
  $csv = Join-Path $Reports ("status_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".csv")
  $rows | Select-Object Agent,READY,@{n='RISK';e={ if($_.RISK -eq $true){'true'} elseif ($_.RISK -eq $false){'false'} else {'n/a'} }},Gate |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csv
  Write-Host ("[OK] Status-Report: {0}" -f $csv) -ForegroundColor Cyan
}

function Cmd-Start {
  param([string]$Model,[int]$StaggerSeconds)
  if (-not (Test-Path $Runner)) { throw ("Runner fehlt: {0}" -f $Runner) }

  Warmup -Model $Model

  $started = 0
  foreach ($agent in $Agents) {
    $agentDir = Join-Path $FabPath $agent
    $persona  = Join-Path $agentDir 'persona.yaml'
    $memory   = Join-Path $agentDir 'memory.yaml'

    if (-not (Test-Path $persona)) { Write-Host ("[SKIP] {0}: persona.yaml fehlt" -f $agent) -ForegroundColor Yellow; continue }
    if (-not (Test-Path $memory))  { Write-Host ("[SKIP] {0}: memory.yaml fehlt" -f $agent) -ForegroundColor Yellow;  continue }

    $gate = Get-AgentGate -Agent $agent
    if ($gate.Gate -ne 'GO') { Write-Host ("[SKIP] {0}: Gate STOP (READY/RISK)" -f $agent) -ForegroundColor Yellow; continue }

    Write-Host ("[START] {0}" -f $agent) -ForegroundColor Green
    Start-Process powershell.exe -WorkingDirectory $agentDir -ArgumentList @(
      '-NoExit','-NoLogo','-ExecutionPolicy','Bypass',
      '-File', $Runner,
      '-AgentName', $agent,
      '-Model', $Model,
      '-RoleFile', $persona,
      '-MemoryFile', $memory
    )
    Start-Sleep -Seconds $StaggerSeconds
    $started++
  }
  Write-Host ("[SUMMARY] gestartete Fenster: {0}" -f $started) -ForegroundColor Cyan
}

function Cmd-Stop {
  $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
           Where-Object { $_.CommandLine -match 'llama-core\\llm-runner.ps1' -and $_.CommandLine -match '\\llama-fab7\\' }
  $n = 0
  foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $n++ }
  Write-Host ("[OK] Beendet: {0} Runner-Fenster" -f $n) -ForegroundColor Green
}

function Cmd-Audit {
  foreach ($a in $Agents) {
    $mem = Join-Path (Join-Path $FabPath $a) 'memory.yaml'
    $res = Update-Ready -MemPath $mem
    if ($res.Ok) {
      Write-Host ("[READY] {0}: true" -f $a) -ForegroundColor Green
    } else {
      Write-Host ("[READY] {0}: false (fehlt: {1})" -f $a, ($res.Missing -join ', ')) -ForegroundColor Yellow
    }
  }

  $riskAudit = Join-Path $Base 'risk-audit.ps1'
  if (Test-Path $riskAudit) {
    Write-Host '[INFO] risk-audit.ps1 wird ausgefuehrt...' -ForegroundColor Cyan
    & $riskAudit
  } else {
    Write-Host '[WARN] risk-audit.ps1 nicht gefunden â€“ RISK bleibt unveraendert.' -ForegroundColor Yellow
  }

  Cmd-Status
}

function Cmd-Overview {
  $outFile = Join-Path $Base 'llama-shared\overview.md'
  $outDir  = Split-Path $outFile -Parent
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

  function Get-Scalar([string]$text,[string[]]$keys){
    foreach($k in $keys){
      $pattern = ('(?mi)^\s*{0}\s*:\s*"?([^\r\n"]+)"?\s*$' -f ([regex]::Escape($k)))
      $m = [regex]::Match($text,$pattern)
      if($m.Success){ return $m.Groups[1].Value.Trim() }
    }; return ''
  }
  function Get-ListStrict([string]$text,[string]$blockKey){
    $pat = ('(?msi)^\s*{0}\s*:\s*(?<b>.*?)(?=^\s*[\p{{L}}\p{{N}}_.-]+\s*:|\Z)' -f ([regex]::Escape($blockKey)))
    $m = [regex]::Match($text,$pat)
    if(-not $m.Success){ return @() }
    return [regex]::Matches($m.Groups['b'].Value,'(?m)^\s*-\s+([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
  }
  function Get-VisionBlock([string]$text){
    $m = [regex]::Match($text,'(?msi)^\s*vision_anchor\s*:\s*(?<b>.*?)(?=^\s*[\p{L}\p{N}_.-]+\s*:|\Z)')
    if(-not $m.Success){ return @{} }
    $b=$m.Groups['b'].Value
    return @{
      ziel_1satz = Get-Scalar $b @('ziel_1satz')
      leitstern  = Get-Scalar $b @('leitstern')
      motivation = Get-Scalar $b @('motivation')
    }
  }

  $md = @('# FAB7 Overview','',("_Stand: {0}_" -f (Get-Date -Format 'yyyy-MM-dd HH:mm')),'')
  foreach($agent in $Agents){
    $memFile = Join-Path (Join-Path $FabPath $agent) 'memory.yaml'
    $md += "## $agent",""
    if(-not (Test-Path $memFile)){ $md += '> WARN: memory.yaml fehlt',''; continue }

    $mem = Get-Content $memFile -Raw -Encoding UTF8
    $ziel    = Get-Scalar $mem @('ziel')
    $rolle   = Get-Scalar $mem @('rolle')
    $zust    = Get-Scalar $mem @('zustaendigkeit','zustÃ¤ndigkeit','zust.ndigkeit','zust.*ndigkeit')
    $auftrag = Get-Scalar $mem @('auftrag')
    $ready   = if($mem -match '(?mi)^\s*READY\s*:\s*true\b'){'true'} elseif ($mem -match '(?mi)^\s*READY\s*:\s*false\b'){'false'} else {'n/a'}
    $risk    = if($mem -match '(?mi)^\s*RISK\s*:\s*true\b') {'true'} elseif ($mem -match '(?mi)^\s*RISK\s*:\s*false\b') {'false'} else {'n/a'}
    $riskW   = Get-Scalar $mem @('RISK_WARNUNG')
    $skills  = Get-ListStrict $mem 'skills'
    $kis     = Get-ListStrict $mem 'zusatz_kis'
    $vision  = Get-VisionBlock $mem

    $md += '| Feld | Wert |','|---|---|'
    $md += ("| Rolle | {0} |"   -f ($rolle   -replace '\|','\|'))
    $md += ("| Ziel  | {0} |"   -f ($ziel    -replace '\|','\|'))
    $md += ("| Auftrag | {0} |" -f ($auftrag -replace '\|','\|'))
    $md += ("| Zustaendigkeit | {0} |" -f ($zust -replace '\|','\|'))
    $md += ("| READY | {0} |"  -f $ready)
    $md += ("| RISK  | {0} |"  -f $risk)
    if($riskW){ $md += ("| RISK_WARNUNG | {0} |" -f ($riskW -replace '\|','\|')) }
    $md += ''
    $md += '**Vision-Anchor**'
    $md += ("- Ziel-1-Satz: {0}" -f ($vision.ziel_1satz -replace '\|','\|'))
    $md += ("- Leitstern:   {0}" -f ($vision.leitstern  -replace '\|','\|'))
    $md += ("- Motivation:  {0}" -f ($vision.motivation -replace '\|','\|'))
    $md += ''
    $md += ("**Skills ({0})**" -f $skills.Count)
    if($skills.Count -gt 0){ $skills | ForEach-Object { $md += ("- {0}" -f $_) } } else { $md += '- â€”' }
    $md += ''
    $md += ("**Zusatz-KIs ({0})**" -f $kis.Count)
    if($kis.Count -gt 0){ $kis | ForEach-Object { $md += ("- {0}" -f $_) } } else { $md += '- â€”' }
    $md += '','---',''
  }

  $md | Set-Content -Path $outFile -Encoding UTF8
  Write-Host ("[OK] Uebersicht geschrieben: {0}" -f $outFile) -ForegroundColor Green
}

# ====== NEU: Schritt A / Mandat (Scope) ======
function Remove-TopBlock {
  param([string]$text,[string]$key)
  $pat = '(?ms)^\s*' + [regex]::Escape($key) + '\s*:\s*.*?(?=^\S|\Z)'
  return [regex]::Replace($text,$pat,'')
}

function Write-MandateBlock {
  param([string]$file,[string[]]$InList,[string[]]$OutList)

  $raw = Get-Content $file -Raw -Encoding UTF8
  $raw = Remove-TopBlock -text $raw -key 'mandat'
  $lines = @()
  $lines += 'mandat:'
  $lines += '  in:'
  foreach($i in $InList){ $lines += ('    - {0}' -f $i) }
  $lines += '  out:'
  foreach($o in $OutList){ $lines += ('    - {0}' -f $o) }

  $out = $raw.TrimEnd() + "`r`n`r`n" + ($lines -join "`r`n") + "`r`n"
  Set-Content -Path $file -Value $out -Encoding UTF8
}

function Cmd-Mandate {
  # Inhalte aus deinem FAB7-Dossier (ASCII-varianten), Quelle: internes Dossier
  # Arin
  $arin_in  = @('Begriffsdefinitionen','Zielschaerfung','Ambiguitaeten-Aufloesung','harte Entscheidungsvorlagen (A/B, Ja/Nein)','Eingabe-Normalisierung')
  $arin_out = @('Umsetzungsschritte -> Axel','Risikoabwaegung -> Argus','Zeit/Sequenz -> Kayros','Strukturierung -> Lydia','Tool/Infra-Empfehlungen -> Vega','Zielbilder -> Orion')

  # Axel
  $axel_in  = @('Klare Definitionen + READY=true von Arin','uebergebene Risiken von Argus','Zeitfenster von Kayros','Strukturvorgaben von Lydia','Toolhinweise von Vega','Zielbilder von Orion')
  $axel_out = @('exakte, testbare Handlungsschritte (sofort)','Testbeschreibung (Pass/Fail)','Ressourcenliste (Tools, Dateien, Parameter)','Ergebnisflag DONE true/false')

  # Argus
  $argus_in  = @('Inputs des Users','Definitionen von Arin','Schritte von Axel','Timing von Kayros','Strukturen von Lydia','Technik von Vega','Zielbild von Orion')
  $argus_out = @('Risikomatrix (Kategorie, Schwere, Wahrscheinlichkeit)','Ampelstatus (Gruen/Gelb/Rot)','Warnhinweis (kurz)','Fallback-Optionen')

  # Kayros
  $kay_in  = @('Klarheit von Arin','Schritte von Axel','Risiko-Einschaetzungen von Argus','Strukturen von Lydia','Toolvorschlaege von Vega','Zielbilder von Orion')
  $kay_out = @('Zeitplaene','Prioritaetenlisten (MUST/SHOULD/LATER)','Sequenzen','Stop-/Go-Signal')

  # Lydia
  $lyd_in  = @('Definitionen von Arin','Umsetzungsschritte von Axel','Risikomeldungen von Argus','Zeitplaene von Kayros','Tool-Hinweise von Vega','Zielbilder von Orion')
  $lyd_out = @('Strukturen','Gliederungen','Tabellen','Roadmaps')

  # Vega
  $veg_in  = @('Klarheit von Arin','Schritte von Axel','Risiko-Einschaetzungen von Argus','Zeitfenster von Kayros','Struktur von Lydia','Zielbilder von Orion')
  $veg_out = @('Tools','Code-Snippets','technische Empfehlungen','konkrete Kommandos')

  # Orion
  $ori_in  = @('Definitionen (Arin)','Schritte (Axel)','Risiken (Argus)','Zeitplaene (Kayros)','Strukturen (Lydia)','Tools (Vega)')
  $ori_out = @('Zielbild-Formulierungen (1 Satz)','Soll-Ist-Abgleich','Leitstern-Frage','Motivationsanker')

  $map = @{
    'arin'  = @{ IN=$arin_in; OUT=$arin_out }
    'axel'  = @{ IN=$axel_in; OUT=$axel_out }
    'argus' = @{ IN=$argus_in; OUT=$argus_out }
    'kayros'= @{ IN=$kay_in ; OUT=$kay_out }
    'lydia' = @{ IN=$lyd_in ; OUT=$lyd_out }
    'vega'  = @{ IN=$veg_in ; OUT=$veg_out }
    'orion' = @{ IN=$ori_in ; OUT=$ori_out }
  }

  foreach($a in $Agents){
    $file = Join-Path (Join-Path $FabPath $a) 'memory.yaml'
    if (-not (Test-Path $file)) { Write-Host ("[WARN] {0}: memory.yaml fehlt" -f $a) -ForegroundColor Yellow; continue }
    $IN  = $map[$a].IN
    $OUT = $map[$a].OUT
    Write-MandateBlock -file $file -InList $IN -OutList $OUT
    Write-Host ("[OK] {0}: mandat (A/Scope) gesetzt" -f $a) -ForegroundColor Green
  }

  # Nachziehen: READY (und ggf. risk-audit) aktualisieren
  Cmd-Audit
}

# â”€â”€ Dispatcher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
try {
  switch ($Command) {
    'warmup'   { Warmup -Model $Model }
    'audit'    { Cmd-Audit }
    'overview' { Cmd-Overview }
    'status'   { Cmd-Status }
    'start'    { Cmd-Start -Model $Model -StaggerSeconds $StaggerSeconds }
    'stop'     { Cmd-Stop }
    'mandate'  { Cmd-Mandate }
    'hydrateA' { Cmd-Mandate }  # Alias
  }
}
catch {
  Write-Host ("[ERR] {0}" -f $_.Exception.Message) -ForegroundColor Red
  exit 1
}

