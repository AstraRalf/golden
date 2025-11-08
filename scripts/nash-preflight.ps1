Param([switch]$ci)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$fail = 0
function Ok  ($m){ Write-Host ("✔️  " + $m) -ForegroundColor Green }
function Bad ($m){ Write-Host ("❌ " + $m) -ForegroundColor Red; $script:fail++ }
function Info($m){ Write-Host ("ℹ️  " + $m) -ForegroundColor DarkCyan }
function Link($t,$u){ Write-Host ("🔗 {0}: {1}" -f $t,$u) }

# 0) Umgebung (lokal vs CI)
if (-not $ci) {
  try { gh --version *> $null; Ok "gh CLI vorhanden." } catch { Info "gh CLI lokal nicht verfügbar (optional)." }
  try {
    $origin = git remote get-url origin
    if ($origin -match 'github.com[:/](.+)/(.+?)(?:\.git)?$'){ Ok ("GitHub-Remote: {0}/{1}" -f $Matches[1],$Matches[2]) } else { Info "Remote nicht GitHub (optional)." }
  } catch { Info "Git-Remote nicht lesbar (optional)." }
}

# 1) Workflow vorhanden?
$wfRel = '.github/workflows/nash-regression.yml'
if (-not (Test-Path $wfRel)) { Bad "Workflow fehlt: $wfRel" } else { Ok "Workflow-Datei gefunden: $wfRel" }
$yaml = if (Test-Path $wfRel) { Get-Content $wfRel -Raw -Encoding UTF8 } else { "" }

# 2) Keine riskanten caches
if ($yaml -match '(?m)^\s*cache\s*:\s*\S+') { Bad "Workflow nutzt 'cache:' im setup-python-Step → ohne requirements/pyproject riskant." } else { Ok "Kein 'cache:' in setup-python." }

# 3) Packaging ODER jobweiter PYTHONPATH
$patternPyPath = '(?s)\bjobs\s*:\s*.*?\btest-and-export\s*:\s*.*?\benv\s*:\s*.*?\bPYTHONPATH\s*:\s*\$\{\{\s*github\.workspace\s*\}\}'
$hasPyPath     = [regex]::IsMatch($yaml, $patternPyPath)
$hasPyProject  = Test-Path 'pyproject.toml'
$hasSetup      = (@(Get-ChildItem -File -Name 'setup.*' -ErrorAction SilentlyContinue).Count -gt 0)

if ($hasPyProject -or $hasSetup) {
  Ok ("Packaging erkannt ({0})." -f (if($hasPyProject){'pyproject.toml'} else {'setup.*'}))
} else {
  if ($hasPyPath) { Ok 'Jobweiter PYTHONPATH=${{ github.workspace }} gesetzt.' }
  else { Bad "Weder Packaging noch jobweiter PYTHONPATH im Workflow → 'ModuleNotFoundError: lama' wahrscheinlich." }
}

# 4) Schritte-Qualität
if ($yaml -match 'actions/setup-python@v5') { Ok "actions/setup-python@v5 verwendet." } else { Bad "setup-python nicht @v5 (oder fehlt)." }
if ($yaml -match 'python\s+-m\s+pytest') { Ok "Tests via 'python -m pytest'." } else {
  if ($yaml -match 'pytest\s+-q') { Info "pytest -q gefunden; Empfehlung: 'python -m pytest'." } else { Bad "Kein Pytest-Schritt gefunden." }
}

# 5) Trigger
$pushMain = [regex]::IsMatch($yaml, '(?s)\bon\s*:\s*.*?push\s*:\s*.*?branches\s*:\s*\[\s*"?main"?\s*\]')
if ($pushMain) { Ok "Trigger enthält push → main." } else { Info "push→main nicht eindeutig (manuelles Dispatch ok)." }
if ($yaml -match '(?m)^\s*workflow_dispatch\s*:') { Ok "workflow_dispatch aktiv." } else { Info "workflow_dispatch fehlt (optional)." }

# 6) Repo-Struktur
$pkgOk   = (Test-Path 'lama\__init__.py') -or (Test-Path 'lama/__init__.py')
$runner  = (Test-Path 'lama\nash\runner.py') -or (Test-Path 'lama/nash/runner.py')
$testsOk = (Test-Path 'lama\tests\test_nash2x2.py') -or (Test-Path 'lama/tests/test_nash2x2.py')
$scenCnt = @(Get-ChildItem -Recurse -File -Include *.nash -ErrorAction SilentlyContinue | Select-Object -First 1).Count -gt 0

if ($pkgOk)   { Ok "Paketstamm 'lama/' vorhanden." } else { Bad "Ordner 'lama/' mit __init__.py fehlt." }
if ($runner)  { Ok "Runner 'lama/nash/runner.py' vorhanden." } else { Bad "Runner fehlt: lama/nash/runner.py" }
if ($testsOk) { Ok "Tests gefunden: lama/tests/test_nash2x2.py" } else { Bad "Tests fehlen: lama/tests/test_nash2x2.py" }
if ($scenCnt) { Ok "Mind. ein *.nash-Szenario vorhanden." } else { Info "Keine *.nash-Dateien gefunden (Export optional)." }

Write-Host "`n==================== PRECHECK-SUMMARY ====================" -ForegroundColor Yellow
if ($fail -eq 0) {
  Ok  "Alle kritischen Voraussetzungen erfüllt."
} else {
  Bad ("{0} kritische(r) Check(s) fehlgeschlagen." -f $fail)
  Write-Host "Empfehlungen:" -ForegroundColor Yellow
  if ($yaml -match '(?m)^\s*cache\s*:') { Write-Host ' - Entferne "cache:" im setup-python-Step.' }
  if (-not ($hasPyProject -or $hasSetup) -and -not $hasPyPath) { Write-Host ' - Setze jobweit `PYTHONPATH: ${{ github.workspace }}` ODER füge Packaging hinzu.' }
  if (-not $pkgOk)    { Write-Host " - Stelle sicher, dass 'lama/__init__.py' vorhanden ist." }
  if (-not $runner)   { Write-Host " - Pflege 'lama/nash/runner.py'." }
  if (-not $testsOk)  { Write-Host " - Ergänze Tests 'lama/tests/test_nash2x2.py'." }
  if (-not $pushMain) { Write-Host ' - Optional: Trigger push: ["main"] ergänzen.' }
}

$code = if ($fail -eq 0) { 0 } else { 2 }
if ($ci) { exit $code } else { $null = Read-Host -Prompt "Fertig. Enter zum Schließen…"; exit $code }