#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ohana-dogfood-user-status.XXXXXX")"
data_container="${fixture_root}/container"
store="${data_container}/Library/Application Support/default.store"
preferences="${data_container}/Library/Preferences/com.guanchen.li.Ohana.plist"
status_json="${fixture_root}/status.json"
failures=0

mkdir -p "$(dirname "${store}")" "$(dirname "${preferences}")"

cleanup() {
  rm -rf "${fixture_root}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

python3 - "${store}" "${preferences}" <<'PY'
import plistlib
import sqlite3
import sys

store, preferences = sys.argv[1:]
connection = sqlite3.connect(store)
connection.executescript(
    """
    CREATE TABLE ZHUMAN (
        ZID BLOB,
        ZNAME TEXT,
        ZPASSEDAWAYDATE REAL,
        ZTRASHEDAT REAL,
        ZCREATEDAT REAL
    );
    CREATE TABLE ZPET (
        ZNAME TEXT,
        ZPASSEDAWAYDATE REAL,
        ZTRASHEDAT REAL,
        ZCREATEDAT REAL
    );
    CREATE TABLE ZEVENT (ZRECURRENCEDAYS INTEGER, ZTRASHEDAT REAL, ZCREATEDAT REAL);
    CREATE TABLE ZREMINDER (ZSTATUS TEXT);
    CREATE TABLE ZPETCARELOG (ZDATE REAL, ZTRASHEDAT REAL);
    CREATE TABLE ZCOCONUTLEDGERENTRY (
        ZDELTA INTEGER,
        ZENTRYKINDRAW TEXT,
        ZSOURCERAW TEXT,
        ZOCCURREDAT REAL
    );
    CREATE TABLE ZCARELEDGEREVENT (
        ZEVENTKIND TEXT,
        ZCOCONUTDELTA INTEGER,
        ZOCCURREDAT REAL
    );
    CREATE TABLE ZOASISUNLOCK (ZID BLOB);
    CREATE TABLE ZHOUSEHOLD (ZID BLOB);
    CREATE TABLE Z_METADATA (Z_UUID TEXT);
    INSERT INTO Z_METADATA VALUES ('fixture-store-uuid');
    """
)
connection.commit()
connection.close()
with open(preferences, "wb") as handle:
    plistlib.dump({}, handle)
PY

"${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --json > "${status_json}"

python3 - "${status_json}" <<'PY' || fail "empty store snapshot was not bootstrap/incomplete"
import json
import sys

snapshot = json.load(open(sys.argv[1], encoding="utf-8"))
assert snapshot["stage"] == "bootstrap"
assert snapshot["ready"] is False
assert snapshot["counts"]["activeHumans"] == 0
PY

set +e
incomplete_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
incomplete_status=$?
set -e
[[ "${incomplete_status}" == "67" ]] || fail "incomplete baseline must exit 67"
grep -qF "missing: active Humans 0/1" <<< "${incomplete_output}" || \
  fail "incomplete baseline did not name its missing active Human"

wrong_store="${fixture_root}/unrelated.store"
cp "${store}" "${wrong_store}"
set +e
wrong_store_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${wrong_store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-safe 2>&1)"
wrong_store_status=$?
set -e
[[ "${wrong_store_status}" == "66" ]] || \
  fail "gated status must reject a store outside the supplied App container"
grep -qF "requires Library/Application Support/default.store" <<< "${wrong_store_output}" || \
  fail "wrong-store rejection did not name the fixed primary store"

python3 - "${store}" "${preferences}" <<'PY'
import plistlib
import sqlite3
import sys
import time
import uuid

store, preferences = sys.argv[1:]
now = time.time()
connection = sqlite3.connect(store)
connection.execute(
    "INSERT INTO ZHUMAN VALUES (?, ?, NULL, NULL, ?)",
    (uuid.UUID("00000000-0000-0000-0000-000000000001").bytes, "Sensitive Synthetic Human", now),
)
connection.execute(
    "INSERT INTO ZPET VALUES (?, NULL, NULL, ?)",
    ("Sensitive Synthetic Pet", now),
)
connection.executemany(
    "INSERT INTO ZEVENT VALUES (?, NULL, ?)",
    ((1, now), (30, now)),
)
connection.execute("INSERT INTO ZPETCARELOG VALUES (?, NULL)", (now,))
connection.executemany(
    "INSERT INTO ZCOCONUTLEDGERENTRY VALUES (?, 'reward', ?, ?)",
    ((3, "careEvent", now), (50, "starterGift", now)),
)
connection.execute("INSERT INTO ZCARELEDGEREVENT VALUES ('care', 3, ?)", (now,))
connection.execute("INSERT INTO ZHOUSEHOLD VALUES (X'01')")
connection.commit()
connection.close()
payload = {
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
}
with open(preferences, "wb") as handle:
    plistlib.dump(payload, handle)
PY

"${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready \
  --json > "${status_json}" || fail "complete Day-0 baseline was rejected"

python3 - "${status_json}" <<'PY' || fail "ready snapshot counts or privacy contract drifted"
import json
import sys

text = open(sys.argv[1], encoding="utf-8").read()
assert "Sensitive Synthetic" not in text
snapshot = json.loads(text)
assert snapshot["stage"] == "active"
assert snapshot["ready"] is True
assert snapshot["longitudinal"] is False
assert snapshot["counts"]["activeHumans"] == 1
assert snapshot["counts"]["activePets"] == 1
assert snapshot["counts"]["careRecords"] == 1
assert snapshot["counts"]["carePlans"] == 2
assert snapshot["counts"]["ledgerEntries"] == 2
assert snapshot["counts"]["careRewardLedgerEntries"] == 1
assert snapshot["counts"]["starterGiftLedgerEntries"] == 1
assert snapshot["counts"]["rewardedCareEvents"] == 1
assert snapshot["counts"]["linkedRewardedCareEvents"] == 1
assert snapshot["preferences"]["oasisAccessUnlocked"] is True
assert snapshot["counts"]["oasisRewardUnlocks"] == 0
PY

python3 - "${preferences}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["currentActiveHumanId"] = "00000000-0000-0000-0000-000000000099"
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY
set +e
stale_active_human_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
stale_active_human_status=$?
set -e
[[ "${stale_active_human_status}" == "67" ]] || \
  fail "a stale active-Human preference must not satisfy readiness"
grep -qF "missing: active Human selected" <<< "${stale_active_human_output}" || \
  fail "stale active-Human preference was not named"
python3 - "${preferences}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["currentActiveHumanId"] = "00000000-0000-0000-0000-000000000001"
payload["appCountry"] = "US"
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

set +e
wrong_locale_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
wrong_locale_status=$?
set -e
[[ "${wrong_locale_status}" == "67" ]] || \
  fail "a locale that differs from the persona must not satisfy readiness"
grep -qF "missing: profile region" <<< "${wrong_locale_output}" || \
  fail "persona locale drift was not named"
python3 - "${preferences}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["appCountry"] = "DE"
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

python3 - "${store}" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute("UPDATE ZEVENT SET ZRECURRENCEDAYS = 0")
connection.commit()
connection.close()
PY

set +e
nonrecurring_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
nonrecurring_status=$?
set -e
[[ "${nonrecurring_status}" == "67" ]] || fail "non-recurring events must not satisfy the plan baseline"
grep -qF "missing: recurring care plans 0/2" <<< "${nonrecurring_output}" || \
  fail "non-recurring event rejection did not name missing care plans"

python3 - "${store}" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute("UPDATE ZEVENT SET ZRECURRENCEDAYS = 1")
connection.execute(
    "UPDATE ZCOCONUTLEDGERENTRY SET ZSOURCERAW = 'starterGift' "
    "WHERE ZSOURCERAW = 'careEvent'"
)
connection.commit()
connection.close()
PY

set +e
uncoupled_reward_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
uncoupled_reward_status=$?
set -e
[[ "${uncoupled_reward_status}" == "67" ]] || \
  fail "starter-gift ledger entry must not prove a care reward"
grep -qF "missing: care reward ledger entries 0/1" <<< "${uncoupled_reward_output}" || \
  fail "missing care reward was not named in readiness output"

python3 - "${store}" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute(
    "UPDATE ZCOCONUTLEDGERENTRY SET ZSOURCERAW = 'careEvent' "
    "WHERE ZDELTA = 3"
)
connection.execute("UPDATE ZCARELEDGEREVENT SET ZCOCONUTDELTA = 0")
connection.commit()
connection.close()
PY

set +e
unrewarded_care_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
unrewarded_care_status=$?
set -e
[[ "${unrewarded_care_status}" == "67" ]] || \
  fail "an unrewarded canonical care event must not satisfy Day-0"
grep -qF "missing: rewarded care events 0/1" <<< "${unrewarded_care_output}" || \
  fail "missing rewarded care event was not named in readiness output"

python3 - "${store}" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute("UPDATE ZCARELEDGEREVENT SET ZCOCONUTDELTA = 3")
connection.execute("UPDATE ZCARELEDGEREVENT SET ZOCCURREDAT = ZOCCURREDAT + 100")
connection.commit()
connection.close()
PY

set +e
unlinked_care_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
unlinked_care_status=$?
set -e
[[ "${unlinked_care_status}" == "67" ]] || \
  fail "temporally unrelated care and reward facts must not satisfy Day-0"
grep -qF "missing: linked rewarded care events 0/1" <<< "${unlinked_care_output}" || \
  fail "unlinked care reward was not named in readiness output"

python3 - "${store}" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute("UPDATE ZCARELEDGEREVENT SET ZOCCURREDAT = ZOCCURREDAT - 100")
connection.commit()
connection.close()
PY

python3 - "${preferences}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["ohanaStarterLv0CeremonySeenV1"] = False
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

set +e
locked_oasis_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
locked_oasis_status=$?
set -e
[[ "${locked_oasis_status}" == "67" ]] || fail "locked Oasis access must exit 67"
grep -qF "missing: Oasis access unlocked" <<< "${locked_oasis_output}" || \
  fail "locked Oasis access was not named in readiness output"

python3 - "${preferences}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["ohanaStarterLv0CeremonySeenV1"] = True
payload["ohanaStarterOasisTabPromptPendingV1"] = True
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

set +e
unvisited_oasis_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-ready 2>&1)"
unvisited_oasis_status=$?
set -e
[[ "${unvisited_oasis_status}" == "67" ]] || fail "pending Oasis first visit must exit 67"
grep -qF "missing: Oasis first-visit prompt cleared" <<< "${unvisited_oasis_output}" || \
  fail "pending Oasis first visit was not named in readiness output"

