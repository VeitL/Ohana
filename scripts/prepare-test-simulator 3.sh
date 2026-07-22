#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

STATUS_ONLY=0
if [[ "${1:-}" == "--status" ]]; then
  STATUS_ONLY=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: scripts/prepare-test-simulator.sh [--status]" >&2
  exit 2
fi

dogfood_udid="$(ohana_require_dogfood_pin)"
test_udid="$(ohana_resolve_simulator_by_name "${OHANA_TEST_SIMULATOR_NAME_FIXED}" || true)"

if [[ -n "${test_udid}" ]]; then
  ohana_assert_test_simulator_udid "${test_udid}"
  metadata="$(ohana_simulator_metadata "${test_udid}")"
  echo "Test Simulator ready: ${metadata}"
  echo "  UDID: ${test_udid}"
  echo "  Dogfood protected: ${dogfood_udid}"
  exit 0
fi

if [[ "${STATUS_ONLY}" == "1" ]]; then
  echo "Test Simulator missing: ${OHANA_TEST_SIMULATOR_NAME_FIXED}" >&2
  echo "Dogfood remains protected: ${dogfood_udid}" >&2
  exit 66
fi

ohana_require_build_disk_space

device_type_id="$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys

payload = json.load(sys.stdin)
for row in payload.get("devicetypes", []):
    if row.get("name") == "iPhone 17":
        print(row.get("identifier", ""))
        raise SystemExit(0)
raise SystemExit(1)
')"

runtime_id="$(xcrun simctl list runtimes available -j | python3 -c '
import json, re, sys

payload = json.load(sys.stdin)
candidates = []
for row in payload.get("runtimes", []):
    if row.get("platform") != "iOS" or not row.get("isAvailable", True):
        continue
    version = [int(part) for part in re.findall(r"\d+", row.get("version", ""))]
    candidates.append((version, row.get("identifier", "")))
if not candidates:
    raise SystemExit(1)
candidates.sort()
print(candidates[-1][1])
')"

created_udid="$(xcrun simctl create "${OHANA_TEST_SIMULATOR_NAME_FIXED}" "${device_type_id}" "${runtime_id}")"
ohana_assert_test_simulator_udid "${created_udid}"

echo "Created disposable Test Simulator: ${OHANA_TEST_SIMULATOR_NAME_FIXED} (${created_udid})"
echo "Runtime: ${runtime_id}"
echo "Dogfood remains protected: ${dogfood_udid}"
