import Foundation

nonisolated protocol ActiveHumanSelecting {
    var currentHumanId: String? { get }
    var currentHumanIdRaw: String { get }
}

final nonisolated class UserDefaultsActiveHumanSelection: ActiveHumanSelecting {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentHumanId: String? {
        defaults.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
    }

    var currentHumanIdRaw: String {
        currentHumanId ?? ""
    }
}

enum ActiveHumanSelectionPolicy {
    static func activeHumanIdAfterCreatingHuman(
        currentHumanIdRaw: String,
        createdHumanId: UUID
    ) -> String {
        currentHumanIdRaw.isEmpty ? createdHumanId.uuidString : currentHumanIdRaw
    }
}
