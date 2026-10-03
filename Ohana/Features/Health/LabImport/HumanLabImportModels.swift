//
//  HumanLabImportModels.swift
//  Ohana
//
//  Value-only types shared by on-device document recognition, deterministic
//  parsing, and the review UI. Raw images and full OCR transcripts are kept in
//  memory by the caller and are never persistence models.
//

import CoreGraphics
import Foundation

nonisolated struct HumanLabOCRBounds: Equatable, Sendable {
    let minX: Double
    let minY: Double
    let width: Double
    let height: Double

    init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        self.init(
            minX: Double(rect.minX),
            minY: Double(rect.minY),
            width: Double(rect.width),
            height: Double(rect.height)
        )
    }

    var maxX: Double { minX + width }
    var maxY: Double { minY + height }
    var midX: Double { minX + width / 2 }
    var midY: Double { minY + height / 2 }
}

nonisolated struct HumanLabOCRTextLine: Equatable, Sendable {
    let text: String
    let confidence: Float
    let bounds: HumanLabOCRBounds

    init(text: String, confidence: Float, bounds: HumanLabOCRBounds) {
        self.text = text
        self.confidence = confidence
        self.bounds = bounds
    }
}

nonisolated struct HumanLabOCRCell: Equatable, Sendable {
    let text: String
    let confidence: Float
    let rowRange: ClosedRange<Int>
    let columnRange: ClosedRange<Int>
    let bounds: HumanLabOCRBounds?

    init(
        text: String,
        confidence: Float,
        rowRange: ClosedRange<Int> = 0 ... 0,
        columnRange: ClosedRange<Int> = 0 ... 0,
        bounds: HumanLabOCRBounds? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.rowRange = rowRange
        self.columnRange = columnRange
        self.bounds = bounds
    }
}

nonisolated struct HumanLabOCRTable: Equatable, Sendable {
    let rows: [[HumanLabOCRCell]]
    let bounds: HumanLabOCRBounds?

    init(rows: [[HumanLabOCRCell]], bounds: HumanLabOCRBounds? = nil) {
        self.rows = rows
        self.bounds = bounds
    }
}

nonisolated struct HumanLabOCRPage: Equatable, Sendable {
    let pageIndex: Int
    let transcript: String
    let confidence: Float
    let tables: [HumanLabOCRTable]
    let textLines: [HumanLabOCRTextLine]
    let wasTruncated: Bool

    init(
        pageIndex: Int,
        transcript: String,
        confidence: Float,
        tables: [HumanLabOCRTable] = [],
        textLines: [HumanLabOCRTextLine] = [],
        wasTruncated: Bool = false
    ) {
        self.pageIndex = pageIndex
        self.transcript = transcript
        self.confidence = confidence
        self.tables = tables
        self.textLines = textLines
        self.wasTruncated = wasTruncated
    }
}

/// A bounded parser result. `wasTruncated` means at least one non-empty OCR row
/// was not reviewed because the row or candidate safety ceiling was reached.
nonisolated struct HumanLabResultParseOutcome: Equatable, Sendable {
    let candidates: [HumanLabResultCandidate]
    let wasTruncated: Bool

    init(candidates: [HumanLabResultCandidate], wasTruncated: Bool) {
        self.candidates = candidates
        self.wasTruncated = wasTruncated
    }
}

nonisolated enum HumanLabValueQualifier: String, CaseIterable, Equatable, Sendable {
    case exact
    case lessThan
    case greaterThan
}

nonisolated enum HumanLabResultFlag: String, CaseIterable, Equatable, Sendable {
    case normal
    case low
    case high
    case unknown
}

nonisolated struct HumanLabResultCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let pageIndex: Int
    let sourceText: String
    var sourceLabel: String
    var metricKey: String?
    var value: Double?
    var valueQualifier: HumanLabValueQualifier
    var unitCode: String?
    var sourceUnit: String?
    var referenceLow: Double?
    var referenceHigh: Double?
    var referenceRangeText: String?
    var reportedFlag: HumanLabResultFlag
    var observedAt: Date?
    var confidence: Float
    var isSelected: Bool
    var hasBeenReviewed: Bool
    var requiresReview: Bool

    init(
        id: UUID = UUID(),
        pageIndex: Int = 0,
        sourceText: String = "",
        sourceLabel: String = "",
        metricKey: String? = nil,
        value: Double? = nil,
        valueQualifier: HumanLabValueQualifier = .exact,
        unitCode: String? = nil,
        sourceUnit: String? = nil,
        referenceLow: Double? = nil,
        referenceHigh: Double? = nil,
        referenceRangeText: String? = nil,
        reportedFlag: HumanLabResultFlag = .unknown,
        observedAt: Date? = nil,
        confidence: Float = 0,
        isSelected: Bool = false,
        hasBeenReviewed: Bool = false,
        requiresReview: Bool = true
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.sourceText = sourceText
        self.sourceLabel = sourceLabel
        self.metricKey = metricKey
        self.value = value
        self.valueQualifier = valueQualifier
        self.unitCode = unitCode
        self.sourceUnit = sourceUnit
        self.referenceLow = referenceLow
        self.referenceHigh = referenceHigh
        self.referenceRangeText = referenceRangeText
        self.reportedFlag = reportedFlag
        self.observedAt = observedAt
        self.confidence = confidence
        self.isSelected = isSelected
        self.hasBeenReviewed = hasBeenReviewed
        self.requiresReview = requiresReview
    }
}
