#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

export SCHEME="${SCHEME:-OhanaUnitTests}"

exec scripts/test-simulator.sh \
  '-only-testing:OhanaTests' \
  "$@"
