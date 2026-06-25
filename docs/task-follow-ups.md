# Task Follow-ups

> Active backlog only. Full pre-compaction history is archived at
> [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md).
>
> Release bar: first release is blocked only by **P0 and first-release-reachable**
> issues. P1/P2/P3, CloudKit `.none` work, feature-gated work, and manual device
> validation remain visible here but do not automatically block shipping.

## Current Read

- Last compacted: 2026-06-25.
- Open follow-ups: 12 total: P1 = 4, P2 = 6, P3 = 2.
- Open P0: 0.
- Known first-release-reachable repository-code P1: none identified in the
  latest local closure pass.
- P1 still open because of review-gate evidence, CloudKit 1.x deferred work, or
  real-device validation.

## How To Update

- Keep only active work in this file. When a follow-up closes, add one short
  `Closed:` line and then move details to the archive during the next compaction.
- New entries must include: priority, reachability/bucket, blocker, next action,
  and close condition.
- Long command logs, full review transcripts, and repeated progress bullets do
  not belong here; put the durable evidence in `docs/testing-progress.md` or an
  archive note.

## P1 Triage

| Bucket | TFUs | Meaning | Next move |
| --- | --- | --- | --- |
| Review-gate / likely implemented locally | TFU-20260612-014 | Local architecture/localization/notification evidence exists, but the item still needs push/CI inspection and a fresh pure review before Domain maturity can claim closure. | Run a dedicated closure pass; close or split only current-code findings. |
| Deferred 1.x / first-release-unreachable | TFU-20260614-014 | CloudSync live-apply delete-wins, parent lifecycle, and natural identity are real work, but unreachable while `cloudKitDatabase: .none`. | Keep in CloudKit 1.x planning; do not mix into first-release burn-down unless CloudKit is enabled. |
| External/manual validation | TFU-20260612-017, TFU-20260612-016 | Real iOS notification/UI behavior must be checked on device. Repo tests cannot close these alone. | Run GAP-9 and GAP-6 manual checklists on a physical device. |

## Open Items

### TFU-20260612-014 - Finish Domain Presentation And Infrastructure Boundary Cleanup

- Priority / bucket: P1, review-gate / Domain architecture, localization, notifications.
- Status: Open; notification scheduling, generated-copy localization, and local adapter gates have current local evidence.
- Why still open: close condition still requires push/CI inspection and a fresh pure Domain review.
- Next action: rerun current-code guards, inspect CI once after a coherent push, then perform a fresh pure review.
- Close when: Domain app code has no SwiftUI leakage, Domain services do not instantiate App/Feature concrete infrastructure directly, generated user-visible Domain strings are localized, and reminder/care notification side effects are covered through injected fakes.

### TFU-20260614-014 - Enforce CloudSync Live-Apply Deletion Wins, Parent Lifecycle, And Natural Identity

- Priority / bucket: P1, deferred CloudKit 1.x / first-release-unreachable.
- Status: Open while CloudKit is disabled.
- Why still open: live remote apply can resurrect newer remote `Pet`/`Human` rows over local tombstones, accept child records after parent deletion, and duplicate `GachaOwnedItem` ownership by random id instead of natural key.
- Next action: add red tests for delete-wins, parent active/existence gating, and Gacha owned-item natural-key merge; then implement one CloudSync apply disposition layer.
- Close when: those tests fail before and pass after the policy layer, CloudSync/physical-deletion/home/economy/derived audits pass, and a fresh Domain review reports P0/P1 = 0 for the reachable surface.

### TFU-20260612-017 - Validate GAP-9 Memorial Mode On Real UI And Device Notifications

- Priority / bucket: P1, external/manual validation.
- Status: Open; paid-team signing path is verified, but real memorial notification/UI behavior is not.
- Why still open: simulator and unit tests cannot prove real iOS notification cancellation, restoration, or final memorial-mode visible behavior.
- Next action: run the GAP-9 manual checklist in `docs/planning/gap-acceptance-track-list.md#gap-9-离世退场`.
- Close when: real-device checklist is checked off and any device-specific defect is fixed or split into a scoped follow-up.

### TFU-20260612-016 - Validate GAP-6 Notification Delivery On Real Devices

- Priority / bucket: P1, external/manual validation.
- Status: Open; paid-team Push/iCloud entitlement signing path is verified, but notification delivery is not.
- Why still open: repo tests cannot prove banners, permission prompts, Focus/DND interaction, or notification action behavior on physical devices.
- Next action: run the GAP-6 manual checklist in `docs/planning/gap-acceptance-track-list.md#gap-6-通知分级`.
- Close when: real-device checklist is checked off and any delivery/routing defect is fixed or split into a scoped follow-up.

### TFU-20260613-004 - Restore Pet Quick-Access Derived State

