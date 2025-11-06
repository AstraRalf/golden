#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

# =============================================
# FAB7 â€“ Risk-Audit von memory.yaml (Final)
# Ort:   C:\Users\ralfb\golden\risk-audit.ps1
# Start: PS C:\Users\ralfb\golden> .\risk-audit.ps1
# Wirkung: Setzt/aktualisiert RISK / RISK_WARNUNG je Agent
# Hinweis: Keine Emojis, UTF8-kompatibel fÃ¼r Windows PowerShell 5.1
# =============================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$base    = "C:\Users\ralfb\golden\llama-fab7"
$agents  = "arin","argus","axel","lydia","vega","kayros","orion"

# PrÃ¼f-Parameter
$minSkillCount   = 3
$minFactsCount   = 3
$jaccardThreshold = 0.20   # Mindest-Ã„hnlichkeit Zielâ†”Auftrag (0..1)

# ----------------- Hilfsfunktionen -----------------

function Normalize-Text {
  param([string]$s)
  if (-not $s) { return "" }
  $s = $s.ToLowerInvariant()
  # Unicode zerlegen und diakritische Zeichen entfernen
  $formD  = $s.Normalize([Text.NormalizationForm]::FormD)
  $noMark = [regex]::Replace($formD, "\p{Mn}", "")
  # deutsche Umlaute zusÃ¤tzlich absichern
  $noMark = $noMark -replace "Ã¤","ae" -replace "Ã¶","oe" -replace "Ã¼","ue" -replace "ÃŸ","ss"
  # Satzzeichen entfernen, Whitespace normalisieren
  $noPunct = [regex]::Replace($noMark, "[^a-z0-9\s]", " ")
  $noPunct = [regex]::Replace($noPunct, "\s+", " ").Trim()
  return $noPunct
}

# schlanke Stoppwortliste (kann erweitert werden)
$stop = @(
  "und","oder","der","die","das","ein","eine","einer","eines","ist","sind",
  "mit","im","in","am","an","den","dem","des","zu","zum","zur","von","fÃ¼r",
  "auf","aus","wie","dass","bis","ohne","nicht","jede","jeder","jedes","alle",
  "sofort","so","klar","klares","ziel","auftrag"
)

function To-TokenSet {
  param([string]$s)
  $s = Normalize-Text $s
  $hs = [System.Collections.Generic.HashSet[string]]::new()
  if (-not $s) { return $hs }
  foreach ($t in $s.Split(" ")) {
    if ($t.Length -lt 3) { continue }
    if ($stop -contains $t) { continue }
    [void]$hs.Add($t)
  }
  return $hs
}

function Jaccard {
  param([string]$a,[string]$b)
  $setA = To-TokenSet $a
  $setB = To-TokenSet $b
  if ($setA.Count -eq 0 -and $setB.Count -eq 0) { return 1.0 }
  if ($setA.Count -eq 0 -or  $setB.Count -eq 0) { return 0.0 }
  $inter = 0
  foreach ($t in $setA) { if ($setB.Contains($t)) { $inter++ } }
  $union = $setA.Count + $setB.Count - $inter
  if ($union -eq 0) { return 0.0 }
  return [math]::Round($inter / $union, 2)
}

function Get-Scalar {
  param([string]$text, [string[]]$keys)
  foreach ($k in $keys) {
    # nur einfache, einzeilige Werte
    $m = [regex]::Match($text, "(?mi)^\s*$k\s*:\s*""?([^\r\n""]+)""?\s*$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
  }
  return ""
}

function Get-ListStrict {
  param([string]$text, [string]$blockKey)
  # Block bis nÃ¤chstem Top-Level-Key oder EOF
  $pat = "(?msi)^\s*$blockKey\s*:\s*(?<b>.*?)(?=^\s*[A-Za-z0-9_\p{L}\-\.]+\s*:|\Z)"
  $m = [regex]::Match($text, $pat)
  if (-not $m.Success) { return @() }
  $b = $m.Groups['b'].Value
  $items = [regex]::Matches($b, "(?m)^\s*-\s+([^\r\n]+)") | ForEach-Object { $_.Groups[1].Value.Trim() }
  return $items
}

# ----------------- Hauptlauf -----------------

foreach ($agent in $agents) {
  $file = Join-Path $base "$agent\memory.yaml"
  if (-not (Test-Path $file)) {
    Write-Host ("[WARN] {0}: memory.yaml fehlt!" -f $agent) -ForegroundColor Yellow
    continue
  }

  $text = Get-Content $file -Raw -Encoding UTF8

  $ziel    = Get-Scalar $text @("ziel")
  $auftrag = Get-Scalar $text @("auftrag")
  $skills  = Get-ListStrict $text "skills"
  $kis     = Get-ListStrict $text "zusatz_kis"
  $facts   = Get-ListStrict $text "deep_facts"

  $warnings = New-Object System.Collections.Generic.List[string]

  if (-not $ziel)    { $warnings.Add("Ziel fehlt oder leer") }
  if (-not $auftrag) { $warnings.Add("Auftrag fehlt oder leer") }

  if ($ziel -and $auftrag) {
    $j = Jaccard $ziel $auftrag
    if ($j -lt $jaccardThreshold) {
      $warnings.Add(("Ziel/Auftrag geringe inhaltliche Ueberschneidung (J={0})" -f $j))
    }
  }

  if ($skills.Count -lt $minSkillCount) {
    $warnings.Add(("Weniger als {0} Skills" -f $minSkillCount))
  }

  if ($kis.Count -eq 0) {
    $warnings.Add("Keine Zusatz-KIs")
  } else {
    $dups = @($kis | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    if ($dups.Count -gt 0) {
      $warnings.Add(("Doppelte KIs: {0}" -f ($dups -join ", ")))
    }
  }

  if ($facts.Count -lt $minFactsCount) {
    $warnings.Add(("Weniger als {0} deep_facts" -f $minFactsCount))
  }

  # Alte RISK-Zeilen entfernen
  $clean = [regex]::Replace($text, "(?mi)^\s*(RISK|RISK_WARNUNG)\s*:\s*.*(?:\r?\n)?", "")

  if ($warnings.Count -eq 0) {
    $clean = $clean.TrimEnd() + "`r`nRISK: false`r`n"
    Write-Host ("[OK] {0}: Kein Risiko erkannt." -f $agent) -ForegroundColor Green
  } else {
    $warnText = ($warnings -join "; ")
    $clean = $clean.TrimEnd() + "`r`nRISK: true`r`nRISK_WARNUNG: '" + $warnText + "'`r`n"
    Write-Host ("[X] {0}: RISIKO! ({1})" -f $agent, $warnText) -ForegroundColor Red
  }

  Set-Content -Path $file -Value $clean -Encoding UTF8
}


