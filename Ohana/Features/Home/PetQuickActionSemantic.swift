import Foundation

nonisolated enum PetQuickActionSemantic: String, Sendable {
    case recordOnce
    case fillRecord
    case startWalk
    case viewRecords

    func title(_ l: L10n) -> String {
        let copy = PetCareExperienceCopy(l: l)
        return switch self {
        case .recordOnce: copy.recordOnce
        case .fillRecord: copy.fillRecord
        case .startWalk: copy.startWalk
        case .viewRecords: copy.viewHistory
        }
    }
}
