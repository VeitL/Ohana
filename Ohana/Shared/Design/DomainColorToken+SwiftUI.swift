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

    var actionTextColor: Color {
        switch self {
        case let .hex(value):
            OhanaResolvedPrimaryAccent(customHex: value)?.actionTextColor ?? Color.ohanaPrimaryText
        case .goPrimary:
            Color.ohanaPrimaryActionText
        case .goPurple:
            OhanaResolvedPrimaryAccent(customHex: "A855F7")?.actionTextColor ?? Color.ohanaPrimaryText
        case .goOrange:
            OhanaResolvedPrimaryAccent(customHex: "FF8C42")?.actionTextColor ?? Color.arkInk
        case .goYellow:
            OhanaResolvedPrimaryAccent(customHex: "FFF44F")?.actionTextColor ?? Color.arkInk
        case .goRed:
            OhanaResolvedPrimaryAccent(customHex: "FF4757")?.actionTextColor ?? Color.arkInk
        case .goTeal:
            OhanaResolvedPrimaryAccent(customHex: "00D4AA")?.actionTextColor ?? Color.arkInk
        case .goMint:
            OhanaResolvedPrimaryAccent(customHex: "B8FFD0")?.actionTextColor ?? Color.arkInk
        case .secondaryText:
            Color.ohanaCardSurface
        }
    }
}
