//
//  HumanLabResultParserGeometrySupport.swift
//  Ohana
//
//  Small geometry-table helpers kept separate from the parser orchestration.
//

import Foundation

nonisolated extension HumanLabResultParser {
    struct GeometryTableLayout: Sendable {
        let cells: [HumanLabOCRCell]
        let dateHeaders: [GeometryDateColumn]
        let referenceColumnIndex: Int?
        let referenceCenterX: Double?
        let columnAnchors: [GeometryColumnAnchor]
        let headerY: Double?
        let labelCells: [HumanLabOCRCell]
        let tolerance: Double
        let tableTop: Double
        let tableBottom: Double
    }

    struct LineGeometryLayout: Sendable {
        let tableBounds: HumanLabOCRBounds
        let parameterLines: [HumanLabOCRTextLine]
        let referenceLines: [HumanLabOCRTextLine]
        let bodyLines: [HumanLabOCRTextLine]
        let dateColumns: [LineDateColumn]
        let anchors: [LineColumnAnchor]
        let headerY: Double
        let labels: [LineMetricLabel]
    }

    func makeGeometryTableLayout(
        table: HumanLabOCRTable,
        patterns: PatternBundle
    ) -> GeometryTableLayout? {
        let cells = table.rows.flatMap(\.self).filter { cell in
            cell.bounds != nil && !normalizedWhitespace(cell.text).isEmpty
        }
        guard !cells.isEmpty else { return nil }

        let parameterHeader = cells.first { cell in
            let text = normalizedSearchText(cell.text)
            return text == "parameter" || text == "test" || text == "item"
                || text == "项目" || text == "项目名称"
        }
        let referenceHeader = cells.first { cell in
            let text = normalizedSearchText(cell.text)
            return text.contains("normwert")
                || text.contains("referenzbereich")
                || text.contains("reference range")
                || text.contains("normal range")
                || text.contains("参考范围")
        }
        let dateHeaders = cells.compactMap { cell -> GeometryDateColumn? in
            guard let bounds = cell.bounds,
                  let date = parseDateHeader(cell.text, patterns: patterns) else { return nil }
            return GeometryDateColumn(
                columnIndex: cell.columnRange.lowerBound,
                centerX: bounds.midX,
                date: date
            )
        }
        guard !dateHeaders.isEmpty else { return nil }

        let labelColumnIndex = parameterHeader?.columnRange.lowerBound
            ?? cells.map(\.columnRange.lowerBound).min()
        guard let labelColumnIndex else { return nil }
        let referenceColumnIndex = referenceHeader?.columnRange.lowerBound
        let referenceCenterX = referenceHeader?.bounds?.midX
        var columnAnchors = dateHeaders.map {
            GeometryColumnAnchor(index: $0.columnIndex, centerX: $0.centerX)
        }
        if let referenceColumnIndex, let referenceCenterX {
            columnAnchors.append(GeometryColumnAnchor(
                index: referenceColumnIndex,
                centerX: referenceCenterX
            ))
        }
        if let parameterHeader, let centerX = parameterHeader.bounds?.midX {
            columnAnchors.append(GeometryColumnAnchor(
                index: parameterHeader.columnRange.lowerBound,
                centerX: centerX
            ))
        }
        columnAnchors = uniqueColumns(columnAnchors)

        let headerY = ([parameterHeader, referenceHeader].compactMap { $0?.bounds?.midY }
            + dateHeaders.compactMap { column in
                cells.first(where: {
                    $0.columnRange.lowerBound == column.columnIndex
                        && parseDateHeader($0.text, patterns: patterns) == column.date
                })?.bounds?.midY
            }).min()
        let labelCells = cells.filter { cell in
            guard let bounds = cell.bounds,
                  cell.columnRange.contains(labelColumnIndex),
                  !isGeometryHeader(cell.text, patterns: patterns),
                  normalizedSearchText(cell.text).unicodeScalars.contains(where: {
                      CharacterSet.letters.contains($0)
                  }) else { return false }
            return headerY.map { bounds.midY < $0 } ?? true
        }.sorted {
            guard let left = $0.bounds, let right = $1.bounds else { return false }
            return left.midY > right.midY
        }
        guard !labelCells.isEmpty else { return nil }
        let medianHeight = median(cells.compactMap(\.bounds?.height).filter { $0 > 0 })
        return GeometryTableLayout(
            cells: cells,
            dateHeaders: dateHeaders,
            referenceColumnIndex: referenceColumnIndex,
            referenceCenterX: referenceCenterX,
            columnAnchors: columnAnchors,
            headerY: headerY,
            labelCells: labelCells,
            tolerance: max(0.004, medianHeight * 0.35),
            tableTop: table.bounds?.maxY ?? 1,
            tableBottom: table.bounds?.minY ?? 0
        )
    }

    func makeLineGeometryLayout(
        table: HumanLabOCRTable,
        textLines: [HumanLabOCRTextLine],
        patterns: PatternBundle
    ) -> LineGeometryLayout? {
        guard let tableBounds = table.bounds else { return nil }
        let tolerance = 0.008
        let lines = textLines.filter { line in
            let bounds = line.bounds
            return bounds.midX >= tableBounds.minX - tolerance
                && bounds.midX <= tableBounds.maxX + tolerance
                && bounds.midY >= tableBounds.minY - tolerance
                && bounds.midY <= tableBounds.maxY + tolerance
                && !normalizedWhitespace(line.text).isEmpty
        }
        guard !lines.isEmpty else { return nil }
        let parameterHeader = lines.first { line in
            let text = normalizedSearchText(line.text)
            return text == "parameter" || text == "test" || text == "item"
                || text == "项目" || text == "项目名称"
        }
        let referenceHeader = lines.first { isReferenceHeader($0.text) }
        let dateColumns = lines.compactMap { line -> LineDateColumn? in
            guard let date = parseDateHeader(line.text, patterns: patterns) else { return nil }
            return LineDateColumn(
                centerX: line.bounds.midX,
                headerY: line.bounds.midY,
                date: date
            )
        }.sorted { $0.centerX < $1.centerX }
        guard let parameterHeader, let referenceHeader, !dateColumns.isEmpty else { return nil }
        let anchors = ([
            LineColumnAnchor(role: .parameter, centerX: parameterHeader.bounds.midX),
            LineColumnAnchor(role: .reference, centerX: referenceHeader.bounds.midX)
        ] + dateColumns.enumerated().map { index, column in
            LineColumnAnchor(role: .result(index), centerX: column.centerX)
        }).sorted { $0.centerX < $1.centerX }
        guard anchors.indices.dropFirst().allSatisfy({ index in
            anchors[index].centerX - anchors[index - 1].centerX >= 0.04
        }) else { return nil }
        let headerY = ([parameterHeader.bounds.midY, referenceHeader.bounds.midY]
            + dateColumns.map(\.headerY)).min() ?? tableBounds.maxY
        let bodyLines = lines.filter { line in
            line.bounds.midY < headerY - 0.001
                && !isGeometryHeader(line.text, patterns: patterns)
        }
        let parameterLines = bodyLines.filter {
            nearestColumn(to: $0.bounds.midX, anchors: anchors) == .parameter
        }
        let referenceLines = bodyLines.filter {
            nearestColumn(to: $0.bounds.midX, anchors: anchors) == .reference
                && containsReference(in: $0.text, patterns: patterns)
        }
        let labels = parameterLines.compactMap { line -> LineMetricLabel? in
            let text = normalizedWhitespace(line.text)
            guard let metric = bestMetricMatch(in: [text])?.metric else { return nil }
            return LineMetricLabel(line: line, text: text, metric: metric)
        }.sorted { $0.line.bounds.midY > $1.line.bounds.midY }
        return LineGeometryLayout(
            tableBounds: tableBounds,
            parameterLines: parameterLines,
            referenceLines: referenceLines,
            bodyLines: bodyLines,
            dateColumns: dateColumns,
            anchors: anchors,
            headerY: headerY,
            labels: labels
        )
    }

    func joinedCellText(_ cells: [HumanLabOCRCell]) -> String? {
        let values = cells.sorted { left, right in
            guard let leftBounds = left.bounds, let rightBounds = right.bounds else {
                return left.text < right.text
            }
            if abs(leftBounds.midY - rightBounds.midY) > 0.002 {
                return leftBounds.midY > rightBounds.midY
            }
            return leftBounds.midX < rightBounds.midX
        }.map { normalizedWhitespace($0.text) }.filter { !$0.isEmpty }
        guard !values.isEmpty else { return nil }
        return values.joined(separator: " ")
    }

    func parseDateHeader(_ text: String, patterns: PatternBundle) -> Date? {
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = patterns.dateHeader.firstMatch(in: text, range: range),
              let day = Int((text as NSString).substring(with: match.range(at: 1))),
              let month = Int((text as NSString).substring(with: match.range(at: 2))),
              let year = Int((text as NSString).substring(with: match.range(at: 3))),
              (1 ... 31).contains(day),
              (1 ... 12).contains(month),
              (1900 ... 2100).contains(year) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        ))
    }

    func isGeometryHeader(_ text: String, patterns: PatternBundle) -> Bool {
        if parseDateHeader(text, patterns: patterns) != nil { return true }
        let normalized = normalizedSearchText(text)
        return normalized == "parameter"
            || normalized == "test"
            || normalized == "item"
            || normalized == "项目"
            || normalized == "项目名称"
            || isReferenceHeader(text)
            || normalized.contains("referenzbereich")
            || normalized.contains("reference range")
            || normalized.contains("normal range")
            || normalized.contains("参考范围")
    }

    func isReferenceHeader(_ text: String) -> Bool {
        let normalized = normalizedSearchText(text)
        return normalized.contains("normwert")
            || normalized.contains("normert")
            || normalized.contains("reference value")
    }

    func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
