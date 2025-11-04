# John-Nash-Proben (2x2, Normalform)
Ziel: deterministische Spieltheorie-Checks ohne Netz.
Abgedeckt:
- Pure Nash Equilibria (PNE) für 2x2
- Mixed NE (falls kein PNE; 2x2-Formel)
- Hinweise: Pareto-Dominanz, Preis der Anarchie (PoA) – informativ

Nutzung mit Szenarien-DSL (Textform):
name: nash-prisoners
steps:
  - run: pwsh -NoLogo -File sandbox/tools/nash_eval.ps1 -Path sandbox/fixtures/nash/2x2_prisoners.json -AnyNE
    expect: 0
