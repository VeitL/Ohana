//
//  HumanLabImagePageProcessor.swift
//  Ohana
//
//  Volatile, bounded normalization for photo-library and document-camera pages.
//

import CoreGraphics
import CoreImage
import CoreTransferable
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum HumanLabImagePageProcessingError: Error, Equatable, Sendable {
    case noReadablePages
    case pageLimitExceeded(maximum: Int)
    case sourceTooLarge(index: Int, maximumBytes: Int)
    case unreadablePage(index: Int)
    case normalizedOutputTooLarge(maximumBytes: Int)

    func replacingPageIndex(with pageIndex: Int) -> HumanLabImagePageProcessingError {
        switch self {
        case .sourceTooLarge:
            .sourceTooLarge(
                index: pageIndex,
                maximumBytes: HumanLabImagePageProcessingClient.maximumSourceBytes
            )
        case .unreadablePage:
            .unreadablePage(index: pageIndex)
        case .noReadablePages,
             .pageLimitExceeded,
             .normalizedOutputTooLarge:
            self
        }
    }
}

/// Loads a PhotosPicker selection through its provider-owned file
/// representation and finishes normalization before that temporary URL leaves
/// the import closure. Raw source bytes are never copied into app-owned memory
/// or an app-managed temporary file.
nonisolated struct HumanLabPhotoPickerPageTransfer: Transferable, Sendable {
    private let outcome: Result<Data, HumanLabImagePageProcessingError>

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { receivedFile in
            try await importingFile(
                at: receivedFile.file,
                pageIndex: 0,
                processor: .live
            )
        }
    }

    static func importingFile(
        at sourceURL: URL,
        pageIndex: Int,
        processor: HumanLabImagePageProcessingClient
    ) async throws -> HumanLabPhotoPickerPageTransfer {
        do {
            let normalizedData = try await processor.normalizePhotoPageFile(
                sourceURL,
                pageIndex
            )
            try Task.checkCancellation()
            return HumanLabPhotoPickerPageTransfer(outcome: .success(normalizedData))
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HumanLabImagePageProcessingError {
            return HumanLabPhotoPickerPageTransfer(outcome: .failure(error))
        }
    }

    func normalizedData(for pageIndex: Int) throws -> Data {
        switch outcome {
        case let .success(data):
            data
        case let .failure(error):
            throw error.replacingPageIndex(with: pageIndex)
        }
    }
}

/// `CGImage` is an immutable Core Graphics snapshot. The wrapper deliberately
/// crosses the main-actor camera bridge without sending a mutable `UIImage`.
nonisolated struct HumanLabCameraPageImage: @unchecked Sendable {
    fileprivate let image: CGImage
    let orientation: CGImagePropertyOrientation

    init(image: CGImage, orientation: CGImagePropertyOrientation = .up) {
        self.image = image
        self.orientation = orientation
    }

    var pixelWidth: Int { image.width }
    var pixelHeight: Int { image.height }
}

nonisolated struct HumanLabImagePageProcessingClient: Sendable {
    static let maximumPageCount = HumanLabPDFPageLoadingClient.maximumPageCount
    static let maximumPagePixelCount = HumanLabPDFPageLoadingClient.maximumPagePixelCount
    static let maximumPageLongEdge = HumanLabPDFPageLoadingClient.maximumPageLongEdge
    static let maximumSourceBytes = HumanLabPDFPageLoadingClient.maximumSourceFileBytes
    static let maximumNormalizedOutputBytes = HumanLabPDFPageLoadingClient.maximumRenderedOutputBytes

    var normalizePhotoPageFile: @Sendable (
        _ sourceURL: URL,
        _ pageIndex: Int
    ) async throws -> Data
    var normalizeCameraPage: @Sendable (
        _ sourceImage: HumanLabCameraPageImage,
        _ pageIndex: Int
    ) async throws -> Data

    init(
        normalizePhotoPageFile: @escaping @Sendable (
            _ sourceURL: URL,
            _ pageIndex: Int
        ) async throws -> Data,
        normalizeCameraPage: @escaping @Sendable (
            _ sourceImage: HumanLabCameraPageImage,
            _ pageIndex: Int
        ) async throws -> Data
    ) {
        self.normalizePhotoPageFile = normalizePhotoPageFile
        self.normalizeCameraPage = normalizeCameraPage
    }

    static let live = HumanLabImagePageProcessingClient(
        normalizePhotoPageFile: { sourceURL, pageIndex in
            return try await HumanLabImagePageNormalizer.offMain {
                try HumanLabImagePageNormalizer.normalize(
                    sourceURL: sourceURL,
                    pageIndex: pageIndex
                )
            }
        },
        normalizeCameraPage: { sourceImage, pageIndex in
            return try await HumanLabImagePageNormalizer.offMain {
                try HumanLabImagePageNormalizer.normalize(
                    cameraImage: sourceImage,
                    pageIndex: pageIndex
                )
            }
        }
    )
}

