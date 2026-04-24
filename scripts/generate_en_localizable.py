#!/usr/bin/env python3
"""
Extract Swift string literals containing CJK, translate zh→en, write en.lproj/Localizable.strings.
Caches progress in scripts/.l10n_en_cache.json so interrupted runs can resume.

Usage (from repo root):
  python3 -u scripts/generate_en_localizable.py

Requires: pip install deep-translator (see .venv-l10n)
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OHANA = ROOT / "Ohana"
OUT_DIR = OHANA / "en.lproj"
OUT_FILE = OUT_DIR / "Localizable.strings"
CACHE_FILE = ROOT / "scripts" / ".l10n_en_cache.json"

LIT_RE = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
CJK_RE = re.compile(r"[\u4e00-\u9fff]")


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
        text = path.read_text(encoding="utf-8", errors="ignore")
        for m in LIT_RE.finditer(text):
            raw = m.group(1)
            inner = unescape_swift_string(raw)
            if not inner or len(inner) > 2000:
                continue
            if CJK_RE.search(inner):
                found.add(inner)
    return sorted(found, key=lambda s: (len(s), s))


def load_cache() -> dict[str, str]:
    if not CACHE_FILE.is_file():
        return {}
    try:
        data = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")


def write_strings_file(cache: dict[str, str], keys: list[str]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        "/*",
        "  English localizations for Ohana (keys = zh-Hans UI strings from source).",
        "  Machine-translated; refine in Xcode or by editing scripts/.l10n_en_cache.json + re-run.",
        "*/",
        "",
    ]
    for k in keys:
        if k in cache:
            v = cache[k]
            lines.append(f'"{escape_strings_file(k)}" = "{escape_strings_file(v)}";')
    OUT_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    try:
        from deep_translator import GoogleTranslator  # noqa: PLC0415
    except ImportError:
        print("Install: python3 -m venv .venv-l10n && . .venv-l10n/bin/activate && pip install deep-translator", file=sys.stderr)
        sys.exit(1)

    keys = extract_cjk_strings()
    print(f"Found {len(keys)} unique CJK string literals.", flush=True)

    cache = load_cache()
    translator = GoogleTranslator(source="zh-CN", target="en")
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
        save_cache(cache)
        write_strings_file(cache, keys)
        done = len([x for x in keys if x in cache])
        print(f"  progress {done}/{len(keys)}", flush=True)
        time.sleep(0.25)

    print(f"Done. Wrote {OUT_FILE}", flush=True)


if __name__ == "__main__":
    main()
