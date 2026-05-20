//
//  WeightTrendDataBuilderTests.swift
//  OhanaTests
//

import Foundation
import Testing
@testable import Ohana

struct WeightTrendDataBuilderTests {
    @Test func weightTrendCarriesPreviousValueIntoSelectedRange() {
        let calendar = Calendar(identifier: .gregorian)
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end))!
        let previous = calendar.date(byAdding: .day, value: -10, to: end)!
        let recent = calendar.date(byAdding: .day, value: -2, to: end)!

        let points = WeightTrendDataBuilder.points(
            from: [
                (date: previous, kilograms: 4.8),
                (date: recent, kilograms: 5.1)
            ],
            rangeStart: start,
            rangeEnd: end
        )

        #expect(points.count == 3)
        #expect(points.first?.date == start)
        #expect(points.first?.kilograms == 4.8)
        #expect(points.first?.isSynthetic == true)
        #expect(points[1].date == recent)
        #expect(points[1].isSynthetic == false)
        #expect(points.last?.date == end)
        #expect(points.last?.kilograms == 5.1)
        #expect(points.last?.isSynthetic == true)
    }

    @Test func weightTrendShowsFlatKnownWeightWhenRangeHasNoNewLog() {
        let calendar = Calendar(identifier: .gregorian)
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end))!
        let previous = calendar.date(byAdding: .day, value: -20, to: end)!

        let points = WeightTrendDataBuilder.points(
            from: [(date: previous, kilograms: 6.2)],
            rangeStart: start,
            rangeEnd: end
        )

        #expect(points.map(\.date) == [start, end])
        #expect(points.map(\.isSynthetic) == [true, true])
        #expect(points.map(\.kilograms) == [6.2, 6.2])
    }

    @Test func weightTrendPointIdIsStableForSameDateAndWeight() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = WeightTrendPoint(date: date, kilograms: 5.1234)
        let second = WeightTrendPoint(date: date, kilograms: 5.1234)

        #expect(first.id == second.id)
    }
}
