#!/usr/bin/env python3
"""Normalize companion stage PNGs onto a shared transparent 1200 pt canvas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageCms


CANVAS_SIZE = 1200
SUBJECT_LIMIT = 1000
GROUND_LINE = 1050
ALPHA_THRESHOLD = 8


def normalized_image(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")

    alpha = image.getchannel("A").point(
        lambda value: 255 if value > ALPHA_THRESHOLD else 0
    )
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"{source} has no visible pixels")

    subject = image.crop(bounds)
    scale = min(
        SUBJECT_LIMIT / subject.width,
        SUBJECT_LIMIT / subject.height,
        1.0 if subject.width <= SUBJECT_LIMIT and subject.height <= SUBJECT_LIMIT else 10.0,
    )
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    if target_size != subject.size:
        subject = subject.resize(target_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = round((CANVAS_SIZE - subject.width) / 2)
    y = GROUND_LINE - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def srgb_profile() -> bytes:
    return ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()


def normalize(source: Path) -> None:
    image = normalized_image(source)
    image.save(
        source,
        format="PNG",
        optimize=True,
        icc_profile=srgb_profile(),
    )
    print(source)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("images", nargs="+", type=Path)
    args = parser.parse_args()
    for image in args.images:
        if image.suffix.lower() != ".png" or not image.is_file():
            raise ValueError(f"not a PNG file: {image}")
        normalize(image)


if __name__ == "__main__":
    main()
