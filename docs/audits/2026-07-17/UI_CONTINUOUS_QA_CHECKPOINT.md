# Continuous UI QA Checkpoint

Date: 2026-07-17 20:04 CEST

## Result

- Formal UI manifest: 119 selectors, each assigned once.
- Exact current-build evidence: 25 distinct selectors passed, 0 failed.
- Remaining without green evidence from this exact build: 94 selectors.
- Device: `iPhone 17 Tests`
  (`DFCF3E93-1A6F-4430-9312-8BFD08FC9FE0`), iOS 26.5.
- Build scope: `app+ui`, scheme `OhanaUITests`, code signing disabled.
- Provenance source hash:
  `31afe81538188e5dc0771701a9078c723c76fcfff07f1f52792e0cff14f4ea6f`.
- Provenance contract hash:
  `22251f9e4dcd8f0b1dbee2d3a2a606adb01438fb2c1423162a4b088e03be4376`.
- Free disk at checkpoint: about 44 GiB.

This is a targeted current-build checkpoint, not a 119/119 full-suite claim.
Historical results from an older build are not silently promoted into the 25.

## Current-Build Green Selectors

1. `OhanaUITests/OhanaUITests/testHumanFirstOnboardingCreatesPetClaimsGiftAndUnlocksOasis`
2. `OhanaUITests/OhanaUITests/testPetLitterPlanReminderCancelAndSaveFromQuickCareDetail`
3. `OhanaUITests/PlantRoomStackUITests/testRoomStacksOpenIntoTheExistingPlantDeck`
4. `OhanaUITests/OhanaUITests/testSingleHumanPetHomeAndFunctionMenuFeelComplete`
5. `OhanaUITests/OhanaUITests/testDeletedPetCalendarEventDoesNotOpenLiveCareRoute`
6. `OhanaUITests/OhanaUITests/testMemorialPetCalendarEventDoesNotOpenLiveCareRoute`
7. `OhanaUITests/OhanaUITests/testHumanPermanentDeleteWithExactNamePersistsAcrossRelaunch`
8. `OhanaUITests/OhanaUITests/testPetProfileBodyNotApplicablePersonalityPrivateAndDailyReviewedCompletesAnyThree`
9. `OhanaUITests/OhanaUITests/testMemberCardPrivateAppearanceAndUnknownOptionalPath`
10. `OhanaUITests/OhanaUITests/testPetIdentityPrivateDocumentsAndUnknownEmergencyPersistAcrossRelaunchWithoutFabricationAndRewardsOnce`
11. `OhanaUITests/OhanaUITests/testSkippedPetCreationMovesToTasksAndCompletesFromSystemJourney`
12. `OhanaUITests/OhanaUITests/testPetCreationBackDefersThenTasksCancelPreservesJourney`
13. `OhanaUITests/OhanaUITests/testPetDailyCareUnknownCancelThenRealSetupSurvivesRelaunchWithoutFabricationAndRewardsOnce`
14. `OhanaUITests/OhanaUITests/testDeferredFirstPetTaskPersistsAcrossRelaunchWithoutUnsavedDraft`
15. `OhanaUITests/OhanaUITests/testStarterPreventiveHealthUnknownCloseReopenCompletesWithoutFabricatedRecord`
16. `OhanaUITests/OhanaUITests/testMemberCardPrivateAppearanceThenRealAvatarSupersedesResolutionAcrossRelaunch`
17. `OhanaUITests/OhanaUITests/testStarterPreventiveHealthClaimedNotApplicableThenRealRecordDoesNotResurrectAcrossRelaunch`
18. `OhanaUITests/OhanaUITests/testPetIdentityNotApplicableResumesThenEmergencyContactSaveCompletes`
19. `OhanaUITests/OhanaUITests/testStarterPreventiveHealthPrivateAnswerSurvivesRelaunchWithoutFabricatedRecordAndRewardsOnce`
20. `OhanaUITests/OhanaUITests/testPetDailyCareNotApplicableThenRealSetupSupersedesResolutionAcrossRelaunch`
21. `OhanaUITests/OhanaUITests/testPetEmergencyContactNotApplicableThenRealSaveSupersedesResolutionAcrossRelaunch`
22. `OhanaUITests/OhanaUITests/testMemberCardNavigationCancelResumeReviewedAndPrivate`
23. `OhanaUITests/OhanaUITests/testStarterGiftCeremonyResumesAfterRelaunchWithoutDuplicateReward`
24. `OhanaUITests/OhanaUITests/testHumanFirstOnboardingAccessibilityContract`
25. `OhanaUITests/OhanaUITests/testMemberCardMixedPrivateAndSavedAnswersSurviveRelaunchAndRewardOnce`

