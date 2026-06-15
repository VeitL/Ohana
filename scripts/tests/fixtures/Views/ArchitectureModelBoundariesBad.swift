import Foundation
import SwiftUI

enum ArchitectureModelBoundariesBadStatus: String, Codable {
    case active

    var color: Color {
        .goPrimary
    }

    var icon: Image {
        Image(systemName: "pawprint.fill")
    }
}
