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

preferred_runtime_version="${OHANA_TEST_RUNTIME_VERSION:-}"
preferred_device_type_name="${OHANA_TEST_DEVICE_TYPE_NAME:-iPhone 17}"
selection="$(
  xcrun simctl list runtimes available -j | python3 -c '
import json
import re
import sys

preferred_version = sys.argv[1]
preferred_device = sys.argv[2]
payload = json.load(sys.stdin)
candidates = []
for runtime in payload.get("runtimes", []):
    if runtime.get("platform") != "iOS" or not runtime.get("isAvailable", True):
        continue
    version_text = runtime.get("version", "")
    version_key = tuple(int(part) for part in re.findall(r"\d+", version_text))
    candidates.append((version_key, version_text, runtime))
if not candidates:
    raise SystemExit("No available iOS Simulator runtime.")

preferred = [row for row in candidates if row[1] == preferred_version]
if preferred_version and not preferred:
    raise SystemExit(f"Requested iOS runtime {preferred_version} is unavailable.")
selected = preferred[0] if preferred else max(candidates)
runtime = selected[2]
iphone_types = [
    row for row in runtime.get("supportedDeviceTypes", [])
    if row.get("productFamily") == "iPhone"
]
if not iphone_types:
    raise SystemExit("Selected runtime has no supported iPhone type.")

device_preferences = [
    preferred_device,
    "iPhone 17",
    "iPhone 16",
    "iPhone 16e",
    "iPhone 15",
    "iPhone 14",
    "iPhone SE (3rd generation)",
]
device = None
for name in device_preferences:
    device = next((row for row in iphone_types if row.get("name") == name), None)
    if device:
        break
if device is None:
    device = iphone_types[0]

print("\t".join((
    runtime.get("identifier", ""),
    runtime.get("version", ""),
    device.get("identifier", ""),
    device.get("name", ""),
)))
' "${preferred_runtime_version}" "${preferred_device_type_name}"
)"
IFS=$'\t' read -r runtime_id runtime_version device_type_id device_type_name \
  <<< "${selection}"
if [[ -z "${runtime_id}" || -z "${device_type_id}" ]]; then
  echo "Could not resolve a compatible local test runtime and iPhone type." >&2
  exit 66
fi

created_udid="$(xcrun simctl create "${OHANA_TEST_SIMULATOR_NAME_FIXED}" "${device_type_id}" "${runtime_id}")"
ohana_assert_test_simulator_udid "${created_udid}"

echo "Created disposable Test Simulator: ${OHANA_TEST_SIMULATOR_NAME_FIXED} (${created_udid})"
echo "Runtime: ${runtime_version} (${runtime_id})"
echo "Device type: ${device_type_name} (${device_type_id})"
echo "Dogfood remains protected: ${dogfood_udid}"
