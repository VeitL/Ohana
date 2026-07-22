#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-dogfood-simulator.XXXXXX")"
fixture_root="$(cd "${fixture_root}" && pwd -P)"
fake_repo="${fixture_root}/repo"
fake_home="${fixture_root}/home"
fake_bin="${fixture_root}/bin"
fake_app="${fake_repo}/.build/DerivedData/dogfood/Build/Products/Release-iphonesimulator/Ohana.app"
fake_data="${fixture_root}/data"
fake_data_after="${fixture_root}/data-after-remount"
fake_initial_data="${fixture_root}/first-install-data"
fake_offline_app_root="${fake_home}/Library/Developer/CoreSimulator/Devices/DOGFOOD-UDID/data/Containers/Bundle/Application/OFFLINE"
fake_offline_app="${fake_offline_app_root}/Ohana.app"
fake_offline_data="${fake_home}/Library/Developer/CoreSimulator/Devices/DOGFOOD-UDID/data/Containers/Data/Application/OFFLINE"
fake_preferences="${fake_data}/Library/Preferences/com.guanchen.li.Ohana.plist"
fake_preferences_after="${fake_data_after}/Library/Preferences/com.guanchen.li.Ohana.plist"
fake_install_state="${fixture_root}/install-state"
fake_boot_state="${fixture_root}/boot-state"
xcrun_log="${fixture_root}/xcrun.log"
failures=0

cleanup() {
  rm -rf "${fixture_root}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

mkdir -p "${fake_repo}/.build" "${fake_home}" "${fake_bin}" \
  "${fake_app}" "${fake_data}/Library/Application Support" \
  "${fake_data}/Library/Preferences" \
  "${fake_data_after}/Library/Application Support" \
  "${fake_data_after}/Library/Preferences" \
  "${fake_initial_data}" \
  "${fake_offline_app}" \
  "${fake_offline_data}/Library/Application Support" \
  "${fake_offline_data}/Library/Preferences"
printf '%s\n' 'DOGFOOD-UDID' > "${fake_repo}/.build/dogfood-simulator.udid"

python3 - "${fake_app}/Info.plist" \
  "${fake_data}/Library/Application Support/default.store" \
  "${fake_preferences}" <<'PY'
import plistlib
import sqlite3
import sys
import time
import uuid

info, store, preferences = sys.argv[1:]
with open(info, "wb") as handle:
    plistlib.dump(
        {
            "CFBundleIdentifier": "com.guanchen.li.Ohana",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "fixture",
        },
        handle,
    )
connection = sqlite3.connect(store)
connection.executescript(
    """
    CREATE TABLE Z_METADATA (Z_UUID TEXT);
    INSERT INTO Z_METADATA VALUES ('fixture-store-uuid');
    CREATE TABLE ZHUMAN (ZID BLOB, ZTRASHEDAT REAL, ZPASSEDAWAYDATE REAL);
    CREATE TABLE ZPET (ZTRASHEDAT REAL, ZPASSEDAWAYDATE REAL);
    CREATE TABLE ZEVENT (ZRECURRENCEDAYS INTEGER, ZTRASHEDAT REAL);
    CREATE TABLE ZCOCONUTLEDGERENTRY (
        ZENTRYKINDRAW TEXT,
        ZSOURCERAW TEXT,
        ZDELTA INTEGER,
        ZOCCURREDAT REAL
    );
    CREATE TABLE ZCARELEDGEREVENT (
        ZEVENTKIND TEXT,
        ZCOCONUTDELTA INTEGER,
        ZOCCURREDAT REAL
    );
    """
)
now = time.time()
connection.execute(
    "INSERT INTO ZHUMAN VALUES (?, NULL, NULL)",
    (uuid.UUID("00000000-0000-0000-0000-000000000001").bytes,),
)
connection.execute("INSERT INTO ZPET VALUES (NULL, NULL)")
connection.executemany("INSERT INTO ZEVENT VALUES (?, NULL)", ((1,), (30,)))
connection.executemany(
    "INSERT INTO ZCOCONUTLEDGERENTRY VALUES ('reward', ?, ?, ?)",
    (("careEvent", 3, now), ("starterGift", 50, now)),
)
connection.execute("INSERT INTO ZCARELEDGEREVENT VALUES ('care', 3, ?)", (now,))
connection.commit()
connection.close()
with open(preferences, "wb") as handle:
    plistlib.dump(
        {
            "ohana_has_onboarded": True,
            "currentActiveHumanId": "00000000-0000-0000-0000-000000000001",
            "ohanaStarterGiftClaimedV1": True,
            "ohanaStarterGiftPendingV1": False,
            "ohanaStarterLv0CeremonySeenV1": True,
            "ohanaStarterOasisTabPromptPendingV1": False,
            "appLanguage": "en",
            "appCountry": "DE",
            "appCurrency": "EUR",
            "appMeasurementSystem": "metric",
        },
        handle,
    )
PY
cp "${fake_data}/Library/Application Support/default.store" \
  "${fake_data_after}/Library/Application Support/default.store"
cp "${fake_preferences}" "${fake_preferences_after}"
cp "${fake_app}/Info.plist" "${fake_offline_app}/Info.plist"
cp "${fake_data}/Library/Application Support/default.store" \
  "${fake_offline_data}/Library/Application Support/default.store"
cp "${fake_preferences}" \
  "${fake_offline_data}/Library/Preferences/com.guanchen.li.Ohana.plist"
python3 - \
  "${fake_offline_app_root}/.com.apple.mobile_container_manager.metadata.plist" \
  "${fake_offline_data}/.com.apple.mobile_container_manager.metadata.plist" <<'PY'
import plistlib
import sys

for path in sys.argv[1:]:
    with open(path, "wb") as handle:
        plistlib.dump({"MCMMetadataIdentifier": "com.guanchen.li.Ohana"}, handle)
PY
printf 'regenerated-before\n' > "${fake_data}/Library/Application Support/default.store-shm"
printf 'regenerated-after\n' > "${fake_data_after}/Library/Application Support/default.store-shm"

cat > "${fake_bin}/xcrun" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_XCRUN_LOG}"
if [[ "$*" == "simctl list devices available -j" ]]; then
  dogfood_state="Shutdown"
  [[ -f "${FAKE_BOOT_STATE}" ]] && dogfood_state="Booted"
  cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
  {"name":"iPhone 17 Dogfood","udid":"DOGFOOD-UDID","state":"${dogfood_state}","isAvailable":true},
  {"name":"iPhone 17 Tests","udid":"TEST-UDID","state":"Shutdown","isAvailable":true}
]}}
JSON
  exit 0
