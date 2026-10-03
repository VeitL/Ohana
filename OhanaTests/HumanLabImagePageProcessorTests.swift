import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Ohana

@MainActor
@Suite("Human lab image page processor")
struct HumanLabImagePageProcessorTests {
    @Test("Large photo pages are normalized inside both pixel budgets")
    func largePhotoIsDownsampled() async throws {
        let sourceImage = try Self.makeGrayscaleImage(width: 4000, height: 3000)
        let sourceData = try Self.jpegData(from: sourceImage)
        let sourceURL = try Self.makeTemporaryFile(contents: sourceData, pathExtension: "jpg")
        defer { Self.removeTemporaryFile(at: sourceURL) }

        let normalizedData = try await HumanLabImagePageProcessingClient.live
            .normalizePhotoPageFile(sourceURL, 0)
        let normalizedImage = try Self.decodeImage(normalizedData)

        #expect(sourceData.count <= HumanLabImagePageProcessingClient.maximumSourceBytes)
        #expect(
            max(normalizedImage.width, normalizedImage.height)
                <= HumanLabImagePageProcessingClient.maximumPageLongEdge
        )
        #expect(
            normalizedImage.width * normalizedImage.height
                <= HumanLabImagePageProcessingClient.maximumPagePixelCount
        )
        #expect(normalizedImage.width > normalizedImage.height)
    }

    @Test("Camera orientation is applied before the bounded output is encoded")
    func cameraOrientationIsNormalized() async throws {
        let sourceImage = try Self.makeGrayscaleImage(width: 4000, height: 3000)
        let source = HumanLabCameraPageImage(image: sourceImage, orientation: .right)

        let normalizedData = try await HumanLabImagePageProcessingClient.live
            .normalizeCameraPage(source, 0)
        let normalizedImage = try Self.decodeImage(normalizedData)

        #expect(normalizedImage.height > normalizedImage.width)
        #expect(
            max(normalizedImage.width, normalizedImage.height)
                <= HumanLabImagePageProcessingClient.maximumPageLongEdge
        )
        #expect(
            normalizedImage.width * normalizedImage.height
                <= HumanLabImagePageProcessingClient.maximumPagePixelCount
        )
    }

    @Test("A photo source over 50 MiB fails before decoding")
    func oversizedPhotoSourceFailsClosed() async throws {
        let maximum = HumanLabImagePageProcessingClient.maximumSourceBytes
        let sourceURL = try Self.makeTemporaryFile(contents: Data(), pathExtension: "jpg")
        defer { Self.removeTemporaryFile(at: sourceURL) }
        let handle = try FileHandle(forWritingTo: sourceURL)
        try handle.truncate(atOffset: UInt64(maximum + 1))
        try handle.close()
        let transferredPage = try await HumanLabPhotoPickerPageTransfer.importingFile(
            at: sourceURL,
            pageIndex: 0,
            processor: .live
        )

        #expect(throws: HumanLabImagePageProcessingError.sourceTooLarge(
            index: 2,
            maximumBytes: maximum
        )) {
            try transferredPage.normalizedData(for: 2)
        }
    }

    @Test("Empty and undecodable photo pages fail as unreadable")
    func emptyAndUnreadablePagesFailClosed() async throws {
        let emptyURL = try Self.makeTemporaryFile(contents: Data(), pathExtension: "jpg")
        let unreadableURL = try Self.makeTemporaryFile(
            contents: Data("not an image".utf8),
            pathExtension: "jpg"
        )
        defer {
            Self.removeTemporaryFile(at: emptyURL)
            Self.removeTemporaryFile(at: unreadableURL)
        }

        await #expect(throws: HumanLabImagePageProcessingError.unreadablePage(index: 0)) {
            try await HumanLabImagePageProcessingClient.live
                .normalizePhotoPageFile(emptyURL, 0)
        }
        await #expect(throws: HumanLabImagePageProcessingError.unreadablePage(index: 1)) {
            try await HumanLabImagePageProcessingClient.live
                .normalizePhotoPageFile(unreadableURL, 1)
        }
    }

    @Test("Photos load, normalize, and enter recognition one page at a time")
    func photoRecognitionIsSequentialAndPreservesPageIndexes() async throws {
        let probe = SequenceProbe()
        let processor = HumanLabImagePageProcessingClient(
            normalizePhotoPageFile: { _, pageIndex in
                await probe.record("normalize-\(pageIndex)")
                return Data([UInt8(pageIndex)])
            },
            normalizeCameraPage: { _, pageIndex in
                await probe.record("camera-\(pageIndex)")
                return Data([UInt8(pageIndex)])
            }
        )
        let recognizer = HumanLabDocumentRecognitionClient { pageData in
            let marker = Int(try #require(pageData.first?.first))
            await probe.record("recognize-\(marker)")
            return [HumanLabOCRPage(
                pageIndex: 0,
                transcript: "TSH \(marker)",
                confidence: 0.99
            )]
        }
        let providerFile = try Self.makeTemporaryFile(contents: Data([1]), pathExtension: "jpg")
        defer { Self.removeTemporaryFile(at: providerFile) }

        let pages = try await HumanLabSequentialPageRecognizer.recognizePhotoPages(
            pageCount: 3,
            loadPage: { pageIndex in
                await probe.record("load-\(pageIndex)")
                let transferredPage = try await HumanLabPhotoPickerPageTransfer.importingFile(
                    at: providerFile,
                    pageIndex: pageIndex,
                    processor: processor
                )
                return try transferredPage.normalizedData(for: pageIndex)
            },
            recognitionClient: recognizer
        )
        let events = await probe.events

        #expect(pages.map(\.pageIndex) == [0, 1, 2])
        #expect(events == [
            "load-0", "normalize-0", "recognize-0",
            "load-1", "normalize-1", "recognize-1",
            "load-2", "normalize-2", "recognize-2"
        ])
    }

    @Test("Camera pages also enter normalization and OCR one at a time")
    func cameraRecognitionIsSequentialAndPreservesPageIndexes() async throws {
        let probe = SequenceProbe()
        let sourceImage = try Self.makeGrayscaleImage(width: 8, height: 8)
        let processor = HumanLabImagePageProcessingClient(
            normalizePhotoPageFile: { _, _ in Data([0]) },
            normalizeCameraPage: { _, pageIndex in
                await probe.record("normalize-\(pageIndex)")
                return Data([UInt8(pageIndex)])
            }
        )
        let recognizer = HumanLabDocumentRecognitionClient { pageData in
            let marker = Int(try #require(pageData.first?.first))
            await probe.record("recognize-\(marker)")
            return [HumanLabOCRPage(
                pageIndex: 0,
                transcript: "TSH \(marker)",
                confidence: 0.99
            )]
        }

        let pages = try await HumanLabSequentialPageRecognizer.recognizeCameraPages(
            pageCount: 2,
            loadPage: { pageIndex in
                await probe.record("load-\(pageIndex)")
                return HumanLabCameraPageImage(image: sourceImage)
            },
            processor: processor,
            recognitionClient: recognizer
        )
        let events = await probe.events

        #expect(pages.map(\.pageIndex) == [0, 1])
        #expect(events == [
            "load-0", "normalize-0", "recognize-0",
            "load-1", "normalize-1", "recognize-1"
        ])
    }

    @Test("The normalized output sum fails closed before the next OCR call")
    func cumulativeOutputBudgetFailsClosed() async throws {
        let probe = RecognitionCountProbe()
        let recognizer = HumanLabDocumentRecognitionClient { _ in
            await probe.increment()
            return [HumanLabOCRPage(pageIndex: 0, transcript: "TSH 2.4", confidence: 0.99)]
        }

        await #expect(throws: HumanLabImagePageProcessingError.normalizedOutputTooLarge(
            maximumBytes: 10
        )) {
            try await HumanLabSequentialPageRecognizer.recognizePhotoPages(
                pageCount: 2,
                loadPage: { _ in Data(repeating: 7, count: 6) },
                recognitionClient: recognizer,
                maximumNormalizedOutputBytes: 10
            )
        }
        let recognitionCount = await probe.count
        #expect(recognitionCount == 1)
    }

    @Test("Image budget errors use an existing localized failure surface")
    func budgetErrorsUseLocalizedFailureCopy() {
        let l = L10n("en")
        let description = HumanLabImportFailureCopy.recognition(
            HumanLabImagePageProcessingError.normalizedOutputTooLarge(maximumBytes: 64),
            l: l
        )

        #expect(description == HumanLabScanCopy.text(.genericRecognitionFailure, l: l))
    }

    private actor SequenceProbe {
        private var storage: [String] = []

        func record(_ event: String) {
            storage.append(event)
        }

        var events: [String] { storage }
    }

    private actor RecognitionCountProbe {
        private(set) var count = 0

        func increment() {
            count += 1
        }
    }

    private enum FixtureError: Error {
        case couldNotCreateImage
        case couldNotEncodeImage
        case couldNotDecodeImage
    }

    private static func makeGrayscaleImage(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw FixtureError.couldNotCreateImage
        }
        context.setFillColor(gray: 0.72, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw FixtureError.couldNotCreateImage
        }
        return image
    }

    private static func jpegData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw FixtureError.couldNotEncodeImage
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.couldNotEncodeImage
        }
        return data as Data
    }

    private static func decodeImage(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FixtureError.couldNotDecodeImage
        }
        return image
    }

    private static func makeTemporaryFile(
        contents: Data,
        pathExtension: String
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HumanLabImagePageProcessorTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("source").appendingPathExtension(pathExtension)
        try contents.write(to: url, options: .atomic)
        return url
    }

    private static func removeTemporaryFile(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
