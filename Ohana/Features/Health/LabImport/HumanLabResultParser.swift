//
//  HumanLabResultParser.swift
//  Ohana
//
//  Deterministic, local parsing of Vision document DTOs. The parser deliberately
//  keeps uncertain rows for review and never turns OCR text into a diagnosis.
//

import Foundation

nonisolated struct HumanLabResultParser: Sendable {
    static let defaultMaximumCandidateCount = 128
    static let directConfirmationConfidence: Float = 0.75

    private let maximumCandidateCount: Int
    let metrics: [MetricDescriptor]
    let allUnits: [UnitDescriptor]

    @MainActor
    init(maximumCandidateCount: Int = HumanLabResultParser.defaultMaximumCandidateCount) {
        self.maximumCandidateCount = min(max(1, maximumCandidateCount), 256)
        metrics = HealthMetricCatalog.all.map(MetricDescriptor.init)
        allUnits = Self.makeUnitVocabulary(from: HealthMetricCatalog.all)
    }

    func parse(pages: [HumanLabOCRPage]) -> HumanLabResultParseOutcome {
        guard let patterns = try? PatternBundle() else {
            return HumanLabResultParseOutcome(candidates: [], wasTruncated: false)
        }
        let rowLimit = max(256, maximumCandidateCount * 8)
        let rowBatch = makeRows(from: pages, limit: rowLimit, patterns: patterns)
        var candidates: [HumanLabResultCandidate] = []
        candidates.reserveCapacity(min(rowBatch.rows.count, maximumCandidateCount))
        var deduplicationKeys = Set<String>()
        var wasTruncated = rowBatch.wasTruncated

        for row in rowBatch.rows {
            guard candidates.count < maximumCandidateCount else {
                wasTruncated = true
                break
            }
            guard let candidate = parse(row: row, patterns: patterns) else { continue }
            let key = deduplicationKey(for: candidate)
            guard deduplicationKeys.insert(key).inserted else { continue }
            candidates.append(candidate)
        }

        return HumanLabResultParseOutcome(
            candidates: candidates,
            wasTruncated: wasTruncated
        )
    }

    private func parse(
        row: SourceRow,
        patterns: PatternBundle
    ) -> HumanLabResultCandidate? {
        let sourceText = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return nil }

        let metricMatch = bestMetricMatch(in: row.cells)
        let fields = extractFields(
            from: sourceText,
            preferredValueText: row.preferredValueText,
            preferredReferenceText: row.preferredReferenceText,
            metricMatch: metricMatch,
            patterns: patterns
        )
        guard let parsedValue = fields.value else { return nil }

        let metric = metricMatch?.metric
        let metricUnit = metric.flatMap { resolveUnit(in: sourceText, metric: $0) }
        let anyUnit = metricUnit?.descriptor ?? matchUnit(in: sourceText, units: allUnits)
        let unitCode = metricUnit?.descriptor.code
        let sourceUnit = metricUnit?.sourceLabel ?? anyUnit?.label
        let multiplier = metricUnit?.multiplier ?? 1
        let value = parsedValue * multiplier
        let referenceLow = fields.referenceLow.map { $0 * multiplier }
        let referenceHigh = fields.referenceHigh.map { $0 * multiplier }

        if metric == nil {
            guard !isHeader(sourceText) else { return nil }
            let hasReference = referenceLow != nil || referenceHigh != nil
            let isStructuredResult = row.isTable && row.cells.count >= 2
            guard sourceUnit != nil, hasReference || isStructuredResult else { return nil }
        }

        let sourceLabel = makeSourceLabel(
            row: row,
            metricMatch: metricMatch,
            valueRange: fields.valueRange
        )
        guard !sourceLabel.isEmpty else { return nil }

        let confidence = min(max(row.confidence, 0), 1)
        let exactValue = fields.qualifier == .exact
        let mappingNeedsReview = metricMatch?.requiresReview ?? true
        let canSkipEditorReview = metric != nil
            && unitCode != nil
            && exactValue
            && !fields.valueRequiresReview
            && !(metricUnit?.requiresReview ?? true)
            && confidence >= Self.directConfirmationConfidence
            && !mappingNeedsReview

        return HumanLabResultCandidate(
            pageIndex: row.pageIndex,
            sourceText: sourceText,
            sourceLabel: sourceLabel,
            metricKey: metric?.key,
            value: value,
            valueQualifier: fields.qualifier,
            unitCode: unitCode,
            sourceUnit: sourceUnit,
            referenceLow: referenceLow,
            referenceHigh: referenceHigh,
            referenceRangeText: fields.referenceText,
            reportedFlag: flag(in: row.preferredValueText ?? sourceText, patterns: patterns),
            observedAt: row.observedAt,
            confidence: confidence,
            isSelected: false,
            hasBeenReviewed: false,
            requiresReview: !canSkipEditorReview
        )
    }

    private func makeRows(from pages: [HumanLabOCRPage], limit: Int, patterns: PatternBundle) -> SourceRowBatch {
        var rows: [SourceRow] = []
        var wasTruncated = false
        rows.reserveCapacity(min(limit, pages.count * 32))

        for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            wasTruncated = wasTruncated || page.wasTruncated
            var pageHasStructuredRows = false
            for table in page.tables {
                let lineGeometryRows = makeLineGeometryRows(
                    table: table,
                    textLines: page.textLines,
                    pageIndex: page.pageIndex,
                    patterns: patterns
                )
                let cellGeometryRows = makeGeometryRows(
                    table: table,
                    pageIndex: page.pageIndex,
                    patterns: patterns
                )
                let fallbackRows = cellGeometryRows.isEmpty
                    ? makeTableRows(table: table, pageIndex: page.pageIndex)
                    : cellGeometryRows
                let geometryRows: [SourceRow] = if lineGeometryRows.isEmpty {
                    fallbackRows
                } else {
                    lineGeometryRows + safeSupplementalRows(
                        fallbackRows,
                        excluding: lineGeometryRows,
                        patterns: patterns
                    )
                }
                if !geometryRows.isEmpty {
                    pageHasStructuredRows = true
                    for row in geometryRows {
                        guard rows.count < limit else {
                            return SourceRowBatch(rows: rows, wasTruncated: true)
                        }
                        rows.append(row)
                    }
                    continue
                }
            }

            guard !pageHasStructuredRows else { continue }
            for line in page.transcript.components(separatedBy: .newlines) {
                let text = normalizedWhitespace(line)
                guard !text.isEmpty else { continue }
                guard rows.count < limit else {
                    return SourceRowBatch(rows: rows, wasTruncated: true)
                }
                rows.append(SourceRow(
                    pageIndex: page.pageIndex,
                    cells: [text],
                    text: text,
                    confidence: page.confidence,
                    isTable: false,
                    preferredValueText: nil,
                    preferredReferenceText: nil,
                    observedAt: nil
                ))
            }
        }

        return SourceRowBatch(rows: rows, wasTruncated: wasTruncated)
    }

    private func makeTableRows(
        table: HumanLabOCRTable,
        pageIndex: Int
    ) -> [SourceRow] {
        table.rows.compactMap { tableRow in
            let nonemptyCells = tableRow.filter {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            let cells = nonemptyCells.map { normalizedWhitespace($0.text) }
            guard !cells.isEmpty else { return nil }
            return SourceRow(
                pageIndex: pageIndex,
                cells: cells,
                text: cells.joined(separator: "\t"),
                confidence: average(nonemptyCells.map(\.confidence)),
                isTable: true,
                preferredValueText: nil,
                preferredReferenceText: nil,
                observedAt: nil
            )
        }
    }

    /// Page-level text lines are more reliable than Vision's occasionally
    /// shifted table cells, but they can omit a row. Keep the line rows as the
    /// source of truth and recover only table rows that are not already covered
    /// and have an explicit, metric-compatible unit. Recovered rows always
    /// require review through their capped confidence.
    private func safeSupplementalRows(
        _ fallbackRows: [SourceRow],
        excluding lineRows: [SourceRow],
        patterns: PatternBundle
    ) -> [SourceRow] {
        let covered = lineRows.map(sourceRowCoverage)
        var supplementalCoverage = Set<SourceRowCoverage>()
        var rows: [SourceRow] = []

        for row in fallbackRows {
            let coverage = sourceRowCoverage(row)
            let isCovered = covered.contains { existing in
                existing.label == coverage.label
                    && (coverage.observedAt == nil || existing.observedAt == coverage.observedAt)
            }
            guard !isCovered,
                  isSafeSupplementalRow(row, patterns: patterns),
                  supplementalCoverage.insert(coverage).inserted else { continue }

            rows.append(SourceRow(
                pageIndex: row.pageIndex,
                cells: row.cells,
                text: row.text,
                confidence: min(row.confidence, Self.directConfirmationConfidence - 0.01),
                isTable: row.isTable,
                preferredValueText: row.preferredValueText,
                preferredReferenceText: row.preferredReferenceText,
                observedAt: row.observedAt
            ))
        }
        return rows
    }

    private func sourceRowCoverage(_ row: SourceRow) -> SourceRowCoverage {
        let metricMatch = bestMetricMatch(in: row.cells)
        let labelIndex = metricMatch?.cellIndex ?? 0
        let label = row.cells.indices.contains(labelIndex)
            ? normalizedSearchText(row.cells[labelIndex])
            : normalizedSearchText(row.text)
        return SourceRowCoverage(
            label: metricMatch?.metric.key ?? label,
            observedAt: row.observedAt
        )
    }

    private func isSafeSupplementalRow(
        _ row: SourceRow,
        patterns: PatternBundle
    ) -> Bool {
        guard row.isTable, row.cells.count >= 2 else { return false }
        let metricMatch = bestMetricMatch(in: row.cells)
        let fields = extractFields(
            from: row.text,
            preferredValueText: row.preferredValueText,
            preferredReferenceText: row.preferredReferenceText,
            metricMatch: metricMatch,
            patterns: patterns
        )
        guard fields.value != nil else { return false }

        if let metric = metricMatch?.metric {
            return resolveUnit(in: row.text, metric: metric) != nil
        }
        let label = row.cells.first ?? ""
        return isPlausibleUnknownLineLabel(label)
            && matchUnit(in: row.text, units: allUnits) != nil
    }

    private func makeGeometryRows(
        table: HumanLabOCRTable,
        pageIndex: Int,
        patterns: PatternBundle
    ) -> [SourceRow] {
        guard let layout = makeGeometryTableLayout(table: table, patterns: patterns) else {
            return []
        }
        let cells = layout.cells
        let dateHeaders = layout.dateHeaders
        let referenceColumnIndex = layout.referenceColumnIndex
        let referenceCenterX = layout.referenceCenterX
        let columnAnchors = layout.columnAnchors
        let headerY = layout.headerY
        let labelCells = layout.labelCells
        let tolerance = layout.tolerance
        let tableTop = layout.tableTop
        let tableBottom = layout.tableBottom
        var result: [SourceRow] = []

        for (index, labelCell) in labelCells.enumerated() {
            guard let labelBounds = labelCell.bounds else { continue }
            let upperBoundary: Double = if index == 0 {
                min(tableTop, headerY ?? tableTop)
            } else if let aboveBounds = labelCells[index - 1].bounds {
                (aboveBounds.minY + labelBounds.maxY) / 2
            } else {
                tableTop
            }
            let lowerBoundary: Double = if index == labelCells.count - 1 {
                tableBottom
            } else if let belowBounds = labelCells[index + 1].bounds {
                (labelBounds.minY + belowBounds.maxY) / 2
            } else {
                tableBottom
            }

            let rowCells = cells.filter { cell in
                guard let bounds = cell.bounds,
                      cell != labelCell else { return false }
                return bounds.midY <= upperBoundary + tolerance
                    && bounds.midY >= lowerBoundary - tolerance
                    && !isGeometryHeader(cell.text, patterns: patterns)
            }
            let referenceText = referenceColumnIndex.flatMap { columnIndex in
                joinedCellText(rowCells.filter {
                    belongsToColumn(
                        $0,
                        index: columnIndex,
                        centerX: referenceCenterX,
                        anchors: columnAnchors
                    )
                })
            }

            for dateColumn in dateHeaders {
                let valueText = joinedCellText(rowCells.filter {
                    belongsToColumn(
                        $0,
                        index: dateColumn.columnIndex,
                        centerX: dateColumn.centerX,
                        anchors: columnAnchors
                    )
                })
                guard let valueText,
                      firstParsedNumber(in: valueText, patterns: patterns) != nil else { continue }

                let label = normalizedWhitespace(labelCell.text)
                let parts = [label, valueText, referenceText]
                    .compactMap(\.self)
                    .filter { !$0.isEmpty }
                let contributingCells = [labelCell] + rowCells.filter { cell in
                    if let referenceColumnIndex,
                       belongsToColumn(
                           cell,
                           index: referenceColumnIndex,
                           centerX: referenceCenterX,
                           anchors: columnAnchors
                       ) {
                        return true
                    }
                    return belongsToColumn(
                        cell,
                        index: dateColumn.columnIndex,
                        centerX: dateColumn.centerX,
                        anchors: columnAnchors
                    )
                }
                result.append(SourceRow(
                    pageIndex: pageIndex,
                    cells: parts,
                    text: parts.joined(separator: "\t"),
                    confidence: average(contributingCells.map(\.confidence)),
                    isTable: true,
                    preferredValueText: valueText,
                    preferredReferenceText: referenceText,
                    observedAt: dateColumn.date
                ))
            }
        }
        return result
    }

    /// Vision's table cells can merge a wrapped parameter label with the next
    /// laboratory row. The page-level text lines preserve the printed geometry,
    /// so rebuild rows from the column headers and pair result lines with metric
    /// labels in their visual top-to-bottom order. The original table-cell path
    /// remains the fallback for documents without usable line geometry.
    private func makeLineGeometryRows(
        table: HumanLabOCRTable,
        textLines: [HumanLabOCRTextLine],
        pageIndex: Int,
        patterns: PatternBundle
    ) -> [SourceRow] {
        guard let layout = makeLineGeometryLayout(
            table: table,
            textLines: textLines,
            patterns: patterns
        ) else { return [] }
        let tableBounds = layout.tableBounds
        let parameterLines = layout.parameterLines
        let referenceLines = layout.referenceLines
        let bodyLines = layout.bodyLines
        let dateColumns = layout.dateColumns
        let anchors = layout.anchors
        let headerY = layout.headerY
        let labels = layout.labels
        guard !labels.isEmpty else {
            return makeUnknownLineGeometryRows(
                parameterLines: parameterLines,
                referenceLines: referenceLines,
                bodyLines: bodyLines,
                dateColumns: dateColumns,
                anchors: anchors,
                pageIndex: pageIndex,
                patterns: patterns
            )
        }

        var rows: [SourceRow] = []
        for (columnIndex, column) in dateColumns.enumerated() {
            let resultLines = bodyLines.filter { line in
                nearestColumn(to: line.bounds.midX, anchors: anchors) == .result(columnIndex)
                    && firstParsedNumber(in: line.text, patterns: patterns) != nil
            }.sorted { $0.bounds.midY > $1.bounds.midY }

            var previousLabelIndex = -1
            for valueLine in resultLines {
                guard let labelIndex = nextLabelIndex(
                    for: valueLine,
                    labels: labels,
                    after: previousLabelIndex
                ) else { continue }
                previousLabelIndex = labelIndex
                let label = labels[labelIndex]
                let upperBoundary: Double = if labelIndex == 0 {
                    headerY
                } else {
                    (labels[labelIndex - 1].line.bounds.midY + label.line.bounds.midY) / 2
                }
                let lowerBoundary: Double = if labelIndex == labels.count - 1 {
                    tableBounds.minY
                } else {
                    (label.line.bounds.midY + labels[labelIndex + 1].line.bounds.midY) / 2
                }
                let unitFragments = parameterLines.filter { line in
                    line != label.line
                        && isInsideVisualRowBand(
                            line,
                            upperBoundary: upperBoundary,
                            lowerBoundary: lowerBoundary,
                            valueLine: valueLine
                        )
                        && isEligibleUnitFragment(line.text)
                        && lineUnit(
                            in: line.text,
                            metric: label.metric
                        ) != nil
                }.sorted { $0.bounds.midY > $1.bounds.midY }
                let labelText = ([label.text] + unitFragments.map { normalizedWhitespace($0.text) })
                    .joined(separator: " ")
                let rowReferenceLines = referenceLines.filter { line in
                    isInsideVisualRowBand(
                        line,
                        upperBoundary: upperBoundary,
                        lowerBoundary: lowerBoundary,
                        valueLine: valueLine
                    )
                }
                let referenceLine = preferredReferenceLine(
                    from: rowReferenceLines,
                    label: label
                )
                let referenceText = referenceLine.map { normalizedWhitespace($0.text) }
                let valueText = normalizedWhitespace(valueLine.text)
                let structuredText = [labelText, valueText, referenceText]
                    .compactMap(\.self)
                    .joined(separator: " ")
                guard label.metric != nil
                    || referenceText != nil
                    || matchUnit(in: structuredText, units: allUnits) != nil else { continue }
                let parts = [labelText, valueText, referenceText]
                    .compactMap(\.self)
                    .filter { !$0.isEmpty }
                let confidenceLines = [label.line, valueLine] + unitFragments
                    + [referenceLine].compactMap(\.self)
                rows.append(SourceRow(
                    pageIndex: pageIndex,
                    cells: parts,
                    text: parts.joined(separator: "\t"),
                    confidence: average(confidenceLines.map(\.confidence)),
                    isTable: true,
                    preferredValueText: valueText,
                    preferredReferenceText: referenceText,
                    observedAt: column.date
                ))
            }
        }
        return rows
    }

    private func makeUnknownLineGeometryRows(
        parameterLines: [HumanLabOCRTextLine],
        referenceLines: [HumanLabOCRTextLine],
        bodyLines: [HumanLabOCRTextLine],
        dateColumns: [LineDateColumn],
        anchors: [LineColumnAnchor],
        pageIndex: Int,
        patterns: PatternBundle
    ) -> [SourceRow] {
        let labels = parameterLines.filter {
            isPlausibleUnknownLineLabel(normalizedWhitespace($0.text))
        }.sorted { $0.bounds.midY > $1.bounds.midY }
        guard !labels.isEmpty else { return [] }

        var rows: [SourceRow] = []
        for (columnIndex, column) in dateColumns.enumerated() {
            let resultLines = bodyLines.filter { line in
                nearestColumn(to: line.bounds.midX, anchors: anchors) == .result(columnIndex)
                    && firstParsedNumber(in: line.text, patterns: patterns) != nil
            }
            var usedResultIndexes = Set<Int>()
            for label in labels {
                guard let indexedResult = resultLines.enumerated().filter({ index, line in
                    !usedResultIndexes.contains(index)
                        && abs(line.bounds.midY - label.bounds.midY) <= 0.012
                }).min(by: { left, right in
                    abs(left.element.bounds.midY - label.bounds.midY)
                        < abs(right.element.bounds.midY - label.bounds.midY)
                }) else { continue }

                let referenceLine = referenceLines.min { left, right in
                    abs(left.bounds.midY - label.bounds.midY)
                        < abs(right.bounds.midY - label.bounds.midY)
                }
                guard let referenceLine,
                      abs(referenceLine.bounds.midY - label.bounds.midY) <= 0.015 else { continue }
                let labelText = normalizedWhitespace(label.text)
                let valueText = normalizedWhitespace(indexedResult.element.text)
                let referenceText = normalizedWhitespace(referenceLine.text)
                let parts = [labelText, valueText, referenceText]
                guard matchUnit(in: parts.joined(separator: " "), units: allUnits) != nil else {
                    continue
                }
                usedResultIndexes.insert(indexedResult.offset)
                rows.append(SourceRow(
                    pageIndex: pageIndex,
                    cells: parts,
                    text: parts.joined(separator: "\t"),
                    confidence: min(
                        average([
                            label.confidence,
                            indexedResult.element.confidence,
                            referenceLine.confidence
                        ]),
                        Self.directConfirmationConfidence - 0.01
                    ),
                    isTable: true,
                    preferredValueText: valueText,
                    preferredReferenceText: referenceText,
                    observedAt: column.date
                ))
            }
        }
        return rows
    }

    private func isInsideVisualRowBand(
        _ line: HumanLabOCRTextLine,
        upperBoundary: Double,
        lowerBoundary: Double,
        valueLine: HumanLabOCRTextLine
    ) -> Bool {
        let valueY = valueLine.bounds.midY
        let upper = max(upperBoundary + 0.006, valueY + 0.006)
        let lower = min(lowerBoundary - 0.006, valueY - 0.006)
        return line.bounds.midY <= upper
            && line.bounds.midY >= lower
            && abs(line.bounds.midY - valueY) <= 0.03
    }

    private func preferredReferenceLine(
        from lines: [HumanLabOCRTextLine],
        label: LineMetricLabel
    ) -> HumanLabOCRTextLine? {
        guard let closest = lines.min(by: {
            abs($0.bounds.midY - label.line.bounds.midY)
                < abs($1.bounds.midY - label.line.bounds.midY)
        }) else { return nil }
        let closestDistance = abs(closest.bounds.midY - label.line.bounds.midY)
        let overlappingLines = lines.filter {
            abs($0.bounds.midY - label.line.bounds.midY) <= closestDistance + 0.006
        }
        return overlappingLines.min { left, right in
            let leftHasUnit = lineUnit(in: left.text, metric: label.metric) != nil
            let rightHasUnit = lineUnit(in: right.text, metric: label.metric) != nil
            if leftHasUnit != rightHasUnit { return leftHasUnit }
            return abs(left.bounds.midY - label.line.bounds.midY)
                < abs(right.bounds.midY - label.line.bounds.midY)
        }
    }

    private func isEligibleUnitFragment(_ text: String) -> Bool {
        if bestMetricMatch(in: [text]) == nil { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return false }
        return "([［{".contains(first) || trimmed.count <= 8
    }

    private func isPlausibleUnknownLineLabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !isHeader(trimmed),
              !(trimmed.hasPrefix("(") && trimmed.hasSuffix(")")) else { return false }
        let letterCount = trimmed.unicodeScalars.count(where: {
            CharacterSet.letters.contains($0)
        })
        guard letterCount >= 3 else { return false }

        if matchUnit(in: trimmed, units: allUnits) != nil,
           normalizedSearchText(trimmed).split(separator: " ").count <= 2,
           trimmed.count <= 16 {
            return false
        }
        return true
    }

    private func lineUnit(
        in text: String,
        metric: MetricDescriptor?
    ) -> UnitDescriptor? {
        if let metric {
            return resolveUnit(in: text, metric: metric)?.descriptor
        }
        return matchUnit(in: text, units: allUnits)
    }

    func nearestColumn(
        to centerX: Double,
        anchors: [LineColumnAnchor]
    ) -> LineColumnRole? {
        anchors.min {
            abs($0.centerX - centerX) < abs($1.centerX - centerX)
        }?.role
    }

    private func nextLabelIndex(
        for valueLine: HumanLabOCRTextLine,
        labels: [LineMetricLabel],
        after previousIndex: Int
    ) -> Int? {
        let eligible = labels.indices.filter { index in
            guard index > previousIndex else { return false }
            let delta = valueLine.bounds.midY - labels[index].line.bounds.midY
            return delta >= -0.025 && delta <= 0.022
        }
        return eligible.min { left, right in
            labelPairingScore(valueLine: valueLine, label: labels[left])
                < labelPairingScore(valueLine: valueLine, label: labels[right])
        }
    }

    private func labelPairingScore(
        valueLine: HumanLabOCRTextLine,
        label: LineMetricLabel
    ) -> Double {
        let delta = valueLine.bounds.midY - label.line.bounds.midY
        // Printed results usually sit level with or just above their label.
        // A small penalty for labels above the value prevents a result in the
        // next dated section from attaching to the preceding section's label.
        return abs(delta)
            + (delta < -0.002 ? 0.005 : 0)
            + (label.metric == nil ? 0.004 : 0)
    }

    func containsReference(in text: String, patterns: PatternBundle) -> Bool {
        let normalized = normalizedOCRNumberText(text)
        let range = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
        return patterns.doubleRange.firstMatch(in: normalized, range: range) != nil
            || patterns.comparatorRange.firstMatch(in: normalized, range: range) != nil
    }

    func uniqueColumns(_ columns: [GeometryColumnAnchor]) -> [GeometryColumnAnchor] {
        var seen = Set<Int>()
        return columns
            .sorted { $0.centerX < $1.centerX }
            .filter { seen.insert($0.index).inserted }
    }

    private func belongsToColumn(
        _ cell: HumanLabOCRCell,
        index: Int,
        centerX: Double?,
        anchors: [GeometryColumnAnchor]
    ) -> Bool {
        if cell.columnRange.contains(index),
           cell.columnRange.upperBound - cell.columnRange.lowerBound <= 1 {
            return true
        }
        guard let cellCenter = cell.bounds?.midX,
              let centerX else { return false }
        guard let closest = anchors.min(by: {
            abs($0.centerX - cellCenter) < abs($1.centerX - cellCenter)
        }) else {
            return abs(centerX - cellCenter) <= 0.035
        }
        return closest.index == index
    }

    private func makeSourceLabel(
        row: SourceRow,
        metricMatch: MetricMatch?,
        valueRange: NSRange?
    ) -> String {
        if row.cells.count > 1 {
            let index = metricMatch?.cellIndex ?? 0
            if row.cells.indices.contains(index) {
                return trimLabel(row.cells[index])
            }
        }
        guard let valueRange else { return "" }
        let prefix = (row.text as NSString).substring(to: valueRange.location)
        return trimLabel(prefix)
    }

    private func trimLabel(_ label: String) -> String {
        label.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ":：|·•-–—")
        ))
    }

    private func flag(in text: String, patterns: PatternBundle) -> HumanLabResultFlag {
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        if patterns.highFlag.firstMatch(in: text, range: range) != nil { return .high }
        if patterns.lowFlag.firstMatch(in: text, range: range) != nil { return .low }
        if patterns.normalFlag.firstMatch(in: text, range: range) != nil { return .normal }
        return .unknown
    }

    func qualifier(in value: String) -> HumanLabValueQualifier {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<") || trimmed.hasPrefix("≤") { return .lessThan }
        if trimmed.hasPrefix(">") || trimmed.hasPrefix("≥") { return .greaterThan }
        return .exact
    }

    func parseNumber(_ rawValue: String) -> ParsedNumber? {
        var value = normalizedOCRNumberText(rawValue)
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "≤", with: "")
            .replacingOccurrences(of: "≥", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")

        let requiresReview = hasAmbiguousSingleSeparator(value)

        if value.contains(","), value.contains(".") {
            let comma = value.lastIndex(of: ",")
            let dot = value.lastIndex(of: ".")
            if let comma, let dot, comma > dot {
                value = value.replacingOccurrences(of: ".", with: "")
                value = value.replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        } else if value.contains(",") {
            value = value.replacingOccurrences(of: ",", with: ".")
        }

        guard let parsed = Double(value), parsed.isFinite else { return nil }
        return ParsedNumber(value: parsed, requiresReview: requiresReview)
    }

    func normalizedOCRNumberText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "，.", with: ".")
            .replacingOccurrences(of: ",.", with: ".")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "−", with: "-")
    }

    /// A lone separator followed by exactly three digits can be either a
    /// decimal or a thousands separator depending on the laboratory locale.
    /// Keep the parsed draft value, but never auto-select it.
    private func hasAmbiguousSingleSeparator(_ value: String) -> Bool {
        let separators = value.indices.filter { value[$0] == "," || value[$0] == "." }
        guard separators.count == 1, let separator = separators.first else { return false }
        let integerPart = value[..<separator].filter(\.isNumber)
        let fractionPart = value[value.index(after: separator)...].filter(\.isNumber)
        return !integerPart.isEmpty && fractionPart.count == 3
    }

    private func isHeader(_ text: String) -> Bool {
        let normalized = normalizedSearchText(text)
        let headerPhrases = [
            "reference range", "referenzbereich", "normal range", "参考范围",
            "result unit", "ergebnis einheit", "结果 单位", "项目 结果"
        ]
        return headerPhrases.contains { normalized.contains(normalizedSearchText($0)) }
    }

    private func deduplicationKey(for candidate: HumanLabResultCandidate) -> String {
        let metric = candidate.metricKey ?? normalizedSearchText(candidate.sourceLabel)
        let value = candidate.value.map { String(format: "%.12g", $0) } ?? "nil"
        let low = candidate.referenceLow.map { String(format: "%.12g", $0) } ?? "nil"
        let high = candidate.referenceHigh.map { String(format: "%.12g", $0) } ?? "nil"
        let observedAt = candidate.observedAt.map {
            String(format: "%.0f", $0.timeIntervalSinceReferenceDate)
        } ?? "nil"
        return [
            metric,
            value,
            candidate.valueQualifier.rawValue,
            candidate.unitCode ?? normalizedUnitText(candidate.sourceUnit ?? ""),
            low,
            high,
            observedAt,
            candidate.reportedFlag.rawValue
        ].joined(separator: "|")
    }
}