fi
if [[ "$1" == "simctl" && "$2" == "get_app_container" ]]; then
  if [[ "${FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL:-0}" == "1" && ! -f "${FAKE_BOOT_STATE}" ]]; then
    echo "Unable to lookup in current state: Shutdown" >&2
    exit 149
  fi
  if [[ "${FAKE_DETACHED_RECOVERY:-0}" == "1" ]]; then
    [[ -f "${FAKE_INSTALL_STATE}" ]] || exit 1
    case "${5:-}" in
      app) printf '%s\n' "${FAKE_APP_CONTAINER}" ;;
      data)
        if [[ "${FAKE_REPAIR_WRONG_DATA:-0}" == "1" ]]; then
          printf '%s\n' "${FAKE_DATA_CONTAINER_AFTER}"
        else
          printf '%s\n' "${FAKE_DETACHED_CONTAINER}"
        fi
        ;;
      *) exit 64 ;;
    esac
    exit 0
  fi
  if [[ "${FAKE_CONTAINERS_MISSING:-0}" == "1" ]]; then
    exit 1
  fi
  if [[ "${FAKE_FIRST_INSTALL:-0}" == "1" && ! -f "${FAKE_INSTALL_STATE}" ]]; then
    exit 1
  fi
  case "${5:-}" in
    app) printf '%s\n' "${FAKE_APP_CONTAINER}" ;;
    data)
      if [[ "${FAKE_FIRST_INSTALL:-0}" == "1" ]]; then
        printf '%s\n' "${FAKE_INITIAL_DATA_CONTAINER}"
      elif [[ -f "${FAKE_INSTALL_STATE}" ]]; then
        printf '%s\n' "${FAKE_DATA_CONTAINER_AFTER}"
      else
        printf '%s\n' "${FAKE_DATA_CONTAINER}"
      fi
      ;;
    *) exit 64 ;;
  esac
  exit 0
fi
if [[ "$1" == "simctl" && "$2" == "boot" ]]; then
  : > "${FAKE_BOOT_STATE}"
  exit 0
fi
if [[ "$1" == "simctl" && "$2" == "install" ]]; then
  : > "${FAKE_INSTALL_STATE}"
  if [[ "${FAKE_REPAIR_MUTATE_DURABLE:-0}" == "1" ]]; then
    printf '%s\n' 'synthetic-install-mutation' >> \
      "${FAKE_DETACHED_CONTAINER}/Library/Preferences/com.guanchen.li.Ohana.plist"
  fi
  exit 0
fi
if [[ "$1" == "simctl" && "$2" == "terminate" && "${FAKE_TERMINATE_NOT_FOUND:-0}" == "1" ]]; then
  echo "The process was not found." >&2
  exit 3
