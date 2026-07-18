#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/local-build-environment.sh
source "${REPO_ROOT}/scripts/lib/local-build-environment.sh"

EVIDENCE_ROOT="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/dogfood-evidence"
JOURNAL_PATH="${EVIDENCE_ROOT}/check-ins.jsonl"
LATEST_PATH="${EVIDENCE_ROOT}/latest.json"
BUNDLE_ID="com.guanchen.li.Ohana"
STORE_IDENTITY_FILE="${OHANA_DOGFOOD_STORE_IDENTITY_FILE}"
OVERLAY_RECEIPT_PATH="${OHANA_LOCAL_BUILD_REPO_ROOT}/.build/dogfood-evidence/last-overlay.json"

usage() {
  cat <<'USAGE'
Usage:
  scripts/record-dogfood-checkin.sh <bootstrap|daily|weekly|monthly|overlay|upgrade> <pass|fail|blocked> [--note TEXT]
  scripts/record-dogfood-checkin.sh --list

Records privacy-minimized local evidence under ignored .build/dogfood-evidence.
A daily/bootstrap pass requires Day-0; weekly requires Day-7; monthly requires
Day-30. Overlay/upgrade passes also consume one fresh verified launcher receipt,
and upgrade requires a version/build change. This command never boots, builds,
installs, launches, writes app data, or reads user-entered content.
USAGE
}

if [[ "${1:-}" == "--list" ]]; then
  if [[ ! -f "${JOURNAL_PATH}" ]]; then
    echo "No Dogfood check-ins recorded."
    exit 0
  fi
  python3 - "${JOURNAL_PATH}" <<'PY'
import json
import pathlib
import sys

rows = []
for raw in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    try:
        rows.append(json.loads(raw))
    except json.JSONDecodeError:
        rows.append({"timestamp": "invalid", "journey": "invalid", "outcome": "invalid", "stage": "invalid"})
for row in rows[-20:]:
    note = row.get("note", "")
    suffix = f" | {note}" if note else ""
    print(f"{row.get('timestamp')} | {row.get('journey')} | {row.get('outcome')} | {row.get('stage')}{suffix}")
PY
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 2
fi

JOURNEY="$1"
OUTCOME="$2"
NOTE=""
shift 2

case "${JOURNEY}" in
  bootstrap|daily|weekly|monthly|overlay|upgrade) ;;
  *)
    echo "Unsupported Dogfood journey: ${JOURNEY}" >&2
    usage >&2
    exit 2
    ;;
esac

case "${OUTCOME}" in
  pass|fail|blocked) ;;
  *)
    echo "Unsupported Dogfood outcome: ${OUTCOME}" >&2
    usage >&2
    exit 2
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --note)
      [[ $# -ge 2 ]] || { echo "--note requires text." >&2; exit 2; }
      NOTE="$2"
      shift 2
      ;;
    *)
      echo "Unknown check-in option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${NOTE}" == *$'\n'* || "${NOTE}" == *$'\r'* || ${#NOTE} -gt 240 ]]; then
  echo "Dogfood notes must be one line and at most 240 characters." >&2
  exit 2
fi
if [[ "${NOTE}" == *"/Users/"* || "${NOTE}" == *"@"* ]]; then
  echo "Dogfood notes may not contain machine paths or email-like identifiers." >&2
  exit 2
fi

SIMULATOR_UDID="$(ohana_require_dogfood_pin)"
ohana_assert_dogfood_simulator_udid "${SIMULATOR_UDID}"

OVERLAY_RECEIPT_ID=""
if [[ "${OUTCOME}" == "pass" ]]; then
  case "${JOURNEY}" in
    weekly)
      READINESS_OPTION="--require-longitudinal"
      ;;
    monthly)
      READINESS_OPTION="--require-day30"
      ;;
    bootstrap|daily|overlay|upgrade)
      READINESS_OPTION="--require-ready"
      ;;
  esac
  READY_OUTPUT="$("${REPO_ROOT}/scripts/run-dogfood-simulator.sh" "${READINESS_OPTION}")"
  if ! grep -qF "store identity: sealed/match" <<< "${READY_OUTPUT}"; then
    echo "A passing Dogfood check-in requires the sealed SwiftData store identity." >&2
    exit 69
  fi
  if [[ "${JOURNEY}" == "overlay" || "${JOURNEY}" == "upgrade" ]]; then
    if [[ ! -f "${STORE_IDENTITY_FILE}" ]]; then
      echo "A passing ${JOURNEY} check-in requires the sealed store identity." >&2
      exit 69
    fi
    set +e
    OVERLAY_RECEIPT_ID="$(python3 - \
      "${OVERLAY_RECEIPT_PATH}" \
      "${JOURNAL_PATH}" \
      "${STORE_IDENTITY_FILE}" \
      "${JOURNEY}" <<'PY'
import json
import pathlib
import sys
import time

receipt_path, journal_path, identity_path, journey = map(pathlib.Path, sys.argv[1:])
try:
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    identity = identity_path.read_text(encoding="utf-8").strip()
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"overlay receipt unavailable: {error}")
if receipt.get("schema") != "ohana.dogfood-overlay-receipt.v1":
    raise SystemExit("overlay receipt schema is invalid")
created = receipt.get("createdAtEpoch")
if not isinstance(created, int) or not 0 <= time.time() - created <= 4 * 60 * 60:
    raise SystemExit("overlay receipt is stale or has an invalid timestamp")
if receipt.get("storeIdentity") != identity:
    raise SystemExit("overlay receipt belongs to a different sealed store")
