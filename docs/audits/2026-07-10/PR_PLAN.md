# Ohana PR Plan

> Baseline: `4d434d5354efdfb0eb7864cadad9ccf3df3825b5`
>
> Planning only. No branch, PR, migration, implementation, commit, push, or CI run has started.

Each PR should merge with a buildable/runnable app. File lists name current files/modules; a path marked **proposed new** does not currently exist.

## PR-001 — Exclude sensitive persistence roots from OS backup

| Field | Plan |
|---|---|
| Goal | Close the confirmed personal-health backup control gap without redesigning persistence. |
| Roadmap / findings | `ROAD-001`; `SEC-001`, `MARKET-002` |
| Expected files/modules | `Ohana/Models/SharedModelContainer.swift`; `Ohana/Features/HumanNotes/HumanNoteAttachmentStore.swift`; **proposed new** focused exclusion helper under `Ohana/Domain/Services/`; `OhanaTests/SharedModelContainerRecoveryTests.swift`; **proposed new** path-policy tests. |
| Modification order | Inventory concrete store/sidecar/fallback/note paths → add testable path policy → apply after create/migrate/fallback/file save → add failure visibility → update policy only after behavior is proven. |
| Do not include | Backup/Reset generation, Restore transaction, CloudKit, schema changes, Store screenshots, unrelated file cleanup. |
| Data migration | No schema migration. Existing paths need one idempotent attribute application at launch/migration. |
| Compatibility risk | Excluding a mixed store reduces OS-level recovery for non-health data; restricted/manual backups become the approved recovery path. File operations can reset the attribute, so reapplication is required. |
| Automated tests | New/existing store, sidecars, disk fallback, migrated store, note directory/file creation, attribute failure; `audit-release-data-safety`, targeted unit tests, fast Debug build. |
| Manual validation | Signed real-device iCloud Backup/restore with synthetic Human health and attachment data. |
| Acceptance | Every sensitive path reports excluded; no prohibited data returns through OS backup; policy language matches; no change to CloudDocuments restricted backup behavior. |
| Rollback | Do not revert to unsafe backup. If exclusion cannot be guaranteed, hide Human-health release surfaces and narrow claims. |
| Dependency / parallelism | No dependency; can run in parallel with PR-002/003/004 if file ownership is coordinated. |
| Risk | High |

## PR-002 — Add backup generation and Reset cancellation

| Field | Plan |
|---|---|
| Goal | Ensure no old automatic backup can write or mark success after Reset. |
| Roadmap / findings | `ROAD-002`; `SEC-002` |
| Expected files/modules | `Ohana/Domain/Services/AutomaticBackupService.swift`; `Ohana/App/AppResetService.swift`; `OhanaTests/AutomaticBackupServiceTests.swift`; `OhanaTests/AppResetServiceTests.swift`. |
| Modification order | Add coordinator/task/generation contract → inject same owner into Reset → cancellation/await/timeout → pre/post write checks → status cleanup → deterministic tests. |
| Do not include | OS backup exclusion, Restore refactor, generic job scheduler, CloudKit queue, Settings redesign. |
| Data migration | None; automatic-backup status keys may need a version/default but no user-data migration. |
| Compatibility risk | A bad generation rule could delete a new post-reset backup or make Reset wait forever. Bound wait and distinguish generations explicitly. |
| Automated tests | Pausable exporter/writer across all interleavings, cancellation propagation, timeout, cleanup failure/retry, new-generation backup, background trigger. |
| Manual validation | Real iCloud Drive latency, background/lock/reopen during Reset. |
| Acceptance | Reset return is a hard boundary: no old file or success state appears later; a later user-enabled backup succeeds. |
| Rollback | Disable automatic backup and retain manual export rather than restore the race. |
| Dependency / parallelism | Independent; parallel with PR-001/003/004. |
| Risk | High |

## PR-003 — Delete owned Human Note attachments safely

