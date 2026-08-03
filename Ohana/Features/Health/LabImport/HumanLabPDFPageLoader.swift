//
//  HumanLabPDFPageLoader.swift
//  Ohana
//
//  Bounded, on-device PDF page rendering for volatile lab report recognition.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum HumanLabPDFPageLoadingError: Error, Equatable, Sendable {
    case unreadableFile
    case fileTooLarge(maximumBytes: Int)
    case noReadablePages
    case pageLimitExceeded(maximum: Int)
    case pageRenderingFailed(index: Int)
    case renderedOutputTooLarge(maximumBytes: Int)
}

nonisolated struct HumanLabPDFPageLoadingClient: Sendable {
    typealias RenderedPageHandler = @Sendable (
        _ pageIndex: Int,
        _ imageData: Data
    ) async throws -> Void

    static let maximumPageCount = HumanLabDocumentRecognitionClient.maximumPageCount
    static let maximumPagePixelCount = 10_000_000
    static let maximumPageLongEdge = 3600
    static let maximumSourceFileBytes = 50 * 1024 * 1024
    static let maximumRenderedOutputBytes = 64 * 1024 * 1024

    var loadPages: @Sendable (_ url: URL) async throws -> [Data]
    private var processPages: @Sendable (
        _ url: URL,
        _ handler: @escaping RenderedPageHandler
    ) async throws -> Void

    init(
        loadPages: @escaping @Sendable (_ url: URL) async throws -> [Data],
        processPages: (@Sendable (
            _ url: URL,
            _ handler: @escaping RenderedPageHandler
        ) async throws -> Void)? = nil
    ) {
        self.loadPages = loadPages
        self.processPages = processPages ?? { url, handler in
            var renderedPages = try await loadPages(url)
            defer { renderedPages.removeAll(keepingCapacity: false) }

            for pageIndex in renderedPages.indices {
                try Task.checkCancellation()
                var pageData = renderedPages[pageIndex]
                renderedPages[pageIndex].removeAll(keepingCapacity: false)
                defer { pageData.removeAll(keepingCapacity: false) }
                try await handler(pageIndex, pageData)
            }
        }
    }

    func callAsFunction(_ url: URL) async throws -> [Data] {
        try await loadPages(url)
    }

    /// Maps one rendered page at a time. The next page is not rendered until
    /// `transform` returns, so callers can finish OCR and release the image data
    /// before the renderer allocates another page bitmap.
    func mapRenderedPages<Element: Sendable>(
        from url: URL,
        transform: @escaping @Sendable (
            _ pageIndex: Int,
            _ imageData: Data
        ) async throws -> Element
    ) async throws -> [Element] {
        let accumulator = HumanLabPDFPageAccumulator<Element>()
        try await processPages(url) { pageIndex, imageData in
            let element = try await transform(pageIndex, imageData)
            await accumulator.append(element)
        }
        return await accumulator.elements
    }

    static let live = HumanLabPDFPageLoadingClient(
        loadPages: { url in
            try await HumanLabPDFPageRenderer.renderPages(from: url)
        },
        processPages: { url, handler in
            try await HumanLabPDFPageRenderer.processPages(from: url, handler: handler)
        }
    )
}

private actor HumanLabPDFPageAccumulator<Element: Sendable> {
    private var storage: [Element] = []

    func append(_ element: Element) {
        storage.append(element)
    }

    var elements: [Element] { storage }
}

