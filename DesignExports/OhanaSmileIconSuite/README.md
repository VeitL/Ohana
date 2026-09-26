# Ohana Exact Black / White Icon Suite

`input/Icon.png` is the source of truth. The mark is extracted from its alpha channel and rendered as a binary mask, so the icon uses only pure black `#000000` and pure white `#FFFFFF`.

## Contents

- `input/Icon.png`: raster extraction source.
- `input/Icon.svg`: editable vector source.
- `input/Icon.pixel-exact.svg`: pixel-exact vector reference.
- `masters/ohana-smile-black-on-white-1024.png`: black mark on white.
- `masters/ohana-smile-white-on-black-1024.png`: white mark on black.
- `source/ohana-smile-mask-binary-1024.png`: pure black/white extracted mask.
- `source/ohana-smile-mark-black-transparent-1024.png`: black transparent glyph source.
- `source/ohana-smile-mark-white-transparent-1024.png`: white transparent glyph source.
- `ios-universal/AppIconOhanaSmile.appiconset/`: Xcode-ready universal light/dark/tinted icon set.
- `ios-legacy/`: full iPhone/iPad size exports for both black-on-white and white-on-black variants.
- `previews/ohana-smile-bw-icon-suite-preview.png`: preview and small-size proof.

## Extraction Rules

- Source: `input/Icon.png`.
- Canvas: `1024x1024`.
- Mask: alpha channel, threshold `>= 16`.
- Final opaque app icons contain only two RGB values: black and white.

This deliberately avoids gradients, shadows, blur, edge highlights, and redrawn curves.
