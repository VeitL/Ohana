#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 0 ]]; then
  echo "Usage: scripts/xcode-storage-audit.sh" >&2
  echo "This command is read-only." >&2
  exit 2
fi

exec "${SCRIPT_DIR}/report-local-build-storage.sh"
