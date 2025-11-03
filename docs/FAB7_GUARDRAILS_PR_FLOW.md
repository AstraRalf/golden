# FAB7 Guardrails & PR-Flow (Kurz)

## Ziele (80/20)
- Stabiler, reproduzierbarer PR-Flow.
- Schutz von main vor Direkt-Pushes.
- Saubere Diffs: keine Trailing Spaces, genau 1 LF am Dateiende.

## Regeln
1. **Keine direkten Pushes auf main**. Der *pre-push*-Hook blockt. Notfall-Override: ALLOW_MAIN_PUSH=1 (nur mit Freigabe).
2. **pre-commit** prüft *Whitespace/EOL* und blockt Verstöße.

## Standard-Workflow
1. Feature-Branch anlegen: git switch -c <topic>
2. Änderungen committen (ohne Trailing Spaces; 1 LF am Ende).
3. Push: git push -u origin <topic>
4. PR: gh pr create --base main --head <topic>
5. Labels: chore, cleanup (optional: whitespace).
6. Merge: **Squash-Only**, Branch wird nach Merge gelöscht.

## Self-Tests
- Hook-Guard prüfen: FAB7 **Step 6.3** (non-throw Dry-Run) ausführen.

## Repo-Toggles (Soll-Zustand)
- llow_squash_merge: true
- llow_merge_commit: false
- llow_rebase_merge: false
- delete_branch_on_merge: true

## Troubleshooting (PS5.1)
- *NativeCommandError* vermeiden: Wrapper-Blöcke (Step 6.3 / Step 7.2) nutzen.