## Result Bundles

- `Test-OhanaUITests-2026.07.17_19-28-43-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-30-00-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-31-19-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-31-54-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-33-24-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-35-08-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-36-39-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-38-55-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-39-58-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-40-31-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-43-09-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-44-03-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-45-08-+0200.xcresult`
- `Test-OhanaUITests-2026.07.17_19-47-37-+0200.xcresult` (2 selectors)
- `Test-OhanaUITests-2026.07.17_19-50-19-+0200.xcresult` (2 selectors)
- `Test-OhanaUITests-2026.07.17_19-53-55-+0200.xcresult` (2 selectors)
- `Test-OhanaUITests-2026.07.17_19-57-39-+0200.xcresult` (2 selectors)
- `Test-OhanaUITests-2026.07.17_20-01-25-+0200.xcresult` (2 selectors)
- `Test-OhanaUITests-2026.07.17_20-03-15-+0200.xcresult` (2 selectors)

All bundles are under
`.build/DerivedData/tests/Logs/Test/` and were produced through
`scripts/test-simulator.sh`. The build was created with `build-for-testing` and
each listed selector ran with `test-without-building`; the provenance guard
validated the exact App + UI source tree before execution.

## Post-Checkpoint Continuation

The frozen 20:04 CEST checkpoint above remains an exact-build result of
25/119. It is not rewritten as a 31-selector exact-current-build result.

On the pre-revision provenance, the two-selector continuation produced one
pass and one failure: the identity-document cancel/Reviewed/real-save path
passed, while the Pet-profile Reviewed/real-answer path failed at the immediate
accessibility toggle-value assertion. The Pet-profile selector then passed
unchanged on an immediate retry, including save, completion, relaunch, and
persisted readback. This supports classifying the first failure as an
accessibility-value timing flake rather than an unresolved product-path
failure.

The UI-test-only assertion was changed to wait for the visible production
consequence, `pet-basic-info-home-date-picker`, instead of requiring the
toggle's accessibility value to update immediately. Swift parsing and
`git diff --check` passed, the App + UI test bundle was rebuilt, and the
Pet-profile selector passed again. The rebuilt bundle then also passed the
preventive-health cancel/resume/save/claim path, first care completed through
the normal Home water flow, custom care-plan cancel/save/claim persistence,
and the Memorial mark/cancel/confirm/relaunch/undo lifecycle.

Across the frozen checkpoint and this continuation, 31 distinct formal
selectors have green evidence against unchanged App source. That cumulative
31/119 evidence spans the pre-revision and rebuilt UI-test provenance
identities; it is not an exact-current-build count. Eighty-eight selectors
still have no green evidence anywhere in this campaign. The rebuilt
provenance has five distinct green selectors so far.

Continuation result bundles under `.build/DerivedData/tests/Logs/Test/`:

- `Test-OhanaUITests-2026.07.17_20-07-56-+0200.xcresult`: identity-document
  selector passed; Pet-profile selector failed at the transient accessibility
  toggle-value assertion. This is a mixed bundle, not an all-green artifact.
- `Test-OhanaUITests-2026.07.17_20-12-07-+0200.xcresult`: unchanged
  Pet-profile retry passed.
- `Test-OhanaUITests-2026.07.17_20-15-01-+0200.xcresult`: rebuilt-bundle
  Pet-profile selector passed after the assertion repair.
- `Test-OhanaUITests-2026.07.17_20-17-51-+0200.xcresult`: preventive-health
  cancel/resume/save/claim selector passed.
- `Test-OhanaUITests-2026.07.17_20-20-02-+0200.xcresult`: Home-first water care
  projected into a directly claimable starter task and passed.
