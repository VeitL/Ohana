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

STATE_FILE="${DOMAIN_WRITE_KERNEL_STATE_FILE:-docs/planning/domain-write-kernel-plan.state.tsv}"

PHASE_IDS=(0 1 2 3 4 5 6 7)
PHASE_NAMES=(
  "Freeze point patches and write matrix"
  "Typed subject taxonomy"
  "Capability authorizer"
  "Schedule writer first closure"
  "Fact ledger economy closure"
  "Restore sync import closure"
  "R8 R9 audit upgrade"
  "Dependency inversion tightening"
)
PHASE_SCOPES=(
  "Stop command-by-command patching; produce the all-app write matrix: model, command, effect, subject, policy, current writer, target writer."
  "Land DomainEntityLinkRegistry and DomainSubjectResolution for Event/Reminder, care fact, ledger, task, notification, backup, and sync. Characterization only."
  "Introduce AuthorizedMutationPlan/token with private or fileprivate construction. Authorizer issues plans; writers and effects consume plans."
  "Close Event/Reminder writes for Calendar, Feeding, Water, Medication, Insurance, HumanNote, MemberCreation, and CarePlanCalendarSync."
  "Move care fact, expense, wallet ledger, reward, and family task completion to plan-driven writers and effect dispatch."
  "Route backup restore and cloud apply through RehydrateWriter with normalize/quarantine/legacyHistoryOnly/dropEffects modes."
  "Upgrade audits from helper-string checks to impossible-bypass checks for direct constructors, raw matchers, restore/apply bypass, effect guessing, and feature-owned taxonomy."
  "Move taxonomy, policy results, and mutation plans to feature-neutral Domain types; prevent new Domain/Models references to feature command results or strings."
)
PHASE_LOCAL_GATES=(
  "Write matrix reviewed locally; no CI until matrix phase is complete."
  "Characterization tests and changed-file audits only; behavior should stay unchanged."
  "Token compile checks, targeted policy tests, and changed-file audits only."
  "Targeted schedule suites, raw Event/Reminder constructor scan, member lifecycle audit, audit fixture tests, module-exit gate locally."
  "Targeted care/economy/family-task suites, ledger/reward fixture tests, economy/member audits locally."
  "Backup/cloud apply targeted tests, rehydrate fixtures, no raw restore insert audit locally."
  "Audit bad/good fixtures first, then all relevant audit scripts locally."
  "Architecture boundary audit, dependency scans, targeted compile/test locally."
)
PHASE_ACCEPTANCE=(
  "No implementation batch begins without a complete write matrix and target writer assignment."
  "New link type without registry entry cannot silently write; typed resolution is the only subject fact consumed downstream."
  "Callers cannot fabricate write capability; disposition remains a result, not authority."
  "Feature commands cannot directly construct and insert member-scoped Event/Reminder."
  "Care facts, ledger, reward, wallet, and task completion cannot bypass authorized plans."
  "Restore/sync cannot raw-insert member-scoped state without resolution and policy mode."
  "Bad fixtures catch constructor bypass, raw matcher, assignee-only, indirect owner, restore/apply, and effects bypass."
  "Domain policy types remain feature-neutral; new feature-owned strings in Domain/Models are audit failures."
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/track-domain-write-kernel-plan.sh status
  scripts/track-domain-write-kernel-plan.sh report
  scripts/track-domain-write-kernel-plan.sh init
  scripts/track-domain-write-kernel-plan.sh start <phase>
  scripts/track-domain-write-kernel-plan.sh complete <phase> "<local validation summary>"
  scripts/track-domain-write-kernel-plan.sh ci <phase> <run-url-or-local> <pass|fail|blocked> ["note"]

Tracking rules:
  - Use local validation inside a phase.
  - Run CI exactly once when a phase is complete and pushed.
  - Record that phase-end CI with the ci command.
  - Do not trigger CI repeatedly during one phase.
USAGE
}

