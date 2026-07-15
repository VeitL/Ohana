# Ohana Documentation Map

This file is the human entry point for repository documentation. It separates
current authority from dated evidence so that humans and coding agents do not
turn an old successful build, plan, or audit into a current product fact.

## Authority

Use the precedence and domain boundaries in [`AGENTS.md`](../AGENTS.md):

1. Current user request.
2. Product behavior and acceptance truth:
   [`specs/product-foundation.md`](specs/product-foundation.md).
3. Engineering workflow and agent conduct: [`AGENTS.md`](../AGENTS.md).
4. UI tokens and component choices: [`ui规范.selection.json`](../ui规范.selection.json).
5. Current governance and module specifications under `docs/`.
6. Current source and tests.
7. Dated planning, evidence, reference, archive, and design-export material.

No dated audit, roadmap, project snapshot, reference export, or chat transcript
may override the active sources below.

## Active Sources

| Area | Source |
| --- | --- |
| Product constitution | `docs/specs/product-foundation.md` |
| Engineering rules | `AGENTS.md` |
| Current release/validation read | `docs/testing-progress.md` |
| Open backlog | `docs/task-follow-ups.md` |
| Status ownership | `docs/status-ledger-map.md` |
| Deferred CloudKit work | `docs/cloud-sync-todo.md` |
| Deferred account/backend work | `docs/planning/account-backend-extension.md` (planning only; not current product or code truth) |
| Physical-device acceptance | `docs/release-true-device-test-plan.md` and `docs/planning/gap-acceptance-track-list.md` |
| Architecture/runtime/privacy gates | `docs/*-governance.md`, `docs/*-policy.md`, and `docs/release-quality-gates.md` |
| Feature behavior | `docs/specs/*-logic.md` |
| Unified tasks / Task Center | `docs/specs/TaskCenter-logic.md` |
| Local build/test storage | `docs/local-build-storage-policy.md` |
| UI tokens | `ui规范.selection.json`; `docs/design/ui规范.md` is explanatory |
| Resource ownership | `docs/governance/manifests/*.json` and family manifests under `Resources/` |

## Dated Evidence And Plans

- `docs/audits/<date>/`: audit and market snapshots. They preserve what was
  observed at one commit; they do not own current status.
- `docs/governance/round-*.md` and `final-verification-matrix.md`: evidence for a
  completed hardening pass, not a permanent release certificate.
- `docs/planning/`: implementation plans and dated inventories. A planning file
  is not current product or code truth unless an active source explicitly adopts it.
- `docs/reference/`, `docs/archive/`, `DesignExports/`, and
  `ohana-design-system/`: historical/reference material only.

## Maintenance Rules

- Keep active status concise. Store the command, result, date, and why it
  matters; move long transcripts and superseded detail to `docs/archive/`.
- Every current-state document must declare an owner or owning source, a status,
  and a last-verified date or code baseline when facts can drift.
- Do not copy the current SwiftData version, entitlement list, language list,
  test count, or simulator result into another active document unless that
  document has an explicit update trigger.
- Use repository-relative links. Machine-local absolute paths are allowed only
  inside clearly marked historical evidence and should not be used as current
  instructions.
- Documentation-only changes use `git diff --check` plus relevant governance,
  link, JSON, or shell checks. They do not require an app build unless they also
  change source/configuration behavior.

## Validation

```bash
scripts/audit-doc-status-ledgers.sh
scripts/audit-governance-manifests.sh
scripts/audit-agent-skill-governance.sh
scripts/tests/run-audit-fixture-tests.sh
```