- `Test-OhanaUITests-2026.07.17_20-22-08-+0200.xcresult`: custom care-plan
  cancel/save/relaunch/claim selector passed.
- `Test-OhanaUITests-2026.07.17_20-24-23-+0200.xcresult`: Memorial lifecycle
  selector passed.

The rebuilt provenance source hash is
`b0b98799097ca2b3d3d7ed1aa753c573ee4ba41a530410bdb6dd62e113ef1509`;
its contract hash is
`f06221e9b9f76c5642180e672bdfa4af721aa4c740a63530205c133039aa6c77`.

## Second Post-Checkpoint Continuation

The next risk-ranked batches added 84 distinct trusted green selectors without
changing App source. Cumulative trusted campaign coverage is now 115/119, with
4 selectors that have no trusted green evidence in this campaign. This
cumulative total spans several UI-test-only provenance identities and is not an
exact-current-build 115/119 claim. At the end of this second continuation, its
latest rebuilt provenance had 9/9 distinct executed selectors green.

New coverage after the 31-selector continuation includes:

- Human Memorial cancel/confirm/relaunch/undo, active-Human deletion with
  account switching, local-profile privacy switching, and persistent-store
  fail-closed/retry recovery.
- Pet permanent-delete safeguards, basic-info cancel/save readback, hygiene
  repeat-submit blocking, Memorial hiding of live-care entry points, and health
  record cancel/save persistence.
- Calendar manual-event edit/delete, feeding-history backdate entry, Home
  ledger open/close, Coconut reward projection, insufficient-balance blocking,
  unlock spending, and shop spending.
- The complete Plant unlock/create/calendar/care/delete journey, advanced
  reminder disclosure mounting, Settings balance responsiveness, and a Reduce
  Motion Human-first value loop.
- Human record persistence, optional-birthday cancel/reopen/save/claim,
  cross-local-member profile visibility, and delete cancel/wrong-name safety.
- Pet empty-name protection, a second-Free-Pet Personal gate, coat selection
  across Back navigation, active-walk minimize/resume, first-care separation,
  and direct permanent-delete smoke.
- Calendar keyboard accessibility, Pet-only filtering, system feeding-event
  routing, and generic/water/potty/walk/play/weight/health/hygiene manual-title
  routing without false care classification.
- First-release Home/Oasis/Settings reachability, reminder observability, and
  weekly-report Settings routes without competition copy.
- Pet Home detail routes, expanded-card one-tap actions, Feature Hub routes,
  Feeding and Water plan flows, direct Water/Potty records, and Walk summary
  persistence/readback.
- Litter/scoop persistence, repeat-submit blocking, reminder deletion and
  Calendar projection/deletion; Human card, avatar, route, gesture and wishlist
  flows; Pet profile/identity privacy; and Preventive Health reviewed-to-real
  replacement with relaunch and single-claim readback.
- Human extended-module persistence and deletion, plus the remaining Plant
  catalog, detail, Home switcher/quick action, room-stack, Calendar-filter,
  function-menu, long-list and bulk-settings paths.

The manual Calendar CRUD selector first encountered one terminated process and
one unrelated Pet-choice precondition failure, then passed unchanged. The Plant
chain exposed a UI-test helper that gated required sex selection on an optional
coat control; the helper was narrowed to require and tap the sex choice. A
subsequent artifact still used the superseded one-level Calendar route and
correctly stopped in Task Center; the current helper now opens the second-level
Calendar surface. After an additional creation-handoff timeout, the stabilized
selector passed the complete 122.918-second journey. These failed attempts are
retained as diagnostic evidence and are not counted as green selectors.

Continuation artifacts under `.build/DerivedData/tests/Logs/Test/` include:

- `Test-OhanaUITests-2026.07.17_20-28-46-+0200.xcresult` through
  `Test-OhanaUITests-2026.07.17_20-46-57-+0200.xcresult`: 12 distinct new
  selectors passed; the Calendar selector's earlier terminated and failed
  attempts were followed by the passing `20-40-34` artifact.
- `Test-OhanaUITests-2026.07.17_20-48-43-+0200.xcresult`,
  `Test-OhanaUITests-2026.07.17_20-55-05-+0200.xcresult`, and
  `Test-OhanaUITests-2026.07.17_20-58-09-+0200.xcresult`: diagnostic Plant
  failures during helper and route stabilization; none is counted green.
