#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

# INIT – argus
# Erstellt am 2025-11-02 15:13
Write-Host "🔁 Starte FAB7-Agent: argus..."
& "C:\Users\ralfb\golden\llama-core\llm-runner.ps1" -Name "argus" -Model "llama3" -RoleFile "\persona.yaml"


