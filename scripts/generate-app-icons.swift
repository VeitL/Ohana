#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct Palette: Decodable {
    let variants: [Variant]
}

private struct Variant: Decodable {
    let assetSet: String
    let displayName: String
    let appearances: [String: Appearance]
}

private struct Appearance: Decodable {
    let backgroundStart: String
    let backgroundEnd: String
    let mark: String
    let accent: String
}

private enum GeneratorError: LocalizedError {
    case invalidRepositoryRoot
    case missingMarkPath
    case missingAppearance(String, String)
    case commandFailed(String)
    case imageDecodeFailed(String)
    case bitmapContextFailed
    case pngWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryRoot:
            "Run this script from the Ohana repository root."
        case .missingMarkPath:
            "Could not find the ohana-mark path in OhanaMark.svg."
        case let .missingAppearance(assetSet, appearance):
            "Missing \(appearance) palette for \(assetSet)."
        case let .commandFailed(command):
            "Command failed: \(command)"
        case let .imageDecodeFailed(path):
            "Could not decode generated image: \(path)"
        case .bitmapContextFailed:
            "Could not create an opaque RGB bitmap context."
        case let .pngWriteFailed(path):
            "Could not write PNG: \(path)"
        }
    }
}

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let sourceRoot = root.appending(path: "Resources/AppIconSources", directoryHint: .isDirectory)
private let paletteURL = sourceRoot.appending(path: "AppIconPalette.json")
private let markURL = sourceRoot.appending(path: "OhanaMark.svg")
private let generatedRoot = sourceRoot.appending(path: "Generated", directoryHint: .isDirectory)
private let catalogRoot = root.appending(path: "Ohana/Assets.xcassets", directoryHint: .isDirectory)
private let iconComposerRoot = root.appending(path: "Ohana/AppIcons", directoryHint: .isDirectory)

guard fileManager.fileExists(atPath: paletteURL.path), fileManager.fileExists(atPath: markURL.path) else {
    throw GeneratorError.invalidRepositoryRoot
}

private let palette = try JSONDecoder().decode(Palette.self, from: Data(contentsOf: paletteURL))
let markSource = try String(contentsOf: markURL, encoding: .utf8)
let markPattern = #"<path id="ohana-mark" d="([^"]+)"/>"#
let markRegex = try NSRegularExpression(pattern: markPattern)
let sourceRange = NSRange(markSource.startIndex ..< markSource.endIndex, in: markSource)
guard let match = markRegex.firstMatch(in: markSource, range: sourceRange),
      let pathRange = Range(match.range(at: 1), in: markSource)
else {
    throw GeneratorError.missingMarkPath
}
let markPath = String(markSource[pathRange])

try fileManager.createDirectory(at: generatedRoot, withIntermediateDirectories: true)
try fileManager.createDirectory(at: iconComposerRoot, withIntermediateDirectories: true)

for variant in palette.variants {
    let variantSourceRoot = generatedRoot.appending(path: variant.assetSet, directoryHint: .isDirectory)
    let assetSetRoot = catalogRoot.appending(path: "\(variant.assetSet).appiconset", directoryHint: .isDirectory)
    let previewSetRoot = catalogRoot.appending(
        path: "\(previewAssetName(assetSet: variant.assetSet)).imageset",
        directoryHint: .isDirectory
    )
    try fileManager.createDirectory(at: variantSourceRoot, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: previewSetRoot, withIntermediateDirectories: true)
    try writeIconComposerPackage(for: variant, markSource: markSource)
    try previewContentsJSON(assetSet: variant.assetSet).write(
        to: previewSetRoot.appending(path: "Contents.json"),
        atomically: true,
        encoding: .utf8
    )

    for appearanceName in ["default", "dark", "tinted"] {
        guard let appearance = variant.appearances[appearanceName] else {
            throw GeneratorError.missingAppearance(variant.assetSet, appearanceName)
        }

        let svg = iconSVG(
            title: "\(variant.displayName) \(appearanceName)",
            appearance: appearance,
            markPath: markPath
        )
        let svgURL = variantSourceRoot.appending(path: "\(appearanceName).svg")
        try svg.write(to: svgURL, atomically: true, encoding: .utf8)

        let temporaryPNG = fileManager.temporaryDirectory
            .appending(path: "ohana-\(variant.assetSet)-\(appearanceName)-rgba.png")
        try run("/usr/bin/sips", ["-s", "format", "png", svgURL.path, "--out", temporaryPNG.path])

        let destinationURL = assetSetRoot.appending(
            path: productionFilename(assetSet: variant.assetSet, appearance: appearanceName)
        )
        try writeOpaquePNG(from: temporaryPNG, to: destinationURL)
        if appearanceName != "tinted" {
            let previewURL = previewSetRoot.appending(
                path: previewFilename(assetSet: variant.assetSet, appearance: appearanceName)
            )
            try writeOpaquePNG(from: temporaryPNG, to: previewURL)
        }
        try? fileManager.removeItem(at: temporaryPNG)
        print("generated \(destinationURL.path)")
    }
}

