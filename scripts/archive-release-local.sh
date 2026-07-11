#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/archive-release-local.sh
  scripts/archive-release-local.sh --verify /path/to/Ohana.xcarchive

Creates and verifies a signed Release WMO Archive outside the repository. It
can also verify an existing Archive without rebuilding. It does not export or
upload the archive.
USAGE
}

if [[ "$#" -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  usage
  exit 0
fi
VERIFY_ONLY_PATH=""
if [[ "$#" -eq 2 && "$1" == "--verify" ]]; then
  VERIFY_ONLY_PATH="$2"
elif [[ "$#" -gt 0 ]]; then
  usage >&2
  exit 2
fi

SCHEME="${SCHEME:-Ohana}"
CONFIGURATION=Release
WORKTREE_HASH="$(printf '%s' "${REPO_ROOT}" | shasum -a 256 | awk '{ print substr($1, 1, 12) }')"
DERIVED_DATA_PATH="${OHANA_ARCHIVE_DERIVED_DATA_PATH:-/tmp/OhanaDerivedData/archive-${WORKTREE_HASH}}"
ARCHIVE_ROOT="${OHANA_ARCHIVE_ROOT:-/tmp/OhanaArchives}"
COMMIT="$(git rev-parse --short=10 HEAD 2>/dev/null || echo unknown)"
DIRTY_SUFFIX=""
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  DIRTY_SUFFIX="-dirty"
fi
STAMP="$(date +%Y-%m-%d-%H%M%S)"
DEFAULT_ARCHIVE_PATH="${ARCHIVE_ROOT}/${STAMP}/Ohana-${COMMIT}${DIRTY_SUFFIX}.xcarchive"
ARCHIVE_PATH="${OHANA_ARCHIVE_PATH:-${DEFAULT_ARCHIVE_PATH}}"
LOCK_DIR="${OHANA_ARCHIVE_LOCK_DIR:-/tmp/OhanaBuildLocks/archive-${WORKTREE_HASH}.lock}"

absolute_path() {
  python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$1"
}

DERIVED_DATA_PATH="$(absolute_path "${DERIVED_DATA_PATH}")"
if [[ -n "${VERIFY_ONLY_PATH}" ]]; then
  ARCHIVE_PATH="$(absolute_path "${VERIFY_ONLY_PATH}")"
  if [[ ! -d "${ARCHIVE_PATH}" ]]; then
    echo "Archive does not exist: ${ARCHIVE_PATH}" >&2
    exit 2
  fi
  echo "Verifying existing Archive: ${ARCHIVE_PATH}"
else
  ARCHIVE_PATH="$(absolute_path "${ARCHIVE_PATH}")"

  for external_path in "${DERIVED_DATA_PATH}" "${ARCHIVE_PATH}"; do
    case "${external_path}" in
      "${REPO_ROOT}"|"${REPO_ROOT}"/*)
        echo "Refusing File Provider-backed Release output inside the repository:" >&2
        echo "  ${external_path}" >&2
        echo "Use /tmp or another non-File Provider path." >&2
        exit 2
        ;;
    esac
  done

  if [[ -e "${ARCHIVE_PATH}" ]]; then
    echo "Archive destination already exists: ${ARCHIVE_PATH}" >&2
    exit 2
  fi

  mkdir -p "$(dirname "${DERIVED_DATA_PATH}")" "$(dirname "${ARCHIVE_PATH}")" "$(dirname "${LOCK_DIR}")"
  if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "Another signed Archive is already running for this worktree." >&2
    echo "Lock: ${LOCK_DIR}" >&2
    exit 75
  fi
  printf '%s\n' "$$" > "${LOCK_DIR}/pid"
  cleanup() {
    rm -f "${LOCK_DIR}/pid"
    rmdir "${LOCK_DIR}" 2>/dev/null || true
  }
  trap cleanup EXIT

  export COPYFILE_DISABLE="${COPYFILE_DISABLE:-1}"

  echo "Archiving ${SCHEME} (${CONFIGURATION}, WMO)"
  echo "DerivedData: ${DERIVED_DATA_PATH}"
  echo "Archive: ${ARCHIVE_PATH}"
  echo "Index store: disabled"

  xcodebuild archive \
    -project Ohana.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination 'generic/platform=iOS' \
    -archivePath "${ARCHIVE_PATH}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -disableAutomaticPackageResolution \
    -skipPackagePluginValidation \
    -allowProvisioningUpdates \
    -showBuildTimingSummary \
    SWIFT_COMPILATION_MODE=wholemodule \
    SWIFT_OPTIMIZATION_LEVEL=-O \
    COMPILER_INDEX_STORE_ENABLE=NO
fi

APP_PATH="${ARCHIVE_PATH}/Products/Applications/Ohana.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Archive completed without the expected app: ${APP_PATH}" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

if xattr -lr "${APP_PATH}" 2>/dev/null | grep -Eq 'com\.apple\.(FinderInfo|ResourceFork)'; then
  echo "Signing-risk extended attributes remain in the archived app." >&2
  exit 1
fi

DEVICE_FAMILY="$(plutil -extract UIDeviceFamily json -o - "${APP_PATH}/Info.plist")"
MINIMUM_OS="$(plutil -extract MinimumOSVersion raw -o - "${APP_PATH}/Info.plist")"
BUNDLE_VERSION="$(plutil -extract CFBundleVersion raw -o - "${APP_PATH}/Info.plist")"
MARKETING_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "${APP_PATH}/Info.plist")"

echo "Archive verified: ${ARCHIVE_PATH}"
echo "Product: Ohana ${MARKETING_VERSION} (${BUNDLE_VERSION}), UIDeviceFamily=${DEVICE_FAMILY}, iOS ${MINIMUM_OS}+"
echo "This command does not export, upload, or validate App Store Connect metadata."
