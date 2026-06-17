#!/usr/bin/env bash
set -euo pipefail

# Remove extended attributes that make codesign reject simulator bundles with:
# "resource fork, Finder information, or similar detritus not allowed".
#
# When no explicit paths are passed, this script discovers the current Xcode
# target product plus sibling app/test/framework bundles from build settings.

declare -a candidates=()

add_path() {
  local path="${1:-}"
  if [[ -n "${path}" ]]; then
    candidates+=("${path}")
  fi
}

discover_bundle_roots() {
  local root="${1:-}"
  if [[ -z "${root}" || ! -d "${root}" ]]; then
    return 0
  fi

  while IFS= read -r -d '' bundle_path; do
    add_path "${bundle_path}"
  done < <(
    find "${root}" -maxdepth 6 \
      \( -name '*.app' -o -name '*.xctest' -o -name '*.framework' -o -name '*.appex' \) \
      -print0 2>/dev/null || true
  )
}

if [[ "$#" -gt 0 ]]; then
  for path in "$@"; do
    add_path "${path}"
  done
else
  add_path "${TARGET_BUILD_DIR:-}"
  add_path "${BUILT_PRODUCTS_DIR:-}"
  add_path "${CONFIGURATION_BUILD_DIR:-}"

  if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${WRAPPER_NAME:-}" ]]; then
    add_path "${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
  fi
  if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
    add_path "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  fi
  if [[ -n "${BUILT_PRODUCTS_DIR:-}" && -n "${WRAPPER_NAME:-}" ]]; then
    add_path "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}"
  fi
  if [[ -n "${BUILT_PRODUCTS_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
    add_path "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  fi

  discover_bundle_roots "${TARGET_BUILD_DIR:-}"
  if [[ "${BUILT_PRODUCTS_DIR:-}" != "${TARGET_BUILD_DIR:-}" ]]; then
    discover_bundle_roots "${BUILT_PRODUCTS_DIR:-}"
  fi
fi

seen_paths=$'\n'
strip_failures=0

for path in "${candidates[@]}"; do
  if [[ ! -e "${path}" ]]; then
    continue
  fi
  case "${seen_paths}" in
    *$'\n'"${path}"$'\n'*)
      continue
      ;;
  esac
  seen_paths+="${path}"$'\n'

  if ! /usr/bin/xattr -cr "${path}" 2>/dev/null; then
    echo "warning: failed to clear all extended attributes under ${path}" >&2
    strip_failures=$((strip_failures + 1))
  fi

  # Some File Provider-backed workspaces can attach FinderInfo through the
  # directory's hidden/invisible flag. xattr -cr may report success while
  # codesign still rejects the bundle root, so clear the Finder flags directly.
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a v "${path}" 2>/dev/null || true
  fi
  chflags nohidden "${path}" 2>/dev/null || true

  # xattr -cr is recursive, but explicitly clear common root-level signing
  # blockers because File Provider can attach them to bundle directories.
  /usr/bin/xattr -d com.apple.FinderInfo "${path}" 2>/dev/null || true
  /usr/bin/xattr -d com.apple.ResourceFork "${path}" 2>/dev/null || true
  /usr/bin/xattr -d com.apple.quarantine "${path}" 2>/dev/null || true
done

if [[ "${OHANA_STRIP_XATTRS_STRICT:-0}" == "1" && "${strip_failures}" -gt 0 ]]; then
  exit 1
fi
