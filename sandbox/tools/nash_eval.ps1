Param(
  [Parameter(Mandatory=$true)][string]$Path,
  [switch]$AnyNE,
  [switch]$PureNE,
  [switch]$ComputeMixed
)
$ErrorActionPreference="Stop"
if(-not ($AnyNE -or $PureNE -or $ComputeMixed)){ $AnyNE=$true }

function Get-PureNE($A,$B){
  $rows=$A.Count; $cols=$A[0].Count
  $maxA=@()
  for($j=0;$j -lt $cols;$j++){
    $col=@(); for($i=0;$i -lt $rows;$i++){ $col += [double]$A[$i][$j] }
    $maxA += ($col | Measure-Object -Maximum).Maximum
  }
  $maxB=@()
  for($i=0;$i -lt $rows;$i++){
    $row=@(); for($j=0;$j -lt $cols;$j++){ $row += [double]$B[$i][$j] }
    $maxB += ($row | Measure-Object -Maximum).Maximum
  }
  $nes=@()
  for($i=0;$i -lt $rows;$i++){
    for($j=0;$j -lt $cols;$j++){
      if([double]$A[$i][$j] -eq $maxA[$j] -and [double]$B[$i][$j] -eq $maxB[$i]){
        $nes += ,@($i,$j)
      }
    }
  }
  return ,$nes
}

function Get-MixedNE-2x2($A,$B){
  $a11=[double]$A[0][0]; $a12=[double]$A[0][1]; $a21=[double]$A[1][0]; $a22=[double]$A[1][1]
  $b11=[double]$B[0][0]; $b12=[double]$B[0][1]; $b21=[double]$B[1][0]; $b22=[double]$B[1][1]
  $denA = ($a11 - $a12) - ($a21 - $a22)
  $denB = ($b11 - $b21) - ($b12 - $b22)
  if([math]::Abs($denA) -lt 1e-12 -or [math]::Abs($denB) -lt 1e-12){ return $null }
  $q = ($a22 - $a12) / $denA
  $p = ($b22 - $b21) / $denB
  if($p -ge -1e-9 -and $p -le 1+1e-9 -and $q -ge -1e-9 -and $q -le 1+1e-9){
    return @{ p=[math]::Max(0,[math]::Min(1,$p)); q=[math]::Max(0,[math]::Min(1,$q)) }
  }
  return $null
}

try{
  $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
} catch {
  Write-Host "[nash] Konnte JSON nicht lesen: $Path" -ForegroundColor Yellow
  exit 2
}
$A = $json.payoffA; $B=$json.payoffB
if(-not $A -or -not $B -or $A.Count -ne 2 -or $A[0].Count -ne 2){ Write-Host "[nash] erwartet 2x2 Matrizen." -ForegroundColor Yellow; exit 2 }

$pnes = Get-PureNE $A $B
$hasPure = ($pnes.Count -gt 0)
if($hasPure){
  $list = ($pnes | ForEach-Object { "($($_[0]),$($_[1]))" }) -join ", "
  Write-Host "[nash] Pure NE: $list" -ForegroundColor Green
} else {
  Write-Host "[nash] Kein Pure NE gefunden." -ForegroundColor Yellow
}

$mixed = Get-MixedNE-2x2 $A $B
if($mixed){
  Write-Host ("[nash] Mixed NE: p(A0)={0:N3}, q(B0)={1:N3}" -f $mixed.p, $mixed.q) -ForegroundColor Green
}else{
  Write-Host "[nash] Kein Mixed NE ableitbar." -ForegroundColor Yellow
}

if($PureNE){ if($hasPure){ exit 0 } else { exit 1 } }
if($AnyNE){ if($hasPure -or $mixed){ exit 0 } else { exit 1 } }
if($ComputeMixed){ if($mixed){ exit 0 } else { exit 1 } }
exit 0
