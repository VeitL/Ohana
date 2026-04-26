#!/usr/bin/env python3
"""
Extract Swift string literals containing CJK, translate zh→target language, write <lproj>/Localizable.strings.
Caches progress in scripts/.l10n_<target>.json so interrupted runs can resume.

Usage (from repo root):
  python3 -u scripts/generate_en_localizable.py
  python3 -u scripts/generate_en_localizable.py --target en --lproj en
  python3 -u scripts/generate_en_localizable.py --target ja --lproj ja

Requires: pip install deep-translator (see .venv-l10n)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OHANA = ROOT / "Ohana"

LIT_RE = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
INTERPOLATION_RE = re.compile(r"\\\(")

TARGET_DEFAULTS = {
    "en": "en",
    "ja": "ja",
    "ko": "ko",
    "fr": "fr",
    "de": "de",
    "es": "es",
}


def unescape_swift_string(inner: str) -> str:
    return (
        inner.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace('\\"', '"')
        .replace("\\\\", "\\")
    )


def escape_strings_file(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def extract_cjk_strings() -> list[str]:
    found: set[str] = set()
    for path in OHANA.rglob("*.swift"):
        if ".build" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for m in LIT_RE.finditer(text):
            raw = m.group(1)
            inner = unescape_swift_string(raw)
            if not inner or len(inner) > 2000:
                continue
            # Skip pure single-character fragments; they often come from symbols,
            # segmented controls, or formatter tokens and produce poor translations.
            if len(inner.strip()) <= 1:
                continue
            # Swift string interpolation needs manual String(localized:) treatment.
            if INTERPOLATION_RE.search(raw):
                continue
            if CJK_RE.search(inner):
                found.add(inner)
    return sorted(found, key=lambda s: (len(s), s))


def load_cache(cache_file: Path) -> dict[str, str]:
    if not cache_file.is_file():
        return {}
    try:
        data = json.loads(cache_file.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def save_cache(cache_file: Path, cache: dict[str, str]) -> None:
    cache_file.write_text(json.dumps(cache, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")


def write_strings_file(out_file: Path, cache: dict[str, str], keys: list[str], target: str) -> None:
    out_file.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "/*",
        f"  {target} localizations for Ohana (keys = zh-Hans UI strings from source).",
        f"  Machine-translated; refine in Xcode or by editing scripts/.l10n_{target}_cache.json + re-run.",
        "*/",
        "",
    ]
    for k in keys:
        if k in cache:
            v = cache[k]
            lines.append(f'"{escape_strings_file(k)}" = "{escape_strings_file(v)}";')
    out_file.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Localizable.strings for a target language.")
    parser.add_argument("--target", default="en", help="deep-translator target language code, e.g. en, ja, ko, fr")
    parser.add_argument("--lproj", default=None, help="Xcode .lproj folder name. Defaults to target.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    target = args.target
    lproj = args.lproj or TARGET_DEFAULTS.get(target, target)
    out_file = OHANA / f"{lproj}.lproj" / "Localizable.strings"
    cache_file = ROOT / "scripts" / f".l10n_{target}_cache.json"

    try:
        from deep_translator import GoogleTranslator  # noqa: PLC0415
    except ImportError:
        print("Install: python3 -m venv .venv-l10n && . .venv-l10n/bin/activate && pip install deep-translator", file=sys.stderr)
        sys.exit(1)

    keys = extract_cjk_strings()
    print(f"Found {len(keys)} unique CJK string literals.", flush=True)

    cache = load_cache(cache_file)
    translator = GoogleTranslator(source="zh-CN", target=target)
    batch_size = 35
    pending = [k for k in keys if k not in cache]
    print(f"Already cached: {len(keys) - len(pending)}, to translate: {len(pending)}", flush=True)

    for start in range(0, len(pending), batch_size):
        batch = pending[start : start + batch_size]
        try:
            en_vals = translator.translate_batch(batch)
        except Exception as e:  # noqa: BLE001
            print(f"Batch failed ({e}); per-string fallback.", flush=True)
            en_vals = []
            for k in batch:
                try:
                    en_vals.append(translator.translate(k))
                    time.sleep(0.06)
                except Exception:  # noqa: BLE001
                    en_vals.append(k)
        if len(en_vals) != len(batch):
            while len(en_vals) < len(batch):
                en_vals.append(batch[len(en_vals)])

        for k, v in zip(batch, en_vals):
            cache[k] = v
        save_cache(cache_file, cache)
        write_strings_file(out_file, cache, keys, target)
        done = len([x for x in keys if x in cache])
        print(f"  progress {done}/{len(keys)}", flush=True)
        time.sleep(0.25)

    print(f"Done. Wrote {out_file}", flush=True)


if __name__ == "__main__":
    main()
