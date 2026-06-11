# Task Follow-ups

This document tracks concrete follow-ups discovered while finishing a task when
they cannot or should not be completed in the same turn. Keep it short and
actionable; long-term product ideas belong in planning docs instead.

## How To Use

- Add an entry only when a completed task leaves a real blocker, external action,
  cross-scope repair, validation gap, or follow-up that should not be forgotten.
- Prefer one entry per actionable outcome. Include the blocker and the exact
  next step, not just a vague reminder.
- Close entries by changing `Status` to `Done` and adding a short `Closed` note.
- If there is no meaningful follow-up after a task, do not add noise here.

## Open Items

### TFU-20260611-001 - App Store Connect privacy setup

- Status: Open
- Priority: P1
- Area: Release / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: Requires App Store Connect access and a public privacy policy URL;
  this cannot be completed from the repository alone.
- Next step: In App Store Connect, set the privacy questionnaire to "No, we do
  not collect data from this app" for the current zero-upload build, so the App
  Store label reads `Data Not Collected`.
- Close when: App Store Connect privacy answers are saved and the submitted
  privacy policy URL matches `docs/privacy-compliance.md`.

### TFU-20260611-002 - Wire Settings privacy policy row

- Status: Open
- Priority: P2
- Area: Settings / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: The final public privacy policy URL is not available in the repo.
- Next step: Once the URL exists, connect the Settings screen's "隐私政策" row to
  open that URL and keep the copy localized.
- Close when: The row opens the published privacy policy from Settings and has
  a lightweight validation path.

### TFU-20260611-003 - Normalize sanitized image attachment filenames

- Status: Open
- Priority: P3
- Area: Documents / Expenses / Privacy
- Source task: Privacy hardening audit follow-up, 2026-06-11
- Blocker: Low-risk cosmetic cleanup touches several attachment creation paths
  and historical display behavior, so it should be handled as its own narrow
  pass instead of folded into sanitizer diagnostics.
- Next step: When image bytes are normalized to JPEG, normalize new attachment
  display filenames/extensions to `.jpg` or store an explicit sanitized content
  type, while preserving existing `isImage` behavior.
- Close when: Newly sanitized image attachments no longer show a misleading
  `.png` extension for JPEG bytes, and import/display paths still rely on
  explicit image metadata rather than filename alone.

### TFU-20260611-004 - Add cloud-sync mutation marks for feeding writes

- Status: Open
- Priority: P1
- Area: Cloud Sync / Feeding
- Source task: Feeding quick-action and stock-reminder repair follow-up,
  2026-06-11
- Blocker: Cloud sync is being changed in a separate active workflow with many
  uncommitted edits; patching it from the feeding thread risks crossing worktree
  ownership.
- Next step: In the CloudSync workflow, add `CloudSyncMutationRecorder` coverage
  for `PetFoodRecord`, feeding `Event`, and `Reminder` writes/deletes, including
  stock records, feed plan rules, stock reminders, and `FeedAutoLogMaterializer`
  auto-log inserts.
- Close when: Feeding stock records, feed rules, stock reminders, and auto-log
  materialized records enqueue upload/delete mutations, with focused CloudSync
  tests proving the registered entities are recorded.

### TFU-20260611-005 - Route shared walk writes through an owning command/service

- Status: Open
- Priority: P2
- Area: Walks / Shared Care / Architecture
- Source task: Feeding quick-action and stock-reminder repair follow-up,
  2026-06-11
- Blocker: The violation is in an active Walks/shared-care workflow outside the
  feeding repair scope.
- Next step: Replace the static `CareEventService.recordSharedWalk` call in
  `PetWalkingManager` with the owning shared-care command/service boundary used
  by the current Walks workflow.
- Close when: Whole-repo architecture audit no longer reports the
  `PetWalkingManager` static service-call violation and the shared-walk path is
  covered by the relevant Walks/shared-care validation.

## Done

Move completed entries here instead of deleting them when the history is useful.