private nonisolated enum HumanLabPDFPageRenderer {
    private static let jpegCompressionQuality = 0.94

    static func renderPages(from url: URL) async throws -> [Data] {
        let accumulator = HumanLabPDFPageAccumulator<Data>()
        try await processPages(from: url) { _, pageData in
            await accumulator.append(pageData)
        }
        return await accumulator.elements
    }

    static func processPages(
        from url: URL,
        handler: @escaping HumanLabPDFPageLoadingClient.RenderedPageHandler
    ) async throws {
        let task = Task.detached(priority: .userInitiated) {
            try await processPagesInDetachedTask(from: url, handler: handler)
        }
        return try await withTaskCancellationHandler(operation: {
            try await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    private static func processPagesInDetachedTask(
        from url: URL,
        handler: HumanLabPDFPageLoadingClient.RenderedPageHandler
    ) async throws {
        try Task.checkCancellation()
        guard url.isFileURL else {
            throw HumanLabPDFPageLoadingError.unreadableFile
        }

        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues: URLResourceValues
        do {
            resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        } catch {
            throw HumanLabPDFPageLoadingError.unreadableFile
        }
        guard resourceValues.isRegularFile != false,
              let fileSize = resourceValues.fileSize,
              fileSize > 0 else {
            throw HumanLabPDFPageLoadingError.unreadableFile
        }
        guard fileSize <= HumanLabPDFPageLoadingClient.maximumSourceFileBytes else {
            throw HumanLabPDFPageLoadingError.fileTooLarge(
                maximumBytes: HumanLabPDFPageLoadingClient.maximumSourceFileBytes
            )
        }

        try Task.checkCancellation()
        guard let document = CGPDFDocument(url as CFURL), document.isUnlocked else {
            throw HumanLabPDFPageLoadingError.unreadableFile
        }
        let pageCount = document.numberOfPages
        guard pageCount > 0 else {
            throw HumanLabPDFPageLoadingError.noReadablePages
        }
        guard pageCount <= HumanLabPDFPageLoadingClient.maximumPageCount else {
            throw HumanLabPDFPageLoadingError.pageLimitExceeded(
                maximum: HumanLabPDFPageLoadingClient.maximumPageCount
            )
        }

        var renderedByteCount = 0

        for pageNumber in 1 ... pageCount {
            try Task.checkCancellation()
            let pageIndex = pageNumber - 1
            guard let page = document.page(at: pageNumber) else {
                throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
            }
            var pageData = try autoreleasepool {
                try render(page: page, pageIndex: pageIndex)
            }
            defer { pageData.removeAll(keepingCapacity: false) }
            guard pageData.count <= HumanLabPDFPageLoadingClient.maximumRenderedOutputBytes
                - renderedByteCount else {
                throw HumanLabPDFPageLoadingError.renderedOutputTooLarge(
                    maximumBytes: HumanLabPDFPageLoadingClient.maximumRenderedOutputBytes
                )
            }
            renderedByteCount += pageData.count
            try await handler(pageIndex, pageData)
        }

        try Task.checkCancellation()
    }

    private static func render(page: CGPDFPage, pageIndex: Int) throws -> Data {
        try Task.checkCancellation()
        let box = usableBox(for: page)
        let bounds = page.getBoxRect(box).standardized
        guard bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0 else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }

        let normalizedRotation = ((page.rotationAngle % 360) + 360) % 360
        let orientedSize = normalizedRotation == 90 || normalizedRotation == 270
            ? CGSize(width: bounds.height, height: bounds.width)
            : bounds.size
        let longestSide = max(orientedSize.width, orientedSize.height)
        let pageArea = orientedSize.width * orientedSize.height
        guard longestSide.isFinite,
              longestSide > 0,
              pageArea.isFinite,
              pageArea > 0 else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }

        let longEdgeScale = CGFloat(
            HumanLabPDFPageLoadingClient.maximumPageLongEdge
        ) / longestSide
        let pixelBudgetScale = sqrt(
            CGFloat(HumanLabPDFPageLoadingClient.maximumPagePixelCount) / pageArea
        )
        let scale = min(longEdgeScale, pixelBudgetScale)
        guard scale.isFinite, scale > 0 else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }

        var pixelWidth = min(
            HumanLabPDFPageLoadingClient.maximumPageLongEdge,
            max(1, Int((orientedSize.width * scale).rounded(.down)))
        )
        var pixelHeight = min(
            HumanLabPDFPageLoadingClient.maximumPageLongEdge,
            max(1, Int((orientedSize.height * scale).rounded(.down)))
        )
        // Guard against floating-point rounding crossing the allocation budget.
        if pixelWidth > HumanLabPDFPageLoadingClient.maximumPagePixelCount / pixelHeight {
            if pixelWidth >= pixelHeight {
                pixelWidth = max(
                    1,
                    HumanLabPDFPageLoadingClient.maximumPagePixelCount / pixelHeight
                )
            } else {
                pixelHeight = max(
                    1,
                    HumanLabPDFPageLoadingClient.maximumPagePixelCount / pixelWidth
                )
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }

        let renderRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(pixelWidth),
            height: CGFloat(pixelHeight)
        )
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(renderRect)
        // CGPDFPage's drawing transform does not upscale a point-sized page
        // into a larger bitmap on current SDKs. Establish the point-to-pixel
        // scale explicitly, then let the page transform handle crop/rotation.
        context.scaleBy(
            x: CGFloat(pixelWidth) / orientedSize.width,
            y: CGFloat(pixelHeight) / orientedSize.height
        )
        context.concatenate(page.getDrawingTransform(
            box,
            rect: CGRect(origin: .zero, size: orientedSize),
            rotate: 0,
            preserveAspectRatio: true
        ))
        context.interpolationQuality = .high
        try Task.checkCancellation()
        context.drawPDFPage(page)
        try Task.checkCancellation()

        guard let image = context.makeImage() else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }
        try Task.checkCancellation()
        let encodedData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encodedData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality] as CFDictionary
        )
        try Task.checkCancellation()
        guard CGImageDestinationFinalize(destination), encodedData.length > 0 else {
            throw HumanLabPDFPageLoadingError.pageRenderingFailed(index: pageIndex)
        }
        try Task.checkCancellation()
        return encodedData as Data
    }

    private static func usableBox(for page: CGPDFPage) -> CGPDFBox {
        let cropBox = page.getBoxRect(.cropBox).standardized
        if cropBox.width.isFinite,
           cropBox.height.isFinite,
           cropBox.width > 0,
           cropBox.height > 0 {
            return .cropBox
        }
        return .mediaBox
    }
}