python3 - "${preferences}" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    payload = plistlib.load(handle)
payload["ohanaStarterOasisTabPromptPendingV1"] = False
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

set +e
longitudinal_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-longitudinal 2>&1)"
longitudinal_status=$?
set -e
[[ "${longitudinal_status}" == "68" ]] || fail "fresh Day-0 baseline must not pass longitudinal readiness"
grep -qF "Day-7 missing: weight records 0/1" <<< "${longitudinal_output}" || \
  fail "Day-7 failure did not name its missing weight evidence"

python3 - "${store}" <<'PY'
import sqlite3
import sys
import time

store = sys.argv[1]
now = time.time()
connection = sqlite3.connect(store)
connection.executescript(
    """
    CREATE TABLE ZPETWEIGHTLOG (ZDATE REAL, ZTRASHEDAT REAL);
    CREATE TABLE ZPETEXPENSELOG (ZTRASHEDAT REAL);
    CREATE TABLE ZPETPHOTOLOG (ZTRASHEDAT REAL);
    """
)
care_dates = [now - (day * 86_400) for day in range(1, 9)]
rows = [("care", 1, care_dates[index % len(care_dates)]) for index in range(14)]
connection.executemany("INSERT INTO ZCARELEDGEREVENT VALUES (?, ?, ?)", rows)
connection.execute("INSERT INTO ZPETWEIGHTLOG VALUES (?, NULL)", (care_dates[-1],))
connection.execute("INSERT INTO ZPETEXPENSELOG VALUES (NULL)")
connection.execute("INSERT INTO ZPETPHOTOLOG VALUES (NULL)")
connection.commit()
connection.close()
PY

