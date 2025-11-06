#!/usr/bin/env pwsh
#requires -PSEdition Core
#requires -Version 7.4

# INIT – kayros
# Erstellt am 2025-11-02 15:13
Write-Host "🔁 Starte FAB7-Agent: kayros..."
& "C:\Users\ralfb\golden\llama-core\llm-runner.ps1" -Name "kayros" -Model "llama3" -RoleFile "\persona.yaml"


