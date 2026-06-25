#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REQUIRED_SIMULATOR_NAME="${OHANA_SIMULATOR_NAME:-iPhone 17}"
BRIEF=0

if [[ "${1:-}" == "--brief" ]]; then
  BRIEF=1
fi

TMP_ROOT="${TMPDIR:-/tmp}"
TMP_ROOT="${TMP_ROOT%/}"
SIMCTL_JSON="${TMP_ROOT}/ohana-simctl-devices.$$.json"
SIMCTL_ERR="${TMP_ROOT}/ohana-simctl-devices.$$.err"

cleanup() {
  rm -f "${SIMCTL_JSON}" "${SIMCTL_ERR}"
}
trap cleanup EXIT

section() {
  if [[ "${BRIEF}" != "1" ]]; then
    printf '\n== %s ==\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

print_toolchain() {
  section "Toolchain"
  xcodebuild -version || true
  printf 'xcode-select: %s\n' "$(xcode-select -p 2>/dev/null || printf '<unavailable>')"
  printf 'simctl: %s\n' "$(xcrun --find simctl 2>/dev/null || printf '<unavailable>')"
}

print_simulator_app_state() {
  section "Simulator app"
  local simulator_app="/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
  local simulator_binary="${simulator_app}/Contents/MacOS/Simulator"
  if [[ -x "${simulator_binary}" ]]; then
    printf 'ok: %s\n' "${simulator_binary}"
  else
    printf 'missing executable: %s\n' "${simulator_binary}"
  fi
}

print_recovery_steps() {
  section "Recovery"
  cat <<'EOF'
Run these from a normal macOS Terminal, not from a sandboxed Codex shell:
  open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
  xcrun simctl shutdown all
  xcrun simctl list devices available

If simctl still reports CoreSimulatorService, simdiskimaged, or connection invalid:
  1. Quit Xcode and Simulator.
  2. Reopen Xcode once so it can finish platform/runtime setup.
  3. Check Xcode > Settings > Platforms for an installed iOS simulator runtime.
  4. Restart macOS if simdiskimaged remains crashed or missing.

After simctl works, rerun:
  scripts/test-simulator.sh <same -only-testing args>
EOF
}

print_available_iphones() {
  if [[ -s "${SIMCTL_JSON}" ]]; then
    python3 - <<'PY' "${SIMCTL_JSON}" || true
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
rows = []
for runtime, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            rows.append((runtime, device.get("name", ""), device.get("udid", "")))
for runtime, name, udid in rows[:40]:
    print(f"  {name} | {runtime} | {udid}")
PY
  fi
}

print_toolchain
print_simulator_app_state

section "CoreSimulator"
if ! xcrun simctl list devices available -j >"${SIMCTL_JSON}" 2>"${SIMCTL_ERR}"; then
  printf 'FAIL: xcrun simctl cannot read available devices.\n'
  if [[ -s "${SIMCTL_ERR}" ]]; then
    printf '\n--- simctl stderr ---\n'
    tail -80 "${SIMCTL_ERR}"
  fi
  if grep -Eq 'CoreSimulatorService|simdiskimaged|Connection invalid|Connection refused' "${SIMCTL_ERR}" 2>/dev/null; then
    printf '\nDiagnosis: CoreSimulator services are unhealthy in this shell/session.\n'
  else
    printf '\nDiagnosis: simctl failed before simulator selection could run.\n'
  fi
  print_recovery_steps
  exit 70
fi

set +e
python3 - <<'PY' "${SIMCTL_JSON}" "${REQUIRED_SIMULATOR_NAME}"
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
required_name = sys.argv[2]
candidates = []
for runtime, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    version = [int(part) for part in re.findall(r"\d+", runtime)]
    for device in devices:
        if device.get("name") == required_name and device.get("isAvailable"):
            candidates.append((version, runtime, device.get("udid", "")))
if candidates:
    candidates.sort()
    _, runtime, udid = candidates[-1]
    print(f"ok: {required_name} available on {runtime} ({udid})")
    sys.exit(0)
print(f"FAIL: no available simulator named {required_name!r}.")
sys.exit(2)
PY
STATUS=$?
set -e
if [[ "${STATUS}" == "0" ]]; then
  exit 0
fi

section "Available iPhone simulators"
print_available_iphones
cat <<EOF

Create an '${REQUIRED_SIMULATOR_NAME}' simulator in Xcode > Devices and Simulators,
or override with OHANA_SIMULATOR_NAME=<existing name> / OHANA_SIMULATOR_UDID=<udid>.
EOF
exit 70