"${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-longitudinal \
  --json > "${status_json}" || fail "complete Day-7 milestone was rejected"

python3 - "${status_json}" <<'PY' || fail "complete Day-7 milestone did not become longitudinal"
import json
import sys

snapshot = json.load(open(sys.argv[1], encoding="utf-8"))
assert snapshot["stage"] == "longitudinal"
assert snapshot["longitudinal"] is True
assert snapshot["missingLongitudinal"] == []
assert snapshot["counts"]["weightRecords"] == 1
assert snapshot["counts"]["expenseRecords"] == 1
assert snapshot["counts"]["moments"] == 1
PY

set +e
day30_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-day30 2>&1)"
day30_status=$?
set -e
[[ "${day30_status}" == "71" ]] || fail "Day-7 data must not pass Day-30 readiness"
grep -qF "Day-30 missing: history days" <<< "${day30_output}" || \
  fail "Day-30 failure did not name missing history"

python3 - "${store}" <<'PY'
import sqlite3
import sys
import time

store = sys.argv[1]
now = time.time()
connection = sqlite3.connect(store)
care_dates = [now - (day * 86_400) for day in range(17, 32)]
rows = [("care", 1, care_dates[index % len(care_dates)]) for index in range(15)]
connection.executemany("INSERT INTO ZCARELEDGEREVENT VALUES (?, ?, ?)", rows)
connection.executemany(
    "INSERT INTO ZPETWEIGHTLOG VALUES (?, NULL)",
    ((care_dates[0],), (care_dates[7],), (care_dates[14],)),
)
connection.execute("INSERT INTO ZPETEXPENSELOG VALUES (NULL)")
connection.execute("INSERT INTO ZPETPHOTOLOG VALUES (NULL)")
connection.execute("INSERT INTO ZPETPHOTOLOG VALUES (NULL)")
connection.commit()
connection.close()
PY

