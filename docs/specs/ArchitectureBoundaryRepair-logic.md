# ArchitectureBoundaryRepair Logic

> Date: 2026-06-13
> Scope: TFU-20260613-008, `scripts/audit-architecture-boundaries.sh --all`

## Goal

Restore the architecture-boundary audit as an enforceable CI gate without hiding real cross-layer violations.

## Rules

- `@Query` belongs in route/data container surfaces. If a type is already a feature-owned container, make that boundary visible to the audit by naming or extracting it as a `*DataContainer.swift`/`*RouteContainer.swift` file.
- Views do not call static business services. View actions go through injected `AppServices` protocol surfaces or command executors.
- App-level event delivery must use typed publishers or injected route/revision publishers, not `NotificationCenter.default.post` string buses.
- Feature/domain services that need notification scheduling call an injected `ReminderSchedulingManaging` boundary, not `ReminderSchedulingService` directly.
- Oversized Swift files are a ratchet. This round is allowed to deliberately refresh the oversized-file baseline to the current counts so CI can enforce "no further growth"; broad file-splitting remains a separate architecture debt.

## Non-goals

- Do not refactor the 30 oversized files in this round.
- Do not change CloudKit, schema, routing semantics, or product behavior.
- Do not weaken UI/accessibility/smoothness/runtime gates.

## Validation

- `scripts/audit-architecture-boundaries.sh --all` must pass locally.
- Changed-file validation must pass.
- Because AppServices and Swift feature code are touched, run simulator compile/test validation before push.