| Field | Plan |
|---|---|
| Goal | Extend note/Human/Reset deletion to external files while preserving live shared references. |
| Roadmap / findings | `ROAD-003`; `SEC-003` |
| Expected files/modules | `Ohana/Features/HumanNotes/HumanNoteAttachmentStore.swift`; `Ohana/Features/HumanNotes/HumanNoteCommands.swift`; `Ohana/Domain/Services/PhysicalDeletionService.swift`; `Ohana/App/AppResetService.swift`; **proposed new** `OhanaTests/HumanNoteAttachmentLifecycleTests.swift`. |
| Modification order | Define owner/reference query → test successful-save fixtures → delete database state → verify surviving references → atomically quarantine/remove file → integrate Human/Reset → failure UI/event. |
| Do not include | Universal media library, unrelated pet documents/photos, note UI redesign, schema-wide asset reference counts. |
| Data migration | No required schema migration if marker references remain the source; optional orphan maintenance must be bounded and separately reviewed. |
| Compatibility risk | Irreversible deletion and possible legacy/shared reference. File purge must occur only after successful database commit and live-reference scan. |
| Automated tests | Single note, multiple notes, shared reference, save failure, Human deletion, Reset, repeated deletion, missing file, cleanup failure. |
| Manual validation | Add a real photo/file, delete at each scope, inspect Files/app storage and relaunch. |
| Acceptance | No orphan for deleted ownership; no live attachment loss; failure remains visible/retryable. |
| Rollback | Stop future purge; quarantine design allows operation-local rollback before final delete. Never recreate fake files. |
| Dependency / parallelism | Independent; coordinate `AppResetService` edits with PR-002. Prefer merge PR-002 first, then rebase PR-003. |
| Risk | High |

## PR-004 — Add strict, versioned restore preflight

| Field | Plan |
|---|---|
| Goal | Reject corrupt required identity/date/reference data before any live-store mutation. |
| Roadmap / findings | `ROAD-004`; `DATA-001`, merged `DATA-002`, `RULE-001`, `LOGIC-003` (expense portion may follow separately) |
| Expected files/modules | `Ohana/Domain/Services/DataBackupDTOs.swift`; `DataBackupManager+Decode.swift`; `DataBackupManager.swift`; `DataBackupRuntime.swift`; `OhanaTests/DataBackupCoverageTests.swift`; `OhanaTests/TestDataBackupManagerProjection.swift`; new corrupt fixtures. |
| Modification order | Enumerate required vs optional fields by backup version → validation result/error model → referential/size checks → run before `applyBackup` → error UI mapping → legacy fixtures. |
| Do not include | Removing live checkpoints, staging-store handoff, broad DTO rename, automatic repair of IDs/dates, UI redesign. |
| Data migration | None to live data; compatibility matrix for old backup versions is required. |
| Compatibility risk | Previously accepted malformed backups may now fail. This is intentional for required identity; optional legacy defaults must be explicitly whitelisted. |
| Automated tests | Invalid/duplicate UUID, invalid required date, missing parent, cyclic/unknown reference, payload/media limits, valid legacy/encrypted packages. |
| Manual validation | Import representative user-created backups from every supported version; no production account. |
| Acceptance | Zero live writes/default mutations before preflight success; error is actionable; valid legacy fixtures remain supported. |
| Rollback | Version-gate individual optional-field rules; disable unsupported import rather than fabricate required data. |
| Dependency / parallelism | Independent; prerequisite for PR-005 and useful for PR-010. |
| Risk | Medium |

## PR-005 — Stage Restore and commit atomically

