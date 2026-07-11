# UI Smoke Gate Closure

| Metadata | Value |
| --- | --- |
| Status | Dated repository-local closure evidence |
| Verified | 2026-07-11 |
| Baseline | `4d434d5354efdfb0eb7864cadad9ccf3df3825b5` plus the current modified worktree |
| Current status owner | `docs/testing-progress.md` and `docs/task-follow-ups.md` |

## Decision

`TFU-20260710-004` is closed for the repository-local UI release gate.

The fast release smoke passed 3/3, including the production-overlay first-pet
path and the automated accessibility action contract. The first-pet creation
path then passed 10/10 repetitions with App relaunch enabled between runs. The
47 failures from the 2026-07-10 full-suite checkpoint are individually mapped
below into 14 root-cause clusters; representative tests for every cluster were
rerun after the relevant harness or production repair.

This decision does **not** claim that the full 81-test suite was rerun or passed
81/81. It also does not convert simulator semantics into physical VoiceOver,
signed-device, notification, location, energy, or App Store evidence. Those
remain in the true-device release plan.

## Scope And Environment

| Item | Evidence |
| --- | --- |
| Repository baseline | `4d434d5354efdfb0eb7864cadad9ccf3df3825b5`; validation ran in the current modified worktree, so the fixes do not yet have a commit identity |
| Xcode | 26.6 (`17F113`) |
| Simulator | iPhone 17, iOS 26.5, UDID `EC2C2B3B-3135-4427-89B7-F4B6A6049D66` |
| Build mode | Debug UI-test build, `iphonesimulator`, `CODE_SIGNING_ALLOWED=NO` |
| Historical checkpoint | 81 tests executed: 34 passed, 47 failed |
| Final fast gate | 3 tests passed, 0 failed |
| Stability gate | 10 repetitions passed, 0 failed; relaunch enabled; average test duration 39 seconds |

Passcode-protected physical-device notification-proxy warnings were emitted by
Xcode while the destination remained the pinned iPhone 17 simulator. They did
not change the selected destination or any test result.

## Repairs That Changed Product Behavior

1. `SettingsView` used a root `LazyVStack` for a bounded settings form. During
   the failing Plant reminder route, a five-second process sample found all
   1,939 captured main-thread samples inside SwiftUI ViewGraph layout work,
   including `LazySubviewPlacements`. The route also produced UI-query timeouts
   after approximately 190 seconds. Replacing that bounded root with `VStack`
   removed the layout feedback loop; the reminder route passed in 44 seconds,
   and the longer bulk-defer/edit journey passed without the former idle stall.
2. Each Plant reminder control is now one explicit accessibility leaf instead
   of exposing internal switch geometry as competing descendants.
3. The Human workout screen identifier moved to its header container so the
   screen marker no longer swallows the child Add Workout action.
4. The Today Focus carousel now separates visual rendering from its transparent
   touch proxy while exposing one semantic Button with a combined title/detail
   label. The dismiss action remains a separate accessible control.

## Harness And Gate Repairs

- Replaced stale labels and obsolete route assumptions with current stable
  identifiers and current product routes.
- Scoped ambiguous Calendar, sheet-close, and navigation queries to visible,
  frame-ready controls.
- Required explicit post-save markers instead of treating disappearance of a
  form as success.
- Added deterministic helpers for SwiftUI Menu hit-point issues on the pinned
  simulator and documented every coordinate fallback.
- Added `scripts/test-ui-release-smoke.sh` with a three-test fast smoke and a
  relaunch-isolated ten-repetition stability mode.
- Added an accessibility contract that verifies one first-pet action, Button
  role, the complete combined label, and a stable activation frame.

## Historical 47-Failure Disposition

The names below are copied from the 2026-07-10 xcresult summary. A cluster is a
triage disposition, not a claim that every old test was rerun in one new bundle.

