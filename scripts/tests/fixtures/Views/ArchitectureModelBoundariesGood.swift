import Foundation
import SwiftData

@Model
final class ArchitectureModelBoundariesGoodRecord {
    var id: UUID
    var statusRaw: String

    init(id: UUID = UUID(), statusRaw: String = "active") {
        self.id = id
        self.statusRaw = statusRaw
    }

    var colorHex: String {
        "22C55E"
    }

    var iconSystemName: String {
        "pawprint.fill"
    }
}
