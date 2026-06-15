import Foundation
import SwiftUI

enum ArchitectureModelBoundariesBadStatus: String, Codable {
    case active

    var persistedValue: String? {
        UserDefaults.standard.string(forKey: "architecture-model-bad")
    }

    var color: Color {
        .goPrimary
    }

    var icon: Image {
        Image(systemName: "pawprint.fill")
    }
}

enum ArchitectureModelBoundaryStore {
    static func save(context: ModelContext) {
        context.insert(ArchitectureModelBoundariesBadStatus.active)
    }
}