- `Test-OhanaUITests-2026.07.17_21-02-04-+0200.xcresult`: the complete Plant
  selector passed.
- `Test-OhanaUITests-2026.07.17_21-05-12-+0200.xcresult`: three Settings and
  ledger selectors passed.
- `Test-OhanaUITests-2026.07.17_21-08-08-+0200.xcresult`: four Pet, feeding,
  and Reduce Motion selectors passed.
- `Test-OhanaUITests-2026.07.17_21-14-34-+0200.xcresult`: the strengthened
  required-sex-only Plant helper passed the complete Plant chain again.
- `Test-OhanaUITests-2026.07.17_21-16-54-+0200.xcresult`: Human record, Pet
  empty-name, and Pet Calendar-filter selectors passed.
- `Test-OhanaUITests-2026.07.17_21-22-22-+0200.xcresult`: the Calendar keyboard
  selector passed; Walk and Plant reminder selectors exposed two harness
  locator defects. Later old-helper retries are diagnostic only.
- `Test-OhanaUITests-2026.07.17_21-36-39-+0200.xcresult`: rebuilt Walk and Plant
  reminder selectors both passed after the dynamic submenu and bounded
  Settings-scroll repairs. The immediately preceding run changed source while
  executing and was correctly invalidated by the provenance guard.
- `Test-OhanaUITests-2026.07.17_21-39-09-+0200.xcresult`: optional birthday and
  recommended-care/first-care separation selectors passed.
- `Test-OhanaUITests-2026.07.17_21-42-54-+0200.xcresult`: second-Free-Pet
  Personal gate, coat Back-navigation, and cross-local-member profile selectors
  passed.
- `Test-OhanaUITests-2026.07.17_21-44-58-+0200.xcresult`: system feeding-event,
  Pet delete, and Human delete-safeguard selectors passed.
- `Test-OhanaUITests-2026.07.17_21-48-28-+0200.xcresult`: generic, water-title,
  and potty-title Pet-linked manual Calendar selectors passed.
- `Test-OhanaUITests-2026.07.17_21-51-28-+0200.xcresult`: walk-title,
  play-title, weight-title, health-title, and hygiene-title Pet-linked manual
  Calendar selectors passed.
- `Test-OhanaUITests-2026.07.17_21-56-41-+0200.xcresult`: first-release
  reachability, reminder observability, and family weekly-report selectors
  passed.
- `Test-OhanaUITests-2026.07.17_21-59-30-+0200.xcresult`: Pet Home detail,
  expanded-card, and Feature Hub route selectors passed.
- `Test-OhanaUITests-2026.07.17_22-03-37-+0200.xcresult`: Water, Potty, and
  Feeding plan/quick-action selectors passed.
- `Test-OhanaUITests-2026.07.17_22-07-08-+0200.xcresult`: Water-plan Calendar
  projection/deletion and Walk summary readback selectors passed.
- `Test-OhanaUITests-2026.07.17_22-10-40-+0200.xcresult`: all five litter and
  scoop record/plan selectors passed.
- `Test-OhanaUITests-2026.07.17_22-18-20-+0200.xcresult`: Human expanded-card,
  avatar-save, and Home quick-action selectors passed.
- `Test-OhanaUITests-2026.07.17_22-21-37-+0200.xcresult`: Human module-route and
  tap/long-press distinction selectors passed.
- `Test-OhanaUITests-2026.07.17_22-23-49-+0200.xcresult`: all four selectors
  technically passed. Pet profile editor, Body/Personality relaunch, and Pet
  identity privacy/reward evidence are counted. The Member Card birthday
  replacement/reward selector is held out because `relaunchPreservingPersistentState`
  retained an asynchronously reapplied coconut seed, allowing its final balance
  assertion to win a false-green timing race; it requires a harness repair and
  rerun before being counted.
- `Test-OhanaUITests-2026.07.17_22-29-33-+0200.xcresult`: Human wishlist spend
  and Preventive Health replacement/relaunch/single-claim selectors passed.
