# Round 5 Resource, Privacy, and Release Hardening Evidence

> Date: 2026-06-08
>
> Scope: resource budgets, packaged-resource detritus, xattrs, privacy manifest packaging, data-safety checks, and release hardening gates.

## Repair 1 - Release/Resource Ownership Manifest

Added `docs/governance/manifests/release-resource-ownership.json`.

The manifest records:

- Resource budget owner, path, limit, rationale, release gate, and evidence.
- Pre-sign checks for Finder/AppleDouble detritus, packaged-resource xattrs, privacy manifest packaging, and the Xcode strip-xattrs build phase.

Budgets currently enforced:

| Resource | Budget |
|---|---:|
| `Resources` | 230 MiB |
| `Resources/Avatars/PetAvatarAssets` | 210 MiB |
| `Resources/Avatars/HumanAvatarAssets` | 10 MiB |
| `Ohana/Assets.xcassets` | 60 MiB |

## Repair 2 - Manifest-Driven Resource Audit

`scripts/audit-resource-integrity.sh` now reads resource budgets from the release/resource manifest instead of hardcoded shell constants.

This makes budget changes auditable:

- Changing a budget now requires editing the manifest.
- `scripts/audit-governance-manifests.sh` validates owner, rationale, evidence, positive `limitMiB`, release gate, and real paths.
- `scripts/audit-resource-integrity.sh` still performs the hard checks for size, xattrs, detritus, and privacy manifest packaging.

## Compliance Matrix

| Gate | Status | Evidence |
|---|---|---|
| Resource budget ownership | Compliant | `release-resource-ownership.json` is required by governance manifest audit. |
| Resource budget hard fail | Compliant | `scripts/audit-resource-integrity.sh` reads manifest limits and fails over-budget directories. |
| xattr pre-sign check | Compliant | Resource integrity audit rejects signing-risk xattrs under packaged resource roots. |
| Finder/AppleDouble detritus | Compliant | Resource integrity audit rejects `.DS_Store`, `._*`, and `__MACOSX`. |
| Privacy manifest packaging | Compliant | Resource integrity audit requires valid `Ohana/PrivacyInfo.xcprivacy`. |
| Data-safety gate | Compliant | `scripts/audit-release-data-safety.sh` remains part of release hardening. |
| CodeSign risk check | Compliant for simulator build | The fixed simulator build runs the strip-xattrs build phase before CodeSign and completed CodeSign successfully in Round 4 validation. |

## Validation

- `bash -n scripts/audit-resource-integrity.sh` passed.
- `bash -n scripts/audit-governance-manifests.sh` passed.
- `scripts/audit-governance-manifests.sh` passed.
- `scripts/audit-resource-integrity.sh` passed.
- `git diff --check` passed.
- `scripts/release-hardening-check.sh --skip-build` passed.

Remaining Round 5 work:

- Future archive/release work should add an archive-equivalent signed build check when a Release/archive command is available in CI.
