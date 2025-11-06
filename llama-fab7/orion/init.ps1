#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

# INIT – orion
# Erstellt am 2025-11-02 15:14
Write-Host "🔁 Starte FAB7-Agent: orion..."
& "C:\Users\ralfb\golden\llama-core\llm-runner.ps1" -Name "orion" -Model "llama3" -RoleFile "\persona.yaml"


