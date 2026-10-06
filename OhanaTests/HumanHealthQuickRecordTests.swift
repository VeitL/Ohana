import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite("Human quick record units", .serialized)
struct HumanHealthQuickRecordTests {
    @Test func weightReferenceReadsLatestForThisMemberOnly() throws {
        let schema = Schema(ArkSchemaV99.models)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = container.mainContext
        let first = Human(name: "First")
        let second = Human(name: "Second")
        context.insert(first)
        context.insert(second)
        let now = Date()
        context.insert(HumanWeightLog(date: now.addingTimeInterval(-20), weight: 70, human: first))
        context.insert(HumanWeightLog(date: now.addingTimeInterval(-10), weight: 71, human: first))
        context.insert(HumanWeightLog(date: now, weight: 90, human: second))
        try context.save()
        let reference = HumanWeightEntryReadModel.latest(humanID: first.id, context: context)
        #expect(reference.didLoad)
        #expect(reference.value?.value == 71)
        #expect(reference.value?.date == now.addingTimeInterval(-10))
    }

    @Test func preferredUnitUsesLatestValidMemberRecordAndKeepsRegionalFallback() throws {
        let schema = Schema(ArkSchemaV99.models)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = container.mainContext
        let first = Human(name: "First")
        let second = Human(name: "Second")
        context.insert(first)
        context.insert(second)
        let metric = try #require(HealthMetricCatalog.metric(forKey: "glucose"))
        let olderUnit = try #require(metric.units.first?.code)
        let newerUnit = try #require(metric.units.last?.code)
        let now = Date()
        for (owner, unit, date) in [(first, olderUnit, now.addingTimeInterval(-20)), (first, newerUnit, now.addingTimeInterval(-10)), (first, "invalid", now), (second, olderUnit, now.addingTimeInterval(10))] {
            context.insert(HumanHealthMetricLog(metricKey: metric.key, unitCode: unit, value: 5, date: date, human: owner))
        }
        try context.save()
        #expect(try HumanMetricQuickRecordPolicy.preferredUnit(metric: metric, humanID: first.id, country: "DE", context: context) == newerUnit)
        let emptyMetric = try #require(HealthMetricCatalog.metric(forKey: "tsh"))
        #expect(try HumanMetricQuickRecordPolicy.preferredUnit(metric: emptyMetric, humanID: first.id, country: "US", context: context) == emptyMetric.defaultUnit(for: "US").code)
    }
}