fi
if [[ "$1" == "simctl" && "$2" == "launch" && "${FAKE_LAUNCH_FAIL:-0}" == "1" ]]; then
  echo "Synthetic launch failure" >&2
  exit 5
fi
if [[ "$1" == "simctl" && "$2" =~ ^(boot|bootstatus|terminate|launch)$ ]]; then
  exit 0
fi
exit 64
SH
chmod +x "${fake_bin}/xcrun"

cat > "${fake_bin}/open" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "${fake_bin}/open"

export OHANA_LOCAL_BUILD_REPO_ROOT="${fake_repo}"
export HOME="${fake_home}"
export PATH="${fake_bin}:${PATH}"
export FAKE_XCRUN_LOG="${xcrun_log}"
export FAKE_APP_CONTAINER="${fake_app}"
export FAKE_DATA_CONTAINER="${fake_data}"
export FAKE_DATA_CONTAINER_AFTER="${fake_data_after}"
export FAKE_INITIAL_DATA_CONTAINER="${fake_initial_data}"
export FAKE_INSTALL_STATE="${fake_install_state}"
export FAKE_BOOT_STATE="${fake_boot_state}"

set +e
status_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
status_status=$?
set -e
[[ "${status_status}" == "0" ]] || fail "read-only Dogfood status failed: ${status_output}"
grep -qF "simulator: iPhone 17 Dogfood (DOGFOOD-UDID)" <<< "${status_output}" || \
  fail "status did not report the fixed Dogfood identity"
grep -qF "configuration: Release" <<< "${status_output}" || \
  fail "status did not report Release configuration"
grep -qF "primary stores: 1" <<< "${status_output}" || \
  fail "status did not recognize the primary store"
if rg -n 'simctl (boot|bootstatus|install|erase|delete|uninstall|launch)' "${xcrun_log}" >/dev/null; then
  fail "status mode invoked a mutating Simulator command"
fi

set +e
offline_status_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
offline_status_code=$?
offline_data_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --require-data 2>&1)"
offline_data_code=$?
set -e
[[ "${offline_status_code}" == "0" ]] || \
  fail "Shutdown status could not inspect installed app/data metadata: ${offline_status_output}"
[[ "${offline_data_code}" == "0" ]] || \
  fail "Shutdown existing-data check rejected installed app/data metadata: ${offline_data_output}"
grep -qF "installed app: ${fake_offline_app} (offline metadata fallback)" <<< "${offline_status_output}" || \
  fail "Shutdown status did not expose the offline installed app"
grep -qF "data container: ${fake_offline_data} (offline metadata fallback)" <<< "${offline_status_output}" || \
  fail "Shutdown status did not expose the offline data container"
if grep -qF "DETACHED FROM MISSING APP" <<< "${offline_status_output}"; then
  fail "Shutdown status misclassified an offline installed app as detached"
fi

set +e
offline_initialize_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --initialize --no-build 2>&1)"
offline_initialize_code=$?
set -e
[[ "${offline_initialize_code}" == "69" ]] || \
  fail "initialization must reject an offline installed app/data pair"
grep -qF "allowed only on a true first install" <<< "${offline_initialize_output}" || \
  fail "offline existing-state initialization rejection was not explicit"

: > "${fake_boot_state}"
set +e
booted_authority_output="$(FAKE_CONTAINERS_MISSING=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --require-data 2>&1)"
booted_authority_code=$?
set -e
rm -f "${fake_boot_state}"
[[ "${booted_authority_code}" == "67" ]] || \
  fail "Booted status must not replace failed simctl lookups with offline metadata"
if grep -qF "offline metadata fallback" <<< "${booted_authority_output}"; then
  fail "Booted status used the Shutdown-only metadata fallback"
fi

set +e
offline_seal_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --seal-user 2>&1)"
offline_seal_code=$?
set -e
[[ "${offline_seal_code}" == "0" ]] || \
  fail "Shutdown metadata fallback could not seal the ready store: ${offline_seal_output}"
[[ -f "${fake_repo}/.build/dogfood-store.identity" ]] || \
  fail "Shutdown metadata seal did not create the store identity"

set +e
offline_overlay_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
offline_overlay_code=$?
set -e
[[ "${offline_overlay_code}" == "0" ]] || \
  fail "Shutdown preflight did not recover through booted simctl validation: ${offline_overlay_output}"
grep -qF "CoreSimulator remounted the logical data container" <<< "${offline_overlay_output}" || \
  fail "Shutdown-to-Booted overlay did not report logical data continuity"
[[ -f "${fake_boot_state}" ]] || \
  fail "Shutdown-to-Booted overlay never booted the Simulator"
