#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

usage() {
  cat <<'USAGE'
Usage:
  scripts/audit-architecture-boundaries.sh [--changed|--all|--soft]

Purpose:
  Enforce the architecture boundaries established by the P0-P4 refactor:
  - Models/ contains SwiftData models only, not service/manager infrastructure.
  - @Query only appears in screen/route data containers.
  - Views do not directly use UserDefaults or construct command executors.
  - Swift files above 800 lines are ratcheted; no new oversized files and no
    growth in the existing oversized baseline.
  - Coconut balances may be mutated only by the wallet service, model defaults,
    or backup import projection.
  - Removed singleton registries and NotificationCenter string bus do not return.
  - QuestManager does not write legacy coconut UserDefaults storage.
USAGE
}

mode="changed"
strict=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed)
      mode="changed"
      shift
      ;;
    --all)
      mode="all"
      shift
      ;;
    --soft)
      strict=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

warnings_file="$(mktemp)"
trap 'rm -f "$warnings_file"' EXIT

record_matches() {
  local id="$1"
  local message="$2"
  shift 2
  local matches
  matches="$("$@" || true)"
  if [[ -n "$matches" ]]; then
    {
      printf '[%s]\n%s\n' "$id" "$message"
      printf '%s\n\n' "$matches"
    } >> "$warnings_file"
  fi
}

changed_swift_files() {
  {
    git diff --name-only --diff-filter=ACMR HEAD -- Ohana 2>/dev/null || true
    git ls-files --others --exclude-standard -- Ohana 2>/dev/null || true
  } | awk '/\.swift$/ { print }' | sort -u
}

swift_scope() {
  if [[ "$mode" == "all" ]]; then
    find Ohana -type f -name '*.swift' | sort
  else
    changed_swift_files
  fi
}

files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(swift_scope)

if [[ ${#files[@]} -eq 0 && "$mode" != "all" ]]; then
  echo "Architecture boundaries: no Swift files to scan."
  exit 0
fi

model_pollution() {
  find Ohana/Models -maxdepth 1 -name '*.swift' \
    | rg '(Service|Manager|Executor|Command|Coordinator|Database|Catalog|Localization|Support|Engine)' || true
}

query_outside_containers() {
  local input
  if [[ "$mode" == "all" ]]; then
    input="$(rg -n '^\s*@Query' Ohana --glob '*.swift' || true)"
  else
    input="$(
      for file in "${files[@]}"; do
        [[ -f "$file" ]] || continue
        rg -n '^\s*@Query' "$file" || true
      done
    )"
  fi
  [[ -z "$input" ]] && return 0
  printf '%s\n' "$input" \
    | rg -v '(DataContainer\.swift|RouteContainer\.swift|Ohana/App/RouteContainers/.*\.swift):' || true
}

forbidden_patterns() {
  local pattern="$1"
  if [[ "$mode" == "all" ]]; then
    rg -n --pcre2 "$pattern" Ohana --glob '*.swift' || true
  else
    for file in "${files[@]}"; do
      [[ -f "$file" ]] || continue
      rg -n --pcre2 "$pattern" "$file" || true
    done
  fi
}

view_user_defaults() {
  local roots=(Ohana/Views Ohana/Features)
  rg -n 'UserDefaults\.standard' "${roots[@]}" --glob '*.swift' \
    | rg '/Views/' || true
}

view_command_executors() {
  local roots=(Ohana/Views Ohana/Features)
  rg -n --pcre2 '\b[A-Za-z0-9_]*CommandExecutor\s*\(\s*context:\s*modelContext\s*\)' "${roots[@]}" --glob '*.swift' || true
}

view_static_business_calls() {
  local roots=(Ohana/ContentView.swift Ohana/App/RouteContainers Ohana/Views Ohana/Features)
  rg -n --pcre2 '\b[A-Z][A-Za-z0-9_]*(Service|Manager|Coordinator|Executor)\.' "${roots[@]}" --glob '*.swift' \
    | rg '/Views/|RouteContainers/|Ohana/ContentView\.swift:' \
    | rg -v ':\s*//' \
    | rg -v '\bFileManager\.default\b' \
    | rg -v '\bExpandedQuickActionExecutor\.Feedback\b' || true
}

oversized_swift_files() {
  local threshold=800
  local baseline="docs/governance/manifests/oversized-swift-files-baseline.json"
  if [[ ! -f "$baseline" ]]; then
    printf '%s missing; create the 800-line ratchet baseline before enforcing oversized file checks.\n' "$baseline"
    return 0
  fi

  python3 - "$threshold" "$baseline" "${files[@]}" <<'PY'
import json
import pathlib
import sys

threshold = int(sys.argv[1])
baseline_path = pathlib.Path(sys.argv[2])
paths = sys.argv[3:]

try:
    payload = json.loads(baseline_path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"{baseline_path}: failed to read oversized baseline: {exc}")
    sys.exit(0)

baseline = {
    item["path"]: int(item["lines"])
    for item in payload.get("files", [])
    if "path" in item and "lines" in item
}

violations = []
for path in paths:
    file_path = pathlib.Path(path)
    if not file_path.is_file() or file_path.suffix != ".swift":
        continue
    with file_path.open("r", encoding="utf-8", errors="ignore") as handle:
        lines = sum(1 for _ in handle)
    if lines <= threshold:
        continue
    allowed = baseline.get(path)
    if allowed is None:
        violations.append(
            f"{path}:{lines} lines exceeds {threshold}-line ratchet and is not in the baseline; split it first."
        )
    elif lines > allowed:
        violations.append(
            f"{path}:{lines} lines grew beyond baseline {allowed}; shrink it or split into smaller files."
        )

print("\n".join(violations))
PY
}

coconut_balance_writes_outside_wallet() {
  local input
  input="$(
    forbidden_patterns '(\.|self\.)coconutBalance\s*(=|\+=|-=)'
  )"
  [[ -z "$input" ]] && return 0
  printf '%s\n' "$input" \
    | rg -v '^\s*Ohana/Domain/Economy/CoconutWalletService\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/DataBackupManager\+Decode\.swift:' \
    | rg -v '^\s*Ohana/Models/Human\.swift:' \
    | rg -v '^\s*Ohana/Models/Pet\.swift:' \
    | rg -v '^\s*Ohana/Features/Home/Views/FocusHomeHeaderView\.swift:' || true
}

legacy_coconut_writes_in_quest_manager() {
  rg -n 'quest_coconut(Count|Logs)|flushToDefaults' Ohana/Features/Economy/QuestManager*.swift Ohana/Models/QuestManager.swift 2>/dev/null || true
}

static_service_calls_outside_facades() {
  local input
  input="$(
    forbidden_patterns '(CareEventService|CareLedgerService|FamilyTaskService|ReminderCompletionService|ReminderSchedulingService|MedicationReminderService|OasisUpgradeRewardService|CoconutExchangeService|AppResetService)\.|MedicationReminderService\(|QuestManager\.shared'
  )"
  [[ -z "$input" ]] && return 0
  printf '%s\n' "$input" \
    | rg -v '^\s*Ohana/Domain/Services/AppInfrastructureAdapters\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/CareLedgerBackfillService\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/CareEventRecording\.swift:' \
    | rg -v '^\s*Ohana/Features/CareLedger/CareLedgerRecording\.swift:' \
    | rg -v '^\s*Ohana/Features/Economy/CoconutExchangeManaging\.swift:' \
    | rg -v '^\s*Ohana/Features/FamilyTasks/FamilyTaskManaging\.swift:' \
    | rg -v '^\s*Ohana/Features/Oasis/OasisRewardServices\.swift:' \
    | rg -v ':\s*// ' || true
}

