# Round 1 Performance, Energy, and Smoothness Audit

> Date: 2026-06-08
>
> Scope: static repo inspection plus existing audit scripts. No simulator timing claims are made here.

## Current Strengths

- `MetricKitObserver` records launch, hang, memory, crash, CPU, and disk-write diagnostics into `AppPerformanceMonitor`.
- Startup maintenance is deferred after first render through `StartupMaintenanceCoordinator`.
- `AppWorkloadPolicy` centralizes foreground/background, Low Power Mode, Reduce Motion, app power-saving, and active-walk decisions.
- Home has existing measurement hooks such as `home_first_render`, `home.cardExpandFirstFrame`, `home.firstSnapshotReady`, and avatar preview readiness.
- Full-repo runtime guardrails pass on 435 Swift files.
- Resource integrity audit passes current budgets: `Resources` 186 MiB, pet avatars 180 MiB, human avatars 5.7 MiB, asset catalog 36 MiB.

## P0 Risks

None confirmed by this static pass. P0 requires evidence of a current failing user path, data-loss/privacy issue, startup blocker, signed packaging failure, or active runtime/energy violation.

## P1 Risks

1. Broad `@Query` remains in high-traffic or reusable SwiftUI surfaces.
   - Evidence: `CalendarView` owns multiple full queries including events, pets, humans, plants, insurance, pet medication, and human medication.
   - Evidence: reusable/high-traffic surfaces such as quick feed/water/potty sheets, `FocusHomeAuxiliaryViews`, `CrewRosterOverlay`, `OasisRewardView`, `HumanAllFeaturesSheet`, and `FunctionMenuRootView` still own live queries.
   - Next action: choose the highest-traffic path and move it to a screen container + snapshot/read model.

2. Synchronous image/file decoding still appears in view paths.
   - Evidence: `OnboardingView` reads bundled avatar files with `Data(contentsOf:)` and `UIImage(data:)`.
   - Evidence: many avatar rows/cards still call `UIImage(data:)` in view files.
   - Existing mitigation: home has `FocusWalletAvatarCache`; some form paths already mention background decode.
   - Next action: standardize avatar/image render snapshots and disallow fresh decode in high-frequency rows/cards.

3. Runtime loops are policy-aware but numerous.
   - Evidence: many `repeatForever` and `TimelineView(.animation)` instances remain in view files.
   - Existing mitigation: runtime guardrails pass and many lines include policy-gated allow reasons.
   - Next action: verify visibility gating mechanically for Home, Oasis, walk maps, and onboarding backgrounds.

4. SLO evidence is incomplete.
   - Evidence: docs define targets; manifests define flows; not every critical flow has signpost/test/simulator evidence yet.
   - Next action: Round 2 adds stable measurement probes and evidence requirements.

## P2 Risks

1. Several SwiftUI files remain large enough to affect maintainability and compile-time feedback.
   - Evidence: `PetHealthDetailView.swift` 2949 lines, `OasisRewardView.swift` 2488, `CrewRosterOverlay.swift` 2237, `QuickWaterDetailSheet.swift` 2221, `OverviewQuickActions.swift` 2119.
   - Next action: split only when touching the flow or when compile/runtime evidence points there.

2. Resource package size is within current budget but still large.
   - Evidence: `Resources/Avatars/PetAvatarAssets` is 180 MiB.
   - Next action: Round 5 decides whether to compress, use asset catalogs, on-demand resources, or downloadable resource packs.

3. UI/accessibility/SwiftFormat ratchets remain partial.
   - Evidence: changed-files gates exist; full historical baseline is not yet enforced.
   - Next action: tighten after high-value interaction repairs and formatting baseline cleanup.

## Round 2 Candidate Flows

- Home card expand/collapse.
- Home tab switch and embedded Calendar/Oasis activation.
- Quick care command from home.
- Inline overlay / quick detail sheet entry and exit.
- Calendar open and date change.
- Oasis enter and ambient loop visibility.
- Backup export and delete-my-data.

## New Gate Added

`scripts/audit-smoothness-risk.sh` scans changed SwiftUI code for:

- Broad `@Query` in `Ohana/Features/Home` and `Ohana/Shared/Components`.
- Synchronous `Data(contentsOf:)`, `UIImage(data:)`, or `UIImage(contentsOfFile:)` in view files.
- `Timer.publish`, `TimelineView(.animation)`, and `repeatForever` in view files.

Use `// smoothness: allow <reason>` only for deliberate and measured exceptions.

