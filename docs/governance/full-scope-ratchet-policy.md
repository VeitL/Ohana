# Full-Scope Ratchet Policy

> Date: 2026-06-08; updated 2026-06-10.
>
> Status: RE-ACTIVATED on 2026-06-10. The 2026-06-09 promotion to direct strict
> gates was based on a scan scope of `Ohana/Views` + `Ohana/Utilities` (91
> files). The Features/ directory refactor had silently moved ~88% of Swift
> files outside that scope, so the "zero baseline" was zero over a shrinking
> subset. On 2026-06-10 the three audits were widened to the whole `Ohana/`
> tree (~760 files), new smoothness rules were added (main-actor aggregation,
> imperative view fetch, detached view tasks), and construction-consistency
> UI rules followed the same day (raw-textfield, hardcoded-corner-radius,
> hardcoded-detent-height). The surfaced debt (1381 warnings: ui-v4 1309 —
> dominated by legacy radius literals — accessibility 60, smoothness 12) was
> captured back into the ratchet baseline. `scripts/tests/run-audit-fixture-tests.sh`
> now enforces a scanned-file floor so scope can never silently collapse again.

## Active Gate

CI runs `scripts/audit-full-scope-ratchet.sh`:

- Any NEW or INCREASED per-file/per-rule warning count fails CI.
- Reductions pass and are locked in with `--update-baseline`.
- When the baseline reaches zero again (target tracked in
  `docs/release-hardening-plan.md`), promote CI back to direct
  `--all` strict audits and update this policy.

## Ratchet Rules

- Never increase the baseline to absorb newly introduced debt; fix the new
  warning or use a documented inline allow comment instead.
- `--update-baseline` may only be run after intentional cleanup, and the
  baseline diff must ship in the same commit as the cleanup.
- Do not reintroduce changed-file-only gates for these audit families in CI.
- Do not narrow audit scan scope below the whole `Ohana/` tree; the fixture
  tests' scope floor is the enforcement for this rule.

## Baseline History

Measured on 2026-06-08:

| Audit | Initial warnings | Promotion target |
|---|---:|---|
| UI V4 | 128 | `scripts/audit-ui-v4.sh --all` |
| Accessibility | 4275 | `scripts/audit-accessibility.sh --all` |
| Smoothness | 191 | `scripts/audit-smoothness-risk.sh --all` |

The high accessibility count is mostly historical fixed-font and unlabeled SF
Symbol debt. The smoothness count includes broad `@Query`, sync image decoding,
and runtime loops that should be retired feature-by-feature.

Promoted on 2026-06-09:

| Audit | Current warnings | Active command |
|---|---:|---|
| UI V4 | 0 | `scripts/audit-ui-v4.sh --all` |
| Accessibility | 0 | `scripts/audit-accessibility.sh --all` |
| Smoothness | 0 | `scripts/audit-smoothness-risk.sh --all` |

## Validation

Passed on 2026-06-09:

- `scripts/audit-ui-v4.sh --all`
- `scripts/audit-accessibility.sh --all`
- `scripts/audit-smoothness-risk.sh --all`
