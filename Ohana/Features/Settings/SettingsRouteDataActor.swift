import Foundation
import SwiftData

nonisolated struct SettingsRouteData: Equatable, Sendable {
    var households: [SettingsHouseholdSnapshot]?
    var pets: [SettingsPetSnapshot]?
    var humans: [SettingsHumanSnapshot]?
    var hasLoaded = false

    static let empty = SettingsRouteData()
}

@ModelActor
actor SettingsRouteDataActor {
    func load() throws -> SettingsRouteData {
        try Task.checkCancellation()
        let households = try modelContext.fetch(
            FetchDescriptor<Household>(sortBy: [SortDescriptor(\.createdAt)])
        )
        try Task.checkCancellation()
        let pets = try modelContext.fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)])
        )
        try Task.checkCancellation()
        let humans = try modelContext.fetch(
            FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)])
        )
        try Task.checkCancellation()

        return SettingsRouteData(
            households: households.map(SettingsHouseholdSnapshot.init),
            pets: pets.map(SettingsPetSnapshot.init),
            humans: humans.map(SettingsHumanSnapshot.init),
            hasLoaded: true
        )
    }
}

nonisolated enum SettingsRouteDataFailurePolicy {
    static func preservingLastGoodData(_ current: SettingsRouteData) -> SettingsRouteData {
        current
    }
}