rm -f "${fake_boot_state}" "${fake_install_state}"

install_count_before_offline_repair="$(rg -c 'simctl install' "${xcrun_log}" || true)"
set +e
offline_repair_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --repair-detached --no-build 2>&1)"
offline_repair_code=$?
set -e
[[ "${offline_repair_code}" == "69" ]] || \
  fail "detached repair must reject an offline installed app"
grep -qF -- "--repair-detached requires exactly one detached Dogfood data container" <<< "${offline_repair_output}" || \
  fail "offline installed-app repair rejection was not explicit"
install_count_after_offline_repair="$(rg -c 'simctl install' "${xcrun_log}" || true)"
[[ "${install_count_after_offline_repair}" == "${install_count_before_offline_repair}" ]] || \
  fail "offline installed-app repair attempted installation"
rm -f "${fake_repo}/.build/dogfood-store.identity" \
  "${fake_repo}/.build/dogfood-evidence/last-overlay.json"

fake_ambiguous_app_root="${fake_home}/Library/Developer/CoreSimulator/Devices/DOGFOOD-UDID/data/Containers/Bundle/Application/OFFLINE-2"
mkdir -p "${fake_ambiguous_app_root}/Ohana.app"
cp "${fake_app}/Info.plist" "${fake_ambiguous_app_root}/Ohana.app/Info.plist"
cp "${fake_offline_app_root}/.com.apple.mobile_container_manager.metadata.plist" \
  "${fake_ambiguous_app_root}/.com.apple.mobile_container_manager.metadata.plist"
set +e
ambiguous_app_output="$(FAKE_SHUTDOWN_CONTAINER_LOOKUP_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --require-data 2>&1)"
ambiguous_app_code=$?
set -e
[[ "${ambiguous_app_code}" == "67" ]] || \
  fail "multiple offline installed app bundles must fail existing-data validation"
grep -qF "multiple installed app bundles match" <<< "${ambiguous_app_output}" || \
  fail "ambiguous offline app-bundle rejection message is missing"
rm -rf "${fake_ambiguous_app_root}" "${fake_offline_app_root}" "${fake_offline_data}"

set +e
longitudinal_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --require-longitudinal 2>&1)"
longitudinal_status=$?
day30_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --require-day30 2>&1)"
day30_status=$?
set -e
[[ "${longitudinal_status}" == "68" ]] || \
  fail "runner --require-longitudinal must forward the Day-7 gate"
[[ "${day30_status}" == "71" ]] || \
  fail "runner --require-day30 must forward the Day-30 gate"

detached_container="${fake_home}/Library/Developer/CoreSimulator/Devices/DOGFOOD-UDID/data/Containers/Data/Application/DETACHED"
mkdir -p "${detached_container}/Library/Application Support" \
  "${detached_container}/Library/Preferences"
cp "${fake_data}/Library/Application Support/default.store" \
  "${detached_container}/Library/Application Support/default.store"
cp "${fake_preferences}" \
  "${detached_container}/Library/Preferences/com.guanchen.li.Ohana.plist"
python3 - "${detached_container}/.com.apple.mobile_container_manager.metadata.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as handle:
    plistlib.dump({"MCMMetadataIdentifier": "com.guanchen.li.Ohana"}, handle)
PY
export FAKE_DETACHED_CONTAINER="${detached_container}"
set +e
detached_status_output="$(FAKE_CONTAINERS_MISSING=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
detached_status=$?
set -e
[[ "${detached_status}" == "0" ]] || fail "detached data status should remain read-only and inspectable"
grep -qF "DETACHED FROM MISSING APP" <<< "${detached_status_output}" || \
  fail "status did not expose detached pre-existing app data"

set +e
detached_initialize_output="$(FAKE_CONTAINERS_MISSING=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --initialize --no-build 2>&1)"
detached_initialize_status=$?
set -e
[[ "${detached_initialize_status}" == "69" ]] || \
  fail "initialization over detached app data must exit 69"
grep -qF "silently reconnect that old container" <<< "${detached_initialize_output}" || \
  fail "detached-data initialization rejection message is missing"

set +e
unsealed_repair_output="$(FAKE_DETACHED_RECOVERY=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --repair-detached --no-build 2>&1)"
unsealed_repair_status=$?
set -e
[[ "${unsealed_repair_status}" == "70" ]] || \
  fail "detached repair without a sealed identity must exit 70"
grep -qF "store identity is not sealed" <<< "${unsealed_repair_output}" || \
  fail "unsealed detached repair did not name the identity requirement"

repair_identity="$(python3 - <<'PY'
import hashlib
print(hashlib.sha256(b"fixture-store-uuid").hexdigest())
PY
)"
printf '%s\n' "${repair_identity}" > "${fake_repo}/.build/dogfood-store.identity"

