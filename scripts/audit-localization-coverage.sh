#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

status=0

echo "== Localizable.strings syntax =="
find Ohana -name Localizable.strings -print0 | while IFS= read -r -d '' file; do
  plutil -lint "$file"
done

echo
echo "== Registered language resources =="
lprojs=()
while IFS= read -r lproj; do
  lprojs+=("$lproj")
done < <(perl -ne 'print "$1\n" if /lprojName:\s*"([^"]+)"/' Ohana/Models/Localization.swift | sort -u)
for lproj in "${lprojs[@]}"; do
  file="Ohana/${lproj}.lproj/Localizable.strings"
  if [[ -f "$file" ]]; then
    echo "ok  $file"
  elif [[ "$lproj" == "zh-Hans" ]]; then
    echo "ok  source literals provide zh-Hans fallback"
  else
    echo "missing  $file"
    status=1
  fi
done

echo
echo "== Key parity =="
base="Ohana/en.lproj/Localizable.strings"
if [[ -f "$base" ]]; then
  base_keys="$(mktemp)"
  perl -ne 'print "$1\n" if /^"((?:\\"|[^"])*)"\s*=/' "$base" | sort -u > "$base_keys"
  while IFS= read -r -d '' file; do
    [[ "$file" == "$base" ]] && continue
    keys="$(mktemp)"
    perl -ne 'print "$1\n" if /^"((?:\\"|[^"])*)"\s*=/' "$file" | sort -u > "$keys"
    missing_count="$(comm -23 "$base_keys" "$keys" | wc -l | tr -d ' ')"
    extra_count="$(comm -13 "$base_keys" "$keys" | wc -l | tr -d ' ')"
    if [[ "$missing_count" == "0" && "$extra_count" == "0" ]]; then
      echo "ok  $file"
    else
      echo "warn  $file: missing=$missing_count extra=$extra_count compared with en"
      if [[ "$STRICT" == "1" ]]; then
        status=1
      fi
    fi
    rm -f "$keys"
  done < <(find Ohana -name Localizable.strings -print0)
  rm -f "$base_keys"
else
  echo "missing  $base"
  status=1
fi

echo
echo "== Legacy language branching =="
legacy="$(rg -n '\bisEn\s*\?|if\s+[^\\n]*\bisEn\b|guard\s+[^\\n]*\bisEn\b|!\s*isEn\b' Ohana --glob '*.swift' || true)"
if [[ -z "$legacy" ]]; then
  echo "ok  no legacy isEn branching"
else
  echo "$legacy"
  if [[ "$STRICT" == "1" ]]; then
    status=1
  else
    echo "warn  legacy branches remain; migrate UI copy to L10n.tr/text"
  fi
fi

exit "$status"
