import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Ohana

@Suite("Human lab PDF page loader")
struct HumanLabPDFPageLoaderTests {
    @Test("A PDF page is rendered across the output canvas")
    func renderedPageUsesFullCanvas() async throws {
        let mediaBox = CGRect(x: 0, y: 0, width: 600, height: 800)
        let url = try Self.makePDF(pageCount: 1, mediaBox: mediaBox) { context, box, _ in
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(box)
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(box.insetBy(dx: box.width * 0.125, dy: box.height * 0.125))
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let renderedPages = try await HumanLabPDFPageLoadingClient.live(url)
        let renderedData = try #require(renderedPages.first)
        let renderedImage = try Self.decodeImage(renderedData)

        #expect(renderedPages.count == 1)
        #expect(renderedImage.width == 2700)
        #expect(renderedImage.height == 3600)

        let sample = try Self.grayscaleSample(of: renderedImage, side: 64)
        let darkPixelCount = sample.pixels.count { $0 < 80 }
        let darkFraction = Double(darkPixelCount) / Double(sample.pixels.count)

        #expect(darkFraction > 0.45)
        #expect(sample.pixel(x: sample.side / 2, y: sample.side / 2) < 80)
        #expect(sample.pixel(x: sample.side * 3 / 4, y: sample.side / 2) < 80)
        #expect(sample.pixel(x: sample.side / 20, y: sample.side / 20) > 200)
    }

    @Test("PDFs over the page limit fail before recognition")
    func pageLimitIsEnforced() async throws {
        let maximum = HumanLabPDFPageLoadingClient.maximumPageCount
        let url = try Self.makePDF(pageCount: maximum + 1) { context, _, pageIndex in
            context.setFillColor(gray: pageIndex.isMultiple(of: 2) ? 0 : 1, alpha: 1)
            context.fill(CGRect(x: 8, y: 8, width: 16, height: 16))
        }
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: HumanLabPDFPageLoadingError.pageLimitExceeded(maximum: maximum)) {
            try await HumanLabPDFPageLoadingClient.live(url)
        }
    }

    @Test("Rendered pages stay within the pixel allocation budget")
    func pagePixelBudgetIsEnforced() async throws {
        let url = try Self.makePDF(
            pageCount: 1,
            mediaBox: CGRect(x: 0, y: 0, width: 800, height: 800)
        ) { context, box, _ in
            context.setFillColor(gray: 0.5, alpha: 1)
            context.fill(box)
        }
        defer { try? FileManager.default.removeItem(at: url) }

        let renderedPages = try await HumanLabPDFPageLoadingClient.live(url)
        let renderedData = try #require(renderedPages.first)
        let renderedImage = try Self.decodeImage(renderedData)

        #expect(renderedImage.width == renderedImage.height)
        #expect(
            renderedImage.width * renderedImage.height
                <= HumanLabPDFPageLoadingClient.maximumPagePixelCount
        )
    }

    @Test("Streaming mapping waits for each page consumer and preserves page indexes")
    func streamingMappingIsSequential() async throws {
        let pageCount = 3
        let url = try Self.makePDF(pageCount: pageCount) { context, box, pageIndex in
            context.setFillColor(gray: CGFloat(pageIndex + 1) / CGFloat(pageCount + 1), alpha: 1)
            context.fill(box)
        }
        defer { try? FileManager.default.removeItem(at: url) }
        let probe = StreamingProbe()

        let mappedIndexes = try await HumanLabPDFPageLoadingClient.live.mapRenderedPages(
            from: url
        ) { pageIndex, imageData in
            await probe.begin(pageIndex: pageIndex, byteCount: imageData.count)
            await Task.yield()
            await probe.finish()
            return pageIndex
        }
        let snapshot = await probe.snapshot()

        #expect(mappedIndexes == Array(0 ..< pageCount))
        #expect(snapshot.pageIndexes == Array(0 ..< pageCount))
        #expect(snapshot.byteCounts.allSatisfy { $0 > 0 })
        #expect(snapshot.maximumActiveConsumerCount == 1)
    }

    @Test("A non-PDF file is rejected as unreadable")
    func invalidPDFIsRejected() async throws {
        let url = Self.temporaryURL()
        try Data("not a PDF".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: HumanLabPDFPageLoadingError.unreadableFile) {
            try await HumanLabPDFPageLoadingClient.live(url)
        }
    }

    private struct GrayscaleSample {
        let side: Int
        let pixels: [UInt8]

        func pixel(x: Int, y: Int) -> UInt8 {
            pixels[y * side + x]
        }
    }

    private actor StreamingProbe {
        private var activeConsumerCount = 0
        private var maximumActiveConsumerCount = 0
        private var pageIndexes: [Int] = []
        private var byteCounts: [Int] = []

        func begin(pageIndex: Int, byteCount: Int) {
            activeConsumerCount += 1
            maximumActiveConsumerCount = max(
                maximumActiveConsumerCount,
                activeConsumerCount
            )
            pageIndexes.append(pageIndex)
            byteCounts.append(byteCount)
        }

        func finish() {
            activeConsumerCount -= 1
        }

        func snapshot() -> (
            pageIndexes: [Int],
            byteCounts: [Int],
            maximumActiveConsumerCount: Int
        ) {
            (pageIndexes, byteCounts, maximumActiveConsumerCount)
        }
    }

    private enum FixtureError: Error {
        case couldNotCreatePDF
        case couldNotDecodeImage
        case couldNotCreateSampleContext
    }

    private static func makePDF(
        pageCount: Int,
        mediaBox: CGRect = CGRect(x: 0, y: 0, width: 600, height: 800),
        drawPage: (_ context: CGContext, _ mediaBox: CGRect, _ pageIndex: Int) -> Void
    ) throws -> URL {
        let url = temporaryURL()
        var mutableMediaBox = mediaBox
        guard let context = CGContext(url as CFURL, mediaBox: &mutableMediaBox, nil) else {
            throw FixtureError.couldNotCreatePDF
        }
        for pageIndex in 0 ..< pageCount {
            context.beginPDFPage(nil)
            drawPage(context, mediaBox, pageIndex)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private static func decodeImage(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FixtureError.couldNotDecodeImage
        }
        return image
    }

    private static func grayscaleSample(of image: CGImage, side: Int) throws -> GrayscaleSample {
        var pixels = [UInt8](repeating: 0, count: side * side)
        let didDraw = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard didDraw else {
            throw FixtureError.couldNotCreateSampleContext
        }
        return GrayscaleSample(side: side, pixels: pixels)
    }

    private static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ohana-lab-pdf-loader-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
    }
}