- `Test-OhanaUITests-2026.07.17_22-34-23-+0200.xcresult` and
  `Test-OhanaUITests-2026.07.17_22-38-08-+0200.xcresult`: Human extended-module
  persistence and deletion selectors passed.
- `Test-OhanaUITests-2026.07.17_22-43-01-+0200.xcresult`: three Plant detail and
  Home interaction selectors passed.
- `Test-OhanaUITests-2026.07.17_22-44-38-+0200.xcresult`: Plant detail and wallet
  selectors passed; the Calendar Plants-filter selector exposed a harness bug
  that queried a Picker option before expanding `add-event-related-entity-picker`.
- `Test-OhanaUITests-2026.07.17_22-50-36-+0200.xcresult`: the repaired Calendar
  Plants-filter selector and five remaining Plant catalog/menu/room-stack/bulk
  settings selectors passed on the rebuilt provenance.
- `Test-OhanaUITests-2026.07.17_22-58-29-+0200.xcresult`: Human-first onboarding
  with production overlays, launch smoke, and launch-performance selectors
  passed on the rebuilt provenance.

At the end of this second continuation, the latest provenance source hash was
`7f66cbd65ac459fac5e4f14d6bb42e7ffb7663ddc42fe7bb585728522d74924f`;
its contract hash is
`628bb173f453515c58b6ac4dc29299f2136652fafc18f1f03655b16583b14d34`.
Result-log retention may rotate older bundles as new runs finish; the names,
selector outcomes, and provenance above preserve the checkpoint ledger.

## Final Post-Checkpoint Continuation

The final four previously uncounted selectors now have trusted green evidence
on the guarded `iPhone 17 Tests` simulator, bringing cumulative campaign
coverage to 119/119 distinct formal selectors. The Cat and Dog long sessions
are synthetic disposable-Simulator journeys, not runs on the pinned Dogfood
user:

1. `OhanaUITests/OhanaUITests/testMemberCardReviewedOptionalThenRealBirthdaySupersedesResolutionAcrossRelaunchAndRewardsOnce`
   passed after the relaunch helper stopped asynchronously reapplying its
   one-shot coconut seed and the UI bundle was rebuilt.
2. `OhanaUITests/OhanaUITests/testPetCatRealUserLongSessionCoversCareHealthCalendarAndBondVault`
   passed a 295.111-second Cat session covering repeat-action protection,
   litter and hygiene branches, health cancel/save, Calendar projection,
   low-balance explanation, and a successful Bond Vault unlock/spend/readback.
3. `OhanaUITests/OhanaUITests/testExistingPetRealUserJourneyWithoutReset`
   passed in 108.358 seconds after route discovery was hardened to close visible
   overlays before reading Home. It reused an existing Cat and Human without a
   reset or hidden seed, persisted water and Calendar activity, read back the
   Bond Vault balance, relaunched, and found the Cat still present.
4. `OhanaUITests/OhanaUITests/testPetDogRealUserLongSessionCoversWalkMemorialEditAndDeleteSafeguards`
   passed in 154.584 seconds. It covered a completed walk and relaunch readback,
   Basic Info cancel/save, Memorial cancel/confirm/undo, wrong-name deletion
   blocking, deletion cancellation, exact-name permanent deletion, and a
   responsive post-delete Home surface.

The Human persistence and deletion selectors were also strengthened and rerun.
They now require positive post-relaunch readback of the saved metric, 45-minute
workout, hospital report and summary, wishlist state, and positive empty states
after deleting the created metric, workout, report, and note. These quality
reruns do not increase the distinct-selector total.

The corrected Member Card rerun passed and is counted above, but Xcode result
retention rotated its bundle before final reconciliation, so its exact artifact
name is unavailable. The earlier technically passing false-green artifact is
not substituted for the corrected rerun.

Final continuation result bundles under `.build/DerivedData/tests/Logs/Test/`
include:

- `Test-OhanaUITests-2026.07.17_23-16-03-+0200.xcresult`: strengthened Human
  deletion journey passed, 1/1.
- `Test-OhanaUITests-2026.07.17_23-22-44-+0200.xcresult`: strengthened Human
  persistence/readback journey passed, 1/1.
- `Test-OhanaUITests-2026.07.17_23-28-01-+0200.xcresult`: Cat long session
  passed, 1/1.
