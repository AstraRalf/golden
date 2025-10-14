# ADR-0002 — Doc-Taxonomie & Navigation (v1)

**Status:** Accepted
**Datum:** 2025-10-14
**Owner:** @AstraRalf

## Kontext
Neben domänenspezifischen Ordnern (spot, roadmap, governance, metaos, openperiphery, uxlegal)
brauchen wir einen Ort für querschnittliche Leitfäden und HowTos.

## Entscheidung
- Wir führen **/docs** für **querschnittliche Leitfäden** ein (HowTos, Playbooks, Styleguides).
- Domänendokumente bleiben in ihren **Fach-Ordnern** (z. B. /metaos, /governance).
- **Navigation:** Top-Links in README.md + STRUCTURE.md; relative Links zwischen Dokumenten.
- **Benennung:** Kurze, sprechende Dateinamen in kebab-case; pro Ordner eine knappe README.

## Konsequenzen
- Klarer Ablageort für cross-cutting Inhalte, ohne die Domänenordner zu verwässern.
- Geringe Reibung: bestehende Struktur bleibt; /docs ist additive Erweiterung.

## Follow-ups
- docs/README.md anlegen (Kurzleitfaden & Inhaltsverzeichnis).
- Bei Bedarf ADRs für Unter-Taxonomien in /docs (z. B. 0003-styleguide).
