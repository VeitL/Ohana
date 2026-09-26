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

    nonisolated static func portraitCropSize(
        in container: CGSize,
        horizontalMargin: CGFloat,
        reservedVerticalSpace: CGFloat
    ) -> CGSize {
        guard container.width > 0, container.height > 0 else { return .zero }
        let availableWidth = max(0, container.width - max(0, horizontalMargin) * 2)
        let availableHeight = max(0, container.height - max(0, reservedVerticalSpace))
        guard availableWidth > 0, availableHeight > 0 else { return .zero }

        let cropWidth = min(availableWidth, availableHeight / portraitAspect)
        return CGSize(width: cropWidth, height: cropWidth * portraitAspect)
    }

    nonisolated static func clampedCropScale(
        _ proposed: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        let lowerBound = max(0, minimum)
        let upperBound = max(lowerBound, maximum)
        guard proposed.isFinite else { return lowerBound }
        return min(upperBound, max(lowerBound, proposed))
    }

    nonisolated static func clampedCropOffset(
        _ proposed: CGSize,
        displayedImageSize: CGSize,
        cropSize: CGSize
    ) -> CGSize {
        guard proposed.width.isFinite,
              proposed.height.isFinite,
              displayedImageSize.width.isFinite,
              displayedImageSize.height.isFinite,
              cropSize.width.isFinite,
              cropSize.height.isFinite,
              displayedImageSize.width > 0,
              displayedImageSize.height > 0,
              cropSize.width > 0,
              cropSize.height > 0 else {
            return .zero
        }

        let horizontalLimit = max(0, (displayedImageSize.width - cropSize.width) / 2)
        let verticalLimit = max(0, (displayedImageSize.height - cropSize.height) / 2)
        return CGSize(
            width: min(horizontalLimit, max(-horizontalLimit, proposed.width)),
            height: min(verticalLimit, max(-verticalLimit, proposed.height))
        )
    }

    nonisolated static func outputCropOffset(
        _ offset: CGSize,
        displayCropSize: CGSize,
        outputSize: CGSize
    ) -> CGSize {
        guard displayCropSize.width > 0,
              displayCropSize.height > 0,
              outputSize.width > 0,
              outputSize.height > 0 else {
            return .zero
        }
        return CGSize(
            width: offset.width * outputSize.width / displayCropSize.width,
            height: offset.height * outputSize.height / displayCropSize.height
        )
    }

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

    nonisolated static func persistableAvatarData(_ data: Data?) -> Data? {
        guard let data, let image = image(from: data) else { return data }
        return encodedAvatarData(from: image) ?? data
    }

    nonisolated static func encodedCroppedAvatarData(
        image: UIImage,
        scale: CGFloat,
        offset: CGSize,
        displayCropSize: CGSize = CGSize(width: 320, height: 320 * portraitAspect),
        outputWidth: CGFloat = 900
    ) -> Data? {
        let outputSize = CGSize(width: outputWidth, height: outputWidth * portraitAspect)
        let cropRect = CGRect(origin: .zero, size: outputSize)
        let baseScale = max(outputSize.width / image.size.width, outputSize.height / image.size.height)
        let renderedSize = CGSize(width: image.size.width * baseScale * scale, height: image.size.height * baseScale * scale)
        let outputOffset = outputCropOffset(
            offset,
            displayCropSize: displayCropSize,
            outputSize: outputSize
        )
        let imageFrame = CGRect(
            x: cropRect.midX - renderedSize.width / 2 + outputOffset.width,
            y: cropRect.midY - renderedSize.height / 2 + outputOffset.height,
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
