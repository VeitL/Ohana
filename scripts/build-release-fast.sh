#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: scripts/build-release-fast.sh

Builds an optimized Release product for the pinned iPhone 17 simulator using
incremental Swift compilation. This is the fast optimized compiler-validation
lane; it is not a signed distribution Archive.
USAGE
}

if [[ "$#" -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  usage
  exit 0
fi
if [[ "$#" -gt 0 ]]; then
  usage >&2
  exit 2
fi

export CONFIGURATION=Release
export OHANA_SWIFT_COMPILATION_MODE=incremental
export OHANA_SWIFT_OPTIMIZATION_LEVEL=-O
export OHANA_COMPILER_INDEX_STORE_ENABLE=NO
export OHANA_DERIVED_DATA_ROOT="${OHANA_RELEASE_DERIVED_DATA_ROOT:-/tmp/OhanaDerivedData/release-fast}"

"${SCRIPT_DIR}/build-debug-fast.sh"

swift_file_list="$({
  find "${OHANA_DERIVED_DATA_ROOT}" \
    -path '*/Ohana.build/Release-iphonesimulator/Ohana.build/Objects-normal/*/Ohana.SwiftFileList' \
    -type f \
    -exec ls -t {} + 2>/dev/null || true
} | head -n 1)"

if [[ -z "${swift_file_list}" ]]; then
  echo "Release build succeeded, but its Swift compile file list could not be verified." >&2
  exit 1
fi

if grep -Fq '/Features/Settings/DesignLab/' "${swift_file_list}"; then
  echo "Release compile surface unexpectedly includes Settings DesignLab sources." >&2
  exit 1
fi

echo "Release compile surface: Settings DesignLab excluded."