| Cluster | Count | Historical tests | Disposition and fresh proof |
| --- | ---: | --- | --- |
| Calendar/global ambiguous queries and route dismissal | 12 | `testDeletedPetCalendarEventDoesNotOpenLiveCareRoute`; `testHumanRecordOperationsPersistFromFeatureHub`; `testManualCalendarEventRowOpensDetailEditsAndDeletes`; `testMemorialPetCalendarEventDoesNotOpenLiveCareRoute`; `testPetCalendarFilterShowsOnlyPetLinkedEvents`; linked manual Health, Hygiene, Play, Potty, Walk, Water, and Weight title tests | Harness defect. Queries and dismissal are now route-scoped and frame-aware. A linked manual Calendar row opened its editable detail in `pet-calendar-feed-verified.xcresult`. |
| Current Pet profile entry | 6 | `testPetBasicInfoEditCancelDoesNotPersistAndSaveDoes`; `testPetBasicInfoEmptyNameSaveKeepsOriginalName`; `testPetMemorialHidesHomeLiveCareEntrypoints`; `testPetMemorialMarkCancelConfirmAndUndoFlow`; `testPetPermanentDeleteCancelAndWrongNameAreSafe`; `testPetPermanentDeleteFromBasicInfoSmoke` | Stale Feature Hub tile assumption. The current expanded-card Profile entry is used. Edit cancel/save passed in `residual-ui-core-verified.xcresult`. |
| Pet home-card/context route state | 5 | `testExistingPetRealUserJourneyWithoutReset`; `testPetFeatureHubDailyAndHealthRoutesOpenAndCancel`; `testPetWaterCareRewardAppearsInBondVaultLedger`; `testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail`; `testSystemGeneratedPetCalendarFeedEventRowOpensQuickFeedDetail` | Harness route-state defect. Helpers now close active routes, select Home, collapse expanded cards, and accept current card identity. Feature Hub navigation passed in `pet-feature-hub-verified.xcresult`. |
| Cat litter/current menu | 6 | `testPetLitterFullChangePersistsFromQuickCareDetail`; `testPetLitterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail`; `testPetLitterPlanDeleteClearsSavedReminderFromQuickCareDetail`; `testPetLitterPlanReminderCancelAndSaveFromQuickCareDetail`; `testPetLitterScoopPersistsAndRepeatSubmitIsBlocked`; `testPetScoopPlanCalendarEventAppearsAndDeletesFromQuickCareDetail` | Stale route/menu selectors plus a SwiftUI Menu hit-point issue. Reminder cancel/save passed in `pet-litter-verified.xcresult`. |
| Walk submenu/current controls | 3 | `testPetDogRealUserLongSessionCoversWalkMemorialEditAndDeleteSafeguards`; `testPetHomeWalkCardMinimizesToFloatingBubble`; `testPetWalkQuickActionPersistsAndSummaryReadback` | Stale expectation for embedded/global controls. Current walk action and summary path passed in `pet-route-clusters-rerun.xcresult`. |
| Human workout marker/identifier | 3 | `testHumanExtendedModuleDeletesDisappearFromFeatureHub`; `testHumanExtendedModuleOperationsPersistFromFeatureHub`; `testHumanFeatureHubRoutesOpenFromHome` | One production accessibility-container issue plus stale marker copy. Extended operations passed in `human-extended.xcresult`. |
| Feed anti-repeat/current selector | 2 | `testFeedingManualPlanAndHomeQuickActionSmoke`; `testPetRealUserLongSessionCoversCareCalendarEconomyAndSafeguards` | Localized/current guard selectors were incomplete. The focused feed flow passed in `pet-feed-verified.xcresult`. |
| Plant Settings layout/query | 2 | `testExistingPlantReminderToggleWithoutReset`; `testExistingPlantSettingsBulkDeferAndEditCancelSaveWithoutReset` | Confirmed production SwiftUI layout loop plus imprecise scrolling/text replacement. Both focused tests passed in `plant-reminder-toggle-verified-v5.xcresult` and `plant-settings-bulk-edit-verified-v4.xcresult`. |
| Plant add, current Dashboard, and room rail | 3 | `testAddPlantPrimaryPathUsesCatalogAndChoiceChipsWithoutTyping`; `testPlantFunctionMenuEntrypointsOpenDashboardListPhotosWithoutCalendarReset`; `testPlantRoomRailFiltersAndCollapsesExpandedCard` | Current identifiers and current “collapse before rail” policy replaced obsolete expectations. Add and room rail passed in `plant-residual-verified.xcresult`; Plants/Photos/Sites passed in `plant-function-menu-verified.xcresult`. |
| Human Home quick menu | 1 | `testHumanHomeQuickActionsOpenExpectedSheets` | Harness did not recognize the current inline menu/sheet state. Passed in `residual-ui-core-verified.xcresult`. |
| Daily Streak | 1 | `testDailyStreakSheetOpensAndClosesFromHome` | Recording showed the route opened; the failure was a stale localized title/assertion. Current identifier/title path passed in `residual-ui-core-verified.xcresult`. |
| Health visit action | 1 | `testPetHealthRecordCancelAndSavePersistsFromFeatureHub` | Stale detail action selector. Cancel/save persistence passed in `pet-health-verified.xcresult`. |
| Hygiene single-use guard | 1 | `testPetHygieneRecordPersistsAndRepeatTapIsBlocked` | English/German current guard controls were missing from the test selector. The focused path passed in `pet-residual-clusters.xcresult`. |
| Breed Menu selection/hit point | 1 | `testPetLinkedManualCalendarEventRowOpensEventDetail` | SwiftUI Menu exposed the option label but reported an invalid activation point. The constrained fallback verifies the selected Menu label before continuing; the complete linked-event test passed in `pet-calendar-feed-verified.xcresult`. |

