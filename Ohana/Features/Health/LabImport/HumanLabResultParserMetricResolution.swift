//
//  HumanLabResultParserMetricResolution.swift
//  Ohana
//
//  Deterministic metric alias and unit resolution for lab result parsing.
//

import Foundation

nonisolated extension HumanLabResultParser {
    func bestMetricMatch(in cells: [String]) -> MetricMatch? {
        var matches: [MetricMatch] = []

        for metric in metrics {
            var bestForMetric: MetricMatch?
            for (cellIndex, cell) in cells.enumerated() {
                let normalized = normalizedSearchText(cell)
                guard !normalized.isEmpty else { continue }
                for alias in metric.aliases {
                    guard let score = aliasScore(alias.normalized, in: normalized) else { continue }
                    let match = MetricMatch(
                        metric: metric,
                        cellIndex: cellIndex,
                        score: score,
                        requiresReview: alias.requiresReview
                    )
                    if bestForMetric.map({ match.score > $0.score }) ?? true {
                        bestForMetric = match
                    }
                }
            }
            if let bestForMetric {
                matches.append(bestForMetric)
            }
        }

        let ordered = matches.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.metric.key < $1.metric.key
        }
        guard var best = ordered.first else { return nil }
        if ordered.dropFirst().first?.score == best.score {
            best.requiresReview = true
        }
        return best
    }

    private func aliasScore(_ alias: String, in text: String) -> Int? {
        guard !alias.isEmpty else { return nil }
        if text == alias {
            return 1000 + alias.count
        }
        // One- and two-character abbreviations (T, K, UA, AP...) are too
        // collision-prone inside a longer laboratory label. They remain valid
        // only when the whole normalized label is exactly that abbreviation.
        if alias.count <= 2 {
            return nil
        }
        let paddedText = " \(text) "
        let paddedAlias = " \(alias) "
        if paddedText.contains(paddedAlias) {
            return 850 + alias.count
        }

        let compactAlias = alias.replacingOccurrences(of: " ", with: "")
        let compactText = text.replacingOccurrences(of: " ", with: "")
        let containsCJK = alias.unicodeScalars.contains { scalar in
            (0x3400 ... 0x9FFF).contains(Int(scalar.value))
        }
        if containsCJK && compactAlias.count >= 2,
           compactText.contains(compactAlias) {
            return 650 + compactAlias.count
        }
        return nil
    }

    func matchUnit(in text: String, units: [UnitDescriptor]) -> UnitDescriptor? {
        let normalizedText = normalizedUnitText(text)
        return units
            .sorted { $0.normalizedLabel.count > $1.normalizedLabel.count }
            .first { descriptor in
                guard !descriptor.normalizedLabel.isEmpty else { return false }
                let isShortWord = descriptor.normalizedLabel.count <= 2
                    && descriptor.normalizedLabel.unicodeScalars.allSatisfy {
                        CharacterSet.alphanumerics.contains($0)
                    }
                if isShortWord {
                    let searchableText = " \(normalizedSearchText(text)) "
                    return searchableText.contains(" \(descriptor.normalizedLabel) ")
                }
                return containsUnitLabel(descriptor.normalizedLabel, in: normalizedText)
            }
    }

    private func containsUnitLabel(_ label: String, in text: String) -> Bool {
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(of: label, range: searchStart ..< text.endIndex) {
            let labelStartsWithDelimiter = label.first == "/" || label.first == "%"
            let precedingIsLetter = !labelStartsWithDelimiter
                && range.lowerBound > text.startIndex
                && text[text.index(before: range.lowerBound)].isLetter
            let followingIsAlphaNumeric = range.upperBound < text.endIndex
                && (text[range.upperBound].isLetter || text[range.upperBound].isNumber)
            if !precedingIsLetter, !followingIsAlphaNumeric {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }

    func resolveUnit(in text: String, metric: MetricDescriptor) -> ResolvedUnit? {
        if let direct = matchUnit(in: text, units: metric.units) {
            return ResolvedUnit(
                descriptor: direct,
                sourceLabel: direct.label,
                multiplier: 1,
                requiresReview: false
            )
        }

        let normalizedText = normalizedUnitText(text)
        for mapping in Self.sourceUnitMappings[metric.key] ?? [] {
            guard let label = mapping.labels.sorted(by: { $0.count > $1.count }).first(where: {
                containsUnitLabel(Self.normalizeUnit($0), in: normalizedText)
            }),
            let target = metric.units.first(where: { $0.code == mapping.targetCode }) else {
                continue
            }
            return ResolvedUnit(
                descriptor: target,
                sourceLabel: label,
                multiplier: mapping.multiplier,
                requiresReview: false
            )
        }

        return nil
    }
}
