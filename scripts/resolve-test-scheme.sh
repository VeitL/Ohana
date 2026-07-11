#!/usr/bin/env bash
set -euo pipefail

# Select the narrowest shared scheme when every -only-testing selector belongs
# to one test bundle. Mixed, missing, or unknown selectors stay on the main
# scheme so this helper never silently drops a requested test target.

unit_selectors=0
ui_selectors=0
unknown_selectors=0

for argument in "$@"; do
  case "${argument}" in
    -only-testing:*)
      selector="${argument#-only-testing:}"
      case "${selector}" in
        OhanaTests|OhanaTests/*)
          unit_selectors=$((unit_selectors + 1))
          ;;
        OhanaUITests|OhanaUITests/*)
          ui_selectors=$((ui_selectors + 1))
          ;;
        *)
          unknown_selectors=$((unknown_selectors + 1))
          ;;
      esac
      ;;
  esac
done

if [[ "${unknown_selectors}" -eq 0 && "${unit_selectors}" -gt 0 && "${ui_selectors}" -eq 0 ]]; then
  printf '%s\n' "OhanaUnitTests"
elif [[ "${unknown_selectors}" -eq 0 && "${ui_selectors}" -gt 0 && "${unit_selectors}" -eq 0 ]]; then
  printf '%s\n' "OhanaUITests"
else
  printf '%s\n' "Ohana"
fi
