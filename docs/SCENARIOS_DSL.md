# FAB7 Szenarien-DSL (Minimal-YAML)
Ziel: deterministische Prüfsequenzen lokal/CI ohne Netz.

## Format (unterstützte Teilmenge)
name: <string>
steps:
  - run: <string>      # Befehl (Shell-String)
    expect: <int>      # erwarteter Exitcode (Default 0)

Hinweise:
- Parser unterstützt eine steps-Liste mit Feldern run und (optional) expect.
- Jeder Step läuft isoliert; Abbruch bei erstem Fehler.
- Für Spezialfälle kann "pwsh -NoLogo -File ..." im Feld run genutzt werden.
