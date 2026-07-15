#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

export SCHEME="${SCHEME:-OhanaUITests}"

MODE="${1:-smoke}"

case "${MODE}" in
  smoke)
    exec scripts/test-simulator.sh \
      '-only-testing:OhanaUITests/OhanaUITests/testHumanFirstOnboardingCreatesPetClaimsGiftAndUnlocksOasis'
    ;;
  first-pet-stability)
    exec scripts/test-simulator.sh \
      -test-iterations 10 \
      -test-repetition-relaunch-enabled YES \
      '-only-testing:OhanaUITests/OhanaUITests/testHumanFirstOnboardingCreatesPetClaimsGiftAndUnlocksOasis'
    ;;
  full)
    exec scripts/test-ui-nightly.sh
    ;;
  *)
    echo "Usage: scripts/test-ui-release-smoke.sh [smoke|first-pet-stability|full]" >&2
    exit 2
    ;;
esac
