# Round 3 Interaction Smoothness Evidence

> Date: 2026-06-08
>
> Scope: repair high-frequency interaction paths selected from the full-app smoothness audit. This document records concrete repairs, not only risk inventory.

## Repair 1 - Oasis Home Tab Entry

Interaction class: `interaction-heavy`, `route transition`, `snapshot handoff`, `runtime`.

Non-negotiable invariants:

- The tab switch frame must mutate only local tab/route visual state.
- The Oasis live tree must not mount during `preparing` or outgoing transition frames.
- The visible transition may show only a lightweight preview shell with no SwiftData queries and no ambient loop.
- The live `OasisRewardView` may mount only after the page is stable `live`, then after a deferred frame handoff.
- Leaving the tab must unmount live content immediately and leave only the lightweight shell for exit motion.

Implemented structure:

`VerticalSolidHomeController -> OasisHomeTabHost -> PreviewShell -> DeferredLiveMount -> OasisRewardView`

Code changes:

- `OasisHomeTabHost` now gates live content with `showsLiveContent && lifecycle.isLive`.
- `isPrepared`, `isPreparingForDisplay`, and outgoing `isVisible` states render only `OasisHomeTabPreview`.
- Live content mounts through `liveContentMountTask` after the page is `isLive` and one deferred frame has passed.
- Exit/preparing states cancel pending live mounts and unmount `OasisRewardView`.
- `flow.oasis.open` now separates `shell_ready`, `first_frame`, and `content_mounted` phases so the preview shell and live thaw are visible in evidence.
- Injection handoff remains deferred until live content is mounted.

Compliance matrix:

| Gate | Status | Evidence |
|---|---|---|
| Finger-first frame | Compliant | Tab selection no longer causes Oasis live content mount while `isPreparingForDisplay`. |
| Frozen/render shell handoff | Compliant | `OasisHomeTabPreview` renders the transition shell; `BeautifulCoconutTree` preview has ambient motion disabled. |
| Heavy work deferred and cancellable | Compliant at host layer | `liveContentMountTask` is cancellable and delayed until `isLive`; exit cancels it. |
| Visual/business separation | Compliant at host layer | Preview reads no SwiftData and forwards no business command. |
| Runtime budget and visibility gating | Compliant at host layer | Preview disables ambient motion; live view receives `isEmbeddedActive` only after live mount. |
| Thaw timing | Compliant | Live content mounts after `isLive` and a deferred frame. |
| Safe area and hit testing | Compliant at host layer | Live content hit testing is enabled only while `lifecycle.isLive`. |
| Validation performed | Compliant | Changed-files smoothness, accessibility, release-hardening `--skip-build`, shell syntax, whitespace audits, and fixed-simulator Debug build passed. |

## Repair 2 - Oasis Live Data Snapshot Store

Interaction class: `interaction-heavy`, `snapshot handoff`, `persistence`.

Non-negotiable invariants:

- `OasisRewardView` must not own broad live `@Query` dependencies.
- SwiftData fetches for Oasis live state must happen only in explicit refresh points after the visual shell/handoff.
- Inactive/hidden Oasis content must release live snapshot arrays.
- Fetch scope must be bounded so rendering does not depend on unbounded relationship or table scans.

Implemented structure:

`OasisRewardLiveDataStore -> OasisRewardLiveDataSnapshot -> OasisRewardView render/business refresh`

Code changes:

- Removed the six broad `@Query` properties from `OasisRewardView`.
- Added `OasisRewardLiveDataStore`, a route-scoped `@StateObject` that fetches bounded Oasis data snapshots through `FetchDescriptor`.
- Added bounded fetch limits for pets, humans, plants, upgrade coconuts, electronic pets, and critter fragments.
- Refreshes now occur from explicit lifecycle/refresh methods instead of SwiftUI body-level query observation.
- `deactivateVisibleWork()` resets the live data snapshot so hidden Oasis content releases live arrays.
- Decorative SF Symbols and small noninteractive badges were marked for accessibility audit clarity; remaining fixed fonts in the touched file were moved to `OhanaFont` tokens.

Compliance matrix:

| Gate | Status | Evidence |
|---|---|---|
| Finger-first frame | Compliant | Oasis tab entry still renders the preview shell first; live data refresh is not part of the tab-selection frame. |
| Frozen/render shell handoff | Compliant | Host-level preview shell remains the handoff surface before live mount. |
| Heavy work deferred and cancellable | Compliant | Live content mounts after `isLive`; store reset happens on deactivate. |
| Visual/business separation | Compliant | `OasisRewardView` reads value snapshots from `OasisRewardLiveDataStore` instead of owning direct broad `@Query` bindings. |
| Runtime budget and visibility gating | Compliant | Ambient loops remain `AppWorkloadPolicy` gated and changed-files smoothness audit passes. |
| Thaw timing | Compliant | Live snapshot refresh is attached to visible/prepared refresh methods, not preview-shell rendering. |
| Safe area and hit testing | Compliant at host layer | Host still disables live hit testing outside `lifecycle.isLive`. |
| Validation performed | Compliant | See validation below. |

Validation:

- `scripts/audit-accessibility.sh --changed` passed.
- `scripts/audit-smoothness-risk.sh --changed` passed.
- `git diff --check` passed.
- `scripts/release-hardening-check.sh --skip-build` passed, including governance manifest, resource integrity, xattr, privacy manifest, runtime guardrail, UI V4, accessibility, and smoothness checks.
- `DERIVED_DATA_PATH=/tmp/OhanaDD-fullscore-round4 scripts/build-debug-fast.sh` passed on `platform=iOS Simulator,name=iPhone 17` with `-sdk iphonesimulator`.

Historical validation blocker, now cleared:

- `DERIVED_DATA_PATH=/tmp/OhanaDD-fullscore-round2 scripts/build-debug-fast.sh` was interrupted after `xcodebuild` stayed idle with no compiler/build child processes.
- `DERIVED_DATA_PATH=/tmp/OhanaDD-fullscore-round3 scripts/build-debug-fast.sh` reproduced the same hang.
- `sample` showed `xcodebuild` blocked in `NSFileCoordinator coordinateReadingItemAtURL` while resolving the Xcode project container, before build graph or Swift compilation began.
- The later `/tmp/OhanaDD-fullscore-round4` fixed-simulator build completed successfully, including CodeSign.
