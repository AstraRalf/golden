#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

Param()
$ErrorActionPreference='Stop'
Write-Host '[sandbox] smoke start'
if(-not (Test-Path '..\fixtures')){ Write-Warning 'Keine fixtures/ gefunden.' }
Write-Host '[sandbox] OK'
exit 0

