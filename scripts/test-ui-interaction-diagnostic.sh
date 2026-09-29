#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  echo "Usage: scripts/test-ui-interaction-diagnostic.sh <crew|home-date> [--print]" >&2
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
  crew)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuOpensHumanCreation
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuWithAnimationsOpensHumanCreation
      OhanaUITests/OhanaUITests/testDiagnosticCrewMenuWithoutTouchTraceOpensHumanCreation
      OhanaUITests/OhanaUITests/testHumanSettingsInlineSwitcherHidesLocalPrivacyControls
      OhanaUITests/OhanaUITests/testDeletingActiveHumanRequiresAccountSwitchAndPersistsAcrossRelaunch
    )
    ;;
  home-date)
    selectors=(
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateWithAnimationsRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateWithoutTouchTraceRevealsPicker
      OhanaUITests/OhanaUITests/testDiagnosticPetHomeDateWithoutPreToggleAXRevealsPicker
      OhanaUITests/OhanaUITests/testPetProfileEditorCancelCloseAndDateSaveCompletesLifeStage
      OhanaUITests/OhanaUITests/testPetProfileReviewedThenRealAnswersPersistAcrossRelaunch
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
