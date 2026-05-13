#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

SCHEME="${SCHEME:-Ohana}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.4.1}"

echo "Building ${SCHEME} (${CONFIGURATION})"
echo "Destination: ${DESTINATION}"

xcodebuild \
  -project Ohana.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -disableAutomaticPackageResolution \
  -skipPackagePluginValidation \
  -showBuildTimingSummary \
  build
