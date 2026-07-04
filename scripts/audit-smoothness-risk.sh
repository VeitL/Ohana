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
  scripts/audit-smoothness-risk.sh [--changed|--all|--soft] [Swift files or directories...]

Purpose:
  Catch common mature-app smoothness risks in high-frequency SwiftUI surfaces:
  broad @Query usage, synchronous image/file decoding in views, render-path
  external-storage probes, eager ShareLink exports, runtime loops, main-actor
  read-model aggregation, imperative SwiftData fetches in views, and unscoped
  detached tasks.

Scope note:
  The scan root is the whole Ohana/ tree. Never narrow this back to a
  subdirectory list: directory refactors silently removed 88% of files from
  this audit once before. The fixture tests in scripts/tests/ enforce a
  minimum scanned-file floor.

Allowlist:
  Add "smoothness: allow <reason>" on the line for deliberate exceptions.
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

collect_files() {
  if [[ ${#targets[@]} -gt 0 ]]; then
    for target in "${targets[@]}"; do
      if [[ -d "$target" ]]; then
        find "$target" -type f -name '*.swift'
      elif [[ -f "$target" && "$target" == *.swift ]]; then
        printf '%s\n' "$target"
      fi
    done
    return
  fi

  if [[ "$mode" == "all" ]]; then
    find Ohana -type f -name '*.swift'
    return
  fi

  {
    git diff --name-only --diff-filter=ACMR HEAD -- Ohana 2>/dev/null || true
    git ls-files --others --exclude-standard -- Ohana 2>/dev/null || true
  } | awk '/\.swift$/ { print }'
}

files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && files+=("$file")
done < <(collect_files | sort -u)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Smoothness risk audit: no Swift files to scan."
  exit 0
fi

warnings_file="$(mktemp)"
trap 'rm -f "$warnings_file"' EXIT

# Scope filtering happens in-process (cheap), then ONE rg invocation per rule
# across the scoped files (see audit-ui-v4.sh for why the per-file loop must
# never come back). Output format is load-bearing.
scan() {
  local id="$1"
  local pattern="$2"
  local message="$3"
  local scope_regex="$4"
  local exclude_regex="${5:-}"

  local scoped=()
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    if [[ -n "$scope_regex" ]] && ! [[ "$file" =~ $scope_regex ]]; then
      continue
    fi
    if [[ -n "$exclude_regex" ]] && [[ "$file" =~ $exclude_regex ]]; then
      continue
    fi
    scoped+=("$file")
  done
  [[ ${#scoped[@]} -eq 0 ]] && return 0

  rg --pcre2 -nH --no-heading "$pattern" "${scoped[@]}" 2>/dev/null \
    | while IFS= read -r match; do
        case "$match" in
          *"smoothness: allow"*) continue ;;
        esac
        printf '[%s] %s\n  %s\n\n' "$id" "$match" "$message" >> "$warnings_file"
      done || true
}

scan \
  "broad-query-high-frequency" \
  '@Query' \
  "High-frequency and reusable SwiftUI surfaces should receive value snapshots from containers/read models instead of owning broad live queries." \
  '(^|/)Views/|^Ohana/Shared/' \
  '(Data|Route)Container\.swift$|^Ohana/App/RouteContainers/'

scan \
  "sync-image-decode-in-view" \
  'Data\(contentsOf:|UIImage\(data:|UIImage\(contentsOfFile:' \
  "Image/file decoding in a view path can steal the finger-first frame; prefer prepared assets, snapshot caches, or route-scoped async decode." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "direct-attachment-image-decode-in-view" \
  'AttachmentImageDecoder\.decode\s*\(' \
  "Views should not call the low-level attachment decoder directly; use AsyncDecodedImageView or MediaThumbnailProvider so thumbnails are downsampled, cached, coalesced, and memory-warning evicted." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-external-storage-signature" \
  '\.(avatarImageData|cardPopoutImageData|photoData|imageData|attachmentData|mapSnapshotData|routeLocationsData)\?\.(count|prefix|suffix|first|last|base64EncodedString)(\(|\b)' \
  "SwiftUI render paths and task/onChange keys must not probe external-storage Data for signatures, counts, or exports; build light revision keys/snapshots at explicit invalidation points or in media services." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-local-media-data-key" \
  '\b(avatarImageData|selectedPhotoData|photoData|imageData|attachmentData)\?\.(count|prefix|suffix|first|last|base64EncodedString)(\(|\b)' \
  "SwiftUI render paths and task/onChange keys must not probe local media Data for identity or signatures; maintain an explicit revision/signature at the mutation boundary." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-external-storage-signature-map" \
  '\.(avatarImageData|cardPopoutImageData|photoData|imageData|attachmentData|mapSnapshotData|routeLocationsData)\.map\s*(\(\s*FocusWalletAvatarCache\.signature|\{[^\n}]*FocusWalletAvatarCache\.signature)' \
  "SwiftUI render paths and task/onChange keys must not derive media signatures by mapping external-storage Data; use persisted lightweight signatures or prepared media snapshots." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-live-avatar-data-parameter" \
  '(^|[^A-Za-z0-9_])imageData:\s*(isEditing\s*\?\s*avatarImageData\s*:\s*)?(pet|human|plant)\.avatarImageData|(^|[^A-Za-z0-9_])imageData:\s*(pet|human|plant)\.hasAvatarImageAttachment\s*\?\s*(pet|human|plant)\.avatarImageData\s*:\s*nil' \
  "SwiftUI render paths must not pass live avatarImageData through imageData parameters; pass lightweight signatures plus a route-scoped media provider or prepared snapshot instead." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "feature-hub-live-avatar-provider" \
  '(pet|human|plant)\.hasAvatarImageAttachment\s*\?\s*(pet|human|plant)\.avatarImageData\s*:\s*nil' \
  "FeatureHub avatar entry points must pass a lightweight signature plus persistent model id; do not hide live external-storage avatar reads inside imageDataProvider closures." \
  '(^|/)(FeatureHubComponents|HumanModuleV4Components|PetRetentionHubView|PetBondVaultView|PetMomentsHubView|QuickMomentSheet|PetMedicationDetailSheet|PetMedicationView|HumanWeightDashboardContent|PetWeightDashboardContent|HumanExpenseDashboardContent|PetExpenseDashboardContent|PetAllFeaturesSheet|PlantAllFeaturesSheet|SmoothnessBadSnapshotBuilder)\.swift$'

scan \
  "avatar-pipeline-direct-human-blob-read" \
  'human\.avatarImageData' \
  "High-reuse human avatar pipeline components must load persisted avatar blobs through SwiftDataMediaBlobLoader, keyed by lightweight avatarImageSignature, not by reading external-storage data on the main actor." \
  '(^|/)(HumanAvatarPipelineView|ExecutorPickerBar|SmoothnessBadSnapshotBuilder)\.swift$'

scan \
  "pet-avatar-portrait-direct-blob-read" \
  'pet\.avatarImageData' \
  "PetAvatarPortraitView must load persisted avatar blobs through SwiftDataMediaBlobLoader, keyed by lightweight avatarImageSignature, not by reading external-storage data on the main actor." \
  '(^|/)(PetAvatarPortraitView|SmoothnessBadSnapshotBuilder)\.swift$'

scan \
  "weekly-photo-memory-eager-blob" \
  'AsyncDecodedImageView\s*\(\s*data:\s*memory\.imageData|imageData:\s*log\.imageData|let\s+imageData:\s*Data' \
  "Family weekly photo memories must carry a persistent id plus lightweight media signature, not original image Data; fetch the blob only from a visible thumbnail provider." \
  '(^|/)Views/|^Ohana/Features/FamilyReports/'

scan \
  "milestone-photo-eager-blob" \
  'if\s+let\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*milestone\.photoData|AsyncDecodedImageView\s*\(\s*data:\s*milestone\.photoData' \
  "Milestone views must not eagerly unwrap persisted milestone photoData; use photoThumbnailSignature plus a visible thumbnail provider." \
  '(^|/)Views/|^Ohana/Features/Milestones/'

scan \
  "pet-photo-log-eager-blob" \
  'if\s+let\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*(log|photoLog)\.imageData|return\s+(log|photoLog)\.imageData|AsyncDecodedImageView\s*\(\s*data:\s*(log|photoLog)\.imageData' \
  "Pet photo views must not eagerly unwrap persisted PetPhotoLog.imageData; use imageThumbnailSignature plus a visible thumbnail provider." \
  '(^|/)Views/|^Ohana/Features/(Moments|PhotoAlbum|FamilyReports)/'

scan \
  "plant-care-log-eager-blob" \
  'if\s+let\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*log\.photoData|AsyncDecodedImageView\s*\(\s*data:\s*log\.photoData' \
  "Plant care views must not eagerly unwrap persisted PlantCareLog.photoData; use photoImageSignature plus a visible thumbnail provider." \
  '(^|/)Views/|^Ohana/Features/Plants/'

scan \
  "render-avatar-transparency-probe" \
  'PetAvatarTransparencyCache\.isTransparentAvatar\s*\(' \
  "SwiftUI render paths must not inspect avatar blobs to decide transparency; persist lightweight transparency state at avatar write/repair time or use a route-scoped media result cache." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-photo-data-presence-probe" \
  '\.photoData\s*(==|!=)\s*nil|first\s*\{\s*\$0\.photoData\s*(==|!=)\s*nil\s*\}' \
  "Render paths must not read external-storage photoData just to determine attachment presence; persist a lightweight photo-presence index and fetch the blob only when a visible image needs it." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-image-data-presence-probe" \
  '\.imageData\.isEmpty|\!\s*\$0\.imageData\.isEmpty|first\s*\{\s*\$0\.imageData\.isEmpty\s*(==|!=)\s*(true|false)\s*\}' \
  "Render paths must not read external-storage imageData just to determine attachment presence; persist a lightweight image-presence index and fetch the blob only when a visible image needs it." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "render-document-attachment-data-probe" \
  '\.attachments\.(filter|map)[^\n]*\.data|\.attachments\.first\s*(\([^\n]*\))?\?\.data|\.(attachmentData)\s*(==|!=)\s*nil|if\s+let\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*[^,\n]*\.attachmentData' \
  "Render paths must not read document attachment blobs to count, preview, or determine presence; use lightweight document attachment signatures/states and fetch the blob only for a visible thumbnail or explicit preview." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "eager-sharelink-export" \
  'ShareLink\s*\(\s*item:\s*[A-Za-z_][A-Za-z0-9_]*(Markdown|Summary|Report|Export|shareText|ShareText|Text)' \
  "ShareLink(item:) should not eagerly bind heavy computed export text from a render path; use a cached prepared value, lazy Transferable, or add a measured smoothness allow comment." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "runtime-loop-in-view" \
  'Timer\.publish\s*\(|TimelineView\s*\(\s*\.animation|repeatForever\s*\(' \
  "Timers, TimelineView(.animation), and repeatForever loops must be visible, policy-gated, and paused when hidden or reduced-work." \
  '(^|/)Views/|^Ohana/Shared/'

scan \
  "main-actor-aggregation" \
  'Task\s*\{\s*@MainActor' \
  "Read-model/snapshot refresh must aggregate off the main actor (@ModelActor or background context) and deliver small Equatable snapshots back to the MainActor; deferred work that still runs on main steals scroll frames as data grows." \
  '(ReadModel|SnapshotStore|SnapshotBuilder)[^/]*\.swift$'

scan \
  "plant-detail-view-aggregation" \
  'plant\.careLogs\s*(\.sorted|\.filter|\.map)|appServices\.plantCarePlans\.tasks\(for:\s*plant\)' \
  "PlantDetailContentView must render from PlantDetailRenderDataActor snapshots; direct care-log traversal or care-plan aggregation in the view steals scroll frames as history grows." \
  '^Ohana/Features/Plants/Views/PlantDetailView\.swift$'

scan \
  "view-imperative-fetch" \
  'modelContext\.fetch\(|\.fetch\(FetchDescriptor' \
  "Views must not run imperative SwiftData fetches; containers/read models own data access and pass value snapshots down." \
  '(^|/)Views/' \
  '(Data|Route)Container\.swift$|^Ohana/App/RouteContainers/'

scan \
  "detached-task-in-view" \
  'Task\.detached' \
  "Detached tasks in views escape route-scoped cancellation; use .task(id:), route-scoped tasks, or a service entry point so work cancels when the page disappears." \
  '(^|/)Views/'

if [[ ! -s "$warnings_file" ]]; then
  echo "Smoothness risk audit: passed (${#files[@]} file(s))."
  exit 0
fi

echo "Smoothness risk audit: review warnings in ${#files[@]} file(s)."
echo
cat "$warnings_file"
echo "Add // smoothness: allow <reason> only for deliberate, measured exceptions."
if [[ "$strict" -eq 1 ]]; then
  exit 1
fi
