#!/usr/bin/env python3
"""Render light/dark companion stage contact sheets at shipping display sizes."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PREFIXES = (
    "CritterLumo",
    "CritterAuroraLuma",
    "CritterMossBun",
    "CritterPebblePop",
    "CritterEmberPip",
    "CritterMoonJelly",
)
STAGES = ("Baby", "Child", "Teen", "Adult", "Elder")
DISPLAY_SIZES = (38, 88, 176, 306)


def source_path(asset_root: Path, prefix: str, stage: str) -> Path:
    name = f"{prefix}{stage}"
    return asset_root / f"{name}.imageset" / f"{name}.png"


def render_sheet(asset_root: Path, output: Path, display_size: int) -> None:
    gutter = max(12, round(display_size * 0.12))
    label_height = max(18, round(display_size * 0.11))
    half_width = display_size + gutter * 2
    cell_width = half_width * 2
    cell_height = display_size + label_height + gutter * 2
    sheet = Image.new(
        "RGB",
        (cell_width * len(STAGES), cell_height * len(PREFIXES)),
        "white",
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for row, prefix in enumerate(PREFIXES):
        for column, stage in enumerate(STAGES):
            left = column * cell_width
            top = row * cell_height
            middle = left + half_width
            draw.rectangle(
                (left, top, middle, top + cell_height),
                fill="#F5F6F1",
            )
            draw.rectangle(
                (middle, top, left + cell_width, top + cell_height),
                fill="#101722",
            )
            baseline = top + label_height + gutter + round(display_size * 0.875)
            draw.line((left, baseline, left + cell_width, baseline), fill="#66A85C", width=1)

            with Image.open(source_path(asset_root, prefix, stage)) as opened:
                asset = opened.convert("RGBA").resize(
                    (display_size, display_size),
                    Image.Resampling.LANCZOS,
                )
            y = top + label_height + gutter
            sheet.paste(asset, (left + gutter, y), asset)
            sheet.paste(asset, (middle + gutter, y), asset)
            draw.text(
                (left + gutter, top + 3),
                f"{prefix.removeprefix('Critter')} / {stage} / {display_size}",
                fill="#10231B",
                font=font,
            )
            draw.text(
                (middle + gutter, top + 3),
                "Dark",
                fill="#F5F6F1",
                font=font,
            )

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-root", type=Path, required=True)
    parser.add_argument("--output-directory", type=Path, required=True)
    args = parser.parse_args()
    for display_size in DISPLAY_SIZES:
        render_sheet(
            args.asset_root,
            args.output_directory / f"critter-stages-{display_size}pt.png",
            display_size,
        )


if __name__ == "__main__":
    main()
