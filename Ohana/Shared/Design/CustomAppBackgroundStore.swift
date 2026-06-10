//
//  CustomAppBackgroundStore.swift
//  Ohana
//

import Foundation
import SwiftUI
#if os(iOS)
    import UIKit
#endif

enum CustomAppBackgroundStore {
    private static let folderName = "Ohana"
    private static let fileName = "custom-background.jpg"

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(fileName)
    }

    static var image: UIImage? {
        UIImage(contentsOfFile: fileURL.path) // smoothness: allow settings-scoped custom background preview load; render paths use prepared background views.
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func saveImageData(_ data: Data) throws {
        guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) } // smoothness: allow explicit import/save path, not a finger-frame render decode.
        let optimized = optimizedBackgroundImage(image)
        guard let jpegData = optimized.jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpegData.write(to: fileURL, options: [.atomic])
    }

    static func deleteImage() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func optimizedBackgroundImage(_ image: UIImage) -> UIImage {
        let maxPixel: CGFloat = 2400
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
