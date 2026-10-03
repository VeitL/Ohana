//
//  OnDeviceHumanLabDocumentRecognizer.swift
//  Ohana
//
//  Apple Vision document recognition only. This client performs no network
//  request and returns value DTOs so image data can be released after review.
//

import Foundation
import ImageIO
import Vision

nonisolated enum HumanLabDocumentRecognitionError: Error, Equatable, Sendable {
    case noPages
    case pageLimitExceeded(maximum: Int)
    case unreadablePage(index: Int)
}

nonisolated struct HumanLabDocumentRecognitionClient: Sendable {
    static let maximumPageCount = 6

    var recognize: @Sendable (_ pageImageData: [Data]) async throws -> [HumanLabOCRPage]

    init(
        recognize: @escaping @Sendable (_ pageImageData: [Data]) async throws -> [HumanLabOCRPage]
    ) {
        self.recognize = recognize
    }

    func callAsFunction(_ pageImageData: [Data]) async throws -> [HumanLabOCRPage] {
        try await recognize(pageImageData)
    }

    /// Recognizes exactly one volatile page and restores the caller-owned page
    /// index. This keeps photo, camera, and PDF callers from handing a whole
    /// image batch to Vision at once.
    func recognizePage(
        _ imageData: Data,
        pageIndex: Int
    ) async throws -> HumanLabOCRPage {
        guard !imageData.isEmpty else {
            throw HumanLabDocumentRecognitionError.unreadablePage(index: pageIndex)
        }
        let recognizedPages = try await recognize([imageData])
        try Task.checkCancellation()
        guard recognizedPages.count == 1,
              let recognizedPage = recognizedPages.first else {
            throw HumanLabDocumentRecognitionError.unreadablePage(index: pageIndex)
        }
        return HumanLabOCRPage(
            pageIndex: pageIndex,
            transcript: recognizedPage.transcript,
            confidence: recognizedPage.confidence,
            tables: recognizedPage.tables,
            textLines: recognizedPage.textLines,
            wasTruncated: recognizedPage.wasTruncated
        )
    }

    @MainActor
    static var live: HumanLabDocumentRecognitionClient {
        let catalogWords = HealthMetricCatalog.all.flatMap { metric in
            [metric.nameZh, metric.nameEn, metric.nameDe] + metric.shortNames
        }
        let customWords = Array(Set(catalogWords)).sorted().prefix(512)

        return HumanLabDocumentRecognitionClient { pageImageData in
            try await OnDeviceHumanLabDocumentRecognizer.recognize(
                pageImageData: pageImageData,
                customWords: Array(customWords)
            )
        }
    }
}

