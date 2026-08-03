#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

export SCHEME="${SCHEME:-OhanaUITests}"

MODE="${1:-smoke}"

case "${MODE}" in
  smoke)
    exec scripts/xcode-test.sh \
      --only-testing 'OhanaUITests/OhanaUITests/testHumanFirstOnboardingWithProductionOverlaysCompletes'
    ;;
  first-pet-stability)
    export OHANA_ALLOW_TEST_REPETITION=1
    exec scripts/xcode-test.sh \
      --only-testing 'OhanaUITests/OhanaUITests/testHumanFirstOnboardingWithProductionOverlaysCompletes' \
      -- \
      -test-iterations 10 \
      -test-repetition-relaunch-enabled YES
    ;;
  full)
    exec scripts/test-ui-nightly.sh
    ;;
  *)
    echo "Usage: scripts/test-ui-release-smoke.sh [smoke|first-pet-stability|full]" >&2
    exit 2
    ;;
esac
