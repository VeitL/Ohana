//
//  AddPetWizardImagePreparation.swift
//  Ohana
//
//  Shared avatar image preparation kept behind AddPetWizardView compatibility APIs.
//

import Foundation
import ImageIO
import UIKit

extension AddPetWizardContentView {
    nonisolated static func downsample(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    nonisolated static func cropReadyImage(from data: Data, maxPixel: CGFloat = 1_600) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data).map { preparedCropImage($0, maxPixel: maxPixel) }
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }

        return UIImage(data: data).map { preparedCropImage($0, maxPixel: maxPixel) }
    }

    nonisolated static func preparedCropImage(_ image: UIImage, maxPixel: CGFloat = 1_600) -> UIImage {
        let resized = downsample(image, maxDim: maxPixel)
        guard resized.imageOrientation != .up else { return resized }
        let renderer = UIGraphicsImageRenderer(size: resized.size)
        return renderer.image { _ in
            resized.draw(in: CGRect(origin: .zero, size: resized.size))
        }
    }

    nonisolated static func optimizedAvatarAsset(
        _ image: UIImage,
        preserveAlpha: Bool,
        maxPixel: CGFloat = 900
    ) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preserveAlpha
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
