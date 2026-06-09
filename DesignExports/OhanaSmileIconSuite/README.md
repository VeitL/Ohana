# Ohana Smile Icon Suite

Generated from `Icon.png` as a market-ready app icon suite. The system keeps the original two-dot plus wide-smile silhouette, then adds production icon treatments for iOS light, dark, tinted, and alternate contexts.

## Design Direction

- Keep the mark oversized and readable at 40 px.
- Use a single memorable silhouette; color and lighting change by variant, not the symbol geometry.
- Avoid busy pet literalism. The mark reads as smile, family, and soft companion care without becoming a generic paw.
- Export square opaque app icons; iOS applies the rounded mask at runtime.

## Contents

- `masters/`: 1024 px square PNG masters.
- `source/`: transparent mark PNGs and editable SVG.
- `ios-universal/AppIconOhanaSmile.appiconset/`: Xcode-ready 1024 universal light/dark/tinted set.
- `ios-legacy/`: full iPhone/iPad size exports for light, dark, and tinted appearances.
- `previews/ohana-smile-icon-suite-preview.png`: contact sheet with small-size proof.
- `icon-suite-tokens.json`: palette, roles, and file mapping.

## Variants

- `primary`: Clean Day - Default light app icon
- `dark`: Lime Night - Default dark app icon
- `tinted`: System Tint - iOS tinted appearance
- `graphite`: Soft Graphite - Closest to the provided reference
- `lagoon`: Lagoon Blue - Clean premium alternate
- `milk`: Coconut Milk - Warm calm alternate

## Recommended Use

- Default app icon: `primary` light, `dark` dark, `tinted` tinted in the universal appiconset.
- App Store visual exploration or alternate icon shop: use `graphite`, `lagoon`, and `milk` as premium alternates.
- Functional UI glyphs should continue to follow the existing monochrome SF Symbol/vector policy; this suite is for app identity surfaces.

Generated deterministically with Pillow so the same geometry can be regenerated after token tweaks.
