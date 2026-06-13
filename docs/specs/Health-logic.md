# Health Module Logic

Updated: 2026-06-12

## Product Contract

Health is the pet medical/history source of truth for the single-player first release. A visible active Health page must show only active records for active pets. Memorial or recycled pets are read-only in Health and cannot create new reminders, rewards, tasks, ledger facts, or health records.

## Write Boundary

All Health writes go through command services:

- `PetHealthCommandService.recordHealth`
- `PetSymptomCommandService.recordSymptom`
- `PetHeatCycleCommandService.recordHeatCycle`
- `PetHealthDeleteCommandService`

Views must not directly insert/delete Health models. Commands must reject writes for pets that are deceased or in the recycle bin.

## Delete Semantics

Deleting a `PetHealthLog` deletes or tombstones the whole derived chain created with it:

- the health log itself;
- linked medical `PetExpenseLog`;
- linked expiration `Event`;
- linked `Reminder` and any pending local notification;
- linked `CareLedgerEvent` rows for the health and expense facts.

Deleting `SymptomLog` or `HeatCycleLog` follows Product Foundation D16's single-high-frequency-fact rule: the record does not appear in the recycle-bin UI. The command writes CloudSync tombstones for the source record and related ledger rows, then physically deletes the local record after confirmation.

## Active Read Model Rule

Health views, cards, dashboards, archive pages, alert engines, and Health route containers read active records only:

- `PetHealthLog.trashedAt == nil`
- `SymptomLog.trashedAt == nil`
- `HeatCycleLog.trashedAt == nil`
- active dashboards exclude `pet.trashedAt != nil` and `pet.hasPassedAway`

Memorial/history presentation may still show historical active records, but it must not expose new Health write actions.

## Schema

This module bumped the SwiftData schema from `ArkSchemaV69` to `ArkSchemaV70` by adding lightweight recycle fields to:

- `SymptomLog`
- `HeatCycleLog`

Those fields are kept for backup / migration compatibility, but active product deletion semantics for `SymptomLog` and `HeatCycleLog` are direct delete + tombstone, not recycle-bin retention. `PetHealthLog` remains a recoverable medical / vaccine archive.

`ArkMigrationPlan.stages` remains empty because the change is add-only with defaults.

## Localization

Health user-facing copy must go through `L10n.tr`, `AppLocalizedText`, or existing localization helpers. Chinese and English text are mandatory at authoring time; other registered languages use fallback unless explicit translations already exist.

## Out Of Scope

- No CloudKit enablement.
- No medical diagnosis logic beyond existing alert heuristics.
- No cross-module redesign of Medication, Calendar, or Memorial beyond enforcing Health write/read invariants at their Health entry points.
