from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parents[1]
SOURCE = REPO_ROOT / "Icon.png"
CANVAS = 1024
ALPHA_THRESHOLD = 16


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Helvetica.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def clean_outputs() -> None:
    for name in ["masters", "source", "ios-universal", "ios-legacy", "previews"]:
        path = ROOT / name
        if path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)
    ds_store = ROOT / ".DS_Store"
    if ds_store.exists():
        ds_store.unlink()


def exact_binary_mask() -> Image.Image:
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (CANVAS, CANVAS):
        image = image.resize((CANVAS, CANVAS), Image.Resampling.LANCZOS)
    alpha = image.getchannel("A")
    return alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0, mode="L")


def solid_icon(mask: Image.Image, foreground: str, background: str) -> Image.Image:
    bg = Image.new("RGB", mask.size, background)
    fg = Image.new("RGB", mask.size, foreground)
    bg.paste(fg, mask=mask)
    return bg


def transparent_glyph(mask: Image.Image, color: str) -> Image.Image:
    glyph = Image.new("RGBA", mask.size, color)
    glyph.putalpha(mask)
    return glyph


def rounded_preview(image: Image.Image, size: int) -> Image.Image:
    resized = image.resize((size, size), Image.Resampling.NEAREST).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=round(size * 0.225), fill=255)
    resized.putalpha(mask)
    return resized