| Field | Plan |
|---|---|
| Goal | Replace checkpoint mutation of the live store with an atomic, cancellable restore boundary. |
| Roadmap / findings | `ROAD-005`; `DATA-001`, `PERF-001` |
| Expected files/modules | `Ohana/Domain/Services/DataBackupManager.swift`; `DataBackupRuntime.swift`; model-container creation support; notification/revision effect dispatcher; restore Settings UI; new fault-injection integration tests. |
| Modification order | Define staging owner and budget → build scratch container after preflight → cursor/import with cancellation → full validation → atomic/equivalent live handoff → apply defaults/notifications/revisions once → cleanup. |
| Do not include | SwiftData replacement, CloudKit merge, backup format expansion, unrelated performance tuning. |
| Data migration | Temporary staging-store lifecycle only; no new persistent schema unless required for transaction metadata, which would need the next Ark schema. Prefer no schema. |
| Compatibility risk | Disk peak, app relaunch during handoff, side effects firing twice, inability to swap a live SwiftData store. A technically weaker handoff is not acceptable. |
| Automated tests | Failure after every former checkpoint, disk full, cancellation, force-reopen marker, duplicate restore, defaults/notification/revision once-only, large media budget. |
| Manual validation | Real device low storage, background/cancel/relaunch, valid and corrupt large backup. |
| Acceptance | Any failure/cancel preserves byte/logical pre-restore state; success is complete and idempotent; staging is cleaned. |
| Rollback | Keep Restore disabled behind a release gate if atomic handoff cannot be proven; export remains available. |
| Dependency / parallelism | Requires PR-004; should not parallelize with other `DataBackupManager` edits. |
| Risk | High |

## PR-006 — Repair first-pet accessibility identity and UI bootstrap

| Field | Plan |
|---|---|
| Goal | Make the existing visual first-pet entry queryable and require a positive saved-state marker. |
| Roadmap / findings | `ROAD-006`; `TEST-001` |
| Expected files/modules | `Ohana/Features/TodayFocus/Views/TodayFocusCard+ContentCards.swift`; member creation completion surface; `OhanaUITests/OhanaUITests.swift`; targeted accessibility tests. |
| Modification order | Inspect accessibility tree → choose whole-card vs child-action contract → apply role/identifier → add post-save marker → tighten helper → 10-run targeted test → full suite triage. |
| Do not include | Pet-first onboarding behavior, coordinate taps, unrelated UI styling, full suite rewrite. |
| Data migration | None. |
| Compatibility risk | Combining accessibility children can damage VoiceOver reading order or hide secondary information. Test with VoiceOver, not XCTest alone. |
| Automated tests | Targeted first-pet 10 times, save failure, relaunch, accessibility identity snapshot, full UI suite. |
| Manual validation | VoiceOver reading/order/activation of the card and action. |
| Acceptance | No common bootstrap failure; helper cannot pass on disappearance alone; residual failures have unique causes. |
| Rollback | Revert harmful grouping but keep explicit save marker; expose child button if whole-card semantics fail. |
| Dependency / parallelism | No dependency; merge before PR-009. Can parallelize with data PRs. |
| Risk | Medium |

## PR-007 — Fault-inject primary/fallback store recovery

| Field | Plan |
|---|---|
| Goal | Determine and lock the behavior of primary→disk fallback→primary across launches before changing production policy. |
| Roadmap / findings | `ROAD-007`; `DATA-003` |
| Expected files/modules | `Ohana/Models/SharedModelContainer.swift`; `OhanaTests/SharedModelContainerRecoveryTests.swift`; database fallback alert/state. |
| Modification order | Add injectable store opener/path → reproduce each failure → assert selected identity and data → decide fail-closed/migration → only then patch behavior. |
| Do not include | Database-framework migration, restore refactor, schema feature work. |
| Data migration | None for evidence-only PR; a later explicit fallback migration would require its own PR/plan. |
| Compatibility risk | Tests that mutate default store paths must be isolated; production behavior change could strand fallback data. |
| Automated tests | Primary migration failure, default failure, disk fallback write, relaunch primary recovery, disk full, memory fallback, alert state. |
| Manual validation | Optional sandboxed app-container fault test on simulator/device; no production data. |
| Acceptance | Evidence proves whether split occurs; if reproduced, app fails closed or presents explicit recover/migrate flow—never silent writable fork. |
| Rollback | Revert behavior patch, retain fault-injection tests; prefer visible temporary mode. |
| Dependency / parallelism | Can parallelize except with PR-001 changes to container creation. |
| Risk | Medium for tests, High for policy change |

## PR-008 — Derive app version and configure verified public links