set +e
wrong_container_repair_output="$(FAKE_DETACHED_RECOVERY=1 FAKE_REPAIR_WRONG_DATA=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --repair-detached --no-build 2>&1)"
wrong_container_repair_status=$?
set -e
[[ "${wrong_container_repair_status}" == "69" ]] || \
  fail "detached repair must reject a different post-install container"
grep -qF "original authoritative data container" <<< "${wrong_container_repair_output}" || \
  fail "replacement-container repair rejection was not explicit"
rm -f "${fake_install_state}"

set +e
mutated_repair_output="$(FAKE_DETACHED_RECOVERY=1 FAKE_REPAIR_MUTATE_DURABLE=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --repair-detached --no-build 2>&1)"
mutated_repair_status=$?
set -e
[[ "${mutated_repair_status}" == "69" ]] || \
  fail "detached repair must reject durable data changed by installation"
grep -qF "durable-data fingerprint changed" <<< "${mutated_repair_output}" || \
  fail "installation-time durable mutation rejection message is missing"
if ! python3 - "${fake_repo}/.build/dogfood-evidence/last-overlay.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    receipt = json.load(handle)
assert receipt["schema"] == "ohana.dogfood-overlay-attempt.v1"
assert receipt["launchSucceeded"] is False
PY
then
  fail "mutating detached repair left reusable success evidence"
fi
rm -f "${fake_install_state}"
cp "${fake_preferences}" \
  "${detached_container}/Library/Preferences/com.guanchen.li.Ohana.plist"

set +e
failed_repair_output="$(FAKE_DETACHED_RECOVERY=1 FAKE_LAUNCH_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --repair-detached --no-build 2>&1)"
failed_repair_status=$?
set -e
[[ "${failed_repair_status}" != "0" ]] || \
  fail "detached repair with a failed launch unexpectedly passed"
if ! python3 - "${fake_repo}/.build/dogfood-evidence/last-overlay.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    receipt = json.load(handle)
assert receipt["schema"] == "ohana.dogfood-overlay-attempt.v1"
assert receipt["launchSucceeded"] is False
PY
then
  fail "failed detached repair left reusable success evidence"
fi
rm -f "${fake_install_state}"

set +e
detached_repair_output="$(FAKE_DETACHED_RECOVERY=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --repair-detached --no-build 2>&1)"
detached_repair_status=$?
set -e
[[ "${detached_repair_status}" == "0" ]] || \
  fail "explicit detached repair failed: ${detached_repair_output}"
grep -qF "detached App association repaired" <<< "${detached_repair_output}" || \
  fail "successful detached repair did not report byte-identical recovery"
if ! python3 - "${fake_repo}/.build/dogfood-evidence/last-overlay.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    receipt = json.load(handle)
assert receipt["schema"] == "ohana.dogfood-overlay-receipt.v1"
assert receipt["launchSucceeded"] is True
assert receipt["repairDetachedAssociation"] is True
assert receipt["isVersionChange"] is False
PY
then
  fail "successful detached repair receipt could masquerade as an upgrade"
fi
set +e
repaired_ready_output="$(FAKE_DETACHED_RECOVERY=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --require-ready 2>&1)"
repaired_ready_status=$?
set -e
[[ "${repaired_ready_status}" == "0" ]] || \
  fail "repaired detached user did not pass readiness: ${repaired_ready_output}"
if rg -n 'simctl (erase|delete|uninstall)' "${xcrun_log}" >/dev/null; then
  fail "detached repair invoked a destructive Simulator command"
fi
rm -f "${fake_install_state}" \
  "${fake_repo}/.build/dogfood-store.identity" \
  "${fake_repo}/.build/dogfood-evidence/last-overlay.json"

ambiguous_container="${fake_home}/Library/Developer/CoreSimulator/Devices/DOGFOOD-UDID/data/Containers/Data/Application/AMBIGUOUS"
mkdir -p "${ambiguous_container}"
python3 - "${ambiguous_container}/.com.apple.mobile_container_manager.metadata.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as handle:
    plistlib.dump({"MCMMetadataIdentifier": "com.guanchen.li.Ohana"}, handle)
PY
set +e
ambiguous_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --require-data 2>&1)"
ambiguous_status=$?
set -e
[[ "${ambiguous_status}" == "67" ]] || \
  fail "ambiguous matching app data containers must fail existing-data validation"
grep -qF "multiple app data containers match" <<< "${ambiguous_output}" || \
  fail "ambiguous app data rejection message is missing"
rm -rf "${ambiguous_container}"

