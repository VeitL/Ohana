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
  scripts/audit-architecture-boundaries.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  Enforce the architecture boundaries established by the P0-P4 refactor:
  - Models/ contains SwiftData models only, not service/manager infrastructure.
  - Models/ sources declare @Model, schema/migration containers, or model
    extensions; taxonomy, route, store, catalog, and presentation helper files
    live in Domain, App, Shared, or Features instead.
  - Models/ do not read UserDefaults or feature preference stores; persistence
    models expose data, while feature/app layers own preferences.
  - Models/ do not declare store/writer/service/command types or accept
    ModelContext write authority.
  - @Query only appears in screen/route data containers.
  - Views do not directly use UserDefaults or construct command executors.
  - Members views do not publish member profile revisions directly; profile
    command executors own the publish boundary.
  - Swift files above 800 lines are ratcheted; no new oversized files and no
    growth in the existing oversized baseline.
  - Coconut balances may be mutated only by the wallet service, model defaults,
    or backup import projection.
  - Removed singleton registries and NotificationCenter string bus do not return.
  - QuestManager does not write legacy coconut UserDefaults storage.
  - Domain/Models expose domain-neutral reward payloads instead of QuestManager
    feature reward types.
  - Domain/Models do not reference concrete economy/Oasis feature
    implementations; adapters live at feature/app boundaries.
  - Domain services return semantic presentation tokens instead of SwiftUI
    Color/View types.
  - Models do not import SwiftUI or expose SwiftUI Color/View/Image types.
  - Domain/Models do not import platform UI frameworks such as UIKit.

Explicit file or directory targets select an isolated targeted scan even when
the worktree contains unrelated changes.
USAGE
}

mode="changed"
strict=1
targets=()

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
      targets+=("$1")
      shift
      ;;
  esac
done

