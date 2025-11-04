# UXLegal Waiver
- Nur verwenden, um **bekannte False Positives** in der **CI-Ausgabe** zu unterdrücken.
- Keine Policy-Freigabe! Sachverhalte müssen separat dokumentiert/behoben werden.
- Datei: `docs/audit/WAIVER-UXLEGAL.yml`

Beispiel:
waivers:
  - id: pii.email
    file: docs/examples/contact.md
    reason: Beispieladresse in Doku
    expires: 2025-12-31
