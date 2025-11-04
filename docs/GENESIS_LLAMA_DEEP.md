# Genesis → Llama (FAB7) — Deep Facts & Playbook

> **Prämissen**: #Elementar · #8020 · #AutoSPOT · #Governance · SPOT=einzige Quelle (Canvas/Repo), Memory nur Trigger.

## 1) Zielbild & Invarianten
- **Stabiler, auditierbarer Stack** mit reproduzierbaren Ergebnissen.
- **SPOT-first**: Langtexte/Artefakte im Repo/Canvas; Memory nur Triggers (#LamaSPOT, #MetaOS, #OpenPeriphery, #UXLegal, #Philosophy, #Roadmap).
- **Hook-/PR-Guardrails**: Kein Direkt-Push auf main, Squash-Only, nach Merge Branch löschen, Whitespaces/EOL sauber.
- **Sandbox-Pflicht** für riskante/„-S“-Operationen (ohne Netz, deterministisch).

## 2) Architektur (3-Schichten wie Genesis)
**Archiv (Immutable)**
- Git-Repo (Docs/ADR, Policies, Agent-Registry, Fixtures, Logs/Agents).
- Canvas-SPOT als Master-Sicht.
- Backups extern (out of band), Hash-/Tag-basierte Releases.

**Zwischenlayer (Control Plane)**
- **Orchestrator (Arin)**: Planen, Sequenzieren, Gatekeeping.
- **Policy/UXLegal**: Advisory Lints (PII, Lizenzen, Third-Party-Notices); Stufen: _local advisory_ → _CI warn_ → _manual review_.
- **Audit/Telemetry**: logs/agents/*; jede Aktion mit Zeit, Agent, Input/Output-Hash.
- **Sandbox/Harness**: sandbox/ für Smoke/Szenarien (offline, deterministisch).
- **Adapters/OpenPeriphery**: Schnittstellen nach außen sind *opt-in* und durch Policies gated.

**Frontend (Experience)**
- SPOT/Canvas + CLI (ein Block, PS 5.1-safe), GH-PR-Flow.
- Klare UX-Routinen: „ein Befehl = ein Ergebnis“; Dry-Runs vor realen Aktionen.

## 3) FAB7 Rollen & -S-Doubles (Prinzip)
- **Arin (Orchestrator)** – Single verantwortlich für Fluss, Gating, Policy-Kompilation.
- **A2–A7 (Musterrollen)**: Research, Architektur, Builder, Reviewer, Ops, QA/Eval.
- **„-S“-Double je Agent**: begrenzte Spezialfunktionen (z. B. Sandbox-Exec, sichere Low-Level-Ops).
  **Regel**: „-S“ darf nur in sandbox/-Kontexten wirken. Kein Netz. Alles geloggt.
- **Registry**: gents/registry.yml (Owner, Scopes, Capabilities). Beispiel vorhanden (Arin, Arin-S).

## 4) Governance & Guardrails (konkret)
- **Git**: pre-commit (Whitespace/EOL), pre-push (block main), Repo-Toggles: squash-only, rebase/merge-commit off, delete-branch on.
- **Labels**: chore, cleanup, whitespace. Pflicht bei Maintenance-PRs.
- **PR-Policy**: Auto-Merge nur wenn Checks grün; sonst Review-Gate.
- **Audit**: Jede „-S“-Aktion loggen; ADRs für Architekturentscheidungen.

## 5) Sandbox & Szenarien
- **Harness**: sandbox/harness/smoke.ps1 (deterministisch), Fixtures in sandbox/fixtures/.
- **Szenarien**: definieren als einfache YAML/Markdown-Rezepte (Inputs, erwartete Checks, Exit-Codes).
- **Nash/Nash-Test**: _Platzhalter_ → in Genesis genutzt; in Llama als **Negative/Adversarial/Safety**-Test interpretieren (finale Benennung offen).
  Vorschlag: „Nash-Test“ = **N**egative/**A**dversarial/**S**afety-Probe gegen Policies & Hooks (ohne Netz).

## 6) Juristische Prüffunktion (UXLegal)
- **Ziel**: Hinweise (advisory) früh, nicht blockierend lokal; in CI optional strengere Gates.
- **Aktuell**: policy/uxlegal/lint.ps1 (PII-Heuristik, Lizenz-/Third-Party-Hinweise als TODO).
- **Tipps**:
  1) Lokal als pre-commit *advisory* laufen lassen.
  2) CI: Diff-Scope prüfen, “escapes” nur per docs/audit/WAIVER-*.md mit Owner-Sign-off.
  3) Keine Voll-PII-Regeln ohne hohe Präzision → lieber „signal first“, dann manuelles Review.

## 7) Optimierungs-Frameworks
### 7.1 15-stufige **Skill-Optimierung** (Template)
1) Problemdefinition (KPIs), 2) Goldensets, 3) Baseline, 4) Prompt-/Tooling-Inventar,
5) Fehlerklassifikation, 6) Daten/Linter-Hygiene, 7) Few-shot-Design, 8) Tool-Routing,
9) Guardrail-Übersetzungen, 10) Eval-Harness (auto), 11) Szenarienabdeckung, 12) Ablation,
13) Cost/Latency-Tuning, 14) Regression-Wachhunde, 15) Wissens-Transfer (Docs/ADR).

### 7.2 10-stufiger **Iterativer Loop** (jede Änderung)
1) Hypothese → 2) Minimal-Delta → 3) Sandbox-Run → 4) Local Lint/UXLegal →
5) Hook-Selftest → 6) PR + Labels → 7) Auto-Checks → 8) Review/Gate →
9) Merge + Post-Merge-Health → 10) ADR/Changelog + Roll-Forward-Plan.

## 8) Tipps & Tricks (aus ChatGPT-Stack übernommen)
- Hooks lokal testen (Dry-Run auf main → erwarteter Block).
- Ein PS-Block, PS5.1-safe (ProcessStartInfo-Wrapper).
- LF-Normalisierung + 1 LF am Ende für „grüne“ Diffs.
- Squash-Only + kuratierte Commit-Messages.
- „-S“-Arbeiten strikt in sandbox/ mit Fixtures & Logs.

## 9) Migration Genesis → Llama (Schritte)
1) Registry vervollständigen (A1–A7 + „-S“), Owner festlegen.
2) Policies schärfen (PII-Muster, Lizenz-Header, Third-Party-Notices).
3) Szenarien-DSL (YAML/MD) + Beispiel-Fixtures.
4) Eval-Metriken & Goldensets (Pass/Fail klar).
5) CI-Gates staffeln (advisory → warn → required).
6) ADR-Serie (0001 Sandbox → …).
7) Onboarding-README (Kurz) + Cheatsheet (CLI/PR-Flow).

## 10) Offene Punkte zur FAB7-Abstimmung
- Nash/Nash-Test: endgültige Definition/Scope.
- Vollständige sieben Rollen: Bezeichnungen/Capabilities/Owner.
- Policy-Schärfe in CI: was warn vs. required?
- Spezial-Szenarien (rechtliche Edge-Cases, Daten-Maskierung).
