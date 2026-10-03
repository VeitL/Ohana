#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  echo "Usage: scripts/test-ui-interaction-diagnostic.sh <unresolved-controls-context-launch-onboarding|unresolved-controls-context-pet-care-hygiene|unresolved-controls-context-pet-long-session|unresolved-controls-observed|unresolved-controls-control|permission-policy|water-plan-control|ci-repair-preflight|ci-preflight-permissions|ci-preflight-interactions|historical-failures|regression-failures|current-failures|keyboard-dismissal|crew|crew-long|crew-onboarding|home-date|home-date-long|home-date-control|plant-reminder|zen-private> [--print]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi
scenario="$1"
print_only=0
if [[ $# -eq 2 ]]; then
  if [[ "$2" != "--print" ]]; then
    usage
    exit 2
  fi
  print_only=1
fi

case "${scenario}" in
  unresolved-controls-context-launch-onboarding|unresolved-controls-context-pet-care-hygiene|unresolved-controls-context-pet-long-session)
    # Preserve every original group prerequisite and XCTest lexical position.
    # Only its previously failed case opts into input observation. This is
    # group-context diagnosis, never a replacement for the full 132-case gate.
    group="${scenario#unresolved-controls-context-}"
    selectors=()
    observed_cases=0
    while IFS=$'\t' read -r shard selector; do
      [[ "${shard}" == "${group}" ]] || continue
      case "${selector}" in
        OhanaUITests/OhanaUITests/testExistingPetRealUserJourneyWithoutReset|OhanaUITests/OhanaUITests/testPetScoopPlanCalendarEventAppearsAndDeletesFromQuickCareDetail|OhanaUITests/OhanaUITests/testSettingsNotificationCategoriesAndPlantDetailsUseSeparatePages)
          selector="${selector}WithReceivedInputTrace"
          observed_cases=$((observed_cases + 1))
          ;;
      esac
      selectors+=("${selector}")
    done < "${SCRIPT_DIR}/ui-test-shards.tsv"
    if [[ "${observed_cases}" != "1" || ${#selectors[@]} -eq 0 ]]; then
      echo "Context diagnosis requires exactly one observed case in an existing complete group." >&2
      exit 2
    fi
    ;;
  unresolved-controls-control)
    # Unchanged original journeys on a fresh governed Tests environment.
    selectors=(
      OhanaUITests/OhanaUITests/testExistingPetRealUserJourneyWithoutReset
      OhanaUITests/OhanaUITests/testPetScoopPlanCalendarEventAppearsAndDeletesFromQuickCareDetail
      OhanaUITests/OhanaUITests/testSettingsNotificationCategoriesAndPlantDetailsUseSeparatePages
    )
    ;;
  unresolved-controls-observed)
    # The same journeys with opt-in received-input and actual setter receipts.
    # A diagnostic pass cannot replace any original full-run failure.
    selectors=(
      OhanaUITests/OhanaUITests/testExistingPetRealUserJourneyWithoutResetWithReceivedInputTrace
      OhanaUITests/OhanaUITests/testPetScoopPlanCalendarEventAppearsAndDeletesFromQuickCareDetailWithReceivedInputTrace
      OhanaUITests/OhanaUITests/testSettingsNotificationCategoriesAndPlantDetailsUseSeparatePagesWithReceivedInputTrace
    )
    ;;
  ci-preflight-permissions)
    # Original permission-blocked journeys plus the original Feed smoke. This
    # is focused diagnostic evidence, never full 132-case acceptance.
    selectors=(
      OhanaUITests/OhanaUITests/testFeedingManualPlanAndHomeQuickActionSmoke
      OhanaUITests/OhanaUITests/testFirstCareCompletedByHomeWaterBeforeOpeningJourneyBecomesClaimable
      OhanaUITests/OhanaUITests/testPetExpandedCardShowsQuickActionsWithoutSecondTap
      OhanaUITests/OhanaUITests/testPetFeatureHubDailyAndHealthRoutesOpenAndCancel
      OhanaUITests/OhanaUITests/testPetHomeQuickActionDetailRoutesOpenAndCancel
      OhanaUITests/OhanaUITests/testPetHomeWalkCardMinimizesToFloatingBubble
      OhanaUITests/OhanaUITests/testPetPottyRecordPersistsFromQuickCareDetail
      OhanaUITests/OhanaUITests/testPetWalkQuickActionPersistsAndSummaryReadback
      OhanaUITests/OhanaUITests/testPetWaterCareRewardAppearsInBondVaultLedger
      OhanaUITests/OhanaUITests/testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail
      OhanaUITests/OhanaUITests/testPetWaterRecordPersistsFromQuickCareDetail
      OhanaUITests/OhanaUITests/testStarterCustomCarePlanCancelAndSaveRemainSeparatedAcrossRelaunch
      OhanaUITests/OhanaUITests/testStarterRecommendedCarePlanAndFirstCareCancelResumeClaimSeparation
    )
    ;;
  ci-preflight-interactions)
    selectors=(
      OhanaUITests/OhanaUITests/testCoconutBalanceButtonOpensAndClosesLedgerFromHome
      OhanaUITests/OhanaUITests/testDeletedPetCalendarEventDoesNotOpenLiveCareRoute
      OhanaUITests/OhanaUITests/testHumanExtendedModuleDeletesDisappearFromCurrentUI
      OhanaUITests/OhanaUITests/testHumanPermanentDeleteWithExactNamePersistsAcrossRelaunch
      OhanaUITests/OhanaUITests/testManualCalendarEventRowOpensDetailEditsAndDeletes
      OhanaUITests/OhanaUITests/testPetBasicInfoEditCancelDoesNotPersistAndSaveDoes
      OhanaUITests/OhanaUITests/testPetBasicInfoEmptyNameSaveKeepsOriginalName
      OhanaUITests/OhanaUITests/testPetCoconutShopEffectPurchaseSpendsHumanBalanceFromFunctionMenu
      OhanaUITests/OhanaUITests/testPetLitterPlanDeleteClearsSavedReminderFromQuickCareDetail
      OhanaUITests/OhanaUITests/testSettingsNotificationCategoriesAndPlantDetailsUseSeparatePages
      OhanaUITests/OhanaUITests/testSystemGeneratedPetCalendarFeedEventRowOpensQuickFeedDetail
      OhanaUITests/OhanaUITests/testZenFreshInstallCreatesOnlyAHumanAndOpensTheThreeTabShell
    )
    ;;
  water-plan-control)
    # Passive action/commit observation. Both journeys use the same normal UI
    # and preserve Calendar save/delete readback; only preexisting state differs.
    selectors=(
      'OhanaUITests/OhanaUITests/testDiagnosticWaterPlanAfterStarterWithPassiveStateTrace()'
      'OhanaUITests/OhanaUITests/testDiagnosticWaterPlanMatureHouseholdWithPassiveStateTrace()'
    )
    ;;
  ci-repair-preflight)
    # Compare passive observation with the unchanged original Water journey.
    # Zen uses its evidence-backed, exact-menu interaction repair. No result
    # from this four-case comparison is a complete release acceptance.
    selectors=(
      'OhanaUITests/OhanaUITests/testDiagnosticWaterPlanAfterStarterWithPassiveStateTrace()'
      'OhanaUITests/OhanaUITests/testDiagnosticWaterPlanMatureHouseholdWithPassiveStateTrace()'
      OhanaUITests/OhanaUITests/testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail
      OhanaUITests/OhanaUITests/testZenFreshInstallCreatesOnlyAHumanAndOpensTheThreeTabShell
    )
    ;;
  permission-policy)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticAuthorizationMatcherRejectsUnrelatedPrompts
    )
    ;;
  current-failures)
    # Original failed journeys; this focused set is not 132-case acceptance.
    selectors=(
      OhanaUITests/OhanaUITests/testFamilyWeeklyReportOpensFromDebugSettingsWithoutCompetitionCopy
      OhanaUITests/OhanaUITests/testSettingsLanguageSelectionSurvivesImmediateCloseAndRelaunch
      OhanaUITests/OhanaUITests/testZenFreshInstallCreatesOnlyAHumanAndOpensTheThreeTabShell
      OhanaUITests/OhanaUITests/testHumanHealthConditionsCreateObservationEditDeleteAndPersistAcrossRelaunch
    )
    ;;
  keyboard-dismissal)
    # Original journeys cover native keyboard Done and the clipped toolbar Done.
    selectors=(
      OhanaUITests/OhanaUITests/testHumanSettingsInlineSwitcherHidesLocalPrivacyControls
      OhanaUITests/OhanaUITests/testPetDailyCareNotApplicableThenRealSetupSupersedesResolutionAcrossRelaunch
    )
    ;;
  crew)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuOpensHumanCreation
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuWithAnimationsOpensHumanCreation
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuWithoutTouchTraceOpensHumanCreation
      OhanaUITests/OhanaUITests/testDeletingActiveHumanRequiresAccountSwitchAndPersistsAcrossRelaunch
    )
    ;;
  crew-long)
    selectors=(
      OhanaUITests/OhanaUITests/testDeletingActiveHumanRequiresAccountSwitchAndPersistsAcrossRelaunch
    )
    ;;
  crew-onboarding)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuAfterRealOnboardingOpensHumanCreation
    )
    ;;
  historical-failures|regression-failures)
    selectors=(
      OhanaUITests/OhanaUITests/testDeletingActiveHumanRequiresAccountSwitchAndPersistsAcrossRelaunch
      OhanaUITests/OhanaUITests/testMemberCardPrivateAppearanceSurvivesRelaunchAndZenRoundTrip
      OhanaUITests/OhanaUITests/testPetDailyCareNotApplicableThenRealSetupSupersedesResolutionAcrossRelaunch
      OhanaUITests/OhanaUITests/testPetDailyCareUnknownCancelThenRealSetupSurvivesRelaunchWithoutFabricationAndRewardsOnce
      OhanaUITests/OhanaUITests/testPetIdentityNotApplicableResumesThenEmergencyContactSaveCompletes
      OhanaUITests/OhanaUITests/testPetIdentityPrivateDocumentsAndPrivateEmergencyPersistAcrossRelaunchWithoutFabricationAndRewardsOnce
      OhanaUITests/OhanaUITests/testPetProfileReviewedThenRealAnswersPersistAcrossRelaunch
      OhanaUITests/OhanaUITests/testStarterPreventiveHealthPrivateAnswerSurvivesRelaunchWithoutFabricatedRecordAndRewardsOnce
    )
    if [[ "${scenario}" == "regression-failures" ]]; then
      selectors+=(
        OhanaUITests/OhanaUITests/testHumanModuleRoutesOpenFromCurrentUI
        OhanaUITests/OhanaUITests/testHumanSettingsInlineSwitcherHidesLocalPrivacyControls
        OhanaUITests/OhanaUITests/testHouseholdInsightsKeepAllSixTabsVisibleAtLevelSix
        OhanaUITests/OhanaUITests/testImportedLabFactsStayReadableAndEditableAfterDowngradeToFree
        OhanaUITests/OhanaUITests/testHumanOnlyHouseholdOpensUnifiedAchievementsFromAllFeatures
      )
    fi
    ;;
  home-date)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateWithAnimationsRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateBaselineWithoutTouchTraceRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateWithoutPreToggleAXRevealsPicker
      OhanaUITests/OhanaUITests/testPetProfileEditorCancelCloseAndDateSaveCompletesLifeStage
      OhanaUITests/OhanaUITests/testPetProfileReviewedThenRealAnswersPersistAcrossRelaunch
    )
    ;;
  home-date-long)
    selectors=(
      OhanaUITests/OhanaUITests/testPetProfileEditorCancelCloseAndDateSaveCompletesLifeStage
    )
    ;;
  home-date-control)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateBaselineWithoutTouchTraceRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateWithPassiveControlStateTraceRevealsPicker
    )
    ;;
  zen-private)
    selectors=(
      OhanaUITests/OhanaUITests/testMemberCardPrivateAppearanceSurvivesRelaunchAndZenRoundTrip
    )
    ;;
  plant-reminder)
    selectors=(
      OhanaUITests/PlantModuleUITests/testDiagnosticPlantReminderRoundTripWithTouchTrace
    )
    ;;
  *)
    usage
    exit 2
    ;;
esac

cd "${REPO_ROOT}"
scripts/audit-ui-test-shards.sh
if [[ "${print_only}" == "1" ]]; then
  printf '%s\n' "${selectors[@]}"
  exit 0
fi

args=(--keep-success-result)
for selector in "${selectors[@]}"; do
  args+=(--only-testing "${selector}")
done
scripts/xcode-test.sh "${args[@]}"