if not (
    receipt.get("launchSucceeded")
    and receipt.get("sqliteQuickCheckVerified")
    and receipt.get("durableFingerprintVerified")
):
    raise SystemExit("overlay receipt is missing required verification flags")
if journey.name == "upgrade" and receipt.get("isVersionChange") is not True:
    raise SystemExit("upgrade check-in requires an App version or build change")
receipt_id = receipt.get("receiptId")
if not isinstance(receipt_id, str) or not receipt_id:
    raise SystemExit("overlay receipt id is missing")
if journal_path.is_file():
    for raw in journal_path.read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if row.get("overlayReceiptId") == receipt_id:
            raise SystemExit("overlay receipt was already consumed by a check-in")
print(receipt_id)
PY
)"
    receipt_status=$?
    set -e
    if [[ "${receipt_status}" != "0" ]]; then
      echo "A passing ${JOURNEY} check-in requires a fresh, unconsumed launcher receipt." >&2
      exit 69
    fi
  fi
fi

APP_CONTAINER="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" app 2>/dev/null || true)"
DATA_CONTAINER="$(xcrun simctl get_app_container "${SIMULATOR_UDID}" "${BUNDLE_ID}" data 2>/dev/null || true)"
STORE_PATH=""
PREFERENCES_PATH=""
if [[ -n "${DATA_CONTAINER}" && -d "${DATA_CONTAINER}/Library/Application Support" ]]; then
  if [[ -f "${DATA_CONTAINER}/Library/Application Support/default.store" ]]; then
    STORE_PATH="${DATA_CONTAINER}/Library/Application Support/default.store"
  fi
  PREFERENCES_PATH="${DATA_CONTAINER}/Library/Preferences/${BUNDLE_ID}.plist"
fi

mkdir -p "${EVIDENCE_ROOT}"
SNAPSHOT_PATH="$(mktemp "${EVIDENCE_ROOT}/snapshot.XXXXXX.json")"
cleanup() {
  rm -f "${SNAPSHOT_PATH}"
}
trap cleanup EXIT

if [[ -n "${STORE_PATH}" ]]; then
  if ! "${REPO_ROOT}/scripts/dogfood-user-status.py" \
    --store "${STORE_PATH}" \
    --preferences "${PREFERENCES_PATH}" \
    --data-container "${DATA_CONTAINER}" \
    --json > "${SNAPSHOT_PATH}"; then
    printf '%s\n' '{"schema":"ohana.dogfood-user-status.v1","stage":"unavailable","ready":false,"counts":{}}' \
      > "${SNAPSHOT_PATH}"
  fi
else
  printf '%s\n' '{"schema":"ohana.dogfood-user-status.v1","stage":"uninitialized","ready":false,"counts":{}}' \
    > "${SNAPSHOT_PATH}"
fi

METADATA="$(ohana_simulator_metadata "${SIMULATOR_UDID}")"
SIMULATOR_NAME="$(printf '%s' "${METADATA}" | awk -F '\t' '{ print $1 }')"
SIMULATOR_RUNTIME="$(printf '%s' "${METADATA}" | awk -F '\t' '{ print $2 }')"
APP_VERSION="missing"
APP_BUILD="missing"
if [[ -n "${APP_CONTAINER}" && -f "${APP_CONTAINER}/Info.plist" ]]; then
  APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "${APP_CONTAINER}/Info.plist" 2>/dev/null || true)"
  APP_BUILD="$(plutil -extract CFBundleVersion raw -o - "${APP_CONTAINER}/Info.plist" 2>/dev/null || true)"
fi
GIT_REVISION="$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain 2>/dev/null)" ]]; then
  WORKTREE_DIRTY=true
else
  WORKTREE_DIRTY=false
fi

python3 - \
  "${SNAPSHOT_PATH}" \
  "${JOURNAL_PATH}" \
  "${LATEST_PATH}" \
  "${JOURNEY}" \
  "${OUTCOME}" \
  "${NOTE}" \
  "${SIMULATOR_NAME}" \
  "${SIMULATOR_RUNTIME}" \
  "${APP_VERSION:-unknown}" \
  "${APP_BUILD:-unknown}" \
  "${GIT_REVISION}" \
  "${WORKTREE_DIRTY}" \
  "${OVERLAY_RECEIPT_ID}" <<'PY'
import datetime
import json
import pathlib
import sys

(
    snapshot_path,
    journal_path,
    latest_path,
    journey,
    outcome,
    note,
    simulator_name,
    simulator_runtime,
    app_version,
    app_build,
    git_revision,
    worktree_dirty,
    overlay_receipt_id,
) = sys.argv[1:]
snapshot = json.loads(pathlib.Path(snapshot_path).read_text(encoding="utf-8"))
record = {
    "schema": "ohana.dogfood-check-in.v1",
    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "journey": journey,
    "outcome": outcome,
    "note": note,
    "simulatorName": simulator_name,
    "simulatorRuntime": simulator_runtime,
    "configuration": "Release",
    "appVersion": app_version,
    "appBuild": app_build,
    "gitRevision": git_revision,
    "worktreeDirty": worktree_dirty == "true",
    "stage": snapshot.get("stage", "unknown"),
    "ready": bool(snapshot.get("ready", False)),
    "counts": snapshot.get("counts", {}),
}
if overlay_receipt_id:
    record["overlayReceiptId"] = overlay_receipt_id
journal = pathlib.Path(journal_path)
with journal.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
latest = pathlib.Path(latest_path)
temporary = latest.with_suffix(".tmp")
temporary.write_text(json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
temporary.replace(latest)
print(
    f"Recorded Dogfood {record['journey']}={record['outcome']} "
    f"at stage={record['stage']} ({record['timestamp']})."
)
PY