set +e
unsafe_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build -- -OHANA_UI_TESTS 2>&1)"
unsafe_status=$?
set -e
[[ "${unsafe_status}" == "2" ]] || fail "UI-test launch argument must exit 2"
grep -qF "rejects Ohana test/debug launch argument" <<< "${unsafe_output}" || \
  fail "UI-test launch argument rejection message is missing"

mv "${fake_data}/Library/Application Support/default.store" \
  "${fake_data}/Library/Application Support/default.store-wal"
set +e
orphan_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --require-data 2>&1)"
orphan_status=$?
set -e
[[ "${orphan_status}" == "67" ]] || fail "orphan store sidecar must not satisfy --require-data"
grep -qF "expected default.store is missing" <<< "${orphan_output}" || \
  fail "orphan sidecar failure did not name the missing primary store"
mv "${fake_data}/Library/Application Support/default.store-wal" \
  "${fake_data}/Library/Application Support/default.store"

set +e
debug_output="$(CONFIGURATION=Debug "${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
debug_status=$?
set -e
[[ "${debug_status}" == "2" ]] || fail "Debug Dogfood configuration must exit 2"
grep -qF "requires the Release configuration" <<< "${debug_output}" || \
  fail "Debug configuration rejection message is missing"

set +e
bundle_override_output="$(OHANA_BUNDLE_ID=com.example.Wrong \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
bundle_override_status=$?
set -e
[[ "${bundle_override_status}" == "2" ]] || fail "Dogfood bundle-id override must exit 2"
grep -qF "bundle id is fixed" <<< "${bundle_override_output}" || \
  fail "bundle-id override rejection message is missing"

printf '%s\n' 'TEST-UDID' > "${fake_repo}/.build/dogfood-simulator.udid"
set +e
test_pin_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
test_pin_status=$?
set -e
[[ "${test_pin_status}" == "2" ]] || fail "Tests device pinned as Dogfood must exit 2"
grep -qF "Dogfood requires 'iPhone 17 Dogfood'" <<< "${test_pin_output}" || \
  fail "Tests-device pin rejection message is missing"

rm -f "${fake_repo}/.build/dogfood-simulator.udid"
set +e
missing_pin_output="$(OHANA_DOGFOOD_SIMULATOR_UDID=DOGFOOD-UDID \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
missing_pin_status=$?
set -e
[[ "${missing_pin_status}" == "70" ]] || fail "missing Dogfood pin must exit 70 outside initialization"
[[ ! -e "${fake_repo}/.build/dogfood-simulator.udid" ]] || \
  fail "read-only status silently recreated the missing Dogfood pin"

set +e
failed_initialize_output="$(OHANA_DOGFOOD_SIMULATOR_UDID=DOGFOOD-UDID \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --initialize --no-build 2>&1)"
failed_initialize_status=$?
set -e
[[ "${failed_initialize_status}" == "69" ]] || \
  fail "initialization over existing app/data state must exit 69"
grep -qF "allowed only on a true first install" <<< "${failed_initialize_output}" || \
  fail "existing-state initialization rejection message is missing"
[[ ! -e "${fake_repo}/.build/dogfood-simulator.udid" ]] || \
  fail "failed initialization left behind a new Dogfood pin"

set +e
mixed_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --initialize --status 2>&1)"
mixed_status=$?
set -e
[[ "${mixed_status}" == "2" ]] || fail "--initialize combined with --status must exit 2"

printf '%s\n' 'DOGFOOD-UDID' > "${fake_repo}/.build/dogfood-simulator.udid"
rm -f "${fake_install_state}"
rm -f "${fake_repo}/.build/dogfood-store.identity"
set +e
unsealed_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
unsealed_status=$?
set -e
[[ "${unsealed_status}" == "70" ]] || \
  fail "normal overlay must reject an unsealed Dogfood store identity"
grep -qF "store identity is not sealed" <<< "${unsealed_output}" || \
  fail "unsealed store identity rejection message is missing"

set +e
seal_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --seal-user 2>&1)"
seal_status=$?
set -e
[[ "${seal_status}" == "0" ]] || fail "ready Dogfood identity sealing failed: ${seal_output}"
grep -qF "Sealed Dogfood SwiftData store identity" <<< "${seal_output}" || \
  fail "first identity seal did not report success"
[[ -f "${fake_repo}/.build/dogfood-store.identity" ]] || \
  fail "identity seal did not create the ignored local pin"
sealed_identity="$(tr -d '[:space:]' < "${fake_repo}/.build/dogfood-store.identity")"

set +e
reseal_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --seal-user 2>&1)"
reseal_status=$?
set -e
[[ "${reseal_status}" == "0" ]] || fail "idempotent identity seal failed"
grep -qF "already sealed" <<< "${reseal_output}" || \
  fail "idempotent identity seal did not report the existing match"