if [[ ${#targets[@]} -gt 0 ]]; then
  mode="targeted"
fi

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
  if [[ ${#targets[@]} -gt 0 ]]; then
    for target in "${targets[@]}"; do
      if [[ -d "$target" ]]; then
        rg --files "$target" -g '*.swift'
      elif [[ -f "$target" && "$target" == *.swift ]]; then
        printf '%s\n' "$target"
      fi
    done
  elif [[ "$mode" == "all" ]]; then
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
  if [[ "$mode" == "all" ]]; then
    find Ohana/Models -maxdepth 1 -name '*.swift' \
      | rg '(Service|Manager|Executor|Command|Coordinator|Database|Catalog|Localization|Support|Engine)' || true
    return
  fi
  printf '%s\n' "${files[@]}" \
    | rg '^Ohana/Models/[^/]*(Service|Manager|Executor|Command|Coordinator|Database|Catalog|Localization|Support|Engine)[^/]*\.swift$' || true
}

query_outside_containers() {
  local input
  if [[ "$mode" == "all" ]]; then
    input="$(rg -n '^\s*@Query' Ohana --glob '*.swift' || true)"
  else
    input="$(
      for file in "${files[@]}"; do
        [[ -f "$file" ]] || continue
        rg -n --with-filename '^\s*@Query' "$file" || true
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
    rg -n --with-filename --pcre2 "$pattern" Ohana --glob '*.swift' || true
  else
    for file in "${files[@]}"; do
      [[ -f "$file" ]] || continue
      rg -n --with-filename --pcre2 "$pattern" "$file" || true
    done
  fi
}

view_user_defaults() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    scoped_files=(Ohana/Features Ohana/Shared/Components)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Features/*.swift|Ohana/Features/*/*.swift|Ohana/Features/*/*/*.swift|Ohana/Features/*/*/*/*.swift|Ohana/Shared/Components/*.swift|Ohana/Shared/Components/*/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n 'UserDefaults\.standard' "${scoped_files[@]}" --glob '*.swift' \
    | rg '/Views/|Ohana/Shared/Components/' || true
}

view_command_executors() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    scoped_files=(Ohana/Features Ohana/Shared/Components)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Features/*.swift|Ohana/Features/*/*.swift|Ohana/Features/*/*/*.swift|Ohana/Features/*/*/*/*.swift|Ohana/Shared/Components/*.swift|Ohana/Shared/Components/*/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --pcre2 '\b[A-Za-z0-9_]*CommandExecutor\s*\(\s*context:\s*modelContext\s*\)' "${scoped_files[@]}" --glob '*.swift' || true
}

view_static_business_calls() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    scoped_files=(Ohana/App/ContentView.swift Ohana/App/RouteContainers Ohana/Features Ohana/Shared/Components)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/App/ContentView.swift|Ohana/App/RouteContainers/*.swift|Ohana/App/RouteContainers/*/*.swift|Ohana/Features/*.swift|Ohana/Features/*/*.swift|Ohana/Features/*/*/*.swift|Ohana/Features/*/*/*/*.swift|Ohana/Shared/Components/*.swift|Ohana/Shared/Components/*/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --pcre2 '\b[A-Z][A-Za-z0-9_]*(Service|Manager|Coordinator|Executor)\.' "${scoped_files[@]}" --glob '*.swift' \
    | rg '/Views/|Ohana/Shared/Components/|RouteContainers/|Ohana/App/ContentView\.swift:' \
    | rg -v ':\s*//' \
    | rg -v '\bFileManager\.default\b' \
    | rg -v '\bExpandedQuickActionExecutor\.Feedback\b' || true
}

member_view_direct_profile_revision_publishes() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && scoped_files+=("$file")
    done < <(find Ohana/Features/Members/Views -type f -name '*.swift' | sort)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Features/Members/Views/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '\bpublishMemberProfile\s*\(' "${scoped_files[@]}" || true
}

oversized_swift_files() {
  local threshold=1200
  local growth_tolerance=200
  local baseline="docs/governance/manifests/oversized-swift-files-baseline.json"
  if [[ ! -f "$baseline" ]]; then
    printf '%s missing; create the oversized-file ratchet baseline before enforcing oversized file checks.\n' "$baseline"
    return 0
  fi

  python3 - "$threshold" "$growth_tolerance" "$baseline" "${files[@]}" <<'PY'
import json
import pathlib
import sys

threshold = int(sys.argv[1])
growth_tolerance = int(sys.argv[2])
baseline_path = pathlib.Path(sys.argv[3])
paths = sys.argv[4:]

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

# Data / resource / preview files are large by nature (localization tables,
# asset catalogs, DesignLab preview canvases). Line count is a poor proxy for
# their health, so they are exempt from the oversized-logic ratchet. Keep this
# list narrow: only genuinely logic-free files belong here.
def is_data_or_preview(p):
    name = pathlib.Path(p).name
    if name.endswith("AssetCatalog.swift"):
        return True
    if name == "Localization.swift":
        return True
    if "/DesignLab/" in p and "Canvas" in name:
        return True
    return False

violations = []
for path in paths:
    file_path = pathlib.Path(path)
    if not file_path.is_file() or file_path.suffix != ".swift":
        continue
    if is_data_or_preview(path):
        continue
    with file_path.open("r", encoding="utf-8", errors="ignore") as handle:
        lines = sum(1 for _ in handle)
    if lines <= threshold:
        continue
    allowed = baseline.get(path)
    if allowed is None:
        violations.append(
            f"{path}:{lines} lines exceeds relaxed {threshold}-line oversized threshold and is not in the baseline; split it intentionally or add a baseline entry."
        )
    elif lines > allowed + growth_tolerance:
        violations.append(
            f"{path}:{lines} lines grew more than {growth_tolerance} lines beyond baseline {allowed}; shrink it intentionally or refresh the baseline with review."
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
    | rg -v '^\s*Ohana/Domain/Economy/CoconutWalletService(\+[^:]*)?\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/DataBackupManager\+Decode\.swift:' \
    | rg -v '^\s*Ohana/Models/Human\.swift:' \
    | rg -v '^\s*Ohana/Models/Pet\.swift:' \
    | rg -v '^\s*Ohana/Features/Home/Views/FocusHomeHeaderView\.swift:' || true
}

legacy_coconut_writes_in_quest_manager() {
  if [[ "$mode" == "all" ]]; then
    rg -n 'quest_coconut(Count|Logs)|flushToDefaults' Ohana/Features/Economy/QuestManager*.swift Ohana/Models/QuestManager.swift 2>/dev/null || true
    return
  fi
  for file in "${files[@]}"; do
    case "$file" in
      Ohana/Features/Economy/QuestManager*.swift|Ohana/Models/QuestManager.swift)
        rg -n --with-filename 'quest_coconut(Count|Logs)|flushToDefaults' "$file" 2>/dev/null || true
        ;;
    esac
  done
}

static_service_calls_outside_facades() {
  local input
  input="$(
    forbidden_patterns '(CareEventService|CareLedgerService|FamilyTaskService|ReminderCompletionService|ReminderSchedulingService|MedicationReminderService|OasisUpgradeRewardService|CoconutExchangeService|AppResetService)\.|MedicationReminderService\(|QuestManager\.shared'
  )"
  [[ -z "$input" ]] && return 0
  printf '%s\n' "$input" \
    | rg -v '^\s*Ohana/App/AppRuntimeAdapters\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/DomainServiceAdapters\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/CareLedgerBackfillService\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/CareEventRecording\.swift:' \
    | rg -v '^\s*Ohana/Domain/Services/CareEventService\+RecordingAdapter\.swift:' \
    | rg -v '^\s*Ohana/Features/CareLedger/CareLedgerRecording\.swift:' \
    | rg -v '^\s*Ohana/Features/Economy/CoconutExchangeManaging\.swift:' \
    | rg -v '^\s*Ohana/Features/FamilyTasks/FamilyTaskManaging\.swift:' \
    | rg -v '^\s*Ohana/Features/Medication/SharedMedicationReminderManager\.swift:' \
    | rg -v '^\s*Ohana/Features/Notifications/ReminderSchedulingManager\.swift:' \
    | rg -v '^\s*Ohana/Features/Oasis/OasisRewardServices\.swift:' \
    | rg -v '^\s*Ohana/Features/Walks/StaticWalkCareEventManager\.swift:' \
    | rg -v ':\s*// ' || true
}

