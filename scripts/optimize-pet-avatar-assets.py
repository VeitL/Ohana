#!/usr/bin/env python3
"""Optimize bundled avatar PNGs with a guarded, repeatable pipeline."""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from skimage.metrics import structural_similarity


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSET_DIR = ROOT / "Resources" / "Avatars" / "PetAvatarAssets"


@dataclass
class OptimizationResult:
    path: Path
    original_size: int
    optimized_size: int
    original_dimensions: tuple[int, int]
    optimized_dimensions: tuple[int, int]
    rgb_ssim: float
    alpha_max_delta: int
    alpha_mean_delta: float
    accepted: bool
    reason: str
    output_path: Path | None

    @property
    def saved_bytes(self) -> int:
        return self.original_size - self.optimized_size if self.accepted else 0

    @property
    def saved_percent(self) -> float:
        if self.original_size <= 0:
            return 0.0
        return self.saved_bytes / self.original_size * 100


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Optimize bundled avatar PNGs without changing filenames.")
    parser.add_argument("--asset-dir", type=Path, default=DEFAULT_ASSET_DIR)
    parser.add_argument("--width", type=int, default=450)
    parser.add_argument("--height", type=int, default=600)
    parser.add_argument("--colors", type=int, default=256)
    parser.add_argument("--display-width", type=int, default=330)
    parser.add_argument("--display-height", type=int, default=440)
    parser.add_argument("--min-ssim", type=float, default=0.985)
    parser.add_argument("--max-alpha-delta", type=int, default=0)
    parser.add_argument(
        "--palette-alpha",
        action="store_true",
        help="Use indexed PNG output with palette transparency. This is much smaller for plant cutout art, but should use explicit SSIM/alpha gates.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Preview output without replacing files. This is the default.")
    parser.add_argument("--apply", action="store_true", help="Replace source PNGs after all candidates pass.")
    parser.add_argument("--no-zopflipng", action="store_true", help="Skip optional zopflipng pass.")
    parser.add_argument("--report", type=Path, help="Optional CSV report path.")
    parser.add_argument("--contact-sheet", type=Path, help="Optional before/after PNG contact sheet path.")
    parser.add_argument("--contact-count", type=int, default=16)
    return parser.parse_args()


def png_files(asset_dir: Path) -> list[Path]:
    return sorted(path for path in asset_dir.iterdir() if path.suffix.lower() == ".png")


def validate_manifest(asset_dir: Path, files: list[Path]) -> list[str]:
    manifest = asset_dir / "manifest.json"
    if not manifest.exists():
        return [f"missing manifest: {manifest}"]

    try:
        entries = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - report exact malformed manifest.
        return [f"manifest parse failed: {exc}"]

    file_names = {path.name for path in files}
    errors: list[str] = []
    for index, entry in enumerate(entries):
        filename = entry.get("filename") if isinstance(entry, dict) else None
        if not isinstance(filename, str) or not filename:
            errors.append(f"manifest entry {index} has no filename")
        elif filename not in file_names:
            errors.append(f"manifest references missing file: {filename}")
    return errors


def manifest_warnings(asset_dir: Path, files: list[Path]) -> list[str]:
    manifest = asset_dir / "manifest.json"
    if not manifest.exists():
        return []

    try:
        entries = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception:
        return []

    referenced = {
        entry["filename"]
        for entry in entries
        if isinstance(entry, dict) and isinstance(entry.get("filename"), str)
    }
    file_names = {path.name for path in files}
    warnings: list[str] = []
    for filename in sorted(file_names - referenced):
        warnings.append(f"PNG is not referenced by manifest: {filename!r}")
    return warnings


def open_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


def optimized_candidate(
    image: Image.Image,
    output_path: Path,
    target_size: tuple[int, int],
    colors: int,
    palette_alpha: bool,
) -> None:
    resized = image.resize(target_size, Image.Resampling.LANCZOS)
    if palette_alpha:
        quantized = resized.quantize(
            colors=colors,
            method=Image.Quantize.FASTOCTREE,
            dither=Image.Dither.NONE,
        )
        quantized.save(output_path, optimize=True)
        return

    alpha = resized.getchannel("A")
    rgb = resized.convert("RGB")
    quantized = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    merged = Image.merge("RGBA", (*quantized.split(), alpha))
    merged.save(output_path, optimize=True, compress_level=9)


def lossless_resized_candidate(image: Image.Image, output_path: Path, target_size: tuple[int, int]) -> None:
    resized = image.resize(target_size, Image.Resampling.LANCZOS)
    resized.save(output_path, optimize=True, compress_level=9)