record_matches \
  "models-layer-pollution" \
  "Service/manager/executor/support files must not live directly under Ohana/Models." \
  model_pollution

record_matches \
  "query-outside-container" \
  "@Query may only appear in DataContainer/RouteContainer files or App route containers." \
  query_outside_containers

record_matches \
  "removed-global-registry" \
  "QuestManagerRegistry and DomainRevisionCenterRegistry were removed; inject dependencies explicitly." \
  forbidden_patterns 'QuestManagerRegistry|DomainRevisionCenterRegistry'

record_matches \
  "notification-string-bus" \
  "Do not reintroduce NotificationCenter.default.post for cross-page sync; publish typed domain revisions." \
  forbidden_patterns 'NotificationCenter\.default\.post'

record_matches \
  "view-userdefaults" \
  "Views must not read/write UserDefaults.standard directly; use AppStorage, stores, read models, or services." \
  view_user_defaults

record_matches \
  "view-command-executor" \
  "Views must not construct command executors without AppServices injection." \
  view_command_executors

record_matches \
  "view-static-business-call" \
  "Views must call injected AppServices protocols instead of static Service/Manager/Coordinator/Executor entry points." \
  view_static_business_calls

record_matches \
  "oversized-swift-file" \
  "Swift files above 800 lines are allowed only as a shrinking ratchet baseline; new or growing oversized files must be split." \
  oversized_swift_files

record_matches \
  "coconut-balance-direct-write" \
  "Business code must mutate coconut balances through CoconutWalletService so account, ledger, and cache stay transactional." \
  coconut_balance_writes_outside_wallet

record_matches \
  "quest-legacy-coconut-defaults" \
  "QuestManager must not read/write legacy quest_coconutCount or quest_coconutLogs storage." \
  legacy_coconut_writes_in_quest_manager

record_matches \
  "static-service-business-call" \
  "Business code must use AppServices/protocol instances; legacy static service calls are allowed only inside adapter/facade/backfill boundaries." \
  static_service_calls_outside_facades

if [[ ! -s "$warnings_file" ]]; then
  echo "Architecture boundaries: passed (${mode})."
  exit 0
fi

echo "Architecture boundaries: failed (${mode})." >&2
echo >&2
cat "$warnings_file" >&2

if [[ "$strict" -eq 1 ]]; then
  exit 1
fi