now_utc() {
  date -u "+%Y-%m-%dT%H:%M:%SZ"
}

phase_index() {
  local id="$1"
  local index
  for index in "${!PHASE_IDS[@]}"; do
    if [[ "${PHASE_IDS[$index]}" == "${id}" ]]; then
      echo "${index}"
      return 0
    fi
  done
  echo "Unknown phase: ${id}" >&2
  exit 2
}

ensure_state_file() {
  if [[ -f "${STATE_FILE}" ]]; then
    return
  fi
  mkdir -p "$(dirname "${STATE_FILE}")"
  {
    printf 'phase\tstatus\tlocal_validation\tphase_end_ci\tci_result\tupdated_at\tnote\n'
    printf '0\tpending\twrite matrix not produced yet\tpending\tpending\t%s\tStart here before another implementation batch.\n' "$(now_utc)"
    printf '1\tpartial\tEvent/Reminder taxonomy started; all-app subject resolution pending\tpending\tpending\t%s\tSchedule work began before full all-app matrix.\n' "$(now_utc)"
    printf '2\tpartial\tSchedule write token exists; global AuthorizedMutationPlan pending\tpending\tpending\t%s\tCapability model is not yet app-wide.\n' "$(now_utc)"
    printf '3\tcompleted\tEvent/Reminder first closure passed module-exit gate locally\tpending\tpending\t%s\tPhase-end CI still needs one push/run after commit.\n' "$(now_utc)"
    printf '4\tpending\tpending\tpending\tpending\t%s\t\n' "$(now_utc)"
    printf '5\tpending\tpending\tpending\tpending\t%s\t\n' "$(now_utc)"
    printf '6\tpartial\tMember lifecycle schedule audit upgraded; full R8/R9 pending\tpending\tpending\t%s\tAudit currently covers schedule closure, not all effects.\n' "$(now_utc)"
    printf '7\tpending\tpending\tpending\tpending\t%s\t\n' "$(now_utc)"
  } >"${STATE_FILE}"
}

state_value() {
  local phase="$1"
  local column="$2"
  awk -F '\t' -v phase="${phase}" -v column="${column}" '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == column) {
          col = i
        }
      }
      next
    }
    $1 == phase {
      print $col
    }
  ' "${STATE_FILE}"
}

update_state() {
  local phase="$1"
  local status="$2"
  local local_validation="$3"
  local phase_end_ci="$4"
  local ci_result="$5"
  local note="$6"
  local timestamp
  timestamp="$(now_utc)"
  local tmp
  tmp="$(mktemp)"
  awk -F '\t' -v OFS='\t' \
    -v phase="${phase}" \
    -v status="${status}" \
    -v local_validation="${local_validation}" \
    -v phase_end_ci="${phase_end_ci}" \
    -v ci_result="${ci_result}" \
    -v timestamp="${timestamp}" \
    -v note="${note}" '
      NR == 1 { print; next }
      $1 == phase {
        $2 = status
        $3 = local_validation
        $4 = phase_end_ci
        $5 = ci_result
        $6 = timestamp
        $7 = note
      }
      { print }
    ' "${STATE_FILE}" >"${tmp}"
  mv "${tmp}" "${STATE_FILE}"
}

print_status() {
  ensure_state_file
  printf 'Domain write-kernel rollout tracker\n'
  printf 'State file: %s\n\n' "${STATE_FILE}"
  printf 'CI cadence: local-only inside a phase; exactly one CI check after each completed phase is pushed.\n\n'

  local index
  for index in "${!PHASE_IDS[@]}"; do
    local id="${PHASE_IDS[$index]}"
    printf 'Phase %s: %s\n' "${id}" "${PHASE_NAMES[$index]}"
    printf '  Status: %s\n' "$(state_value "${id}" status)"
    printf '  Scope: %s\n' "${PHASE_SCOPES[$index]}"
    printf '  Local gate: %s\n' "${PHASE_LOCAL_GATES[$index]}"
    printf '  Phase-end CI: %s (%s)\n' "$(state_value "${id}" phase_end_ci)" "$(state_value "${id}" ci_result)"
    printf '  Acceptance: %s\n' "${PHASE_ACCEPTANCE[$index]}"
    printf '  Note: %s\n\n' "$(state_value "${id}" note)"
  done
}

