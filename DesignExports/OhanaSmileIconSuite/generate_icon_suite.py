from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
CANVAS = 1024
SUPERSAMPLE = 4


def rgb(hex_value: str) -> tuple[int, int, int]:
    value = hex_value.strip().lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    red, green, blue = rgb(hex_value)
    return red, green, blue, alpha


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def cubic(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int,
) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for index in range(steps + 1):
        t = index / steps
        mt = 1 - t
        x = (
            mt * mt * mt * p0[0]
            + 3 * mt * mt * t * p1[0]
            + 3 * mt * t * t * p2[0]
            + t * t * t * p3[0]
        )
        y = (
            mt * mt * mt * p0[1]
            + 3 * mt * mt * t * p1[1]
            + 3 * mt * t * t * p2[1]
            + t * t * t * p3[1]
        )
        points.append((x, y))
    return points


def scaled(points: list[tuple[float, float]], scale: float) -> list[tuple[int, int]]:
    return [(round(x * scale), round(y * scale)) for x, y in points]


def mouth_points() -> list[tuple[float, float]]:
    segments = [
        ((250, 459), (315, 463), (370, 594), (514, 594)),
        ((514, 594), (641, 594), (707, 532), (757, 476)),
        ((757, 476), (810, 430), (858, 478), (852, 546)),
        ((852, 546), (842, 704), (699, 790), (516, 789)),
        ((516, 789), (329, 788), (177, 706), (171, 550)),
        ((171, 550), (166, 490), (202, 454), (250, 459)),
    ]
    points: list[tuple[float, float]] = []
    for segment in segments:
        curve = cubic(*segment, steps=34)
        if points:
            curve = curve[1:]
        points.extend(curve)
    return points


def mark_mask(size: int = CANVAS) -> Image.Image:
    high = size * SUPERSAMPLE
    scale = high / CANVAS
    mask = Image.new("L", (high, high), 0)
    draw = ImageDraw.Draw(mask)

    eye_boxes = [
        (266, 230, 479, 443),
        (547, 270, 749, 473),
    ]
    for box in eye_boxes:
        draw.ellipse([round(v * scale) for v in box], fill=255)

    draw.polygon(scaled(mouth_points(), scale), fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def linear_background(size: int, top: str, bottom: str) -> Image.Image:
    top_rgb = rgb(top)
    bottom_rgb = rgb(bottom)
    image = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=mix(top_rgb, bottom_rgb, t))
    return image.convert("RGBA")


def linear_background_rect(width: int, height: int, top: str, bottom: str) -> Image.Image:
    top_rgb = rgb(top)
    bottom_rgb = rgb(bottom)
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        draw.line([(0, y), (width, y)], fill=mix(top_rgb, bottom_rgb, t))
    return image.convert("RGBA")


def add_soft_glow(
    image: Image.Image,
    center: tuple[float, float],
    radius: float,
    color: str,
    alpha: int,
    blur: float | None = None,
) -> Image.Image:
    width, height = image.size
    unit = max(width, height)
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = center
    r = radius * unit
    draw.ellipse(
        (
            round(cx * width - r),
            round(cy * height - r),
            round(cx * width + r),
            round(cy * height + r),
        ),
        fill=rgba(color, alpha),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(round((blur or radius * 0.36) * unit)))
    return Image.alpha_composite(image, layer)


def add_noise(image: Image.Image, opacity: int = 10) -> Image.Image:
    rnd = random.Random(240609)
    width, height = image.size
    noise = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = noise.load()
    step = 2
    for y in range(0, height, step):
        for x in range(0, width, step):
            value = rnd.randint(-18, 18)
            if value >= 0:
                color = (255, 255, 255, min(opacity, value))
            else:
                color = (0, 0, 0, min(opacity, -value))
            for dy in range(step):
                for dx in range(step):
                    if x + dx < width and y + dy < height:
                        pixels[x + dx, y + dy] = color
    return Image.alpha_composite(image, noise)


def gradient_fill(mask: Image.Image, top: str, bottom: str) -> Image.Image:
    size = mask.size[0]
    base = linear_background(size, top, bottom)
    base.putalpha(mask)
    return base


def offset_mask(mask: Image.Image, offset: tuple[int, int]) -> Image.Image:
    shifted = Image.new("L", mask.size, 0)
    shifted.paste(mask, offset)
    return shifted