- `Test-OhanaUITests-2026.07.17_23-33-18-+0200.xcresult` and
  `Test-OhanaUITests-2026.07.17_23-35-35-+0200.xcresult`: existing-user
  discovery skipped after covered-route state produced a false Home signal;
  these diagnostic attempts are not counted as passes.
- `Test-OhanaUITests-2026.07.17_23-37-27-+0200.xcresult`: repaired existing-user
  no-reset journey passed, 1/1 with 0 skips or failures.
- `Test-OhanaUITests-2026.07.17_23-39-30-+0200.xcresult`: Dog long session
  passed, 1/1 with 0 skips or failures.
- `Test-OhanaUITests-2026.07.17_23-52-07-+0200.xcresult`: focused Walk-card
  minimize/resume/stop journey passed, 1/1 in 59.140 seconds.

The latest rebuilt provenance therefore has 3/3 distinct executed selectors
green: the existing-user no-reset journey, Dog long session, and focused Walk
card rerun. Its source hash is
`0f35961adee8706169324916eacc8d681c9b6b9a0b302cc63a5094ae1b54e33a`;
its contract hash is
`455ed8a5eadf14a54995eb0faf64a6021809f9fc027e3078880d1428019ba42d`.
The formal manifest was re-audited as 119 rows, 119 unique selectors, and zero
duplicates or malformed rows.

Across compatible UI-test-only provenance identities, all 119/119 distinct
formal selectors now have trusted green evidence against unchanged App source.
This is cumulative campaign evidence, not an exact-current-build 119/119 result
or a single-run full-suite claim. The observed functional failures and skips
were narrowed to over-specific assertions, stale route assumptions, and overlay
normalization in the UI harness; no functional product-source defect was
established in the final continuation.

The Dog result bundle reported a non-failing CoreLocation runtime warning that
a method capable of UI unresponsiveness was invoked on the main thread and that
authorization should instead be read after
`locationManagerDidChangeAuthorization`. Its timestamp coincides with live Walk
route startup. The focused Walk-card rerun passed but reproduced the same
warning at the same transition, so it is not treated as one-run noise. The
result bundles contain no stack or source location, and source search finds no
direct `locationServicesEnabled()` call; attribution between the App's live
Map/location lifecycle and MapKit/CoreLocation remains open under
TFU-20260629-004. This warning does not invalidate the functional passes, but it
does prevent a clean runtime/performance claim for live Walk startup.

The pinned Dogfood user was not launched, reset, seeded, uninstalled, or
directly edited; all automated execution targeted only the guarded
`iPhone 17 Tests` simulator.

## Post-UI Unit/Release Continuation

The current Human-first/D28 focused Unit/Integration lane selected nine suites
covering onboarding coordination, handoff responsiveness, starter gift,
household journey, Task Center snapshot/guide, reset, growth unlock, and
compatibility. It executed 97/97 tests with zero failures or skips. The result
bundle is
`.build/DerivedData/tests/Logs/Test/Test-OhanaUnitTests-2026.07.17_23-58-13-+0200.xcresult`.
This is focused current-source evidence, not a current full-Unit claim.

`scripts/release-hardening-check.sh --static-only` passed its early shell,
whitespace, fixture/self-test, CI-policy, 119-selector exactly-once manifest,
runtime-guardrail, and architecture checks, then stopped at the production
complexity ratchet. `TaskCenterRouteContainer.swift` adds a
`type_body_length` hotspot with maximum 918, and
`TaskCenterRouteDataActor.load` adds a `function_body_length` hotspot with
maximum 124. Because the gate is fail-fast, later static sections were not
reached and this is not a complete release-hardening pass.

Every hidden tail check was then executed directly in its original full-scope,
read-only form. Economy boundaries, member lifecycle, derived-state lifecycle,
shared-care metadata, release data safety, localization, governance manifests,
agent-skill governance, resource integrity, smoothness, route first-frame,
Gitleaks, and Git-size checks passed. Resource integrity retained one advisory:
`Assets.xcassets` is 65.93 MiB, above its 60 MiB review target but below the
70 MiB hard limit. V4 UI failed on five findings; inspection classified the two
30-point room-stack radii and one 12-point Pet edit chip radius as three real
hits across two token-drift causes, while the room-stack shadow/black tint are
intentional depth effects that need scoped allow comments. Accessibility failed
on eight source-pattern hits, but inspection found every icon either hidden by
the following chained modifier or owned by a labeled parent Button. They are
mechanical false positives, not evidence of an unlabeled runtime control, but
the gate remains red until narrow allows or a scanner/fixture repair land.

