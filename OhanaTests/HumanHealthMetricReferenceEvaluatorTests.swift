import Foundation
import Testing
@testable import Ohana

@Suite("Human health metric source references")
@MainActor
struct HumanHealthMetricReferenceEvaluatorTests {
    @Test("Printed laboratory flag wins over the catalog range")
    func printedFlagWins() throws {
        let unit = try #require(HealthMetricCatalog.metric(forKey: "tsh")?.units.first)
        let log = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: unit.code,
            value: 2,
            reportedFlag: .high
        )

        #expect(HumanHealthMetricReferenceEvaluator.status(for: log, fallbackUnit: unit) == .high)
    }

    @Test("Source range wins when the report has no printed flag")
    func sourceRangeWins() throws {
        let unit = try #require(HealthMetricCatalog.metric(forKey: "tsh")?.units.first)
        let log = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: unit.code,
            value: 2,
            referenceLow: 3,
            referenceHigh: 6,
            referenceRangeText: "3.0–6.0"
        )

        #expect(HumanHealthMetricReferenceEvaluator.status(for: log, fallbackUnit: unit) == .low)
        #expect(HumanHealthMetricReferenceEvaluator.referenceLabel(for: log, fallbackUnit: unit) == "3.0–6.0")
    }

    @Test("Manual records continue to use the catalog range")
    func catalogFallback() throws {
        let unit = try #require(HealthMetricCatalog.metric(forKey: "tsh")?.units.first)
        let log = HumanHealthMetricLog(metricKey: "tsh", unitCode: unit.code, value: 100)

        #expect(
            HumanHealthMetricReferenceEvaluator.status(for: log, fallbackUnit: unit)
                == unit.status(for: log.value)
        )
        #expect(!HumanHealthMetricReferenceEvaluator.hasSourceReference(log))
    }

    @Test("A linked report is attributed only when it supplied a reference")
    func sourceReferenceAttributionRequiresReferenceData() {
        let linkedWithoutRange = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2,
            sourceReportID: UUID()
        )
        let linkedWithRange = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2,
            sourceReportID: UUID(),
            referenceRangeText: "0.4–4.0"
        )

        #expect(!HumanHealthMetricReferenceEvaluator.hasSourceReference(linkedWithoutRange))
        #expect(HumanHealthMetricReferenceEvaluator.hasSourceReference(linkedWithRange))
    }
}
