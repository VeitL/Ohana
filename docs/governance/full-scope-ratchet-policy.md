# Full-Scope Ratchet Policy

> Date: 2026-06-08
>
> Status: promoted on 2026-06-09. UI/accessibility/smoothness governance now
> uses direct whole-repo strict gates because the full-scope baseline is zero.

## Active Gate

CI runs direct whole-repo strict audits:

1. `scripts/audit-ui-v4.sh --all`
2. `scripts/audit-accessibility.sh --all`
3. `scripts/audit-smoothness-risk.sh --all`

The historical zero baseline lives at
`docs/governance/manifests/full-scope-audit-baseline.json`. It is retained as
promotion evidence, not as an allowance for future warnings.

## Strict Rules

- Any UI V4, accessibility, or smoothness warning fails CI.
- Do not reintroduce changed-file-only gates for these audit families.
- Do not increase the zero baseline to hide newly introduced debt.
- Use inline allow comments only for deliberate, documented exceptions that the
  strict audit scripts already recognize.

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
