# Ohana app icon sources

`OhanaMark.svg` is the single vector mark shared by the primary icon and every
alternate icon. `AppIconPalette.json` is the source of truth for the Default,
Dark, and Mono color treatments.

Regenerate every tracked app-icon SVG and PNG from the repository root:

```sh
swift scripts/generate-app-icons.swift
```

The generated full-icon SVGs live under `Generated/`. The production PNGs are
written into their matching `Ohana/Assets.xcassets/*.appiconset` directories.
The generator removes the alpha channel after rasterization, so the resulting
1024 x 1024 PNG files are valid full-bleed app-icon artwork.

The same run also creates matching `*Preview.imageset` resources for in-app
shop and inventory previews. App-icon sets are system metadata and cannot be
loaded with `UIImage(named:)`; the preview sets keep runtime artwork visually
identical without duplicating the design source.

Production Icon Composer documents are generated under `Ohana/AppIcons/`.
Each package embeds the transparent Ohana vector mark and annotates Default,
Dark, and Mono appearances from the same palette. Xcode compiles these packages
as the system app icons; the matching app-icon sets remain a compatible raster
fallback and preview source. Do not add a rounded-square mask because Apple
applies the platform mask.
