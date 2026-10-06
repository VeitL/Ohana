import Foundation
import SwiftData

enum HumanMetricQuickRecordPolicy {
    static func matches(_ metric: HealthMetric, query: String, l: L10n) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return ([metric.key, metric.displayName(l), metric.nameZh, metric.nameEn, metric.nameDe]
            + metric.shortNames).contains { $0.localizedStandardContains(query) }
    }

    @MainActor
    static func recentKeys(humanID: UUID, context: ModelContext) throws -> [String] {
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(predicate: #Predicate { $0.human?.id == humanID }, sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 256
        let logs = try context.fetch(descriptor) // route-first-frame: bounded deferred fetch
        var seen = Set<String>()
        return logs.compactMap { log in
            guard HealthMetricCatalog.metric(forKey: log.metricKey) != nil, seen.insert(log.metricKey).inserted else { return nil }
            return log.metricKey
        }
    }

    @MainActor
    static func preferredUnit(metric: HealthMetric, humanID: UUID, country: String, context: ModelContext) throws -> String {
        let key = metric.key
        let validUnits = metric.units.map(\.code)
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate { $0.human?.id == humanID && $0.metricKey == key && validUnits.contains($0.unitCode) },
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.unitCode ?? metric.defaultUnit(for: country).code // route-first-frame: user-triggered bounded fetch
    }
}

enum HumanHealthQuickRecordReadModel {
    @MainActor
    static func condition(humanID: UUID, conditionID: UUID, canViewMedication: Bool, context: ModelContext) throws -> HumanHealthConditionsRouteData {
        let owner = humanID.uuidString
        let lower = owner.lowercased()
        var descriptor = FetchDescriptor<HumanHealthCondition>(predicate: #Predicate { $0.id == conditionID && ($0.humanId.contains(owner) || $0.humanId.contains(lower)) })
        descriptor.fetchLimit = 1
        let records = try context.fetch(descriptor).filter { UUID(uuidString: $0.humanId.trimmingCharacters(in: .whitespacesAndNewlines)) == humanID } // route-first-frame: bounded deferred fetch
        var data = HumanHealthConditionsRouteData()
        data.includesMedicationDetails = canViewMedication
        try data.replaceConditionPage(HumanHealthConditionPage(records: records, nextCursor: nil, hasOlder: false), humanID: humanID, context: context)
        data.hasLoaded = true
        return data
    }
}

@MainActor
struct HumanWeightEntryReference {
    let value: HumanHealthSummaryValue?
    let didLoad: Bool
}

enum HumanWeightEntryReadModel {
    @MainActor
    static func latest(humanID: UUID, context: ModelContext) -> HumanWeightEntryReference {
        var descriptor = FetchDescriptor<HumanWeightLog>(predicate: #Predicate { $0.human?.id == humanID }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        do {
            let log = try context.fetch(descriptor).first // route-first-frame: bounded deferred fetch
            return HumanWeightEntryReference(value: log.map { HumanHealthSummaryValue(value: $0.weight, date: $0.date) }, didLoad: true)
        } catch {
            return HumanWeightEntryReference(value: nil, didLoad: false)
        }
    }
}