printf '%064d\n' 0 > "${fake_repo}/.build/dogfood-store.identity"
set +e
seal_mismatch_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --seal-user 2>&1)"
seal_mismatch_status=$?
set -e
[[ "${seal_mismatch_status}" == "69" ]] || \
  fail "sealing over a different identity pin must exit 69"
grep -qF "refusing to replace a different" <<< "${seal_mismatch_output}" || \
  fail "seal mismatch rejection message is missing"
printf '%s\n' "${sealed_identity}" > "${fake_repo}/.build/dogfood-store.identity"

python3 - "${fake_app}/Info.plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["CFBundleIdentifier"] = "com.example.Wrong"
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY
set +e
wrong_artifact_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
wrong_artifact_status=$?
set -e
[[ "${wrong_artifact_status}" == "69" ]] || \
  fail "wrong-bundle cached Dogfood artifact must exit 69"
grep -qF "artifact bundle id must be" <<< "${wrong_artifact_output}" || \
  fail "wrong-bundle artifact rejection message is missing"
python3 - "${fake_app}/Info.plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["CFBundleIdentifier"] = "com.guanchen.li.Ohana"
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

set +e
remount_output="$(FAKE_TERMINATE_NOT_FOUND=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
remount_status=$?
set -e
[[ "${remount_status}" == "0" ]] || \
  fail "byte-identical durable data must survive a container-path remount: ${remount_output}"
grep -qF "CoreSimulator remounted the logical data container" <<< "${remount_output}" || \
  fail "successful remount did not report content-based continuity"
if rg -n 'simctl (erase|delete|uninstall)' "${xcrun_log}" >/dev/null; then
  fail "Dogfood overlay invoked a destructive Simulator command"
fi

set +e
overlay_checkin_output="$("${repo_root}/scripts/record-dogfood-checkin.sh" overlay pass 2>&1)"
overlay_checkin_status=$?
set -e
[[ "${overlay_checkin_status}" == "0" ]] || \
  fail "fresh verified overlay receipt did not support a passing check-in: ${overlay_checkin_output}"
set +e
reused_receipt_output="$("${repo_root}/scripts/record-dogfood-checkin.sh" overlay pass 2>&1)"
reused_receipt_status=$?
set -e
[[ "${reused_receipt_status}" == "69" ]] || \
  fail "an overlay receipt must not be reusable"

set +e
second_overlay_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
second_overlay_status=$?
set -e
[[ "${second_overlay_status}" == "0" ]] || \
  fail "second fixture overlay failed before upgrade receipt validation"
set +e
failed_after_receipt_output="$(FAKE_LAUNCH_FAIL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
failed_after_receipt_status=$?
stale_success_output="$("${repo_root}/scripts/record-dogfood-checkin.sh" overlay pass 2>&1)"
stale_success_status=$?
set -e
[[ "${failed_after_receipt_status}" != "0" ]] || \
  fail "synthetic overlay launch failure unexpectedly passed"
[[ "${stale_success_status}" == "69" ]] || \
  fail "failed overlay attempt did not invalidate the earlier success receipt"

set +e
recovery_overlay_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
recovery_overlay_status=$?
set -e
[[ "${recovery_overlay_status}" == "0" ]] || \
  fail "receipt recovery overlay failed: ${recovery_overlay_output}"
set +e
false_upgrade_output="$("${repo_root}/scripts/record-dogfood-checkin.sh" upgrade pass 2>&1)"
false_upgrade_status=$?
weekly_checkin_output="$("${repo_root}/scripts/record-dogfood-checkin.sh" weekly pass 2>&1)"
weekly_checkin_status=$?
monthly_checkin_output="$("${repo_root}/scripts/record-dogfood-checkin.sh" monthly pass 2>&1)"
monthly_checkin_status=$?
set -e
[[ "${false_upgrade_status}" == "69" ]] || \
  fail "same-version overlay receipt must not prove an upgrade"
[[ "${weekly_checkin_status}" == "68" ]] || \
  fail "weekly pass must require the Day-7 milestone"
[[ "${monthly_checkin_status}" == "71" ]] || \
  fail "monthly pass must require the Day-30 milestone"

printf 'changed-after-install\n' >> \
  "${fake_data_after}/Library/Application Support/default.store"
rm -f "${fake_install_state}"
set +e
changed_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
changed_status=$?
set -e
[[ "${changed_status}" == "69" ]] || \
  fail "changed durable data during overlay must exit 69"
grep -qF "durable-data fingerprint changed" <<< "${changed_output}" || \
  fail "changed durable data did not trigger the continuity safety stop"

