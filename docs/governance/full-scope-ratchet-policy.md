# Full-Scope Ratchet Policy

> Date: 2026-06-08
>
> Status: active. This policy upgrades UI/accessibility/smoothness governance
> from changed-file-only ratchets to a whole-repo baseline ratchet.

## Active Gate

CI runs both layers:

1. Changed-file strict audits keep new or modified SwiftUI files clean.
2. `scripts/audit-full-scope-ratchet.sh` runs UI V4, accessibility, and
   smoothness audits across all `Ohana/Views` and `Ohana/Utilities` Swift files.

The full-scope baseline lives at
`docs/governance/manifests/full-scope-audit-baseline.json`.

## Ratchet Rules

- Any file/rule warning count above the baseline fails CI.
- Cleanup that reduces counts passes.
- After cleanup, run `scripts/audit-full-scope-ratchet.sh --update-baseline` to
  lock in the lower count.
- Do not increase the baseline to hide newly introduced debt.
- When all three totals reach zero, replace this ratchet with direct strict
  full-scope commands:
  - `scripts/audit-ui-v4.sh --all`
  - `scripts/audit-accessibility.sh --all`
  - `scripts/audit-smoothness-risk.sh --all`

## Initial Baseline

Measured on 2026-06-08:

| Audit | Initial warnings | Promotion target |
|---|---:|---|
| UI V4 | 128 | `scripts/audit-ui-v4.sh --all` |
| Accessibility | 4275 | `scripts/audit-accessibility.sh --all` |
| Smoothness | 191 | `scripts/audit-smoothness-risk.sh --all` |

The high accessibility count is mostly historical fixed-font and unlabeled SF
Symbol debt. The smoothness count includes broad `@Query`, sync image decoding,
and runtime loops that should be retired feature-by-feature.

## Validation

Passed on 2026-06-08:

- `scripts/audit-full-scope-ratchet.sh`
- `scripts/audit-governance-manifests.sh`
- `scripts/release-hardening-check.sh --skip-build`
