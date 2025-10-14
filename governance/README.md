# Governance (Minimum v0)

**Owner:** @AstraRalf
**Ziel:** Klare, leichte Regeln fÃ¼r stabile main.

## Prinzipien
- **PR-first, Squash-only:** Ã„nderungen ausschlieÃŸlich per PR, Merge via Squash.
- **Stabile main:** Keine direkten Pushes auf origin/main.
- **Elementar & 80/20:** Nur Wesentliches, kurze Wege.

## Ablauf
1. **Branch-Namen:** \eat/*\, \ix/*\, \docs/*\, \chore/*\
2. **Commits:** *Conventional Commits* (Hooks prÃ¼fen Format)
3. **PR:** Template nutzen; lokal: pre-commit ohne Fehler

## SchutzmaÃŸnahmen
- pre-commit: Trailing-Whitespace, GrÃ¶ÃŸe (>10MB), Secret-Scan (nur hinzugefÃ¼gte Zeilen)
- pre-push: blockiert Direkt-Push auf main (bewusster Override mÃ¶glich)

## Reviews
- Kleinere Ã„nderungen: kurzer Self-Review okay
- GrÃ¶ÃŸere Ã„nderungen: KurzbegrÃ¼ndung im PR-Body

## Versionierung / Releases
- Tags & SemVer: **TBD** (spÃ¤ter)
- Audit: PR/Squash-Historie dient als Revisionspfad