Count check: `12 + 6 + 5 + 6 + 3 + 3 + 2 + 2 + 3 + 1 + 1 + 1 + 1 + 1 = 47`.

## Fresh Passing Evidence

| Artifact | Result used for this decision |
| --- | --- |
| `.build/TestResults/2026-07-11/human-extended.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/pet-feature-hub-verified.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/pet-litter-verified.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/pet-health-verified.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/pet-feed-verified.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/plant-reminder-toggle-verified-v5.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/plant-settings-bulk-edit-verified-v4.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/plant-function-menu-verified.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/residual-ui-core-verified.xcresult` | 3/3 passed |
| `.build/TestResults/2026-07-11/first-pet-accessibility-verified-v3.xcresult` | 1/1 passed |
| `.build/TestResults/2026-07-11/ui-release-smoke-v3.xcresult` | 3/3 passed |
| `.build/TestResults/2026-07-11/first-pet-stability-10x.xcresult` | Test-details record says “Test case with 10 runs”; repetitions 1 through 10 all passed with relaunch enabled |

Four earlier mixed bundles are used only as per-test evidence, never as overall
green bundles: the linked manual Calendar test passed in
`pet-calendar-feed-verified.xcresult`; the walk test passed in
`pet-route-clusters-rerun.xcresult`; the hygiene test passed in
`pet-residual-clusters.xcresult`; and Plant add plus current room rail passed in
`plant-residual-verified.xcresult`.

## Final Commands

```bash
OHANA_TEST_ACTION=test-without-building \
OHANA_SIMULATOR_UDID=EC2C2B3B-3135-4427-89B7-F4B6A6049D66 \
OHANA_RESULT_BUNDLE_PATH="$PWD/.build/TestResults/2026-07-11/ui-release-smoke-v3.xcresult" \
scripts/test-ui-release-smoke.sh smoke

OHANA_TEST_ACTION=test-without-building \
OHANA_SIMULATOR_UDID=EC2C2B3B-3135-4427-89B7-F4B6A6049D66 \
OHANA_RESULT_BUNDLE_PATH="$PWD/.build/TestResults/2026-07-11/first-pet-stability-10x.xcresult" \
scripts/test-ui-release-smoke.sh first-pet-stability
```

## Remaining Evidence Boundary

- The 2026-07-10 34/81 result remains a historical full-suite checkpoint. No
  final 81/81 claim is made.
- XCUITest verifies the first-pet semantic action contract. SwiftUI render Text
  nodes remain queryable in XCUITest's debug hierarchy even when the parent
  accessibility element ignores its children, so `staticTexts.exists` is not a
  trustworthy VoiceOver traversal assertion.
- Physical VoiceOver order, Switch Control/Voice Control behavior, signed
  Release behavior, real-device performance, and assistive settings remain in
  `docs/release-true-device-test-plan.md`.