- Priority / bucket: P2, recycle-bin/member restore polish.
- Status: Open.
- Why still open: member deletion removes pet quick-access entries; restore currently does not recreate or recompute that derived state.
- Next action: decide intended restored-pet product behavior, then recreate previous quick access or recompute defaults during restore.
- Close when: restored pets have approved quick-action availability and a focused regression test covers it.

### TFU-20260613-003 - Round-Trip Recycle-Bin Soft-Delete Fields In CloudSync

- Priority / bucket: P2, future CloudSync / 1.x.
- Status: Open.
- Why still open: first release keeps CloudKit off, but future sync must serialize/apply `trashedAt`, `trashExpiresAt`, `trashBatchId`, and `trashedByHumanId` consistently.
- Next action: before CloudKit unlock, extend serializer/apply/import paths and registry tests for recoverable entities and bulk-clear batches.
- Close when: remote soft delete and remote restore reproduce the same recycle-bin state locally without premature tombstones.

### TFU-20260612-022 - Add Final Settings Privacy And Support Actions

- Priority / bucket: P2, release links / external content.
- Status: Open.
- Why still open: final public privacy-policy URL and approved support contact route are not both available in the repo.
- Next action: provide final URL/contact route, then add localized About rows that open real destinations.
- Close when: Settings About shows only actionable privacy/support rows and a lightweight validation proves each opens the intended destination.

### TFU-20260612-020 - Finish Members Localization Coverage

- Priority / bucket: P2, Members localization.
- Status: Open.
- Why still open: detail, edit, privacy, and read-only profile surfaces still contain broad user-visible hardcoded Chinese strings.
- Next action: move Members user-facing copy onto the registered localization path, authoring Chinese and English at minimum.
- Close when: Members user-facing strings pass localization coverage and main long-language screens remain visually clean.

### TFU-20260612-018 - Remove Duplicate Member Profile Revision Publishes

- Priority / bucket: P2, smoothness / invalidation cleanup.
- Status: Open.
- Why still open: executors already publish profile revisions, but some view callers publish another revision after executor return.
- Next action: remove duplicate view-level publishes after confirming the executor emits the intended mutation.
- Close when: each profile save publishes exactly one member profile revision and a focused test or audit prevents recurrence.

### TFU-20260611-005 - Route Shared Walk Writes Through Owning Command/Service

- Priority / bucket: P2, Walks/shared-care architecture.
- Status: Open.
- Why still open: active Walks/shared-care workflow still has a static service-call boundary violation in `PetWalkingManager`.
- Next action: route shared walk writes through the owning shared-care command/service boundary used by the current Walks workflow.
- Close when: whole-repo architecture audit no longer reports the violation and relevant Walks/shared-care validation covers the path.

### TFU-20260611-003 - Normalize Sanitized Image Attachment Filenames

- Priority / bucket: P3, low-risk privacy/document polish.
- Status: Open.
- Why still open: normalized JPEG bytes can still display misleading historical or imported filename extensions.
- Next action: normalize new sanitized image filenames/extensions to `.jpg` or store explicit sanitized content type.
- Close when: new sanitized image attachments no longer show misleading `.png` extensions while import/display still rely on explicit image metadata.

### TFU-20260612-010 - Unify Care Status Read Models And Expand Ledger Analysis

- Priority / bucket: P3, product/read-model polish.
- Status: Open.
- Why still open: Hygiene and QuickCare status feedback and ledger analysis dimensions are not fully unified.
- Next action: share overdue/status feedback and extend `CareLedgerAnalysisView` with trend and actor breakdowns.
- Close when: Hygiene/QuickCare display the same status source and ledger analysis includes trend plus executor/family-member breakdowns.

## Recently Closed Pointers

Use the archive for full detail. High-signal closures already reflected in the current open count:

- TFU-20260612-006: CareLedger read-model migration closed; later route-first-frame correction recorded in `docs/testing-progress.md`.
- TFU-20260614-013, 015, 016, 017, 018, 019 and TFU-20260615-001: current-head closure reviews completed on 2026-06-25; raw Open P1 count reduced to 4.
- TFU-20260623-001: Home quick-action render-state isolation cleanup closed after Terminal `iPhone 17` targeted suites reported `TEST SUCCEEDED`; Codex shell CoreSimulator remains a session blocker, now diagnosed by `scripts/diagnose-simulator.sh`.
- TFU-20260612-019: human memorial read-only boundary closed by current guard coverage.
- TFU-20260611-001: App Store Connect privacy setup closed; final public URL/support row remains TFU-20260612-022.

## Archive

- Full pre-compaction backlog: [`docs/archive/task-follow-ups-full-2026-06-25.md`](archive/task-follow-ups-full-2026-06-25.md)
- Full pre-compaction testing ledger: [`docs/archive/testing-progress-full-2026-06-25.md`](archive/testing-progress-full-2026-06-25.md)
