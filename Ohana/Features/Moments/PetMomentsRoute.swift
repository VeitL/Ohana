import Foundation

nonisolated enum PetMomentsTab: String, CaseIterable, Identifiable, Sendable {
    case highlights
    case timeline
    case photos

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .highlights: l.tr(zh: "高光", en: "Highlights", de: "Highlights")
        case .timeline: l.tr(zh: "时光", en: "Diary", de: "Tagebuch")
        case .photos: l.tr(zh: "相册", en: "Album", de: "Album")
        }
    }

    var icon: String {
        switch self {
        case .highlights: "sparkles"
        case .timeline: "clock.arrow.circlepath"
        case .photos: "photo.on.rectangle"
        }
    }
}

/// A value-only handoff from a successful command to the exact fact it saved.
nonisolated struct PetRecordReference: Hashable, Identifiable, Sendable {
    let petID: UUID
    let recordID: UUID
    var sharedSessionID: UUID? = nil
    var filter: PetTimelineDisplayMode = .care

    var id: UUID { sharedSessionID ?? recordID }
    var route: PetMomentsRoute {
        PetMomentsRoute(tab: .timeline, filter: filter, focusedRecordID: id)
    }
}

nonisolated struct PetMomentsRoute: Hashable, Sendable {
    var tab: PetMomentsTab = .highlights
    var filter: PetTimelineDisplayMode = .memories
    var focusedRecordID: UUID? = nil

    static let highlights = PetMomentsRoute()
    static let timeline = PetMomentsRoute(tab: .timeline, filter: .all)
    static let photos = PetMomentsRoute(tab: .photos)

    var routeID: String {
        "\(tab.rawValue)-\(filter.rawValue)-\(focusedRecordID?.uuidString ?? "all")"
    }
}

@MainActor
extension SharedPetActionResult {
    func recordReference(for petID: UUID, ids: [UUID], filter: PetTimelineDisplayMode = .care) -> PetRecordReference? {
        guard didWriteFact,
              let index = targetPetIDs.firstIndex(of: petID),
              ids.indices.contains(index) else { return nil }
        return PetRecordReference(
            petID: petID,
            recordID: ids[index],
            sharedSessionID: targetPetIDs.count > 1 ? sessionID : nil,
            filter: filter
        )
    }
}