def make_preview(black_on_white: Image.Image, white_on_black: Image.Image, mask: Image.Image) -> Image.Image:
    width, height = 1800, 1280
    sheet = Image.new("RGB", (width, height), "#FFFFFF").convert("RGBA")
    draw = ImageDraw.Draw(sheet)
    title_font = font(68, True)
    label_font = font(30, True)
    body_font = font(24, False)

    draw.text((92, 72), "Ohana Exact Black / White Icon Suite", fill="#000000", font=title_font)
    draw.text(
        (96, 152),
        f"Shape extracted directly from Icon.png alpha channel. Colors: #000000 and #FFFFFF only. Threshold: alpha >= {ALPHA_THRESHOLD}.",
        fill="#000000",
        font=body_font,
    )

    icons = [
        ("Black on White", "Light/default master", black_on_white),
        ("White on Black", "Dark/inverted master", white_on_black),
    ]
    for index, (name, role, image) in enumerate(icons):
        x = 160 + index * 760
        y = 270
        preview = rounded_preview(image, 420)
        sheet.alpha_composite(preview, (x, y))
        draw.rounded_rectangle((x, y, x + 420, y + 420), radius=95, outline="#000000", width=4)
        draw.text((x, y + 456), name, fill="#000000", font=label_font)
        draw.text((x, y + 498), role, fill="#000000", font=body_font)

    sizes = [180, 120, 87, 60, 40]
    draw.text((160, 890), "Small-size proof", fill="#000000", font=label_font)
    x = 160
    for size in sizes:
        icon = rounded_preview(black_on_white, size)
        sheet.alpha_composite(icon, (x, 960 + (180 - size)))
        label = f"{size}px"
        box = draw.textbbox((0, 0), label, font=body_font)
        draw.text((x + (size - (box[2] - box[0])) // 2, 960 + 214), label, fill="#000000", font=body_font)
        x += size + 78

    glyph = transparent_glyph(mask, "#000000").resize((280, 280), Image.Resampling.NEAREST)
    draw.text((1040, 890), "Extracted mask", fill="#000000", font=label_font)
    mask_box = Image.new("RGBA", (420, 300), "#FFFFFF")
    box_draw = ImageDraw.Draw(mask_box)
    box_draw.rectangle((0, 0, 419, 299), outline="#000000", width=4)
    mask_box.alpha_composite(glyph, (70, 10))
    sheet.alpha_composite(mask_box, (1040, 940))

    return sheet.convert("RGB")


def write_contents_json(path: Path, images: list[dict[str, object]]) -> None:
    path.write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def save_universal_appiconset(black_on_white: Image.Image, white_on_black: Image.Image) -> None:
    appiconset = ROOT / "ios-universal" / "AppIconOhanaSmile.appiconset"
    appiconset.mkdir(parents=True, exist_ok=True)
    black_on_white.save(appiconset / "AppIconOhanaSmile.png", optimize=True)
    white_on_black.save(appiconset / "AppIconOhanaSmileDark.png", optimize=True)
    black_on_white.save(appiconset / "AppIconOhanaSmileTinted.png", optimize=True)
    write_contents_json(
        appiconset / "Contents.json",
        [
            {"filename": "AppIconOhanaSmile.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "filename": "AppIconOhanaSmileDark.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "tinted"}],
                "filename": "AppIconOhanaSmileTinted.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
        ],
    )


def save_legacy_iconset(name: str, source: Image.Image) -> None:
    output_dir = ROOT / "ios-legacy" / f"{name}.appiconset"
    output_dir.mkdir(parents=True, exist_ok=True)
    specs = [
        ("iphone", "20x20", "2x", 40, "Icon-20x20-2x-iphone.png"),
        ("iphone", "20x20", "3x", 60, "Icon-20x20-3x-iphone.png"),
        ("iphone", "29x29", "2x", 58, "Icon-29x29-2x-iphone.png"),
        ("iphone", "29x29", "3x", 87, "Icon-29x29-3x-iphone.png"),
        ("iphone", "40x40", "2x", 80, "Icon-40x40-2x-iphone.png"),
        ("iphone", "40x40", "3x", 120, "Icon-40x40-3x-iphone.png"),
        ("iphone", "60x60", "2x", 120, "Icon-60x60-2x-iphone.png"),
        ("iphone", "60x60", "3x", 180, "Icon-60x60-3x-iphone.png"),
        ("ipad", "20x20", "1x", 20, "Icon-20x20-1x-ipad.png"),
        ("ipad", "20x20", "2x", 40, "Icon-20x20-2x-ipad.png"),
        ("ipad", "29x29", "1x", 29, "Icon-29x29-1x-ipad.png"),
        ("ipad", "29x29", "2x", 58, "Icon-29x29-2x-ipad.png"),
        ("ipad", "40x40", "1x", 40, "Icon-40x40-1x-ipad.png"),
        ("ipad", "40x40", "2x", 80, "Icon-40x40-2x-ipad.png"),
        ("ipad", "76x76", "1x", 76, "Icon-76x76-1x-ipad.png"),
        ("ipad", "76x76", "2x", 152, "Icon-76x76-2x-ipad.png"),
        ("ipad", "83.5x83.5", "2x", 167, "Icon-83_5x83_5-2x-ipad.png"),
        ("ios-marketing", "1024x1024", "1x", 1024, "Icon-1024x1024-1x-ios-marketing.png"),
    ]
    images = []
    for idiom, size_name, scale, pixel_size, filename in specs:
        resized = source.resize((pixel_size, pixel_size), Image.Resampling.NEAREST)
        resized.save(output_dir / filename, optimize=True)
        images.append({"filename": filename, "idiom": idiom, "scale": scale, "size": size_name})
    write_contents_json(output_dir / "Contents.json", images)


def write_readme() -> None:
    (ROOT / "README.md").write_text(
        "\n".join(
            [
                "# Ohana Exact Black / White Icon Suite",
                "",
                "`Icon.png` is now treated as the source of truth. The mark is extracted from its alpha channel and rendered as a binary mask, so the icon uses only pure black `#000000` and pure white `#FFFFFF`.",
                "",
                "## Contents",
                "",
                "- `masters/ohana-smile-black-on-white-1024.png`: black mark on white.",
                "- `masters/ohana-smile-white-on-black-1024.png`: white mark on black.",
                "- `source/ohana-smile-mask-binary-1024.png`: pure black/white extracted mask.",
                "- `source/ohana-smile-mark-black-transparent-1024.png`: black transparent glyph source.",
                "- `source/ohana-smile-mark-white-transparent-1024.png`: white transparent glyph source.",
                "- `ios-universal/AppIconOhanaSmile.appiconset/`: Xcode-ready universal light/dark/tinted icon set.",
                "- `ios-legacy/`: full iPhone/iPad size exports for both black-on-white and white-on-black variants.",
                "- `previews/ohana-smile-bw-icon-suite-preview.png`: preview and small-size proof.",
                "",
                "## Extraction Rules",
                "",
                f"- Source: `{SOURCE}`.",
                f"- Canvas: `{CANVAS}x{CANVAS}`.",
                f"- Mask: alpha channel, threshold `>= {ALPHA_THRESHOLD}`.",
                "- Final opaque app icons contain only two RGB values: black and white.",
                "",
                "This deliberately avoids gradients, shadows, blur, edge highlights, and redrawn curves.",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def write_tokens(mask: Image.Image) -> None:
    bbox = mask.getbbox()
    payload = {
        "brand": "Ohana",
        "sourceReference": str(SOURCE),
        "generatedAt": "2026-06-09",
        "colorRule": "Only #000000 and #FFFFFF are used in opaque app icon PNGs.",
        "extraction": {
            "method": "Icon.png alpha channel to binary mask",
            "alphaThreshold": ALPHA_THRESHOLD,
            "canvas": [CANVAS, CANVAS],
            "maskBoundingBox": list(bbox) if bbox else None,
        },
        "masters": {
            "blackOnWhite": "masters/ohana-smile-black-on-white-1024.png",
            "whiteOnBlack": "masters/ohana-smile-white-on-black-1024.png",
        },
        "xcode": {
            "universalAppIconSet": "ios-universal/AppIconOhanaSmile.appiconset",
            "legacyBlackOnWhite": "ios-legacy/AppIconOhanaSmileBlackOnWhite.appiconset",
            "legacyWhiteOnBlack": "ios-legacy/AppIconOhanaSmileWhiteOnBlack.appiconset",
        },
    }
    (ROOT / "icon-suite-tokens.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    clean_outputs()
    mask = exact_binary_mask()

    black_on_white = solid_icon(mask, "#000000", "#FFFFFF")
    white_on_black = solid_icon(mask, "#FFFFFF", "#000000")

    black_on_white.save(ROOT / "masters" / "ohana-smile-black-on-white-1024.png", optimize=True)
    white_on_black.save(ROOT / "masters" / "ohana-smile-white-on-black-1024.png", optimize=True)

    mask_rgb = solid_icon(mask, "#000000", "#FFFFFF")
    mask_rgb.save(ROOT / "source" / "ohana-smile-mask-binary-1024.png", optimize=True)
    transparent_glyph(mask, "#000000").save(ROOT / "source" / "ohana-smile-mark-black-transparent-1024.png", optimize=True)
    transparent_glyph(mask, "#FFFFFF").save(ROOT / "source" / "ohana-smile-mark-white-transparent-1024.png", optimize=True)

    save_universal_appiconset(black_on_white, white_on_black)
    save_legacy_iconset("AppIconOhanaSmileBlackOnWhite", black_on_white)
    save_legacy_iconset("AppIconOhanaSmileWhiteOnBlack", white_on_black)

    preview = make_preview(black_on_white, white_on_black, mask)
    preview.save(ROOT / "previews" / "ohana-smile-bw-icon-suite-preview.png", optimize=True)

    write_readme()
    write_tokens(mask)


if __name__ == "__main__":
    main()