| Field | Plan |
|---|---|
| Goal | Remove release identity contradictions in the binary. |
| Roadmap / findings | `ROAD-008`; `MARKET-006`, `DOC-004` |
| Expected files/modules | `Ohana/Features/Settings/Views/SettingsView+MainSections.swift`; `Ohana/App/OhanaPublicLinks.swift`; bundle configuration; focused Settings tests. |
| Modification order | Bundle-derived version/build → verified configurable Apple ID → URL availability behavior → localized About copy → production smoke. |
| Do not include | Store screenshot design, rebrand, privacy policy rewrite, subscription/StoreKit. |
| Data migration | None. |
| Compatibility risk | Review URL unavailable before App Store record exists. UI should hide/disable gracefully. |
| Automated tests | Bundle fallback, valid/absent Apple ID, URL construction, Settings accessibility identifier. |
| Manual validation | Production TestFlight opens correct privacy/support/review destinations. |
| Acceptance | No hardcoded v4.5.0; app shows actual version/build; no unverified rating link ships. |
| Rollback | Hide Rate App until verified; preserve privacy/support. |
| Dependency / parallelism | Independent; App Store Connect value needed for final enablement. |
| Risk | Low |

## PR-009 — Reorder onboarding to pet-first

| Field | Plan |
|---|---|
| Goal | Meet D17: first pet, first care, first Coconut/Oasis value in <=90 seconds with Human deferred. |
| Roadmap / findings | `ROAD-009`; `RULE-002`, `MARKET-001` |
| Expected files/modules | `Ohana/Features/Onboarding/Views/OnboardingView.swift`; onboarding journey/coordinator services; member creation; first-pet Home state; reward/Oasis handoff; unit/UI tests. |
| Modification order | Define migration/interruption state → implicit owner/deferred Human → shorten intro → first pet → safe preset care → saved-state/reward handoff → update tests/docs. |
| Do not include | Family join, paywall, permission bundle, Home redesign, new reward economy. |
| Data migration | Existing onboarded users unchanged; partially onboarded AppStorage/state requires one idempotent migration. No SwiftData schema change expected. |
| Compatibility risk | Duplicate Human/Pet/reward after force quit; Human-dependent services may assume an active Human. Inventory these preconditions first. |
| Automated tests | Every interruption point, no permission, failed save, duplicate prevention, active-human reconciliation, reward once, full UI smoke. |
| Manual validation | Ten clean installs timed; long German and Reduce Motion; comprehension test. |
| Acceptance | Median <=90 seconds; one Pet/one care fact/one reward; Human can be completed later; relaunch resumes safely. |
| Rollback | Internal flag during development only; choose one public flow before release. |
| Dependency / parallelism | Requires PR-006. Avoid parallel changes in onboarding/Home bootstrap. |
| Risk | High |

## PR-010 — Enforce valid expense amounts at the domain boundary

| Field | Plan |
|---|---|
| Goal | Prevent non-finite, zero, or disallowed negative expense values from every command and restore path. |
| Roadmap / findings | `ROAD-010`; `LOGIC-003` |
| Expected files/modules | `Ohana/Features/Expenses/ExpenseCommands.swift`; relevant domain write kernel/rehydrate path; `Ohana/Domain/Services/DataBackupManager+Decode.swift`; `OhanaTests/ExpenseReceiptSupportTests.swift`; `InsuranceExpenseLedgerTests.swift`; new invariant tests. |
| Modification order | Define typed invariant/error → apply to commands → apply to restore preflight/rehydrate → map user error → aggregation guards. |
| Do not include | FX conversion, currency redesign, receipt OCR, charts/UI restyle. |
| Data migration | No schema change. Existing invalid records should be detected/reported, not silently rewritten in this PR. |
| Compatibility risk | Legacy malformed backup may newly fail; coordinate with PR-004 validation messages. |
| Automated tests | NaN/infinity/zero/negative, large max, locale decimal, valid refunds if product allows, restore fixture, summary finite output. |
| Manual validation | Enter edge values in supported locales and verify actionable form error. |
| Acceptance | No domain/restore path persists an invalid amount; established “currency display only” rule remains unchanged. |
| Rollback | Disable affected import/entry path; do not accept non-finite data. |
| Dependency / parallelism | Prefer after PR-004 or coordinate the same decode file; otherwise independent. |
| Risk | Low |