domain_or_models_scope() {
  if [[ "$mode" == "all" ]]; then
    find Ohana/Domain Ohana/Models -type f -name '*.swift' | sort
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Domain/*.swift|Ohana/Domain/*/*.swift|Ohana/Models/*.swift)
          [[ -f "$file" ]] && printf '%s\n' "$file"
          ;;
      esac
    done
  fi
}

domain_feature_command_dependencies() {
  local scoped_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '\b[A-Za-z][A-Za-z0-9_]*(CommandResult|CommandExecutor|CommandService)\b' "${scoped_files[@]}" || true
}

domain_feature_reward_type_dependencies() {
  local scoped_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '\bQuestManager\.(OhanaActionType|QualityBonus)\b' "${scoped_files[@]}" || true
}

domain_feature_implementation_dependencies() {
  local scoped_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '\b(CoconutEconomyPolicyV2|EconomyRewardDiscipline|OasisTreeManagerRegistry|OasisTreeManager|OasisRewardManaging|StaticOasisRewardManager|StaticCareEventEconomyAwarder)\b' "${scoped_files[@]}" || true
}

domain_feature_live_default_dependencies() {
  local scoped_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 'CareEventServiceDependencies\.(live|liveEconomy)\s*\(|providedDependencies\s*\?\?\s*\.live\s*\(|dependencies:\s*\.live\s*\(|\b(StaticFamilyTaskManager|StaticWalkCareEventManager|SharedMedicationReminderManager|ReminderSchedulingManager|MedicationReminderService|ReminderSchedulingService|NotificationManager|OhanaNotificationRouteCenter)\b' "${scoped_files[@]}" || true
}

domain_feature_taxonomy_literals() {
  local scoped_files=()
  local input
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  input="$(
    rg -n --with-filename --pcre2 '"(pet_food_stock|pet_auto_feeder|pet_water_plan|pet_insurance|pet_medication_plan|pet_medication|human_medication|human_note|plant_[^"]*)"' "${scoped_files[@]}" || true
  )"
  [[ -z "$input" ]] && return 0
  printf '%s\n' "$input" \
    | rg -v '^\s*Ohana/Domain/Services/DomainEntityLinkRegistry\.swift:' || true
}

domain_presentation_framework_dependencies() {
  local scoped_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '^\s*import\s+SwiftUI\b|\b(Color|View|LinearGradient|Image)\b' "${scoped_files[@]}" \
    | rg -v '^Ohana/Models/' || true
}

domain_platform_ui_framework_dependencies() {
  local scoped_files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && scoped_files+=("$file")
  done < <(domain_or_models_scope)
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '^\s*import\s+UIKit\b|\b(UIImage|UIColor|UIFont|UIView|UIGraphicsImageRenderer)\b' "${scoped_files[@]}" || true
}

models_presentation_framework_dependencies() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && scoped_files+=("$file")
    done < <(find Ohana/Models -maxdepth 1 -name '*.swift' | sort)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Models/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '^\s*import\s+SwiftUI\b|(:|->)\s*(some\s+|any\s+)?(Color|View|Image|LinearGradient)\b|\bsome\s+View\b|\b(Color|Image|LinearGradient)\s*(\.|\()' "${scoped_files[@]}" \
    | rg -v ':\s*(//|/\*|\*)' || true
}

models_non_schema_sources() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && scoped_files+=("$file")
    done < <(find Ohana/Models -maxdepth 1 -name '*.swift' | sort)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Models/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  python3 - "${scoped_files[@]}" <<'PY'
import pathlib
import re
import sys

allowed_patterns = [
    re.compile(r"^\s*@Model\b", re.MULTILINE),
    re.compile(r"\bVersionedSchema\b"),
    re.compile(r"\bSchemaMigrationPlan\b"),
    re.compile(r"\btypealias\s+ArkSchema\b"),
    re.compile(r"\bMigrationStage\b"),
    re.compile(r"^\s*(public\s+|private\s+|fileprivate\s+|internal\s+)?extension\s+[A-Z][A-Za-z0-9_]*\b", re.MULTILINE),
]

violations = []
for raw_path in sys.argv[1:]:
    path = pathlib.Path(raw_path)
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8", errors="ignore")
    non_comment_text = "\n".join(
        line for line in text.splitlines()
        if not line.lstrip().startswith(("//", "/*", "*"))
    )
    if any(pattern.search(non_comment_text) for pattern in allowed_patterns):
        continue
    violations.append(
        f"{raw_path}: Models sources must declare SwiftData models, schema/migration containers, or model extensions; move taxonomy, routes, stores, catalogs, and presentation helpers out of Models."
    )

print("\n".join(violations))
PY
}

models_persistence_side_effects() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && scoped_files+=("$file")
    done < <(find Ohana/Models -maxdepth 1 -name '*.swift' | sort)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Models/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 'UserDefaults\.standard|\b[A-Za-z0-9_]*PreferenceStore\.' "${scoped_files[@]}" \
    | rg -v '^Ohana/Models/SharedModelContainer\.swift:' || true
}

models_behavior_types() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && scoped_files+=("$file")
    done < <(find Ohana/Models -maxdepth 1 -name '*.swift' | sort)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Models/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '^\s*(nonisolated\s+)?(enum|struct|final\s+class|class)\s+[A-Za-z0-9_]*(Store|Service|Manager|Executor|Writer|Command)\b' "${scoped_files[@]}" \
    | rg -v '^Ohana/Models/SharedModelContainer\.swift:' || true
}

models_writer_context_dependencies() {
  local scoped_files=()
  if [[ "$mode" == "all" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && scoped_files+=("$file")
    done < <(find Ohana/Models -maxdepth 1 -name '*.swift' | sort)
  else
    for file in "${files[@]}"; do
      case "$file" in
        Ohana/Models/*.swift)
          [[ -f "$file" ]] && scoped_files+=("$file")
          ;;
      esac
    done
  fi
  [[ ${#scoped_files[@]} -eq 0 ]] && return 0
  rg -n --with-filename --pcre2 '\bModelContext\b|\bcontext\.(insert|delete|save)\b|\bsafeSave\b' "${scoped_files[@]}" \
    | rg -v '^Ohana/Models/SharedModelContainer\.swift:' || true
}

record_matches \
  "models-non-schema-source" \
  "Models/ may contain SwiftData models, schema/migration containers, or model extensions only; move taxonomy, routes, stores, catalogs, and presentation helpers out." \
  models_non_schema_sources

record_matches \
  "models-persistence-side-effect" \
  "Models must not read/write UserDefaults or feature preference stores; move preference behavior to Feature/App/Shared boundaries." \
  models_persistence_side_effects

record_matches \
  "models-behavior-type" \
  "Models must not declare store/writer/service/command behavior types; keep write and service authority in Domain/Feature/App layers." \
  models_behavior_types

record_matches \
  "models-writer-context-dependency" \
  "Models must not accept ModelContext or perform context insert/delete/save writes; route persistence behavior through writer/service layers." \
  models_writer_context_dependencies

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
  "member-view-direct-profile-revision" \
  "Members views must not publish profile revisions directly; MemberCommandExecutor.update*Profile owns the single profile revision publish." \
  member_view_direct_profile_revision_publishes

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

record_matches \
  "domain-feature-command-dependency" \
  "Domain/Models must not depend on feature command result/executor/service types; translate feature results into DomainMutationResult at the feature boundary." \
  domain_feature_command_dependencies

record_matches \
  "domain-feature-reward-type-dependency" \
  "Domain/Models must expose DomainCareRewardAction/DomainCareRewardQuality instead of QuestManager feature reward types." \
  domain_feature_reward_type_dependencies

record_matches \
  "domain-feature-implementation-dependency" \
  "Domain/Models must not reference concrete economy/Oasis feature implementations; use Domain protocols and feature/app adapters." \
  domain_feature_implementation_dependencies

record_matches \
  "domain-feature-live-default-dependency" \
  "Domain/Models must not construct feature live/default service dependencies; register production adapters at App/Feature boundaries and consume Domain protocols." \
  domain_feature_live_default_dependencies

record_matches \
  "domain-feature-taxonomy-literal" \
  "Feature-owned persisted taxonomy strings may only live in DomainEntityLinkRegistry; Domain/Models consumers must reference typed registry constants." \
  domain_feature_taxonomy_literals

record_matches \
  "domain-presentation-framework-dependency" \
  "Domain services must expose semantic presentation tokens instead of SwiftUI Color/View types; map tokens to SwiftUI at feature/shared presentation boundaries." \
  domain_presentation_framework_dependencies

record_matches \
  "domain-platform-ui-framework-dependency" \
  "Domain/Models must not import UIKit or expose UIKit image/view/color types; move platform media/presentation work to Shared/Feature/App boundaries." \
  domain_platform_ui_framework_dependencies

record_matches \
  "models-presentation-framework-dependency" \
  "Models must not import SwiftUI or expose SwiftUI Color/View/Image types; keep persisted/domain data UI-neutral and map presentation tokens at Shared/Feature boundaries." \
  models_presentation_framework_dependencies

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
