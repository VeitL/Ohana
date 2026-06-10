//
//  ImageSubjectCutoutProcessor.swift
//  Ohana
//
//  UI-facing image cutout helpers. Keeps views decoupled from the concrete
//  Vision-backed implementation while preserving nonisolated pixel inspection.
//

import UIKit

enum ImageSubjectCutoutProcessor {
    @MainActor
    static func removeBackground(from image: UIImage) async throws -> UIImage? {
        try await ImageCutoutService().removeBackground(from: image)
    }

    nonisolated static func isTransparentPNG(_ data: Data) -> Bool {
        ImageCutoutService.isTransparentPNG(data)
    }

    nonisolated static func imageHasTransparentPixels(_ image: UIImage, alphaThreshold: UInt8 = 245) -> Bool {
        ImageCutoutService.imageHasTransparentPixels(image, alphaThreshold: alphaThreshold)
    }

    nonisolated static func trimmedTransparentSubjectImage(
        from image: UIImage,
        alphaThreshold: UInt8 = 12
    ) -> UIImage? {
        ImageCutoutService.trimmedTransparentSubjectImage(from: image, alphaThreshold: alphaThreshold)
    }
}
