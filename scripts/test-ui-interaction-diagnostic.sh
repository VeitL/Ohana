#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  echo "Usage: scripts/test-ui-interaction-diagnostic.sh <historical-failures|regression-failures|current-failures|keyboard-dismissal|crew|crew-long|crew-onboarding|home-date|home-date-long|home-date-control|plant-reminder|zen-private> [--print]" >&2
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
