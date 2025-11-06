#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

Param(
  [Parameter(Mandatory=$true)][string]$Path,
  [switch]$AnyNE,
  [switch]$PureNE,
  [switch]$ComputeMixed,
  [switch]$ReportPoA
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

  # Indifferenz (korrekt für 2x2)
  $denA = (($a11 - $a21) - ($a12 - $a22))
  $denB = (($b11 - $b12) - ($b21 - $b22))
  if([math]::Abs($denA) -lt 1e-12 -or [math]::Abs($denB) -lt 1e-12){ return $null }

  $q = ($a22 - $a12) / $denA
  $p = ($b22 - $b21) / $denB

  if($p -ge -1e-9 -and $p -le 1+1e-9 -and $q -ge -1e-9 -and $q -le 1+1e-9){
    return @{ p=[math]::Max(0,[math]::Min(1,[double]$p)); q=[math]::Max(0,[math]::Min(1,[double]$q)) }
  }
  return $null
}

function Welfare([double[][]]$A,[double[][]]$B,[int]$i,[int]$j){ return [double]$A[$i][$j] + [double]$B[$i][$j] }

function WelfareMixed([double[][]]$A,[double[][]]$B,[double]$p,[double]$q){
  $a11=[double]$A[0][0]; $a12=[double]$A[0][1]; $a21=[double]$A[1][0]; $a22=[double]$A[1][1]
  $b11=[double]$B[0][0]; $b12=[double]$B[0][1]; $b21=[double]$B[1][0]; $b22=[double]$B[1][1]
  $wA = $p*$q*$a11 + $p*(1-$q)*$a12 + (1-$p)*$q*$a21 + (1-$p)*(1-$q)*$a22
  $wB = $p*$q*$b11 + $p*(1-$q)*$b12 + (1-$p)*$q*$b21 + (1-$p)*(1-$q)*$b22
  return $wA + $wB
}

try{
  $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
} catch {
  Write-Host "[nash] Konnte JSON nicht lesen: $Path"
  exit 2
}
$A = $json.payoffA; $B=$json.payoffB
if(-not $A -or -not $B -or $A.Count -ne 2 -or $A[0].Count -ne 2){ Write-Host "[nash] erwartet 2x2 Matrizen."; exit 2 }

$ic = [System.Globalization.CultureInfo]::InvariantCulture

$pnes = Get-PureNE $A $B
$hasPure = ($pnes.Count -gt 0)
if($hasPure){
  $list = ($pnes | ForEach-Object { "($($_[0]),$($_[1]))" }) -join ", "
  Write-Host "[nash] Pure NE: $list"
}else{
  Write-Host "[nash] Kein Pure NE gefunden."
}

$mixed = Get-MixedNE-2x2 $A $B
if($mixed){
  $msg = [string]::Format($ic, "[nash] Mixed NE: p(A0)={0:N3}, q(B0)={1:N3}", $mixed.p, $mixed.q)
  Write-Host $msg
}else{
  Write-Host "[nash] Kein Mixed NE ableitbar."
}

if($ReportPoA){
  $best=[double]::NegativeInfinity
  for($i=0;$i -lt 2;$i++){ for($j=0;$j -lt 2;$j++){ $w = Welfare $A $B $i $j; if($w -gt $best){ $best=$w } } }
  $neWelfares=@()
  if($hasPure){ foreach($ne in $pnes){ $neWelfares += (Welfare $A $B $ne[0] $ne[1]) } }
  if($mixed){ $neWelfares += (WelfareMixed $A $B $mixed.p $mixed.q) }
  if($neWelfares.Count -gt 0 -and $best -gt 1e-12){
    $worstNE = ($neWelfares | Measure-Object -Minimum).Minimum
    $poa = $worstNE / $best
    $msg2 = [string]::Format($ic, "[nash] PoA (worst NE / optimum) = {0:N3}  (worstNE={1:N3}, optimum={2:N3})", $poa, $worstNE, $best)
    Write-Host $msg2
  } else {
    Write-Host "[nash] PoA nicht definiert (kein NE oder Optimum~0)."
  }
}

if($PureNE){ if($hasPure){ exit 0 } else { exit 1 } }
if($AnyNE){ if($hasPure -or $mixed){ exit 0 } else { exit 1 } }
if($ComputeMixed){ if($mixed){ exit 0 } else { exit 1 } }
exit 0