def render_icon(variant: dict[str, object], size: int = CANVAS) -> Image.Image:
    background = linear_background(size, str(variant["bgTop"]), str(variant["bgBottom"]))

    for glow in variant.get("glows", []):
        background = add_soft_glow(
            background,
            center=glow["center"],
            radius=glow["radius"],
            color=glow["color"],
            alpha=glow["alpha"],
            blur=glow.get("blur"),
        )

    if variant.get("noise", True):
        background = add_noise(background, opacity=int(variant.get("noiseOpacity", 7)))

    mask = mark_mask(size)
    shadow = mask.filter(ImageFilter.GaussianBlur(round(size * float(variant.get("shadowBlur", 0.028)))))
    shadow_alpha = shadow.point(lambda value: round(value * float(variant.get("shadowAlpha", 0.42))))
    shadow_layer = Image.new("RGBA", background.size, rgba(str(variant.get("shadowColor", "#000000")), 0))
    shadow_layer.putalpha(shadow_alpha)
    shadow_canvas = Image.new("RGBA", background.size, (0, 0, 0, 0))
    offset = (
        round(size * float(variant.get("shadowOffsetX", 0.0))),
        round(size * float(variant.get("shadowOffsetY", 0.032))),
    )
    shadow_canvas.paste(shadow_layer, offset, shadow_layer)
    image = Image.alpha_composite(background, shadow_canvas)

    mark = gradient_fill(mask, str(variant["markTop"]), str(variant["markBottom"]))
    image = Image.alpha_composite(image, mark)

    inner_edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(17)))
    edge_alpha = inner_edge.point(lambda value: round(value * float(variant.get("edgeAlpha", 0.22))))
    edge = Image.new("RGBA", image.size, rgba(str(variant.get("edgeColor", "#FFFFFF")), 0))
    edge.putalpha(edge_alpha)
    image = Image.alpha_composite(image, edge)

    highlight_mask = ImageChops.subtract(offset_mask(mask, (0, round(size * 0.008))), mask)
    highlight_mask = highlight_mask.filter(ImageFilter.GaussianBlur(round(size * 0.006)))
    highlight_mask = highlight_mask.point(lambda value: round(value * float(variant.get("topHighlightAlpha", 0.18))))
    highlight = Image.new("RGBA", image.size, rgba(str(variant.get("topHighlightColor", "#FFFFFF")), 0))
    highlight.putalpha(highlight_mask)
    image = Image.alpha_composite(image, highlight)

    return image.convert("RGB")


def render_mark(color: str, size: int = CANVAS) -> Image.Image:
    mask = mark_mask(size)
    image = Image.new("RGBA", (size, size), rgba(color, 0))
    image.putalpha(mask)
    solid = Image.new("RGBA", (size, size), rgba(color, 255))
    solid.putalpha(mask)
    return solid


def rounded_preview(image: Image.Image, size: int) -> Image.Image:
    resized = image.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=round(size * 0.225), fill=255)
    resized.putalpha(mask)
    return resized


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Helvetica.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def text_width(draw: ImageDraw.ImageDraw, text: str, font_obj: ImageFont.ImageFont) -> int:
    box = draw.textbbox((0, 0), text, font=font_obj)
    return box[2] - box[0]


