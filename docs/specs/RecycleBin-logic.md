# GAP-2 Recycle Bin Logic

> Status: confirmed on 2026-06-12; adversarial P1 remediation completed on 2026-06-13. Product choices: Q1=A source-model soft delete, Q2=A full constitutional scope, Q3=A one recycle-bin item per bulk clear, Q4=A aggregate-hide member children, Q5=A CloudSync tombstone on final purge, Q6=A keep current active-human routing semantics.

## Purpose

The recycle bin implements Product Foundation D8, D16, G5, and G6. Launch deletion must no longer destroy members or precious archives immediately. Recoverable deletion hides the item from normal product surfaces, keeps the original SwiftData object and relationships intact for 30 days, and allows restoration. Permanent deletion happens only when the 30-day retention expires or when the user invokes the privacy reset/delete-all path.

## Scope

Recoverable objects:

- Members: `Pet`, `Human`, `Plant`.
- Precious archives: `PetPhotoLog`, `PetMilestone`, `PetDocument`, `PetInsurance`; `InsuranceClaim` restores with its parent policy.
- Bulk clear operations: one recycle-bin batch for a pet's cleared activity records. Child records are source-model soft-deleted under the same batch id and are restored as a group.

Non-recoverable objects:

- Single high-frequency fact deletion, such as one feeding, potty, weight, expense, symptom, heat-cycle status, hygiene, walk, medication, or claim record, keeps the existing second-confirmation UX and does not appear in recycle-bin UI. Medical / vaccine `PetHealthLog` records are treated as precious health archives and remain recoverable. Direct-delete commands must still write a CloudSync deletion tombstone before physical deletion when the entity is in the sync pipeline.
- Calendar whole-event deletion and recurrence-tail deletion do not appear in recycle-bin UI, but they must tombstone the deleted `Event` and its child `Reminder` records before physical deletion. Feature commands that remove a business fact and also remove derived upload-pipeline state, such as `CareLedgerEvent`, `Event`, or `PetHygieneLog`, must tombstone those derived records at the same command boundary.
- App reset / delete-all-data remains immediate physical deletion and bypasses the recycle bin.

## Invariants

RB-001. Any recoverable delete sets `trashedAt` and `trashExpiresAt` on the source object instead of calling `context.delete`.

RB-002. Recoverable objects keep their original `id`, relationships, external-storage payloads, attachments, claims, and ledger/event links while in the recycle bin.

RB-003. Normal app surfaces must exclude trashed members and precious archives. A member in the recycle bin also aggregate-hides its child data from normal member, home, settings, document, insurance, milestone, and photo surfaces.

RB-004. Restoring a member or precious archive clears its trash fields and makes the same original object visible again only before `trashExpiresAt`. The 30-day retention is a service-layer hard boundary: expired items must be purged instead of reactivated, even if the user has not tapped a manual cleanup button. Restoring a bulk-clear batch clears trash fields on every item in the batch.

RB-005. Final purge after the retention window physically deletes the source object and writes CloudSync deletion tombstones for sync-pipeline entities at purge time, including syncable child records that will be removed by SwiftData cascade deletion. Moving an object into the recycle bin is a local modification, not a final deletion tombstone.

RB-006. Deleting the active human or the last human keeps the existing route/account semantics: deleting the active human clears `currentActiveHumanId` or asks for account switching; restoration does not automatically switch the active human back.

RB-007. A bulk pet-record clear appears as one recycle-bin batch item. Individual records in that batch do not appear as separate recycle-bin rows.

RB-008. App reset is the G6 privacy path and must remain immediate physical deletion with no recycle-bin retention.

RB-009. Restoring an aggregate member also restores its derived active reminders. Future pending reminders must be scheduled again through the app notification scheduler after their source event is restored.

RB-010. Single-record delete / undo commands are allowed to bypass recycle-bin retention only when the physical delete boundary also records deletion tombstones for every sync-pipeline source or derived record it removes. A UI confirmation is not a sync boundary; the service / command that calls `context.delete` owns the tombstone.

RB-011. Calendar / Today Focus / notification care completion may generate care facts and rewards from a scheduled occurrence. Reopening that occurrence is a direct-delete undo path, not a recycle-bin item; it must tombstone the generated `PetCareLog` / `PetPottyLog` / `PetHygieneLog`, `CareLedgerEvent`, `CoconutLedgerEntry` reversal target metadata, and `EconomyBudgetUsageEvent` budget usage before removing local generated facts.

## State Machine

```mermaid
stateDiagram-v2
    [*] --> Active
    Active --> Trashed: recoverable delete
    Trashed --> Active: restore before expiry
    Trashed --> Purged: purge when trashExpiresAt <= now
    Active --> Purged: privacy reset / single high-frequency delete
```

## Implementation Shape

- Schema: bump latest `ArkSchemaV68` to `ArkSchemaV69`; add lightweight soft-delete fields with defaults to recoverable source models and batch-cleared record models.
- Service boundary: recycle-bin writes live in a domain service so views do not mutate trash fields directly.
- UI: Settings exposes a recycle-bin entry. The screen lists recoverable member/archive items plus one row per bulk-clear batch, with restore and purge actions.
- Tests: in-memory SwiftData tests cover member delete/restore, precious archive delete/restore, bulk clear batch restore, final purge tombstone timing, app reset bypass, Calendar Event + Reminder tombstones, business fact delete + `CareLedgerEvent` tombstones, and CatCare undo tombstones.

## Open Follow-Up Policy

If a normal surface still requires broad query migration to filter trashed child records safely, it must be recorded as a concrete follow-up only after the core GAP-2 invariants and acceptance paths are implemented and verified. Do not use follow-up tracking to skip the recoverable deletion contract itself.
