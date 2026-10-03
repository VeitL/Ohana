//
//  HumanLabResultParserValueExtraction.swift
//  Ohana
//
//  Numeric-result and reference-range extraction for deterministic lab parsing.
//

import Foundation

nonisolated extension HumanLabResultParser {
    func extractFields(
        from text: String,
        preferredValueText: String?,
        preferredReferenceText: String?,
        metricMatch: MetricMatch?,
        patterns: PatternBundle
    ) -> ExtractedFields {
        let fullRange = NSRange(text.startIndex ..< text.endIndex, in: text)
        let doubleRanges = patterns.doubleRange.matches(in: text, range: fullRange)
        let comparatorRanges = patterns.comparatorRange.matches(in: text, range: fullRange)
        let numberMatches = patterns.number.matches(in: text, range: fullRange)

        let labelCellBoundary = metricMatch.flatMap { match -> Int? in
            guard match.cellIndex >= 0 else { return nil }
            let components = text.components(separatedBy: "\t")
            guard match.cellIndex < components.count, components.count > 1 else { return nil }
            var utf16Offset = 0
            for index in 0 ... match.cellIndex {
                utf16Offset += (components[index] as NSString).length
                if index < match.cellIndex { utf16Offset += 1 }
            }
            return utf16Offset
        }

        let standaloneNumberExists = numberMatches.contains { result in
            if let labelCellBoundary, result.range.location < labelCellBoundary { return false }
            guard !doubleRanges.contains(where: {
                NSLocationInRange(result.range.location, $0.range)
            }),
            !comparatorRanges.contains(where: {
                NSLocationInRange(result.range.location, $0.range)
            }) else { return false }
            return !isUnitFragment(result.range, in: text)
        }
        let soleComparatorHasResultUnit = comparatorRanges.count == 1
            && preferredValueText == nil
            && explicitUnitFollows(
                comparatorRanges[0].range,
                in: text,
                metric: metricMatch?.metric
            )
        let comparatorReferenceMatches: [NSTextCheckingResult] = if comparatorRanges.count > 1 {
            Array(comparatorRanges.dropFirst())
        } else if standaloneNumberExists {
            comparatorRanges
        } else if preferredValueText == nil, !soleComparatorHasResultUnit {
            comparatorRanges
        } else {
            []
        }
        let referenceSpans = doubleRanges.map(\.range)
            + comparatorReferenceMatches.map(\.range)

        let preferredValue = preferredValueText.flatMap {
            firstParsedNumber(in: $0, patterns: patterns)
        }
        let valueMatch = preferredValue == nil ? numberMatches.first { result in
            if let labelCellBoundary, result.range.location < labelCellBoundary { return false }
            guard !referenceSpans.contains(where: {
                NSLocationInRange(result.range.location, $0)
            }) else { return false }
            return !isUnitFragment(result.range, in: text)
        } : nil

        let rawValue: String
        let parsedValue: ParsedNumber
        let valueRange: NSRange?
        if let preferredValue {
            rawValue = preferredValue.raw
            parsedValue = preferredValue.number
            valueRange = nil
        } else if let valueMatch {
            rawValue = (text as NSString).substring(with: valueMatch.range)
            guard let number = parseNumber(rawValue) else { return ExtractedFields() }
            parsedValue = number
            valueRange = valueMatch.range
        } else {
            return ExtractedFields()
        }
        let qualifier = qualifier(in: rawValue)

        var referenceLow: Double?
        var referenceHigh: Double?
        var referenceText: String?
        let fallbackReferenceSource: String? = if let range = doubleRanges.first?.range {
            (text as NSString).substring(with: range)
        } else if let range = comparatorReferenceMatches.first?.range {
            (text as NSString).substring(with: range)
        } else {
            nil
        }
        if let referenceSource = preferredReferenceText ?? fallbackReferenceSource {
            extractReference(
                from: referenceSource,
                patterns: patterns,
                low: &referenceLow,
                high: &referenceHigh,
                text: &referenceText
            )
        }

        return ExtractedFields(
            value: parsedValue.value,
            qualifier: qualifier,
            valueRange: valueRange,
            valueRequiresReview: parsedValue.requiresReview,
            referenceLow: referenceLow,
            referenceHigh: referenceHigh,
            referenceText: referenceText,
            textAfterValue: text
        )
    }

    /// A lone comparator is more often a reference bound than a result when
    /// Vision has dropped the result cell. Preserve it as a qualified result
    /// only when a printed unit follows the comparator (for example
    /// "<5 IU/mL"); the qualifier still forces explicit user review.
    private func explicitUnitFollows(
        _ comparatorRange: NSRange,
        in text: String,
        metric: MetricDescriptor?
    ) -> Bool {
        let nsText = text as NSString
        let suffixStart = NSMaxRange(comparatorRange)
        guard suffixStart < nsText.length else { return false }
        let suffix = nsText.substring(from: suffixStart)
        if let metric {
            return resolveUnit(in: suffix, metric: metric) != nil
        }
        return matchUnit(in: suffix, units: allUnits) != nil
    }

    func firstParsedNumber(
        in text: String,
        patterns: PatternBundle
    ) -> (raw: String, number: ParsedNumber)? {
        let normalized = removingLeadingResultFlag(from: normalizedOCRNumberText(text))
        let fullRange = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
        for match in patterns.number.matches(in: normalized, range: fullRange)
        where !isUnitFragment(match.range, in: normalized) {
            let raw = (normalized as NSString).substring(with: match.range)
            if let number = parseNumber(raw) {
                return (raw, number)
            }
        }
        return nil
    }

    private func removingLeadingResultFlag(from text: String) -> String {
        text.replacingOccurrences(
            of: #"^\s*(?:[\[［(]\s*[+-]\s*[\]］)]?|[+-]\s*[\]］)])\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    private func extractReference(
        from text: String,
        patterns: PatternBundle,
        low: inout Double?,
        high: inout Double?,
        text referenceText: inout String?
    ) {
        let normalized = normalizedOCRNumberText(text)
        let fullRange = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
        if let match = patterns.doubleRange.firstMatch(in: normalized, range: fullRange) {
            let lowText = (normalized as NSString).substring(with: match.range(at: 1))
            let highText = (normalized as NSString).substring(with: match.range(at: 2))
            low = parseNumber(lowText)?.value
            high = parseNumber(highText)?.value
            referenceText = (normalized as NSString).substring(with: match.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }
        guard let comparison = patterns.comparatorRange.firstMatch(in: normalized, range: fullRange) else {
            return
        }
        let symbol = (normalized as NSString).substring(with: comparison.range(at: 1))
        let boundText = (normalized as NSString).substring(with: comparison.range(at: 2))
        guard let bound = parseNumber(boundText)?.value else { return }
        if symbol == "<" || symbol == "≤" {
            high = bound
        } else {
            low = bound
        }
        referenceText = (normalized as NSString).substring(with: comparison.range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isUnitFragment(_ range: NSRange, in text: String) -> Bool {
        let nsText = text as NSString
        let beforeIndex = range.location - 1
        if beforeIndex >= 0 {
            let before = nsText.substring(with: NSRange(location: beforeIndex, length: 1))
            if "/^×*".contains(before) { return true }
        }
        let afterIndex = NSMaxRange(range)
        if afterIndex < nsText.length {
            let after = nsText.substring(with: NSRange(location: afterIndex, length: 1))
            if "/^".contains(after) { return true }
        }
        return false
    }
}