private nonisolated enum OnDeviceHumanLabDocumentRecognizer {
    private static let maximumTranscriptCharacters = 131_072
    private static let maximumTextLineCount = 2048
    private static let maximumTableCount = 32
    private static let maximumCellCount = 4096

    static func recognize(
        pageImageData: [Data],
        customWords: [String]
    ) async throws -> [HumanLabOCRPage] {
        guard !pageImageData.isEmpty else {
            throw HumanLabDocumentRecognitionError.noPages
        }
        guard pageImageData.count <= HumanLabDocumentRecognitionClient.maximumPageCount else {
            throw HumanLabDocumentRecognitionError.pageLimitExceeded(
                maximum: HumanLabDocumentRecognitionClient.maximumPageCount
            )
        }

        var pages: [HumanLabOCRPage] = []
        pages.reserveCapacity(pageImageData.count)

        // Pages are intentionally processed in order. This bounds peak memory and
        // keeps page indices stable for review and retry.
        for (pageIndex, imageData) in pageImageData.enumerated() {
            try Task.checkCancellation()
            guard !imageData.isEmpty else {
                throw HumanLabDocumentRecognitionError.unreadablePage(index: pageIndex)
            }

            let orientation = imageOrientation(in: imageData)
            let documentPage = try await recognizeDocumentPage(
                imageData: imageData,
                pageIndex: pageIndex,
                orientation: orientation,
                customWords: customWords
            )
            try Task.checkCancellation()
            let numericFallback: BoundedTextLines
            do {
                numericFallback = try await recognizeNumericFallbackLines(
                    in: imageData,
                    orientation: orientation
                )
            } catch {
                try Task.checkCancellation()
                numericFallback = BoundedTextLines(lines: [], wasTruncated: false)
            }
            let mergedLines = try mergeDocumentLines(
                documentPage.textLines,
                with: numericFallback.lines
            )
            let parameterFallback: BoundedTextLines
            if let region = parameterColumnRegion(in: documentPage) {
                do {
                    parameterFallback = try await recognizeParameterFallbackLines(
                        in: imageData,
                        orientation: orientation,
                        region: region,
                        customWords: customWords
                    )
                } catch {
                    try Task.checkCancellation()
                    parameterFallback = BoundedTextLines(lines: [], wasTruncated: false)
                }
            } else {
                parameterFallback = BoundedTextLines(lines: [], wasTruncated: false)
            }
            let linesWithParameterFallback = try mergeParameterLines(
                mergedLines.lines,
                with: parameterFallback.lines
            )
            pages.append(HumanLabOCRPage(
                pageIndex: documentPage.pageIndex,
                transcript: documentPage.transcript,
                confidence: documentPage.confidence,
                tables: documentPage.tables,
                textLines: linesWithParameterFallback.lines,
                wasTruncated: documentPage.wasTruncated
                    || numericFallback.wasTruncated
                    || mergedLines.wasTruncated
                    || parameterFallback.wasTruncated
                    || linesWithParameterFallback.wasTruncated
            ))
        }

        return pages
    }

    private static let preferredLanguages: [Locale.Language] = [
        Locale.Language(languageCode: "zh", script: "Hans"),
        Locale.Language(languageCode: "zh", script: "Hant"),
        Locale.Language(languageCode: "en"),
        Locale.Language(languageCode: "de"),
        Locale.Language(languageCode: "es"),
        Locale.Language(languageCode: "pt"),
        Locale.Language(languageCode: "fr"),
        Locale.Language(languageCode: "it"),
        Locale.Language(languageCode: "ja"),
        Locale.Language(languageCode: "ko")
    ]

    private static func recognizeDocumentPage(
        imageData: Data,
        pageIndex: Int,
        orientation: CGImagePropertyOrientation?,
        customWords: [String]
    ) async throws -> HumanLabOCRPage {
        var request = RecognizeDocumentsRequest()
        var textOptions = request.textRecognitionOptions
        textOptions.automaticallyDetectLanguage = true
        textOptions.useLanguageCorrection = true
        textOptions.maximumCandidateCount = 1
        textOptions.customWords = customWords
        textOptions.recognitionLanguages = preferredLanguages.filter(
            request.supportedRecognitionLanguages.contains
        )
        request.textRecognitionOptions = textOptions

        var barcodeOptions = request.barcodeDetectionOptions
        barcodeOptions.enabled = false
        request.barcodeDetectionOptions = barcodeOptions

        let observations = try await request.perform(
            on: imageData,
            orientation: orientation
        )
        try Task.checkCancellation()
        guard !observations.isEmpty else {
            throw HumanLabDocumentRecognitionError.unreadablePage(index: pageIndex)
        }
        return try makePage(index: pageIndex, observations: observations)
    }

    private static func makePage(
        index: Int,
        observations: [DocumentObservation]
    ) throws -> HumanLabOCRPage {
        var wasTruncated = false
        var transcriptParts: [String] = []
        var transcriptCharacterCount = 0
        for observation in observations {
            try Task.checkCancellation()
            let part = trimmed(observation.document.text.transcript)
            guard !part.isEmpty else { continue }
            let separatorCount = transcriptParts.isEmpty ? 0 : 1
            let remaining = maximumTranscriptCharacters - transcriptCharacterCount - separatorCount
            guard remaining > 0 else {
                wasTruncated = true
                break
            }
            if part.count > remaining {
                transcriptParts.append(String(part.prefix(remaining)))
                transcriptCharacterCount = maximumTranscriptCharacters
                wasTruncated = true
                break
            }
            transcriptParts.append(part)
            transcriptCharacterCount += separatorCount + part.count
        }
        let transcript = transcriptParts.joined(separator: "\n")

        var textLineConfidences: [Float] = []
        var documentTextLines: [HumanLabOCRTextLine] = []
        textLineConfidences.reserveCapacity(min(maximumTextLineCount, 256))
        documentTextLines.reserveCapacity(min(maximumTextLineCount, 256))
        textLineLoop: for observation in observations {
            for line in observation.document.text.lines {
                if documentTextLines.count.isMultiple(of: 64) {
                    try Task.checkCancellation()
                }
                guard documentTextLines.count < maximumTextLineCount else {
                    wasTruncated = true
                    break textLineLoop
                }
                let text = trimmed(line.transcript)
                guard !text.isEmpty else { continue }
                textLineConfidences.append(line.confidence)
                documentTextLines.append(HumanLabOCRTextLine(
                    text: text,
                    confidence: line.confidence,
                    bounds: HumanLabOCRBounds(line.boundingBox.cgRect)
                ))
            }
        }
        let pageConfidence = average(
            textLineConfidences.isEmpty
                ? observations.map(\.confidence)
                : textLineConfidences
        )

        var tables: [HumanLabOCRTable] = []
        var cellCount = 0
        tableLoop: for observation in observations {
            for table in observation.document.tables {
                try Task.checkCancellation()
                guard tables.count < maximumTableCount else {
                    wasTruncated = true
                    break tableLoop
                }
                var rows: [[HumanLabOCRCell]] = []
                for row in table.rows {
                    var cells: [HumanLabOCRCell] = []
                    for cell in row {
                        guard cellCount < maximumCellCount else {
                            wasTruncated = true
                            break
                        }
                        if cellCount.isMultiple(of: 64) {
                            try Task.checkCancellation()
                        }
                        let lineConfidences = cell.content.text.lines.map(\.confidence)
                        cells.append(HumanLabOCRCell(
                            text: trimmed(cell.content.text.transcript),
                            confidence: average(
                                lineConfidences.isEmpty
                                    ? [observation.confidence]
                                    : lineConfidences
                            ),
                            rowRange: cell.rowRange,
                            columnRange: cell.columnRange,
                            bounds: HumanLabOCRBounds(
                                cell.content.boundingRegion.boundingBox.cgRect
                            )
                        ))
                        cellCount += 1
                    }
                    if !cells.isEmpty {
                        rows.append(cells)
                    }
                    if cellCount >= maximumCellCount { break }
                }
                if !rows.isEmpty {
                    tables.append(HumanLabOCRTable(
                        rows: rows,
                        bounds: HumanLabOCRBounds(table.boundingRegion.boundingBox.cgRect)
                    ))
                }
                if cellCount >= maximumCellCount { break tableLoop }
            }
        }

        return HumanLabOCRPage(
            pageIndex: index,
            transcript: transcript,
            confidence: pageConfidence,
            tables: tables,
            textLines: documentTextLines,
            wasTruncated: wasTruncated
        )
    }

    /// Document recognition is best at table structure, while the dedicated
    /// text request is more reliable for isolated digits and decimal marks.
    /// Only numeric-dominant fallback observations are merged, so custom-word
    /// metric labels from the document request remain authoritative.
    private static func recognizeNumericFallbackLines(
        in imageData: Data,
        orientation: CGImagePropertyOrientation?
    ) async throws -> BoundedTextLines {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = false
        request.minimumTextHeightFraction = 0
        let observations = try await request.perform(
            on: imageData,
            orientation: orientation
        )
        try Task.checkCancellation()
        var lines: [HumanLabOCRTextLine] = []
        lines.reserveCapacity(min(maximumTextLineCount, observations.count))
        var wasTruncated = false
        for (index, observation) in observations.enumerated() {
            if index.isMultiple(of: 64) {
                try Task.checkCancellation()
            }
            let text = trimmed(observation.transcript)
            guard isNumericDominant(text) else { continue }
            guard lines.count < maximumTextLineCount else {
                wasTruncated = true
                break
            }
            lines.append(HumanLabOCRTextLine(
                text: text,
                confidence: observation.confidence,
                bounds: HumanLabOCRBounds(observation.boundingBox.cgRect)
            ))
        }
        return BoundedTextLines(lines: lines, wasTruncated: wasTruncated)
    }

    /// Whole-page OCR can omit short labels in dense tables even when the
    /// printed text is clear. A focused pass over the table's parameter column
    /// increases effective text scale. Only complete catalog words are kept;
    /// values and reference ranges never participate in metric inference.
    private static func recognizeParameterFallbackLines(
        in imageData: Data,
        orientation: CGImagePropertyOrientation?,
        region: HumanLabOCRBounds,
        customWords: [String]
    ) async throws -> BoundedTextLines {
        let normalizedWords = Set(customWords.compactMap { word -> String? in
            let normalized = normalizedCatalogText(word)
            return normalized.count >= 3 ? normalized : nil
        })
        guard !normalizedWords.isEmpty else {
            return BoundedTextLines(lines: [], wasTruncated: false)
        }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        request.minimumTextHeightFraction = 0
        request.customWords = customWords
        request.recognitionLanguages = preferredLanguages.filter(
            request.supportedRecognitionLanguages.contains
        )
        request.regionOfInterest = NormalizedRect(
            x: region.minX,
            y: region.minY,
            width: region.width,
            height: region.height
        )

        let observations = try await request.perform(
            on: imageData,
            orientation: orientation
        )
        try Task.checkCancellation()
        var lines: [HumanLabOCRTextLine] = []
        lines.reserveCapacity(min(maximumTextLineCount, observations.count))
        var wasTruncated = false
        for (index, observation) in observations.enumerated() {
            if index.isMultiple(of: 64) {
                try Task.checkCancellation()
            }
            let text = trimmed(observation.transcript)
            guard containsCatalogWord(text, normalizedWords: normalizedWords) else { continue }
            guard lines.count < maximumTextLineCount else {
                wasTruncated = true
                break
            }
            let relativeBounds = HumanLabOCRBounds(observation.boundingBox.cgRect)
            lines.append(HumanLabOCRTextLine(
                text: text,
                confidence: observation.confidence,
                bounds: expandedBounds(relativeBounds, from: region)
            ))
        }
        return BoundedTextLines(lines: lines, wasTruncated: wasTruncated)
    }

    private static func parameterColumnRegion(in page: HumanLabOCRPage) -> HumanLabOCRBounds? {
        for table in page.tables {
            guard let tableBounds = table.bounds else { continue }
            let tableLines = page.textLines.filter { line in
                line.bounds.midX >= tableBounds.minX - 0.01
                    && line.bounds.midX <= tableBounds.maxX + 0.01
                    && line.bounds.midY >= tableBounds.minY - 0.01
                    && line.bounds.midY <= tableBounds.maxY + 0.01
            }
            guard let parameterHeader = tableLines.first(where: {
                let text = normalizedCatalogText($0.text)
                return text == "parameter" || text == "test" || text == "item"
                    || text == "项目" || text == "项目名称"
            }),
            let referenceHeader = tableLines.first(where: {
                let text = normalizedCatalogText($0.text)
                return text.contains("normwert") || text.contains("normert")
                    || text.contains("reference value")
                    || text.contains("reference range")
                    || text.contains("参考范围")
            }) else { continue }

            let minX = max(0, tableBounds.minX - 0.02)
            let maxX = min(
                1,
                max(parameterHeader.bounds.maxX, referenceHeader.bounds.midX + 0.04)
            )
            let minY = max(0, tableBounds.minY - 0.01)
            let maxY = min(1, tableBounds.maxY + 0.01)
            guard maxX - minX >= 0.15, maxY - minY >= 0.08 else { continue }
            return HumanLabOCRBounds(
                minX: minX,
                minY: minY,
                width: maxX - minX,
                height: maxY - minY
            )
        }
        return nil
    }

    private static func containsCatalogWord(
        _ text: String,
        normalizedWords: Set<String>
    ) -> Bool {
        let normalized = normalizedCatalogText(text)
        guard !normalized.isEmpty else { return false }
        let paddedText = " \(normalized) "
        return normalizedWords.contains { word in
            normalized == word || paddedText.contains(" \(word) ")
        }
    }

    private static func normalizedCatalogText(_ text: String) -> String {
        let folded = text
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
        var result = ""
        var lastWasSeparator = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append(" ")
                lastWasSeparator = true
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func expandedBounds(
        _ relative: HumanLabOCRBounds,
        from region: HumanLabOCRBounds
    ) -> HumanLabOCRBounds {
        HumanLabOCRBounds(
            minX: region.minX + relative.minX * region.width,
            minY: region.minY + relative.minY * region.height,
            width: relative.width * region.width,
            height: relative.height * region.height
        )
    }

    private static func mergeDocumentLines(
        _ documentLines: [HumanLabOCRTextLine],
        with numericFallbackLines: [HumanLabOCRTextLine]
    ) throws -> BoundedTextLines {
        var merged = documentLines
        var buckets: [Int: [Int]] = [:]
        for index in merged.indices {
            buckets[lineBucket(for: merged[index].bounds), default: []].append(index)
        }
        var wasTruncated = false
        for (offset, fallbackLine) in numericFallbackLines.enumerated() {
            if offset.isMultiple(of: 64) {
                try Task.checkCancellation()
            }
            let bucket = lineBucket(for: fallbackLine.bounds)
            let nearbyIndices = (-4 ... 4).flatMap { delta in
                buckets[bucket + delta] ?? []
            }
            let overlappingIndices = nearbyIndices.filter { index in
                geometricallyOverlaps(merged[index].bounds, fallbackLine.bounds)
                    && isNumericDominant(merged[index].text)
            }
            if let closestIndex = overlappingIndices.min(by: { left, right in
                lineDistance(merged[left].bounds, fallbackLine.bounds)
                    < lineDistance(merged[right].bounds, fallbackLine.bounds)
            }) {
                merged[closestIndex] = reconciledNumericLine(
                    documentLine: merged[closestIndex],
                    fallbackLine: fallbackLine
                )
            } else {
                guard merged.count < maximumTextLineCount else {
                    wasTruncated = true
                    continue
                }
                merged.append(reviewRequiredLine(fallbackLine))
                buckets[lineBucket(for: fallbackLine.bounds), default: []].append(merged.count - 1)
            }
        }
        return BoundedTextLines(lines: merged, wasTruncated: wasTruncated)
    }

    private static func mergeParameterLines(
        _ documentLines: [HumanLabOCRTextLine],
        with parameterFallbackLines: [HumanLabOCRTextLine]
    ) throws -> BoundedTextLines {
        var merged = documentLines
        var buckets: [Int: [Int]] = [:]
        for index in merged.indices {
            buckets[lineBucket(for: merged[index].bounds), default: []].append(index)
        }
        var wasTruncated = false
        for (offset, fallbackLine) in parameterFallbackLines.enumerated() {
            if offset.isMultiple(of: 64) {
                try Task.checkCancellation()
            }
            let bucket = lineBucket(for: fallbackLine.bounds)
            let alreadyCovered = (-4 ... 4)
                .flatMap { buckets[bucket + $0] ?? [] }
                .contains { index in
                    geometricallyOverlaps(merged[index].bounds, fallbackLine.bounds)
                        && !isNumericDominant(merged[index].text)
                }
            guard !alreadyCovered else { continue }
            guard merged.count < maximumTextLineCount else {
                wasTruncated = true
                continue
            }
            merged.append(reviewRequiredLine(fallbackLine))
            buckets[lineBucket(for: fallbackLine.bounds), default: []].append(merged.count - 1)
        }
        return BoundedTextLines(lines: merged, wasTruncated: wasTruncated)
    }

    private static func lineBucket(for bounds: HumanLabOCRBounds) -> Int {
        Int((bounds.midY * 100).rounded(.down))
    }

    private static func reconciledNumericLine(
        documentLine: HumanLabOCRTextLine,
        fallbackLine: HumanLabOCRTextLine
    ) -> HumanLabOCRTextLine {
        let documentFingerprint = numericFingerprint(documentLine.text)
        let fallbackFingerprint = numericFingerprint(fallbackLine.text)
        guard let documentFingerprint, let fallbackFingerprint else {
            return reviewRequiredLine(documentLine)
        }
        if normalizedNumericText(documentLine.text) == normalizedNumericText(fallbackLine.text) {
            return fallbackLine.confidence >= documentLine.confidence ? fallbackLine : documentLine
        }

        let chosen: HumanLabOCRTextLine = if documentFingerprint.digits == fallbackFingerprint.digits {
            numericInformationScore(fallbackLine.text) >= numericInformationScore(documentLine.text)
                ? fallbackLine
                : documentLine
        } else if documentFingerprint.digits.dropFirst() == fallbackFingerprint.digits {
            fallbackLine
        } else if fallbackFingerprint.digits.dropFirst() == documentFingerprint.digits {
            documentLine
        } else {
            documentLine
        }
        return reviewRequiredLine(chosen)
    }

    private static func reviewRequiredLine(_ line: HumanLabOCRTextLine) -> HumanLabOCRTextLine {
        HumanLabOCRTextLine(
            text: line.text,
            confidence: min(line.confidence, 0.5),
            bounds: line.bounds
        )
    }

    private static func numericFingerprint(_ text: String) -> NumericFingerprint? {
        let normalized = normalizedNumericText(text)
        guard let range = normalized.range(
            of: #"\d+(?:[.,]\d+)?"#,
            options: .regularExpression
        ) else { return nil }
        let token = String(normalized[range])
        let digits = token.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return NumericFingerprint(digits: digits)
    }

    private static func normalizedNumericText(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "．", with: ".")
            .filter { !$0.isWhitespace }
    }

    private static func numericInformationScore(_ text: String) -> Int {
        let normalized = normalizedNumericText(text)
        var score = 0
        if normalized.contains(",") || normalized.contains(".") { score += 2 }
        if normalized.contains("<") || normalized.contains(">")
            || normalized.contains("≤") || normalized.contains("≥") {
            score += 2
        }
        if normalized.range(of: #"(?:[\[［(]|[lh])[+-]"#, options: .regularExpression) != nil {
            score += 1
        }
        return score
    }

    private static func isNumericDominant(_ text: String) -> Bool {
        if text.range(
            of: #"^[\s\[\]［］(){}+\-]*[<>≤≥]?\s*\d"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return text.range(
            of: #"^\s*[LH]\s*[+-]\s*[\]］]\s*\d"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func geometricallyOverlaps(
        _ left: HumanLabOCRBounds,
        _ right: HumanLabOCRBounds
    ) -> Bool {
        let verticalTolerance = max(0.004, min(left.height, right.height) * 0.75)
        guard abs(left.midY - right.midY) <= verticalTolerance else { return false }
        let intersectionWidth = min(left.maxX, right.maxX) - max(left.minX, right.minX)
        let minimumWidth = max(0.001, min(left.width, right.width))
        return intersectionWidth / minimumWidth >= 0.35
            && abs(left.midX - right.midX) <= max(0.03, max(left.width, right.width) * 0.6)
    }

    private static func lineDistance(
        _ left: HumanLabOCRBounds,
        _ right: HumanLabOCRBounds
    ) -> Double {
        abs(left.midX - right.midX) + abs(left.midY - right.midY) * 2
    }

    private static func imageOrientation(in data: Data) -> CGImagePropertyOrientation? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let orientation = properties[kCGImagePropertyOrientation] as? NSNumber
        else {
            return nil
        }
        return CGImagePropertyOrientation(rawValue: orientation.uint32Value)
    }

    private static func average(_ values: [Float]) -> Float {
        let finiteValues = values.filter(\.isFinite)
        guard !finiteValues.isEmpty else { return 0 }
        return finiteValues.reduce(0, +) / Float(finiteValues.count)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct BoundedTextLines {
        let lines: [HumanLabOCRTextLine]
        let wasTruncated: Bool
    }

    private struct NumericFingerprint {
        let digits: String
    }
}
