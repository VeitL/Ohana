import Foundation

nonisolated enum DomainColorToken: Equatable, Hashable, Sendable {
    case hex(String)
    case goPrimary
    case goPurple
    case goOrange
    case goYellow
    case goRed
    case goTeal
    case goMint
    case secondaryText
}