nonisolated enum HumanLabSequentialPageRecognizer {
    typealias PhotoPageLoader = @MainActor @Sendable (
        _ pageIndex: Int
    ) async throws -> Data?
    typealias CameraPageLoader = @MainActor @Sendable (
        _ pageIndex: Int
    ) async throws -> HumanLabCameraPageImage?

    static func recognizePhotoPages(
        pageCount: Int,
        loadPage: @escaping PhotoPageLoader,
        recognitionClient: HumanLabDocumentRecognitionClient,
        maximumNormalizedOutputBytes: Int = HumanLabImagePageProcessingClient
            .maximumNormalizedOutputBytes
    ) async throws -> [HumanLabOCRPage] {
        try validatePageCount(pageCount)
        var pages: [HumanLabOCRPage] = []
        pages.reserveCapacity(pageCount)
        var normalizedByteCount = 0

        for pageIndex in 0 ..< pageCount {
            try Task.checkCancellation()
            let result = try await recognize(
                pageIndex: pageIndex,
                normalizedByteCount: normalizedByteCount,
                maximumNormalizedOutputBytes: maximumNormalizedOutputBytes,
                recognitionClient: recognitionClient,
                loadNormalizedPage: {
                    try await normalizedPhotoPage(
                        at: pageIndex,
                        loadPage: loadPage
                    )
                }
            )
            normalizedByteCount = result.normalizedByteCount
            pages.append(result.page)
        }

        return pages
    }

    static func recognizeCameraPages(
        pageCount: Int,
        loadPage: @escaping CameraPageLoader,
        processor: HumanLabImagePageProcessingClient,
        recognitionClient: HumanLabDocumentRecognitionClient,
        maximumNormalizedOutputBytes: Int = HumanLabImagePageProcessingClient
            .maximumNormalizedOutputBytes
    ) async throws -> [HumanLabOCRPage] {
        try validatePageCount(pageCount)
        var pages: [HumanLabOCRPage] = []
        pages.reserveCapacity(pageCount)
        var normalizedByteCount = 0

        for pageIndex in 0 ..< pageCount {
            try Task.checkCancellation()
            let result = try await recognize(
                pageIndex: pageIndex,
                normalizedByteCount: normalizedByteCount,
                maximumNormalizedOutputBytes: maximumNormalizedOutputBytes,
                recognitionClient: recognitionClient,
                loadNormalizedPage: {
                    try await normalizedCameraPage(
                        at: pageIndex,
                        loadPage: loadPage,
                        processor: processor
                    )
                }
            )
            normalizedByteCount = result.normalizedByteCount
            pages.append(result.page)
        }

        return pages
    }

    private static func normalizedPhotoPage(
        at pageIndex: Int,
        loadPage: PhotoPageLoader
    ) async throws -> Data {
        guard let normalizedData = try await loadPage(pageIndex) else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        try Task.checkCancellation()
        return normalizedData
    }

    private static func normalizedCameraPage(
        at pageIndex: Int,
        loadPage: CameraPageLoader,
        processor: HumanLabImagePageProcessingClient
    ) async throws -> Data {
        guard let sourceImage = try await loadPage(pageIndex) else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        try Task.checkCancellation()
        return try await processor.normalizeCameraPage(sourceImage, pageIndex)
    }

    private static func recognize(
        pageIndex: Int,
        normalizedByteCount: Int,
        maximumNormalizedOutputBytes: Int,
        recognitionClient: HumanLabDocumentRecognitionClient,
        loadNormalizedPage: @escaping @Sendable () async throws -> Data
    ) async throws -> (page: HumanLabOCRPage, normalizedByteCount: Int) {
        var volatilePageData = try await loadNormalizedPage()
        defer { volatilePageData.removeAll(keepingCapacity: false) }
        guard !volatilePageData.isEmpty else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        guard maximumNormalizedOutputBytes >= 0,
              volatilePageData.count <= maximumNormalizedOutputBytes - normalizedByteCount else {
            throw HumanLabImagePageProcessingError.normalizedOutputTooLarge(
                maximumBytes: maximumNormalizedOutputBytes
            )
        }
        let nextNormalizedByteCount = normalizedByteCount + volatilePageData.count
        try Task.checkCancellation()
        let page = try await recognitionClient.recognizePage(
            volatilePageData,
            pageIndex: pageIndex
        )
        return (page, nextNormalizedByteCount)
    }

    private static func validatePageCount(_ pageCount: Int) throws {
        guard pageCount > 0 else {
            throw HumanLabImagePageProcessingError.noReadablePages
        }
        guard pageCount <= HumanLabImagePageProcessingClient.maximumPageCount else {
            throw HumanLabImagePageProcessingError.pageLimitExceeded(
                maximum: HumanLabImagePageProcessingClient.maximumPageCount
            )
        }
    }
}

