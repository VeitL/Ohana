import SwiftUI

extension PetThemeColor {
    var color: Color {
        switch self {
        case .crimson: Color.petThemeCrimson
        case .vermilion: Color.petThemeVermilion
        case .orange: Color.petThemeOrange
        case .amber: Color.petThemeAmber
        case .yellow: Color.petThemeYellow
        case .brown: Color.petThemeBrown
        case .rust: Color.petThemeRust
        case .burgundy: Color.petThemeBurgundy
        case .magenta: Color.petThemeMagenta
        case .pink: Color.petThemePink
        case .purple: Color.petThemePurple
        case .indigo: Color.petThemeIndigo
        case .violet: Color.petThemeViolet
        case .navy: Color.petThemeNavy
        case .blue: Color.petThemeBlue
        case .skyBlue: Color.petThemeSkyBlue
        }
    }

    var deepColor: Color {
        switch self {
        case .crimson: Color(hex: "C23616")
        case .vermilion: Color(hex: "E15F41")
        case .orange: Color(hex: "E67E22")
        case .amber: Color(hex: "F39C12")
        case .yellow: Color(hex: "F1C40F")
        case .brown: Color(hex: "8D6E63")
        case .rust: Color(hex: "D35400")
        case .burgundy: Color(hex: "833471")
        case .magenta: Color(hex: "C71585")
        case .pink: Color(hex: "E84393")
        case .purple: Color(hex: "8A2BE2")
        case .indigo: Color(hex: "3C40C6")
        case .violet: Color(hex: "4834D4")
        case .navy: Color(hex: "192A56")
        case .blue: Color(hex: "475569")
        case .skyBlue: Color(hex: "BE185D")
        }
    }
}
