#!/usr/bin/env bash
# Track the all-app Domain write-kernel rollout.
#
# CI cadence is part of this tracker:
# - Inside a phase: local validation only.
# - At the end of each phase: one commit/push, then inspect exactly one CI run.
# - Do not use CI as a heartbeat while a phase is still in progress.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TRACKER_FILE="${DOMAIN_WRITE_KERNEL_TRACKER_FILE:-docs/planning/domain-write-kernel-progress.md}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/track-domain-write-kernel-plan.sh status
  scripts/track-domain-write-kernel-plan.sh report
  scripts/track-domain-write-kernel-plan.sh start <phase> ["note"]
  scripts/track-domain-write-kernel-plan.sh complete <phase> "<local validation summary>"
  scripts/track-domain-write-kernel-plan.sh ci <phase> <run-url-or-local> <pass|fail|blocked> ["note"]

Tracking rules:
  - Use local validation inside a phase.
  - Run CI exactly once when a phase is complete and pushed.
  - Record that phase-end CI with the ci command.
  - Do not trigger CI repeatedly during one phase.
USAGE
}

now_stamp() {
  date "+%Y-%m-%d %H:%M:%S %z"
}

require_tracker() {
  if [[ ! -f "${TRACKER_FILE}" ]]; then
    echo "Missing tracker file: ${TRACKER_FILE}" >&2
    exit 1
  fi
}

sanitize_cell() {
  printf '%s' "$1" | tr '\t|' ' /'
}

phase_status() {
  local phase="$1"
  awk -F '|' -v phase="${phase}" '
    /^## 阶段总览/ { in_overview = 1; next }
    /^## Phase 明细/ { in_overview = 0 }
    !in_overview { next }
    $2 ~ "^[[:space:]]*" phase "[[:space:]]*$" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)
      print $4
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "${TRACKER_FILE}"
}

update_phase_row() {
  local phase="$1"
  local status="$2"
  local ci="$3"
  local note="$4"
  local tmp
  tmp="$(mktemp)"

  awk -F '|' -v OFS='|' \
    -v phase="${phase}" \
    -v status=" $(sanitize_cell "${status}") " \
    -v ci=" $(sanitize_cell "${ci}") " \
    -v note=" $(sanitize_cell "${note}") " '
      /^## 阶段总览/ { in_overview = 1 }
      /^## Phase 明细/ { in_overview = 0 }
      !in_overview { print; next }
      $2 ~ "^[[:space:]]*" phase "[[:space:]]*$" {
        $4 = status
        $6 = ci
        $7 = note
      }
      { print }
    ' "${TRACKER_FILE}" >"${tmp}"
  mv "${tmp}" "${TRACKER_FILE}"
}

append_log() {
  local phase="$1"
  local action="$2"
  local note="$3"
  printf '\n- %s Phase %s %s：%s\n' "$(now_stamp)" "${phase}" "${action}" "${note}" >>"${TRACKER_FILE}"
}

cmd="${1:-status}"
case "${cmd}" in
  status)
    require_tracker
    sed -n '1,120p' "${TRACKER_FILE}"
    ;;
  report)
    require_tracker
    cat "${TRACKER_FILE}"
    ;;
  start)
    require_tracker
    phase="${2:-}"
    note="${3:-本地实施中；CI 禁止触发，直到本 phase 完成。}"
    [[ -n "${phase}" ]] || { usage; exit 2; }
    phase_status "${phase}" >/dev/null || { echo "Unknown phase: ${phase}" >&2; exit 2; }
    update_phase_row "${phase}" "🟡" "pending" "${note}"
    append_log "${phase}" "start" "${note}"
    sed -n '1,80p' "${TRACKER_FILE}"
    ;;
  complete)
    require_tracker
    phase="${2:-}"
    summary="${3:-local validation passed}"
    [[ -n "${phase}" ]] || { usage; exit 2; }
    phase_status "${phase}" >/dev/null || { echo "Unknown phase: ${phase}" >&2; exit 2; }
    update_phase_row "${phase}" "🟢" "required" "本地完成：${summary}；下一步 commit/push 一次并查一次 CI。"
    append_log "${phase}" "complete" "本地完成：${summary}；Phase-end CI required。"
    sed -n '1,80p' "${TRACKER_FILE}"
    ;;
  ci)
    require_tracker
    phase="${2:-}"
    run_url="${3:-}"
    result="${4:-}"
    note="${5:-}"
    [[ -n "${phase}" && -n "${run_url}" && -n "${result}" ]] || { usage; exit 2; }
    phase_status "${phase}" >/dev/null || { echo "Unknown phase: ${phase}" >&2; exit 2; }
    case "${result}" in
      pass|fail|blocked) ;;
      *) echo "CI result must be pass, fail, or blocked." >&2; exit 2 ;;
    esac
    current_status="$(phase_status "${phase}")"
    if [[ "${current_status}" != "🟢" && "${current_status}" != "🟢*" ]]; then
      echo "Refusing to record CI for phase ${phase}: phase is not locally complete." >&2
      echo "Only phase-end CI is allowed by this plan." >&2
      exit 1
    fi
    ci_cell="${result}: ${run_url}"
    if [[ "${result}" == "pass" ]]; then
      update_phase_row "${phase}" "🏁" "${ci_cell}" "${note:-Phase-end CI passed; pure review still required where applicable.}"
    else
      update_phase_row "${phase}" "⛔" "${ci_cell}" "${note:-Phase-end CI ${result}.}"
    fi
    append_log "${phase}" "ci ${result}" "${run_url} ${note}"
    sed -n '1,80p' "${TRACKER_FILE}"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
