import SwiftUI

extension DomainColorToken {
    var color: Color {
        switch self {
        case let .hex(value): Color(hex: value)
        case .goPrimary: .goPrimary
        case .goPurple: .goPurple
        case .goOrange: .goOrange
        case .goYellow: .goYellow
        case .goRed: .goRed
        case .goTeal: .goTeal
        case .goMint: .goMint
        case .secondaryText: .ohanaSecondaryText
        }
    }
}