"${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-day30 \
  --json > "${status_json}" || fail "complete Day-30 milestone was rejected"

python3 - "${status_json}" <<'PY' || fail "complete Day-30 milestone did not become mature"
import json
import sys

snapshot = json.load(open(sys.argv[1], encoding="utf-8"))
assert snapshot["stage"] == "mature"
assert snapshot["day30Ready"] is True
assert snapshot["missingDay30"] == []
assert snapshot["counts"]["careRecords"] == 30
assert snapshot["counts"]["weightRecords"] == 4
assert snapshot["counts"]["expenseRecords"] == 2
assert snapshot["counts"]["moments"] == 3
PY

python3 - "${data_container}/Library/Preferences/com.guanchen.li.OhanaUITests.state.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as handle:
    plistlib.dump({"contaminated": True}, handle)
PY
set +e
unsafe_output="$("${repo_root}/scripts/dogfood-user-status.py" \
  --store "${store}" \
  --preferences "${preferences}" \
  --data-container "${data_container}" \
  --require-safe 2>&1)"
unsafe_status=$?
set -e
[[ "${unsafe_status}" == "69" ]] || fail "test-artifact contamination must exit 69"
grep -qF "overlay safety failed" <<< "${unsafe_output}" || \
  fail "test-artifact contamination did not name overlay safety"

printf 'not sqlite\n' > "${fixture_root}/corrupt.store"
set +e
"${repo_root}/scripts/dogfood-user-status.py" \
  --store "${fixture_root}/corrupt.store" \
  --preferences "${preferences}" >/dev/null 2>&1
corrupt_status=$?
set -e
[[ "${corrupt_status}" == "66" ]] || fail "corrupt primary store must exit 66"

if [[ "${failures}" -gt 0 ]]; then
  echo "Dogfood user status tests: ${failures} failure(s)." >&2
  exit 1
fi

echo "Dogfood user status tests: passed."