print_report() {
  ensure_state_file
  cat <<'REPORT'
Final report summary

Root problem:
  MemberLifecycle was only the first visible failure. The deeper issue is that
  business writes, subject resolution, policy, and effects did not share a single
  entry ticket.

Core diagnosis:
  1. Callers owned write capability first, then were asked to remember policy.
  2. Event/Reminder and business facts mixed owner, subject, assignee,
     display target, and effect target as raw strings.
  3. Disposition/resolver signals were advisory, not capability tokens.
  4. Restore/sync/import could still bypass user-command policy.
  5. Audits checked call shapes more than impossibility of invalid state.

Target architecture:
  Raw Intent / DTO / Restore Record
  -> DomainSubjectResolution
  -> DomainPolicyAuthorizer
  -> AuthorizedMutationPlan / token
  -> ScopedPersistenceWriter
  -> Typed Effects Dispatcher
  -> Revision / Sync / Notification / Ledger / Reward

CI cadence:
  Each phase is developed and verified locally. Only when that phase is complete
  do we commit/push once and inspect one CI run. CI is not a heartbeat.

Final acceptance:
  - Commands cannot construct unauthorized member/economy/reminder/ledger writes.
  - Restore/sync cannot construct raw persistence bypass.
  - Deep link, delete, filter, overdue, task, notification, and ledger consume typed resolution.
  - New link type without taxonomy registration fails audit.
  - Bad/good fixtures cover constructor, matcher, assignee-only, indirect owner,
    restore/apply, and effects bypass.
  - Final fresh review has P0/P1 = 0.
REPORT
}

cmd="${1:-status}"
case "${cmd}" in
  init)
    if [[ -f "${STATE_FILE}" ]]; then
      echo "State file already exists: ${STATE_FILE}"
    else
      ensure_state_file
      echo "Created ${STATE_FILE}"
    fi
    ;;
  status)
    print_status
    ;;
  report)
    print_report
    ;;
  start)
    ensure_state_file
    phase="${2:-}"
    [[ -n "${phase}" ]] || { usage; exit 2; }
    phase_index "${phase}" >/dev/null
    update_state "${phase}" "in_progress" "local validation in progress" "pending" "pending" "CI is blocked until this phase is complete."
    print_status
    ;;
  complete)
    ensure_state_file
    phase="${2:-}"
    summary="${3:-local validation passed}"
    [[ -n "${phase}" ]] || { usage; exit 2; }
    phase_index "${phase}" >/dev/null
    update_state "${phase}" "completed" "${summary}" "required" "pending" "Commit and push once, then record one CI run."
    print_status
    ;;
  ci)
    ensure_state_file
    phase="${2:-}"
    run_url="${3:-}"
    result="${4:-}"
    note="${5:-}"
    [[ -n "${phase}" && -n "${run_url}" && -n "${result}" ]] || { usage; exit 2; }
    phase_index "${phase}" >/dev/null
    case "${result}" in
      pass|fail|blocked) ;;
      *) echo "CI result must be pass, fail, or blocked." >&2; exit 2 ;;
    esac
    if [[ "$(state_value "${phase}" status)" != "completed" ]]; then
      echo "Refusing to record CI for phase ${phase}: phase is not completed locally." >&2
      echo "Only phase-end CI is allowed by this plan." >&2
      exit 1
    fi
    update_state "${phase}" "completed" "$(state_value "${phase}" local_validation)" "${run_url}" "${result}" "${note}"
    print_status
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