printf '%064d\n' 0 > "${fake_repo}/.build/dogfood-store.identity"
rm -f "${fake_install_state}"
set +e
mismatched_identity_output="$("${repo_root}/scripts/run-dogfood-simulator.sh" --no-build 2>&1)"
mismatched_identity_status=$?
set -e
[[ "${mismatched_identity_status}" == "69" ]] || \
  fail "a different sealed SwiftData identity must exit 69"
grep -qF "does not match the sealed user" <<< "${mismatched_identity_output}" || \
  fail "mismatched store identity rejection message is missing"

rm -rf "${detached_container}"
rm -f "${fake_repo}/.build/dogfood-simulator.udid" \
  "${fake_repo}/.build/dogfood-store.identity" \
  "${fake_repo}/.build/dogfood-initialization.pending" \
  "${fake_install_state}"
set +e
first_launch_output="$(FAKE_FIRST_INSTALL=1 FAKE_LAUNCH_FAIL=1 \
  OHANA_DOGFOOD_SIMULATOR_UDID=DOGFOOD-UDID \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --initialize --no-build 2>&1)"
first_launch_status=$?
set -e
[[ "${first_launch_status}" != "0" ]] || fail "synthetic first launch failure unexpectedly passed"
[[ ! -e "${fake_repo}/.build/dogfood-simulator.udid" ]] || \
  fail "failed first launch committed the Dogfood pin"
[[ -f "${fake_repo}/.build/dogfood-initialization.pending" ]] || \
  fail "failed first launch did not retain its resumable initialization marker"
set +e
pending_status_output="$(FAKE_FIRST_INSTALL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --status 2>&1)"
pending_status_code=$?
set -e
[[ "${pending_status_code}" == "0" ]] || \
  fail "read-only status could not inspect a pending initialization"

mkdir -p "${fake_initial_data}/Library/Application Support" \
  "${fake_initial_data}/Library/Preferences"
cp "${fake_data}/Library/Application Support/default.store" \
  "${fake_initial_data}/Library/Application Support/default.store"
cp "${fake_preferences}" \
  "${fake_initial_data}/Library/Preferences/com.guanchen.li.Ohana.plist"
install_count_before_resume="$(rg -c 'simctl install' "${xcrun_log}" || true)"

set +e
resume_output="$(FAKE_FIRST_INSTALL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --initialize --no-build 2>&1)"
resume_status=$?
set -e
[[ "${resume_status}" == "0" ]] || \
  fail "same-device initialization resume failed: ${resume_output}"
grep -qF "without reinstalling over its new store" <<< "${resume_output}" || \
  fail "store-bearing initialization resume did not use launch-only recovery"
install_count_after_resume="$(rg -c 'simctl install' "${xcrun_log}" || true)"
[[ "${install_count_after_resume}" == "${install_count_before_resume}" ]] || \
  fail "store-bearing initialization resume reinstalled the App"
[[ "$(tr -d '[:space:]' < "${fake_repo}/.build/dogfood-simulator.udid")" == "DOGFOOD-UDID" ]] || \
  fail "successful initialization resume did not commit the original device pin"
[[ ! -e "${fake_repo}/.build/dogfood-initialization.pending" ]] || \
  fail "successful initialization resume left a pending transaction marker"

rm -f "${fake_repo}/.build/dogfood-simulator.udid" \
  "${fake_repo}/.build/dogfood-store.identity"
printf '%s\n' 'DOGFOOD-UDID' > "${fake_repo}/.build/dogfood-initialization.pending"
set +e
pending_seal_output="$(FAKE_FIRST_INSTALL=1 \
  "${repo_root}/scripts/run-dogfood-simulator.sh" --seal-user 2>&1)"
pending_seal_status=$?
set -e
[[ "${pending_seal_status}" == "0" ]] || \
  fail "ready pending initialization could not atomically seal/finalize: ${pending_seal_output}"
grep -qF "Finalized the pending Dogfood device pin" <<< "${pending_seal_output}" || \
  fail "pending seal did not report device-pin finalization"
[[ -f "${fake_repo}/.build/dogfood-store.identity" ]] || \
  fail "pending seal did not create the store identity"
[[ "$(tr -d '[:space:]' < "${fake_repo}/.build/dogfood-simulator.udid")" == "DOGFOOD-UDID" ]] || \
  fail "pending seal did not commit the original simulator pin"
[[ ! -e "${fake_repo}/.build/dogfood-initialization.pending" ]] || \
  fail "pending seal left the initialization marker"

if [[ "${failures}" -gt 0 ]]; then
  echo "Dogfood Simulator tests: ${failures} failure(s)." >&2
  exit 1
fi

echo "Dogfood Simulator tests: passed."