private nonisolated enum HumanLabImagePageNormalizer {
    private static let jpegCompressionQuality = 0.94

    static func offMain<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try autoreleasepool(invoking: operation)
        }
        return try await withTaskCancellationHandler(operation: {
            try await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    static func normalize(sourceURL: URL, pageIndex: Int) throws -> Data {
        try Task.checkCancellation()
        guard sourceURL.isFileURL else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let sourceSize: Int
        do {
            let attributes = try FileManager.default.attributesOfItem(
                atPath: sourceURL.path
            )
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber,
                  size.int64Value >= 0,
                  size.int64Value <= Int64(Int.max) else {
                throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
            }
            sourceSize = Int(size.int64Value)
        } catch let error as HumanLabImagePageProcessingError {
            throw error
        } catch {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        guard sourceSize > 0 else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        guard sourceSize <= HumanLabImagePageProcessingClient.maximumSourceBytes else {
            throw HumanLabImagePageProcessingError.sourceTooLarge(
                index: pageIndex,
                maximumBytes: HumanLabImagePageProcessingClient.maximumSourceBytes
            )
        }
        try Task.checkCancellation()
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(
            sourceURL as CFURL,
            sourceOptions as CFDictionary
        ),
        CGImageSourceGetCount(source) > 0,
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int,
        let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let dimensions = try targetDimensions(
            width: width,
            height: height,
            orientation: imageOrientation(from: properties),
            pageIndex: pageIndex
        )
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(dimensions.width, dimensions.height)
        ]
        try Task.checkCancellation()
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        try Task.checkCancellation()
        return try encodeNormalized(thumbnail, pageIndex: pageIndex)
    }

    static func normalize(
        cameraImage: HumanLabCameraPageImage,
        pageIndex: Int
    ) throws -> Data {
        try Task.checkCancellation()
        let dimensions = try targetDimensions(
            width: cameraImage.pixelWidth,
            height: cameraImage.pixelHeight,
            orientation: cameraImage.orientation,
            pageIndex: pageIndex
        )
        let input = CIImage(cgImage: cameraImage.image).oriented(cameraImage.orientation)
        let orientedExtent = input.extent.integral
        guard orientedExtent.width.isFinite,
              orientedExtent.height.isFinite,
              orientedExtent.width > 0,
              orientedExtent.height > 0 else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let translated = input.transformed(by: CGAffineTransform(
            translationX: -orientedExtent.minX,
            y: -orientedExtent.minY
        ))
        let scaled = translated.transformed(by: CGAffineTransform(
            scaleX: CGFloat(dimensions.width) / orientedExtent.width,
            y: CGFloat(dimensions.height) / orientedExtent.height
        ))
        try Task.checkCancellation()
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let normalizedImage = context.createCGImage(
            scaled,
            from: CGRect(
                x: 0,
                y: 0,
                width: dimensions.width,
                height: dimensions.height
            ),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        try Task.checkCancellation()
        return try encodeNormalized(normalizedImage, pageIndex: pageIndex)
    }

    private static func targetDimensions(
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation,
        pageIndex: Int
    ) throws -> (width: Int, height: Int) {
        guard width > 0, height > 0 else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let swapsAxes = switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored: true
        default: false
        }
        let orientedWidth = swapsAxes ? height : width
        let orientedHeight = swapsAxes ? width : height
        let longestSide = Double(max(orientedWidth, orientedHeight))
        let pixelCount = Double(orientedWidth) * Double(orientedHeight)
        guard longestSide.isFinite,
              longestSide > 0,
              pixelCount.isFinite,
              pixelCount > 0 else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let longEdgeScale = Double(HumanLabImagePageProcessingClient.maximumPageLongEdge)
            / longestSide
        let pixelBudgetScale = sqrt(
            Double(HumanLabImagePageProcessingClient.maximumPagePixelCount) / pixelCount
        )
        let scale = min(1, longEdgeScale, pixelBudgetScale)
        guard scale.isFinite, scale > 0 else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        var targetWidth = max(1, Int((Double(orientedWidth) * scale).rounded(.down)))
        var targetHeight = max(1, Int((Double(orientedHeight) * scale).rounded(.down)))
        if targetWidth > HumanLabImagePageProcessingClient.maximumPagePixelCount / targetHeight {
            if targetWidth >= targetHeight {
                targetWidth = max(
                    1,
                    HumanLabImagePageProcessingClient.maximumPagePixelCount / targetHeight
                )
            } else {
                targetHeight = max(
                    1,
                    HumanLabImagePageProcessingClient.maximumPagePixelCount / targetWidth
                )
            }
        }
        return (targetWidth, targetHeight)
    }

    private static func imageOrientation(
        from properties: [CFString: Any]
    ) -> CGImagePropertyOrientation {
        guard let rawValue = properties[kCGImagePropertyOrientation] as? NSNumber,
              let orientation = CGImagePropertyOrientation(
                  rawValue: rawValue.uint32Value
              ) else {
            return .up
        }
        return orientation
    }

    private static func encodeNormalized(
        _ image: CGImage,
        pageIndex: Int
    ) throws -> Data {
        guard image.width > 0,
              image.height > 0,
              image.width <= HumanLabImagePageProcessingClient.maximumPageLongEdge,
              image.height <= HumanLabImagePageProcessingClient.maximumPageLongEdge,
              image.width <= HumanLabImagePageProcessingClient.maximumPagePixelCount / image.height
        else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(bounds)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        guard let opaqueImage = context.makeImage() else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        try Task.checkCancellation()
        let encodedData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encodedData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        CGImageDestinationAddImage(
            destination,
            opaqueImage,
            [kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality]
                as CFDictionary
        )
        try Task.checkCancellation()
        guard CGImageDestinationFinalize(destination), encodedData.length > 0 else {
            throw HumanLabImagePageProcessingError.unreadablePage(index: pageIndex)
        }
        guard encodedData.length <= HumanLabImagePageProcessingClient
            .maximumNormalizedOutputBytes else {
            throw HumanLabImagePageProcessingError.normalizedOutputTooLarge(
                maximumBytes: HumanLabImagePageProcessingClient.maximumNormalizedOutputBytes
            )
        }
        try Task.checkCancellation()
        return encodedData as Data
    }
}