## PR-011 — Align Reduce Motion and permission localizations

| Field | Plan |
|---|---|
| Goal | Make the high-frequency Solo path honest and usable under Reduce Motion and every marketed locale. |
| Roadmap / findings | `ROAD-011`; `A11Y-001`, `A11Y-002`, `TEST-001` |
| Expected files/modules | `AppWorkloadPolicy` and callers; `Ohana/en.lproj/InfoPlist.strings`, `Ohana/de.lproj/InfoPlist.strings`, new marketed-locale InfoPlist files if approved; onboarding/Home/quick-care accessibility tests. |
| Modification order | Inventory motion callers → define full/efficient/minimal contract → focused behavior tests → permission-string market decision → add locale files or narrow claims → device checklist. |
| Do not include | Visual redesign, RTL claim without locale, full animation-system rewrite, all-app localization cleanup. |
| Data migration | None. |
| Compatibility risk | Removing all feedback can make completion unclear; minimal mode must preserve non-motion state confirmation. Usage strings must remain accurate to actual permission use. |
| Automated tests | Runtime policy modes, source/static accessibility, long-string layout, localization parity, UI identity. |
| Manual validation | VoiceOver, Voice Control, max Dynamic Type, Reduce Motion, Increase Contrast, modal focus in core path. |
| Acceptance | Core flow works without essential motion; permission prompts match marketed locale; accessibility metadata is useful to people, not only XCUI. |
| Rollback | Revert individual animation/layout change; retain accurate permission strings and essential labels. |
| Dependency / parallelism | After PR-006 identity contract; can otherwise parallelize. |
| Risk | Medium |

## PR-012 — Add explicit Today pending/failure/retry/undo states

| Field | Plan |
|---|---|
| Goal | Make the current Today Focus answer due/done/failed truth without becoming a new dashboard architecture. |
| Roadmap / findings | `ROAD-012`; `MARKET-003`, `PERF-002` |
| Expected files/modules | `Ohana/Features/TodayFocus/` services/views/commands; Home Today Focus bridge; domain mutation/error events; `HomeSurfaceInvalidationTests`, `HomeReadModelStoreTests`, UI tests. |
| Modification order | Value-state model → command outcome mapping → pending/failed/retry → bounded domain-safe undo → snapshot/UI → covered-surface refresh probes. |
| Do not include | Multi-user Family status, global task engine, Home visual rebuild, unrelated care command changes. |
| Data migration | None unless undo requires persisted tombstone; prefer existing facts and typed compensating command. |
| Compatibility risk | Optimistic state can lie or duplicate facts; undo can reverse a fact after downstream effects. Start non-optimistic for medication/high-risk care. |
| Automated tests | Rapid taps, write failure, retry, idempotency, undo side effects, due/overdue, dense items, covered sheet/dismiss coalescing. |
| Manual validation | Five task sessions; Low Power/Reduce Motion; one-handed quick care. |
| Acceptance | A failed write is never shown completed or rewarded; retry creates at most one fact; hidden Home does not refresh; users identify next task. |
| Rollback | Disable new optimistic/undo features and retain current Today Focus. |
| Dependency / parallelism | After core data blockers; avoid parallel changes to the same Today Focus files. |
| Risk | Medium |

## PR-013 — Modernize one proven concurrency boundary

