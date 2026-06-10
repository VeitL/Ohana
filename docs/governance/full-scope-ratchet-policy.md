# Full-Scope Audit Policy

> Date: 2026-06-08; updated 2026-06-10.
>
> Status: PROMOTED TO STRICT ZERO on 2026-06-10. UI V4, accessibility, and
> smoothness now run as direct full-repo `--all` gates in CI and in
> `scripts/release-hardening-check.sh`.

## Active Gate

CI runs these commands directly:

- `scripts/audit-ui-v4.sh --all`
- `scripts/audit-accessibility.sh --all`
- `scripts/audit-smoothness-risk.sh --all`

All three must report zero warnings. The zero baseline remains in
`docs/governance/manifests/full-scope-audit-baseline.json` as promotion evidence
and a historical guardrail, not as a debt allowance.

## Scope Rules

- Do not reintroduce changed-file-only gates for these audit families in CI.
- Do not narrow audit scan scope below the whole `Ohana/` tree; the fixture
  tests' scope floor enforces this.
- Do not use `scripts/audit-full-scope-ratchet.sh --update-baseline` to absorb
  new debt. If any direct `--all` gate fails, fix the warning or add a narrow,
  documented inline allow comment for an intentional exception.

## Baseline History

Measured on 2026-06-08:

| Audit | Initial warnings | Promotion target |
|---|---:|---|
| UI V4 | 128 | `scripts/audit-ui-v4.sh --all` |
| Accessibility | 4275 | `scripts/audit-accessibility.sh --all` |
| Smoothness | 191 | `scripts/audit-smoothness-risk.sh --all` |

On 2026-06-10 the audit scope was widened to the whole `Ohana/` tree after the
Features refactor moved most Swift files outside the previous scan scope. That
surfaced legacy debt into the ratchet baseline. The P1 cleanup then drove the
baseline back to zero and promoted CI to strict direct gates.

Promoted on 2026-06-10:

| Audit | Current warnings | Active command |
|---|---:|---|
| UI V4 | 0 | `scripts/audit-ui-v4.sh --all` |
| Accessibility | 0 | `scripts/audit-accessibility.sh --all` |
| Smoothness | 0 | `scripts/audit-smoothness-risk.sh --all` |

## Validation

Passed on 2026-06-10:

- `scripts/audit-ui-v4.sh --all`
- `scripts/audit-accessibility.sh --all`
- `scripts/audit-smoothness-risk.sh --all`
- `scripts/release-hardening-check.sh --skip-build`