The optimized Release compiler lane subsequently succeeded at `-O` for an
arm64 + x86_64 generic iOS Simulator product and verified that Settings
DesignLab is excluded. The unsigned app is
`.build/DerivedData/release/Build/Products/Release-iphonesimulator/Ohana.app`
(399 MiB; binary SHA-256
`96e66106ad0923746cc623d1fab2cc88b2c64fe17eb4b7ca518a72d1998758f9`).
That compile does not waive the red static gate. It also reported three
LaunchMark image sets with two unassigned conflict-copy children each, Swift 6
actor-isolation diagnostics in starter-journey/Task Center/Home dial code, and
smaller existing unused/unreachable/default and AppIntents metadata warnings.
The stable Release cache is 2.6 GiB and 47 GiB remained free, so no cleanup or
Dogfood mutation was needed.

Disk inspection also explains the recurring growth: `.git` is about 6.0 GiB
and contains 244 invalid conflict-copy object filenames totaling 4.99 GiB.
Twelve are six exact 804 MiB duplicates plus six exact 48 MiB duplicates of
valid packfiles; the remaining 232 are ignored loose-object conflict copies.
The three LaunchMark image sets likewise contain byte-identical `2`/`3`
manifest and SVG copies, which cause the asset-catalog warnings. No Git garbage,
tracked duplicate, cache, or user file was deleted during this continuation.

## Post-Repair Static And Dogfood Acceptance

With explicit cleanup authorization, the 244 invalid spaced Git-object copies
and 12 byte-identical untracked/ignored LaunchMark conflict children were
removed. This reclaimed 5,360,891,808 bytes, reduced `.git` from about 6.0 GiB
to 1.0 GiB, and removed the asset-catalog duplicate-child warnings. The stable
tests, dogfood, and release DerivedData roots were preserved. `git fsck --full
--no-dangling` passed, the final Git-size audit reports zero garbage, and 48 GiB
remained free after the final builds.

The two Task Center complexity hotspots were decomposed without moving
persistent business facts into views. The real V4 geometry-token findings were
centralized, and the intentional card-stack effects plus mechanically
false-positive accessibility patterns received scoped, fixture-covered audit
dispositions. Five focused suites then executed 57/57 tests with no failures.
After the final warning-only `nonisolated` annotation, the service suite
executed 15/15 with artifact
`.build/DerivedData/tests/Logs/Test/Test-OhanaUnitTests-2026.07.18_01-05-51-+0200.xcresult`.

The final `scripts/release-hardening-check.sh --static-only` run passed from
start to finish. Complexity scanned 1,025 production files with 74
grandfathered declarations and no new/growing hotspot. V4 UI, accessibility,
smoothness, route, runtime, architecture, economy, lifecycle, data-safety,
localization, governance, resource, secret, and Git-size checks passed.
Resource integrity retained only the advisory `Assets.xcassets` size of
65.92 MiB, above its 60 MiB review target and below its 70 MiB hard limit.

`scripts/build-release-fast.sh` produced the final 399 MiB unsigned optimized
Simulator app with binary SHA-256
`fca8e18e17676e13a55cb20430fa3e136e6b1b50db9e8a478039410db3fe0644`.
The batch's one guarded `scripts/run-dogfood-simulator.sh` overlay then built and
installed the exact 230 MiB WMO Release app, binary SHA-256
`2bd309344673a1243e93e2fdc9463e398a62609629c93f920b990900e531810d`,
without erase, uninstall, seed, XCTest, direct store/defaults writes, or reset.

