#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/reset-test-simulator.sh --erase --confirm
  scripts/reset-test-simulator.sh --recreate --confirm

Destructive Simulator maintenance is restricted to the exact device named
"iPhone 17 Tests". The pinned Dogfood UDID is always rejected.
USAGE
}

mode=""
confirmed=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --erase)
      mode="erase"
      ;;
    --recreate)
      mode="recreate"
      ;;
    --confirm)
      confirmed=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "${mode}" || "${confirmed}" != "1" ]]; then
  usage >&2
  echo "A destructive mode and --confirm are both required." >&2
  exit 2
fi

test_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"
if [[ -z "${test_udid}" ]]; then
  echo "No '${OHANA_TEST_SIMULATOR_NAME_FIXED}' device exists." >&2
  exit 66
fi
ohana_assert_test_simulator_udid "${test_udid}"

if [[ "${mode}" == "recreate" ]]; then
  # Verify that creating the replacement is safe before deleting the current
  # test phone. Low disk must never turn a rebuild into a missing device.
  ohana_require_build_disk_space
fi

echo "Destructive target verified: ${OHANA_TEST_SIMULATOR_NAME_FIXED} (${test_udid})"
xcrun simctl shutdown "${test_udid}" 2>/dev/null || true

if [[ "${mode}" == "erase" ]]; then
  xcrun simctl erase "${test_udid}"
  echo "Erased disposable Test Simulator: ${test_udid}"
  exit 0
fi

xcrun simctl delete "${test_udid}"
"${REPO_ROOT}/scripts/prepare-test-simulator.sh"