def run_zopflipng(path: Path) -> Path:
    zopflipng = shutil.which("zopflipng")
    if zopflipng is None:
        return path

    optimized_path = path.with_suffix(".zopfli.png")
    subprocess.run(
        [zopflipng, "-y", str(path), str(optimized_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )
    if optimized_path.stat().st_size < path.stat().st_size:
        path.unlink()
        optimized_path.replace(path)
    else:
        optimized_path.unlink(missing_ok=True)
    return path


def composite_rgb(image: Image.Image, size: tuple[int, int], background: tuple[int, int, int]) -> np.ndarray:
    resized = image.resize(size, Image.Resampling.LANCZOS)
    backdrop = Image.new("RGBA", size, (*background, 255))
    backdrop.alpha_composite(resized)
    return np.asarray(backdrop.convert("RGB"))


def compare_quality(
    original: Image.Image,
    candidate: Image.Image,
    display_size: tuple[int, int],
) -> tuple[float, int, float]:
    white_score = structural_similarity(
        composite_rgb(original, display_size, (255, 255, 255)),
        composite_rgb(candidate, display_size, (255, 255, 255)),
        channel_axis=2,
        data_range=255,
    )
    dark_score = structural_similarity(
        composite_rgb(original, display_size, (20, 24, 32)),
        composite_rgb(candidate, display_size, (20, 24, 32)),
        channel_axis=2,
        data_range=255,
    )
    original_alpha = np.asarray(original.resize(candidate.size, Image.Resampling.LANCZOS).getchannel("A"), dtype=np.int16)
    candidate_alpha = np.asarray(candidate.getchannel("A"), dtype=np.int16)
    alpha_delta = np.abs(original_alpha - candidate_alpha)
    return min(float(white_score), float(dark_score)), int(alpha_delta.max()), float(alpha_delta.mean())


def optimize_one(
    path: Path,
    temp_dir: Path,
    target_size: tuple[int, int],
    display_size: tuple[int, int],
    colors: int,
    min_ssim: float,
    max_alpha_delta: int,
    use_zopflipng: bool,
    palette_alpha: bool,
) -> OptimizationResult:
    original_size = path.stat().st_size
    original = open_rgba(path)
    quantized_path = temp_dir / path.name
    optimized_candidate(original, quantized_path, target_size, colors, palette_alpha)
    if use_zopflipng:
        quantized_path = run_zopflipng(quantized_path)

    candidate = open_rgba(quantized_path)
    rgb_ssim, alpha_max_delta, alpha_mean_delta = compare_quality(original, candidate, display_size)
    accepted_path = quantized_path
    reason = "quantized"

    if rgb_ssim < min_ssim or alpha_max_delta > max_alpha_delta:
        fallback_path = temp_dir / f"{path.stem}.lossless-resized.png"
        lossless_resized_candidate(original, fallback_path, target_size)
        if use_zopflipng:
            fallback_path = run_zopflipng(fallback_path)
        fallback = open_rgba(fallback_path)
        rgb_ssim, alpha_max_delta, alpha_mean_delta = compare_quality(original, fallback, display_size)
        accepted_path = fallback_path
        reason = "lossless-resized"

    optimized_size = accepted_path.stat().st_size
    dimensions_ok = accepted_path.exists() and candidate_or_fallback_dimensions(accepted_path) == target_size
    quality_ok = rgb_ssim >= min_ssim and alpha_max_delta <= max_alpha_delta
    if dimensions_ok and quality_ok and optimized_size < original_size:
        accepted = True
    elif original.size == target_size and dimensions_ok and quality_ok:
        accepted = True
        reason = "already-optimized"
        accepted_path = path
        optimized_size = original_size
    else:
        accepted = False
        reason = "rejected"
        accepted_path = None
        optimized_size = original_size

    return OptimizationResult(
        path=path,
        original_size=original_size,
        optimized_size=optimized_size,
        original_dimensions=original.size,
        optimized_dimensions=target_size if accepted else original.size,
        rgb_ssim=rgb_ssim,
        alpha_max_delta=alpha_max_delta,
        alpha_mean_delta=alpha_mean_delta,
        accepted=accepted,
        reason=reason,
        output_path=accepted_path,
    )


def candidate_or_fallback_dimensions(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


def write_report(path: Path, results: list[OptimizationResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "filename",
                "accepted",
                "reason",
                "original_bytes",
                "optimized_bytes",
                "saved_percent",
                "original_dimensions",
                "optimized_dimensions",
                "rgb_ssim",
                "alpha_max_delta",
                "alpha_mean_delta",
            ]
        )
        for result in results:
            writer.writerow(
                [
                    result.path.name,
                    result.accepted,
                    result.reason,
                    result.original_size,
                    result.optimized_size,
                    f"{result.saved_percent:.2f}",
                    f"{result.original_dimensions[0]}x{result.original_dimensions[1]}",
                    f"{result.optimized_dimensions[0]}x{result.optimized_dimensions[1]}",
                    f"{result.rgb_ssim:.6f}",
                    result.alpha_max_delta,
                    f"{result.alpha_mean_delta:.6f}",
                ]
            )


def make_contact_sheet(path: Path, results: list[OptimizationResult], count: int) -> None:
    selected = sorted(
        [result for result in results if result.accepted and result.output_path is not None],
        key=lambda result: result.original_size,
        reverse=True,
    )[:count]
    if not selected:
        return

    thumb = (150, 200)
    label_height = 42
    columns = 4
    rows = math.ceil(len(selected) / columns)
    cell_width = thumb[0] * 2 + 28
    cell_height = thumb[1] + label_height + 16
    sheet = Image.new("RGB", (columns * cell_width, rows * cell_height), (246, 247, 249))
    draw = ImageDraw.Draw(sheet)

    for index, result in enumerate(selected):
        row, col = divmod(index, columns)
        x = col * cell_width + 10
        y = row * cell_height + 8
        before = open_rgba(result.path).resize(thumb, Image.Resampling.LANCZOS)
        after = open_rgba(result.output_path).resize(thumb, Image.Resampling.LANCZOS)
        before_bg = Image.new("RGBA", thumb, (255, 255, 255, 255))
        after_bg = Image.new("RGBA", thumb, (255, 255, 255, 255))
        before_bg.alpha_composite(before)
        after_bg.alpha_composite(after)
        sheet.paste(before_bg.convert("RGB"), (x, y))
        sheet.paste(after_bg.convert("RGB"), (x + thumb[0] + 8, y))
        label = f"{result.path.name[:32]}\n{result.saved_percent:.1f}% smaller"
        draw.text((x, y + thumb[1] + 4), label, fill=(38, 42, 51))

    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def apply_results(results: list[OptimizationResult]) -> None:
    rejected = [result for result in results if not result.accepted or result.output_path is None]
    if rejected:
        names = ", ".join(result.path.name for result in rejected[:10])
        raise RuntimeError(f"refusing --apply because {len(rejected)} file(s) were rejected: {names}")

    for result in results:
        assert result.output_path is not None
        temp_replace = result.path.with_suffix(".optimized.tmp")
        shutil.copyfile(result.output_path, temp_replace)
        os.replace(temp_replace, result.path)


def print_summary(results: list[OptimizationResult], asset_dir: Path, apply: bool, warnings: list[str]) -> None:
    total_original = sum(result.original_size for result in results)
    total_optimized = sum(result.optimized_size for result in results)
    total_saved = total_original - total_optimized
    accepted = sum(1 for result in results if result.accepted)
    rejected = len(results) - accepted
    mode = "applied" if apply else "dry-run"
    print(f"Avatar asset optimization {mode}: {asset_dir}")
    print(f"files: {len(results)} accepted={accepted} rejected={rejected}")
    print(f"total: {total_original / 1024 / 1024:.1f} MiB -> {total_optimized / 1024 / 1024:.1f} MiB")
    print(f"saved: {total_saved / 1024 / 1024:.1f} MiB ({(total_saved / total_original * 100) if total_original else 0:.1f}%)")
    if warnings:
        print("warnings:")
        for warning in warnings:
            print(f"  {warning}")
    if rejected:
        print("rejected:")
        for result in results:
            if not result.accepted:
                print(
                    f"  {result.path.name}: {result.reason} "
                    f"ssim={result.rgb_ssim:.5f} alpha_max_delta={result.alpha_max_delta}"
                )


def main() -> int:
    args = parse_args()
    asset_dir = args.asset_dir.resolve()
    if not asset_dir.exists():
        print(f"missing asset directory: {asset_dir}", file=sys.stderr)
        return 2

    files = png_files(asset_dir)
    manifest_errors = validate_manifest(asset_dir, files)
    if manifest_errors:
        for error in manifest_errors:
            print(f"error: {error}", file=sys.stderr)
        return 2
    warnings = manifest_warnings(asset_dir, files)

    target_size = (args.width, args.height)
    display_size = (args.display_width, args.display_height)
    with tempfile.TemporaryDirectory(prefix="ohana-pet-avatar-opt-") as temp_name:
        temp_dir = Path(temp_name)
        results = [
            optimize_one(
                path=path,
                temp_dir=temp_dir,
                target_size=target_size,
                display_size=display_size,
                colors=args.colors,
                min_ssim=args.min_ssim,
                max_alpha_delta=args.max_alpha_delta,
                use_zopflipng=not args.no_zopflipng,
                palette_alpha=args.palette_alpha,
            )
            for path in files
        ]

        if args.report:
            write_report(args.report.resolve(), results)
        if args.contact_sheet:
            make_contact_sheet(args.contact_sheet.resolve(), results, args.contact_count)

        if args.apply:
            apply_results(results)
        print_summary(results, asset_dir, args.apply, warnings)
        return 1 if any(not result.accepted for result in results) else 0


if __name__ == "__main__":
    sys.exit(main())