def create_preview(variants: list[dict[str, object]], icons: dict[str, Image.Image]) -> Image.Image:
    width = 1900
    height = 1600
    sheet = linear_background_rect(width, height, "#F5F8FC", "#DDE6F1")
    sheet = add_soft_glow(sheet, (0.12, 0.0), 0.42, "#FFFFFF", 190, blur=0.18)
    sheet = add_soft_glow(sheet, (0.95, 0.93), 0.54, "#B8E7FF", 84, blur=0.22)
    draw = ImageDraw.Draw(sheet)
    title_font = font(72, True)
    label_font = font(30, True)
    sub_font = font(24, False)

    draw.text((100, 78), "Ohana Smile Icon Suite", fill="#111820", font=title_font)
    draw.text(
        (104, 160),
        "Reference-led app icon system: light, dark, tinted, alternates, glyph, and small-size proof.",
        fill="#4A5666",
        font=sub_font,
    )

    x = 100
    y = 250
    thumb = 274
    column_step = 590
    for index, variant in enumerate(variants[:6]):
        col = index % 3
        row = index // 3
        tx = x + col * column_step
        ty = y + row * 400
        preview = rounded_preview(icons[str(variant["id"])], thumb)
        shadow = Image.new("RGBA", (thumb + 52, thumb + 52), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle((26, 26, thumb + 26, thumb + 26), radius=round(thumb * 0.225), fill=(5, 12, 20, 78))
        shadow = shadow.filter(ImageFilter.GaussianBlur(20))
        sheet.alpha_composite(shadow, (tx - 26, ty - 18))
        sheet.alpha_composite(preview, (tx, ty))
        name = str(variant["name"])
        role = str(variant["role"])
        draw.text((tx, ty + thumb + 34), name, fill="#121820", font=label_font)
        draw.text((tx, ty + thumb + 76), role, fill="#526172", font=sub_font)

    ladder_y = 1210
    draw.text((100, ladder_y - 86), "Small-size proof", fill="#111820", font=label_font)
    sizes = [180, 120, 87, 60, 40]
    lx = 100
    for size in sizes:
        icon = rounded_preview(icons["primary"], size)
        sheet.alpha_composite(icon, (lx, ladder_y + (180 - size)))
        label = f"{size}px"
        draw.text((lx + (size - text_width(draw, label, sub_font)) // 2, ladder_y + 210), label, fill="#526172", font=sub_font)
        lx += size + 72

    gx = 940
    draw.text((gx, ladder_y - 86), "Glyph source", fill="#111820", font=label_font)
    glyph_box = Image.new("RGBA", (400, 280), (255, 255, 255, 190))
    glyph_draw = ImageDraw.Draw(glyph_box)
    glyph_draw.rounded_rectangle((0, 0, 400, 280), radius=54, fill=(255, 255, 255, 210), outline=(20, 30, 42, 24), width=2)
    glyph = render_mark("#080A0D", 1024).resize((230, 230), Image.Resampling.LANCZOS)
    glyph_box.alpha_composite(glyph, (86, 28))
    sheet.alpha_composite(glyph_box, (gx, ladder_y - 8))

    return sheet.convert("RGB")


def write_svg() -> None:
    path_data = (
        "M250 459 C315 463 370 594 514 594 "
        "C641 594 707 532 757 476 "
        "C810 430 858 478 852 546 "
        "C842 704 699 790 516 789 "
        "C329 788 177 706 171 550 "
        "C166 490 202 454 250 459 Z"
    )
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <title>Ohana Smile Mark</title>
  <g fill="currentColor">
    <circle cx="372.5" cy="336.5" r="106.5"/>
    <circle cx="648" cy="371.5" r="101.5"/>
    <path d="{path_data}"/>
  </g>
</svg>
"""
    (ROOT / "source" / "ohana-smile-mark.svg").write_text(svg, encoding="utf-8")


def write_contents_json(path: Path, images: list[dict[str, object]]) -> None:
    payload = {"images": images, "info": {"author": "xcode", "version": 1}}
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def save_legacy_iconset(name: str, source: Image.Image, output_dir: Path) -> None:
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
        resized = source.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        resized.save(output_dir / filename, optimize=True)
        images.append({"filename": filename, "idiom": idiom, "scale": scale, "size": size_name})
    write_contents_json(output_dir / "Contents.json", images)


def write_readme(variants: list[dict[str, object]]) -> None:
    lines = [
        "# Ohana Smile Icon Suite",
        "",
        "Generated from `Icon.png` as a market-ready app icon suite. The system keeps the original two-dot plus wide-smile silhouette, then adds production icon treatments for iOS light, dark, tinted, and alternate contexts.",
        "",
        "## Design Direction",
        "",
        "- Keep the mark oversized and readable at 40 px.",
        "- Use a single memorable silhouette; color and lighting change by variant, not the symbol geometry.",
        "- Avoid busy pet literalism. The mark reads as smile, family, and soft companion care without becoming a generic paw.",
        "- Export square opaque app icons; iOS applies the rounded mask at runtime.",
        "",
        "## Contents",
        "",
        "- `masters/`: 1024 px square PNG masters.",
        "- `source/`: transparent mark PNGs and editable SVG.",
        "- `ios-universal/AppIconOhanaSmile.appiconset/`: Xcode-ready 1024 universal light/dark/tinted set.",
        "- `ios-legacy/`: full iPhone/iPad size exports for light, dark, and tinted appearances.",
        "- `previews/ohana-smile-icon-suite-preview.png`: contact sheet with small-size proof.",
        "- `icon-suite-tokens.json`: palette, roles, and file mapping.",
        "",
        "## Variants",
        "",
    ]
    for variant in variants:
        lines.append(f"- `{variant['id']}`: {variant['name']} - {variant['role']}")
    lines.extend(
        [
            "",
            "## Recommended Use",
            "",
            "- Default app icon: `primary` light, `dark` dark, `tinted` tinted in the universal appiconset.",
            "- App Store visual exploration or alternate icon shop: use `graphite`, `lagoon`, and `milk` as premium alternates.",
            "- Functional UI glyphs should continue to follow the existing monochrome SF Symbol/vector policy; this suite is for app identity surfaces.",
            "",
            "Generated deterministically with Pillow so the same geometry can be regenerated after token tweaks.",
        ]
    )
    (ROOT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    for directory in ["masters", "source", "ios-universal", "ios-legacy", "previews"]:
        (ROOT / directory).mkdir(parents=True, exist_ok=True)

    variants: list[dict[str, object]] = [
        {
            "id": "primary",
            "name": "Clean Day",
            "role": "Default light app icon",
            "bgTop": "#F7FBFF",
            "bgBottom": "#C9D8E8",
            "markTop": "#151A20",
            "markBottom": "#030508",
            "edgeColor": "#FFFFFF",
            "edgeAlpha": 0.20,
            "shadowColor": "#344357",
            "shadowAlpha": 0.34,
            "shadowBlur": 0.026,
            "shadowOffsetY": 0.026,
            "topHighlightAlpha": 0.20,
            "glows": [
                {"center": (0.20, 0.06), "radius": 0.60, "color": "#FFFFFF", "alpha": 210, "blur": 0.18},
                {"center": (0.88, 0.84), "radius": 0.55, "color": "#74BFFF", "alpha": 48, "blur": 0.18},
                {"center": (0.12, 0.88), "radius": 0.44, "color": "#D9FF5F", "alpha": 34, "blur": 0.20},
            ],
        },
        {
            "id": "dark",
            "name": "Lime Night",
            "role": "Default dark app icon",
            "bgTop": "#18222B",
            "bgBottom": "#05080C",
            "markTop": "#F3FFD1",
            "markBottom": "#B8F540",
            "edgeColor": "#FFFFFF",
            "edgeAlpha": 0.18,
            "shadowColor": "#000000",
            "shadowAlpha": 0.58,
            "shadowBlur": 0.038,
            "shadowOffsetY": 0.03,
            "topHighlightColor": "#FFFFFF",
            "topHighlightAlpha": 0.22,
            "glows": [
                {"center": (0.20, 0.10), "radius": 0.54, "color": "#305BFF", "alpha": 56, "blur": 0.20},
                {"center": (0.78, 0.76), "radius": 0.60, "color": "#C8FF3D", "alpha": 58, "blur": 0.22},
            ],
            "noiseOpacity": 6,
        },
        {
            "id": "tinted",
            "name": "System Tint",
            "role": "iOS tinted appearance",
            "bgTop": "#F4F4F2",
            "bgBottom": "#BFC5C8",
            "markTop": "#0F1113",
            "markBottom": "#000000",
            "edgeColor": "#FFFFFF",
            "edgeAlpha": 0.14,
            "shadowColor": "#1D2228",
            "shadowAlpha": 0.30,
            "shadowBlur": 0.024,
            "shadowOffsetY": 0.023,
            "topHighlightAlpha": 0.14,
            "glows": [
                {"center": (0.25, 0.03), "radius": 0.62, "color": "#FFFFFF", "alpha": 190, "blur": 0.20},
                {"center": (0.85, 0.86), "radius": 0.52, "color": "#939BA2", "alpha": 34, "blur": 0.19},
            ],
        },
        {
            "id": "graphite",
            "name": "Soft Graphite",
            "role": "Closest to the provided reference",
            "bgTop": "#8C8E8C",
            "bgBottom": "#545758",
            "markTop": "#111315",
            "markBottom": "#020303",
            "edgeColor": "#FFFFFF",
            "edgeAlpha": 0.10,
            "shadowColor": "#0A0D0F",
            "shadowAlpha": 0.36,
            "shadowBlur": 0.03,
            "shadowOffsetY": 0.026,
            "topHighlightAlpha": 0.10,
            "glows": [
                {"center": (0.12, 0.06), "radius": 0.68, "color": "#FFFFFF", "alpha": 68, "blur": 0.24},
                {"center": (0.88, 0.92), "radius": 0.70, "color": "#111820", "alpha": 44, "blur": 0.24},
            ],
            "noiseOpacity": 8,
        },
        {
            "id": "lagoon",
            "name": "Lagoon Blue",
            "role": "Clean premium alternate",
            "bgTop": "#E9F7FF",
            "bgBottom": "#77B8E8",
            "markTop": "#071C31",
            "markBottom": "#020914",
            "edgeColor": "#FFFFFF",
            "edgeAlpha": 0.18,
            "shadowColor": "#153450",
            "shadowAlpha": 0.34,
            "shadowBlur": 0.030,
            "shadowOffsetY": 0.027,
            "topHighlightAlpha": 0.18,
            "glows": [
                {"center": (0.20, 0.05), "radius": 0.60, "color": "#FFFFFF", "alpha": 190, "blur": 0.20},
                {"center": (0.86, 0.86), "radius": 0.58, "color": "#C8FF3D", "alpha": 48, "blur": 0.22},
            ],
        },
        {
            "id": "milk",
            "name": "Coconut Milk",
            "role": "Warm calm alternate",
            "bgTop": "#FFFDF7",
            "bgBottom": "#DDE7E0",
            "markTop": "#202015",
            "markBottom": "#060704",
            "edgeColor": "#FFFFFF",
            "edgeAlpha": 0.17,
            "shadowColor": "#47524B",
            "shadowAlpha": 0.28,
            "shadowBlur": 0.025,
            "shadowOffsetY": 0.025,
            "topHighlightAlpha": 0.18,
            "glows": [
                {"center": (0.10, 0.02), "radius": 0.62, "color": "#FFFFFF", "alpha": 220, "blur": 0.19},
                {"center": (0.88, 0.82), "radius": 0.48, "color": "#BDEAFF", "alpha": 44, "blur": 0.20},
            ],
        },
    ]

    icons: dict[str, Image.Image] = {}
    for variant in variants:
        icon = render_icon(variant, CANVAS)
        icons[str(variant["id"])] = icon
        icon.save(ROOT / "masters" / f"ohana-smile-{variant['id']}-1024.png", optimize=True)

    render_mark("#050608", CANVAS).save(ROOT / "source" / "ohana-smile-mark-black-1024.png", optimize=True)
    render_mark("#FFFFFF", CANVAS).save(ROOT / "source" / "ohana-smile-mark-white-1024.png", optimize=True)
    write_svg()

    universal_dir = ROOT / "ios-universal" / "AppIconOhanaSmile.appiconset"
    universal_dir.mkdir(parents=True, exist_ok=True)
    icons["primary"].save(universal_dir / "AppIconOhanaSmile.png", optimize=True)
    icons["dark"].save(universal_dir / "AppIconOhanaSmileDark.png", optimize=True)
    icons["tinted"].save(universal_dir / "AppIconOhanaSmileTinted.png", optimize=True)
    write_contents_json(
        universal_dir / "Contents.json",
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

    save_legacy_iconset("AppIconOhanaSmileLight", icons["primary"], ROOT / "ios-legacy" / "AppIconOhanaSmileLight.appiconset")
    save_legacy_iconset("AppIconOhanaSmileDark", icons["dark"], ROOT / "ios-legacy" / "AppIconOhanaSmileDark.appiconset")
    save_legacy_iconset("AppIconOhanaSmileTinted", icons["tinted"], ROOT / "ios-legacy" / "AppIconOhanaSmileTinted.appiconset")

    preview = create_preview(variants, icons)
    preview.save(ROOT / "previews" / "ohana-smile-icon-suite-preview.png", optimize=True)

    token_payload = {
        "brand": "Ohana",
        "sourceReference": str((ROOT.parents[1] / "Icon.png").resolve()),
        "generatedAt": "2026-06-09",
        "geometry": {
            "canvas": CANVAS,
            "mark": "two circular eyes plus single closed cubic smile body",
            "smallSizeRule": "Symbol remains one silhouette and is tested down to 40 px.",
        },
        "variants": [
            {
                "id": variant["id"],
                "name": variant["name"],
                "role": variant["role"],
                "master": f"masters/ohana-smile-{variant['id']}-1024.png",
                "background": [variant["bgTop"], variant["bgBottom"]],
                "mark": [variant["markTop"], variant["markBottom"]],
            }
            for variant in variants
        ],
        "xcode": {
            "universalAppIconSet": "ios-universal/AppIconOhanaSmile.appiconset",
            "legacyLight": "ios-legacy/AppIconOhanaSmileLight.appiconset",
            "legacyDark": "ios-legacy/AppIconOhanaSmileDark.appiconset",
            "legacyTinted": "ios-legacy/AppIconOhanaSmileTinted.appiconset",
        },
    }
    (ROOT / "icon-suite-tokens.json").write_text(json.dumps(token_payload, indent=2) + "\n", encoding="utf-8")
    write_readme(variants)


if __name__ == "__main__":
    main()
