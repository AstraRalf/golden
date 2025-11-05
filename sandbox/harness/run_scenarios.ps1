Param([string]$Dir = "sandbox/scenarios")
$ErrorActionPreference = "Stop"

function Parse-Scenario([string]$path){
  $lines = [IO.File]::ReadAllLines($path)
  $inSteps=$false; $steps=@(); $current=@{}
  foreach($raw in $lines){
    $line = $raw.TrimEnd()
    if($line -match '^\s*#'){ continue }
    if(-not $inSteps -and $line -match '^\s*steps\s*:'){ $inSteps=$true; continue }
    if($inSteps){
      if($line -match '^\s*-\s*run\s*:\s*(.+)$'){
        if($current.Count -gt 0){ $steps += [pscustomobject]$current }
        $current=@{ run = $matches[1].Trim(); expect = 0 }; continue
      }
      if($line -match '^\s*expect(?:_exit|_code)?\s*:\s*(\d+)\s*$'){
        if($current.Count -eq 0){ continue }
        $current.expect = [int]$matches[1]; continue
      }
      if($line -match '^\S'){ break }
    }
  }
  if($current.Count -gt 0){ $steps += [pscustomobject]$current }
  return ,$steps
}

function Run-Cmd([string]$cmd){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'cmd.exe'; $psi.Arguments = '/c ' + $cmd
  $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError  = $true; $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
  [pscustomobject]@{ Exit=$p.ExitCode; Out=$out; Err=$err; Combined=($out+"`n"+$err).Trim() }
}

$files = Get-ChildItem -Path $Dir -Filter *.yml -File -ErrorAction SilentlyContinue
if(-not $files){ Write-Host "[scenarios] no YAML found in $Dir"; exit 0 }

foreach($f in $files){
  $scn = $f.Name
  Write-Host ("::group::[scenario] {0}" -f $scn)
  Write-Host "[scenario] $scn"

  $steps = Parse-Scenario $f.FullName
  if(-not $steps -or $steps.Count -eq 0){
    Write-Host "  (no steps)"
    Write-Host "::endgroup::"
    continue
  }

  $i=0
  foreach($s in $steps){
    $i++; Write-Host ("  [{0}] run: {1}" -f $i, $s.run)
    $r = Run-Cmd $s.run
    if($r.Exit -ne $s.expect){
      Write-Host ("  [FAIL] Exit={0} expected={1}" -f $r.Exit, $s.expect)
      if($r.Combined){ Write-Host ("    --- OUTPUT ---`n{0}" -f $r.Combined) }
      Write-Host "::endgroup::"
      exit 1
    } else {
      Write-Host ("  [OK] Exit={0}" -f $r.Exit)
    }
  }

  Write-Host "::endgroup::"
}

Write-Host "[scenarios] all runs successful."
exit 0