private func writeIconComposerPackage(for variant: Variant, markSource: String) throws {
    guard let defaultAppearance = variant.appearances["default"],
          let darkAppearance = variant.appearances["dark"],
          let tintedAppearance = variant.appearances["tinted"]
    else {
        throw GeneratorError.missingAppearance(variant.assetSet, "default, dark, or tinted")
    }

    let packageRoot = iconComposerRoot.appending(
        path: "\(variant.assetSet).icon",
        directoryHint: .isDirectory
    )
    let assetsRoot = packageRoot.appending(path: "Assets", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: assetsRoot, withIntermediateDirectories: true)

    for obsoleteAsset in ["Icon.png", "OhanaMark.png"] {
        try? fileManager.removeItem(at: assetsRoot.appending(path: obsoleteAsset))
    }
    try markSource.write(
        to: assetsRoot.appending(path: "OhanaMark.svg"),
        atomically: true,
        encoding: .utf8
    )

    let document: [String: Any] = [
        "fill-specializations": [
            ["value": ["automatic-gradient": iconComposerColor(defaultAppearance.backgroundStart)]],
            [
                "appearance": "dark",
                "value": ["automatic-gradient": iconComposerColor(darkAppearance.backgroundStart)]
            ]
        ],
        "groups": [[
            "layers": [[
                "blend-mode-specializations": [["value": "normal"]],
                "fill-specializations": [
                    ["value": ["solid": iconComposerColor(defaultAppearance.mark)]],
                    [
                        "appearance": "dark",
                        "value": ["solid": iconComposerColor(darkAppearance.mark)]
                    ],
                    [
                        "appearance": "tinted",
                        "value": ["solid": iconComposerColor(tintedAppearance.mark)]
                    ]
                ],
                "glass-specializations": [
                    ["value": false],
                    ["idiom": "square", "value": false]
                ],
                "hidden": false,
                "image-name": "OhanaMark.svg",
                "name": "Ohana Mark",
                "opacity": 1
            ]],
            "shadow": ["kind": "neutral", "opacity": 0.28],
            "translucency": ["enabled": true, "value": 0.16]
        ]],
        "supported-platforms": [
            "circles": ["watchOS"],
            "squares": "shared"
        ]
    ]

    let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: packageRoot.appending(path: "icon.json"), options: .atomic)
}

private func iconComposerColor(_ hex: String) -> String {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard digits.count == 6, let value = Int(digits, radix: 16) else {
        return "srgb:0.00000,0.00000,0.00000,1.00000"
    }

    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255
    return String(format: "srgb:%.5f,%.5f,%.5f,1.00000", red, green, blue)
}

private func previewAssetName(assetSet: String) -> String {
    "\(assetSet)Preview"
}

private func previewFilename(assetSet: String, appearance: String) -> String {
    "\(previewAssetName(assetSet: assetSet))\(appearance == "dark" ? "Dark" : "").png"
}

private func previewContentsJSON(assetSet: String) -> String {
    """
    {
      "images" : [
        {
          "filename" : "\(previewFilename(assetSet: assetSet, appearance: "default"))",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "filename" : "\(previewFilename(assetSet: assetSet, appearance: "dark"))",
          "idiom" : "universal",
          "scale" : "1x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
}

private func productionFilename(assetSet: String, appearance: String) -> String {
    switch (assetSet, appearance) {
    case ("AppIcon", "default"): "AppIcon.png"
    case ("AppIcon", "dark"): "AppIconDark.png"
    case ("AppIcon", "tinted"): "AppIconTinted.png"
    case (_, "default"): "\(assetSet).png"
    case (_, "dark"): "\(assetSet)Dark.png"
    default: "\(assetSet)Tinted.png"
    }
}

private func iconSVG(title: String, appearance: Appearance, markPath: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
      <title>\(title)</title>
      <defs>
        <linearGradient id="background" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="\(appearance.backgroundStart)"/>
          <stop offset="1" stop-color="\(appearance.backgroundEnd)"/>
        </linearGradient>
        <radialGradient id="highlight" cx="0.18" cy="0.12" r="0.74">
          <stop offset="0" stop-color="\(appearance.accent)" stop-opacity="0.22"/>
          <stop offset="0.48" stop-color="\(appearance.accent)" stop-opacity="0.07"/>
          <stop offset="1" stop-color="\(appearance.accent)" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <rect width="1024" height="1024" fill="url(#background)"/>
      <rect width="1024" height="1024" fill="url(#highlight)"/>
      <path d="\(markPath)" fill="\(appearance.mark)"/>
    </svg>
    """
}

private func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw GeneratorError.commandFailed(([executable] + arguments).joined(separator: " "))
    }
}

private func writeOpaquePNG(from source: URL, to destination: URL) throws {
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
        throw GeneratorError.imageDecodeFailed(source.path)
    }

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        throw GeneratorError.bitmapContextFailed
    }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let flattened = context.makeImage(),
          let destinationWriter = CGImageDestinationCreateWithURL(
              destination as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          )
    else {
        throw GeneratorError.pngWriteFailed(destination.path)
    }

    CGImageDestinationAddImage(destinationWriter, flattened, nil)
    guard CGImageDestinationFinalize(destinationWriter) else {
        throw GeneratorError.pngWriteFailed(destination.path)
    }
}
