#!/usr/bin/env bash
set -euo pipefail

repo_root="${OHANA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

mode="all"
base_ref=""
list_only=0
targets=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/ci-swiftformat.sh [--all | --base-ref <git-ref>] [--list] [paths...]

PR and push gates should pass --base-ref so historical formatting debt outside
the commit range cannot block an unrelated change. --all remains available for
explicit debt cleanup and release-wide reporting.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      mode="all"
      shift
      ;;
    --base-ref)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --base-ref requires a git ref." >&2
        exit 2
      fi
      mode="base"
      base_ref="$2"
      shift 2
      ;;
    --list)
      list_only=1
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
  mode="targets"
fi

if [[ "$mode" == "base" ]] && ! git cat-file -e "${base_ref}^{commit}" 2>/dev/null; then
  echo "error: SwiftFormat base ref is not available: $base_ref" >&2
  exit 2
fi

swift_files() {
  case "$mode" in
    all)
      git ls-files -z -- '*.swift'
      ;;
    base)
      git diff --name-only --diff-filter=ACMR -z "${base_ref}...HEAD" -- '*.swift'
      ;;
    targets)
      for target in "${targets[@]}"; do
        if [[ -d "$target" ]]; then
          find "$target" -type f -name '*.swift' -print0
        elif [[ -f "$target" && "$target" == *.swift ]]; then
          printf '%s\0' "$target"
        fi
      done
      ;;
  esac
}

files=()
while IFS= read -r -d '' file; do
  [[ -f "$file" ]] && files+=("$file")
done < <(swift_files)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "SwiftFormat: no Swift files in ${mode} scope."
  exit 0
fi

if [[ "$list_only" -eq 1 ]]; then
  printf '%s\n' "${files[@]}"
  exit 0
fi

swiftformat_bin="${OHANA_SWIFTFORMAT_BIN:-swiftformat}"
if ! command -v "$swiftformat_bin" >/dev/null 2>&1; then
  echo "error: SwiftFormat executable is unavailable: $swiftformat_bin" >&2
  exit 2
fi

echo "SwiftFormat: linting ${#files[@]} scoped Swift file(s)."
"$swiftformat_bin" --lint "${files[@]}"