| Field | Plan |
|---|---|
| Goal | Establish the incremental migration pattern: `@ModelActor` returns Sendable values, and app-owned dependencies are instance-injected. |
| Roadmap / findings | `ROAD-013`; `CONC-001`, `ARCH-001` |
| Expected files/modules | `Ohana/Shared/Media/AvatarAssetMaintenanceService.swift`; relevant `AppServices` registration; `OhanaTests/AvatarAssetMaintenanceServiceTests.swift`; strict-concurrency build configuration for the slice. |
| Modification order | Capture current behavior → replace live model/context return/callback data with IDs/value DTOs → rehydrate only where needed on MainActor → inject service → tests/strict build. |
| Do not include | Whole-repo Swift 6 conversion, Medication boundary, all registries, directory moves, mass `Sendable` annotations. |
| Data migration | None. |
| Compatibility risk | Rehydration may observe deletion/stale IDs; this must become an explicit missing result, not a crash. |
| Automated tests | Existing avatar maintenance behavior, deleted ID, cancellation, strict-concurrency focused build, no live `PersistentModel` in result types. |
| Manual validation | Avatar cleanup/update with app background/foreground and missing media. |
| Acceptance | Target warnings removed; behavior unchanged; pattern documented for later slices. |
| Rollback | Protocol adapter allows reverting this slice without changing callers outside the module. |
| Dependency / parallelism | After release blockers; independent of product UI. |
| Risk | Medium |

## PR-014 — Make Vet Summary discoverable as visit preparation

| Field | Plan |
|---|---|
| Goal | Turn the existing PDF capability into a clear user job without changing medical scope. |
| Roadmap / findings | `ROAD-014`; `MARKET-004` |
| Expected files/modules | `Ohana/Features/Documents/Views/PetVetSummaryPDFView.swift`; `Ohana/Features/DashboardRecords/Views/PetRetentionHubView.swift`; Pet health/profile route; localized copy; PDF tests. |
| Modification order | Validate fields/privacy → add “Prepare for vet visit” entry → completeness/preview → share/save error → Store/help copy later. |
| Do not include | AI diagnosis, provider API, PDF engine rewrite, new health data collection. |
| Data migration | None. |
| Compatibility risk | Summary can be mistaken for medical advice or include unintended data. Copy and privacy field matrix are required. |
| Automated tests | Empty/dense/long locale/multiple medication/missing media render, field inclusion, share failure. |
| Manual validation | A4 readability/print, share sheet, VoiceOver preview, vet-task comprehension. |
| Acceptance | Entry found from pet health; PDF contains only selected pet records; “record summary, not diagnosis” clear; failure recoverable. |
| Rollback | Hide new entry, keep existing PDF feature. |
| Dependency / parallelism | After data/privacy blockers; can parallelize with architecture work. |
| Risk | Low |

## PR-015 — Add a read-only, privacy-redacted care Widget

| Field | Plan |
|---|---|
| Goal | Reduce app-open friction without permitting extension writes or leaking sensitive lock-screen details. |
| Roadmap / findings | `ROAD-015`; `MARKET-005` |
| Expected files/modules | Xcode project/entitlements; **proposed new** Widget extension; **proposed new** small shared snapshot contract; typed deep-link route; cache ownership manifest; tests. |
| Modification order | Approve App Group `group.com.guanchen.li.Ohana` → define redacted value snapshot/TTL → app writes snapshot after facts → Widget reads only → deep link → locked-state/device tests. |
| Do not include | App Intent writes, SwiftData access from extension, medication detail by default, Family/CloudKit, interactive controls. |
| Data migration | New shared-container snapshot only; no SwiftData schema. Upgrade/removal cleanup required. |
| Compatibility risk | Entitlement/signing, stale content, lock-screen privacy, timeline energy. |
| Automated tests | Snapshot redaction/expiry, missing App Group, deep link, cache eviction, no model imports in extension. |
| Manual validation | Home/Lock Screen, reboot, offline, Low Power, protected device, alternate locales. |
| Acceptance | Widget reveals only approved content, expires stale state, opens typed destination, and consumes bounded refresh budget. |
| Rollback | Remove/disable extension independently; core app remains unaffected. |
| Dependency / parallelism | All release blockers and ROAD-008; precedes PR-016. |
| Risk | High |

## PR-016 — Add idempotent App Intents for high-value actions

