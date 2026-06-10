//
//  MemberAvatarImageProcessor.swift
//  Ohana
//
//  Avatar image decoding, cropping, and encoding helpers.
//

import ImageIO
import UIKit

enum MemberAvatarImageProcessor {
    nonisolated static let portraitAspect: CGFloat = 1.58

    nonisolated static func image(from data: Data, maxPixel: CGFloat = 2400) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data).map(normalized) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data).map(normalized) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    nonisolated static func downsample(_ image: UIImage, maxPixel: CGFloat, preserveAlpha: Bool) -> UIImage {
        let image = normalized(image)
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preserveAlpha
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    nonisolated static func encodedAvatarData(from image: UIImage) -> Data? {
        let normalized = normalized(image)
        let hasAlpha = ImageCutoutService.imageHasTransparentPixels(normalized)
        if hasAlpha {
            let trimmed = ImageCutoutService.trimmedTransparentSubjectImage(from: normalized) ?? normalized
            return downsample(trimmed, maxPixel: 900, preserveAlpha: true).pngData()
        }
        return downsample(normalized, maxPixel: 1200, preserveAlpha: false).jpegData(compressionQuality: 0.88)
    }

    nonisolated static func encodedCroppedAvatarData(
        image: UIImage,
        scale: CGFloat,
        offset: CGSize,
        outputWidth: CGFloat = 900
    ) -> Data? {
        let outputSize = CGSize(width: outputWidth, height: outputWidth * portraitAspect)
        let cropRect = CGRect(origin: .zero, size: outputSize)
        let baseScale = max(outputSize.width / image.size.width, outputSize.height / image.size.height)
        let renderedSize = CGSize(width: image.size.width * baseScale * scale, height: image.size.height * baseScale * scale)
        let imageFrame = CGRect(
            x: cropRect.midX - renderedSize.width / 2 + offset.width * (outputWidth / 320),
            y: cropRect.midY - renderedSize.height / 2 + offset.height * (outputWidth / 320),
            width: renderedSize.width,
            height: renderedSize.height
        )
        let cropped = croppedImage(
            image: image,
            cropRect: cropRect,
            renderedImageFrame: imageFrame,
            outputSize: outputSize
        )
        return encodedAvatarData(from: cropped)
    }

    nonisolated static func croppedImage(image: UIImage, cropRect: CGRect, renderedImageFrame: CGRect, outputSize: CGSize) -> UIImage {
        let source = normalized(image)
        let scale = max(renderedImageFrame.width / source.size.width, renderedImageFrame.height / source.size.height)
        let originX = (cropRect.minX - renderedImageFrame.minX) / scale
        let originY = (cropRect.minY - renderedImageFrame.minY) / scale
        let sourceRect = CGRect(
            x: max(0, min(source.size.width - 1, originX)),
            y: max(0, min(source.size.height - 1, originY)),
            width: min(source.size.width, cropRect.width / scale),
            height: min(source.size.height, cropRect.height / scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            source.draw(
                in: CGRect(
                    x: -sourceRect.minX * outputSize.width / sourceRect.width,
                    y: -sourceRect.minY * outputSize.height / sourceRect.height,
                    width: source.size.width * outputSize.width / sourceRect.width,
                    height: source.size.height * outputSize.height / sourceRect.height
                )
            )
        }
    }
}