Normal product UI on the pinned synthetic user proved that the first-Pet
profile task opens the card-style guided flow, opens its real nested editor,
distinguishes Cancel from persistence, and returns to the guide. Choosing
`Not sure yet` advanced the guide from question 1 to question 2 without
granting the +100 reward. After a normal stop/relaunch, the guide resumed at
`petBodyProfile` with all four resolution branches still available and the
coconut balance still 162. Final read-only status reported `sealed/match`,
ready, 1 Human, 1 Pet, 17 ledger facts, and zero test artifacts. The fresh
receipt was recorded as `overlay=pass` at
`2026-07-17T23:23:41+00:00`.

This closes TFU-20260715-002 at the repository and Simulator level. It does not
claim a current full-Unit replay, a single-provenance 119-selector replay, a
signed Archive, or physical-device Storefront, permission, notification,
background, energy, HealthKit, and assistive-technology acceptance.

## Covered Branch Families

- Immediate Pet creation and explicit starter-gift claim.
- Deferred Pet creation, relaunch persistence, task resume, cancellation, and
  later completion without preserving an unsaved draft.
- Real `Skip for now`, Back, cancel-edit, close, reopen, and previous/next
  navigation paths.
- `Unknown`, `Not applicable`, `Prefer not to say`, and `Reviewed` answers.
- Private/placeholder answers superseded by real avatar, birthday, emergency
  contact, preventive-health record, and daily-care settings.
- Relaunch persistence and one-time reward/claim behavior.
- Deleted/Memorial calendar routing, exact-name permanent deletion, and Plant
  room-stack handoff.
- Nested preventive-health and custom-care editors keep cancellation distinct
  from persistence, completion, and explicit reward claim.
- A real Home care record projects into the unopened starter journey without
  duplicating either the care reward or task reward.
- Memorial marking and undo both preserve cancel/confirm semantics across
  relaunch, Home visibility, and roster readback.
- Memorial state removes live-care entry points; local-profile privacy remains
  visible to the selected Human without inventing a remote-account boundary.
- Economy paths cover reward projection, insufficient balance, unlock spend,
  shop spend, ledger presentation, and a responsive Settings apply action.
- Plant creation, calendar projection, care, delete/undo/permanent delete, Pet
  backdated feeding and health persistence, and Reduce Motion interaction.

## Next Risk-Ranked Work

1. Complete Free / Personal Storefront, quota, entitlement lifecycle,
   nine-language commerce copy, Sandbox, second-device restore, and signed
   purchase acceptance under TFU-20260715-003.
2. Complete the remaining signed-device permissions,
   background, energy, HealthKit, notification, and assistive-technology
   acceptance. Continue using the persistent Dogfood user only for relevant
   normal-UI existing-data journeys, never destructive or empty-state scenarios.
3. Attribute the reproducible live-Walk CoreLocation main-thread warning with a
   focused stack/profile or signpost and prove the repaired or platform-owned
   path without a measured startup regression.
4. Disposition the five remaining WMO Release diagnostics: two Home-dial
   isolation warnings, one unused-result warning, and two unreachable-default
   warnings. The standard App Intents no-dependency metadata notice remains
   informational.

## Boundaries Not Proven Here

- At the frozen checkpoint, 94 selectors lacked green evidence from that exact
  build. That historical exact-build count remains unchanged; after compatible
  UI-test-only continuations, zero formal selectors lack trusted green evidence
  anywhere in this cumulative campaign.
- A single-provenance or single-run 119-selector replay.
- A current full Unit suite; the 97/97 Human-first/D28 checkpoint and final
  57/57 plus 15/15 repair evidence are risk-targeted rather than a replay of
  every Unit selector.
- A signed Release Archive or physical-device run; the current successful
  Release product is an unsigned dual-architecture Simulator build.
- A clean live-Walk runtime/performance claim; two passing runs reproduce the
  unresolved CoreLocation main-thread warning at route startup.
- Physical-device permissions, notifications, background behavior, energy,
  HealthKit, Storefront, purchase lifecycle, or assistive-technology traversal.
- Destructive empty-state, restore, migration, reset, or deletion scenarios on
  the pinned Dogfood device.

The pinned Dogfood user was overlaid once through the guarded Release launcher
and exercised only through normal product UI. It was not reset, seeded,
uninstalled, or directly edited. Its natural-day accumulation remains a
separate acceptance lane and was not artificially advanced for this checkpoint.