| Field | Plan |
|---|---|
| Goal | Expose quick pet care, open pet, and Today Focus to Shortcuts/Siri only after the read-only system surface is safe. |
| Roadmap / findings | `ROAD-015`; `MARKET-005` |
| Expected files/modules | **proposed new** App Intents/App Entities files in app target; typed route handoff; domain care command; `docs/specs/AppIntents-logic.md`; route/idempotency tests. |
| Modification order | Small `AppEntity` value surface → open-app intents first → one inline care intent with transaction/idempotency key → error/cancellation → shortcuts phrases/localization. |
| Do not include | Full SwiftData models in entities, arbitrary health queries, Family sync, background unlimited work, Widget UI changes. |
| Data migration | None. Intent transaction keys may use existing ledger/fact identity; do not add schema without a separate migration review. |
| Compatibility risk | Duplicate voice invocation, stale entity, locked-device privacy, ambiguous pet names. |
| Automated tests | Duplicate invocation, deleted entity, offline, cancellation, open route, exactly-one fact/reward, localization. |
| Manual validation | Siri/Shortcuts on device, locked/unlocked behavior, ambiguous names, confirmation language. |
| Acceptance | Intent either completes exactly once with clear confirmation or opens typed route; no sensitive value exposed without unlock. |
| Rollback | Disable inline write intents; retain safe open-app shortcuts. |
| Dependency / parallelism | After PR-015 and stable domain commands; not parallel with entitlement/system-surface changes. |
| Risk | High |

## PR-017 — Reconcile active docs, rules and release traceability

| Field | Plan |
|---|---|
| Goal | Make current policy, current implementation, future plans and historical references impossible to confuse. |
| Roadmap / findings | `ROAD-017`; `DOC-002`, `DOC-003`, `RULE-001`, `RULE-002`, `RULE-004`, `TRACE-001`, `MARKET-006` |
| Expected files/modules | `AGENTS.md` only if necessary; `docs/specs/product-foundation.md`; `docs/privacy-policy.md`; `docs/task-follow-ups.md`; `docs/testing-progress.md`; `docs/release-hardening-plan.md`; `docs/permission-rationale-draft.md`; `docs/governance/manifests/privacy-ownership.json`; `docs/ai-module-test-playbook.md`; governance scripts/fixtures. |
| Modification order | Update status for each already-merged fix → resolve product decisions → align policy/capabilities → archive obsolete release plan → narrow AI playbook → add Rule→Code→Test rows/semantic fixtures. |
| Do not include | Source behavior, dependency upgrades, new root/editor rules, wholesale rewrite of 98 Markdown files, deletion without link/content audit. |
| Data migration | None. |
| Compatibility risk | Broken internal links or accidental loss of historical rationale; archive first and validate references. |
| Automated tests | `git diff --check`, doc-status, agent governance, link/path checks, release data safety fixtures, localization where user copy changes. |
| Manual validation | Product/privacy owner reviews absolute claims, target OS/Storefront and release status. |
| Acceptance | One authority chain; no active doc claims P1=0 while blockers are open; current Solo capability accurate; automated gate catches reintroduced stale schema/capability claims. |
| Rollback | Revert one document decision; preserve prior text in archive when history matters. |
| Dependency / parallelism | Status updates accompany each PR; final consolidation after product decisions and blockers. |
| Risk | Low |

## Recommended Merge Order

1. `PR-001` — sensitive OS backup boundary.
2. `PR-002` — backup/Reset generation.
3. `PR-003` — attachment lifecycle, rebased after PR-002 due shared Reset file.
4. `PR-004` then `PR-005` — strict preflight before atomic restore.
5. `PR-006` — reliable UI smoke gate.
6. `PR-007`, `PR-008`, `PR-010`, `PR-011` — correctness/release identity slices, with independent files where possible.
7. `PR-009` — pet-first after the smoke harness is trustworthy.
8. `PR-012` — Today recovery semantics after data correctness.
9. `PR-017` — final documentation consolidation; status updates happen in every preceding PR.
10. `PR-013`–`PR-016` — post-blocker incremental architecture and market work.

The first implementation PR should be **PR-001**. It closes the highest App Review/privacy control gap with a bounded surface and no schema migration. Its acceptance is not “the helper exists”; all sensitive path variants must be excluded, tests must verify the resource values, and a signed real-device backup/restore must confirm that prohibited personal-health data does not return.
