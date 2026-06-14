# Health Module Logic

Updated: 2026-06-14

## Product Contract

Health is the pet medical/history source of truth for the single-player first release. A visible active Health page must show records for active pets and historical records for deceased pets, but deceased pets are read-only and cannot create, edit, delete, or derive new reminders, rewards, tasks, ledger facts, or health records. User-visible recycled pets no longer exist in the product model.

## Write Boundary

All Health writes go through command services:

- `PetHealthCommandService.recordHealth`
- `PetSymptomCommandService.recordSymptom`
- `PetHeatCycleCommandService.recordHeatCycle`
- `PetHealthDeleteCommandService`

Views must not directly insert/delete Health models. Commands must reject writes for pets that are deceased. Deleted pets are physically removed after irreversible confirmation and therefore have no writable Health surface.

## Delete Semantics

Deleting a `PetHealthLog` physically deletes the source record after writing CloudSync tombstones for the whole derived chain created with it:

- the health log itself;
- linked medical `PetExpenseLog`;
- linked expiration `Event`;
- linked `Reminder` and any pending local notification;
- linked `CareLedgerEvent` rows for the health and expense facts.

Deleting `SymptomLog` or `HeatCycleLog` follows Product Foundation D16's irreversible-delete rule. The command writes CloudSync tombstones for the source record and related ledger rows, then physically deletes the local record after confirmation.

## Active Read Model Rule

Health views, cards, dashboards, archive pages, alert engines, and Health route containers do not filter through any user-visible trash state. Active dashboards exclude deceased pets from writable/active affordances with `pet.hasPassedAway`; historical presentation may still show retained records for deceased pets.

Memorial/history presentation may still show historical active records, but it must not expose new Health write actions.

## Schema

Legacy V69/V70 storage fields created during the cancelled recoverable-delete model may remain in existing stores for lightweight migration compatibility, but active Health product logic must not read or write them as lifecycle state. No new Health behavior may depend on those fields.

`ArkMigrationPlan.stages` remains empty unless a future schema version needs real custom migration logic.

## Localization

Health user-facing copy must go through `L10n.tr`, `AppLocalizedText`, or existing localization helpers. Chinese and English text are mandatory at authoring time; other registered languages use fallback unless explicit translations already exist.

## Out Of Scope

- No CloudKit enablement.
- No medical diagnosis logic beyond existing alert heuristics.
- No cross-module redesign of Medication, Calendar, or Memorial beyond enforcing Health write/read invariants at their Health entry points.
