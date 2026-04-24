//
//  ColorExtensions.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension Color {
    // MARK: - Light/Dark adaptive initializer
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Ohana Brand Colors (Legacy)
    static let arkCoral = Color(hex: "FF5E3A")
    static let arkOrange = Color(hex: "FF9500")
    static let arkPeachPink = Color(hex: "FFB6C1")
    static let arkInk = Color(hex: "1A1A2E")
    static let arkCardDark = Color(hex: "2D2D3A")
    static let arkHotPink = Color(hex: "FF69B4")
    static let arkMint = Color(hex: "00D4AA")
    static let arkCyan = Color(hex: "00BCD4")
    
    // MARK: - Background Gradient Colors (Legacy)
    static let ohanaLavender = Color(hex: "e0c3fc")
    static let ohanaSky = Color(hex: "8ec5fc")
    static let ohanaPeach = Color(hex: "f5d0c5")
    
    // MARK: - Accent Gradients (Legacy)
    static let ohanaAccentStart = Color(hex: "8ec5fc")
    static let ohanaAccentEnd = Color(hex: "e0c3fc")
    
    // MARK: - Go UI Color Palette
    static let goLime = Color(hex: "C8FF00")
    /// GO UI 主强调色：始终为荧光绿（GO UI 永远是深色背景，无需光/暗自适应）
    static let goPrimary = goLime
    static let goPrimaryLight = Color(hex: "E0FF80")  // 浅色高亮变体
    static let goPrimaryDark = Color(hex: "9ECC00")   // 深色按压变体
    static let goBackground = Color(hex: "4338FF")
    static let goLimeLight = Color(hex: "E8FFB0")
    static let goMint = Color(hex: "B8FFD0")
    static let goYellow = Color(hex: "FFF44F")
    static let goYellowBright = Color(hex: "FFEB3B")
    static let goCardWhite = Color(hex: "FFFFFF")
    static let goCardLight = Color(hex: "F0F0FF")
    static let goCardBlue = Color(hex: "5B6AFF")
    static let goCardGreen = Color(hex: "BFFF80")
    static let goCardCyan = Color(hex: "80FFEA")
    static let goTeal = Color(hex: "00D4AA")
    static let goOrange = Color(hex: "FF8C42")
    static let goRed = Color(hex: "FF4757")
    static let goBlue = Color(hex: "3B82F6")
    static let goPurple = Color(hex: "A855F7")
    static let goDarkBlue = Color(hex: "1A0E4B")
    static let goDeepNavy = Color(hex: "0D0638")

    // MARK: - Alert Semantic Colors (from Figma Tokens, Light/Dark adaptive)
    // Alert/Success
    static let alertSuccessBg = Color(light:
        Color(red: 0.941, green: 0.992, blue: 0.957),
        dark: Color(red: 0.020, green: 0.180, blue: 0.086))
    static let alertSuccessBorder = Color(light:
        Color(red: 0.063, green: 0.725, blue: 0.506),
        dark: Color(red: 0.204, green: 0.827, blue: 0.600))
    static let alertSuccessText = Color(light:
        Color(red: 0.024, green: 0.373, blue: 0.275),
        dark: Color(red: 0.431, green: 0.906, blue: 0.718))
    static let alertSuccessIcon = Color(light:
        Color(red: 0.024, green: 0.373, blue: 0.275),
        dark: Color(red: 0.431, green: 0.906, blue: 0.718))

    // Alert/Warning
    static let alertWarningBg = Color(light:
        Color(red: 1.000, green: 0.984, blue: 0.922),
        dark: Color(red: 0.471, green: 0.208, blue: 0.059))
    static let alertWarningBorder = Color(light:
        Color(red: 0.961, green: 0.620, blue: 0.043),
        dark: Color(red: 0.984, green: 0.749, blue: 0.141))
    static let alertWarningText = Color(light:
        Color(red: 0.573, green: 0.251, blue: 0.055),
        dark: Color(red: 0.988, green: 0.827, blue: 0.302))
    static let alertWarningIcon = Color(light:
        Color(red: 0.573, green: 0.251, blue: 0.055),
        dark: Color(red: 0.988, green: 0.827, blue: 0.302))

    // Alert/Error
    static let alertErrorBg = Color(light:
        Color(red: 0.996, green: 0.949, blue: 0.949),
        dark: Color(red: 0.498, green: 0.114, blue: 0.114))
    static let alertErrorBorder = Color(light:
        Color(red: 0.937, green: 0.267, blue: 0.267),
        dark: Color(red: 0.973, green: 0.443, blue: 0.443))
    static let alertErrorText = Color(light:
        Color(red: 0.863, green: 0.149, blue: 0.149),
        dark: Color(red: 0.988, green: 0.647, blue: 0.647))
    static let alertErrorIcon = Color(light:
        Color(red: 0.863, green: 0.149, blue: 0.149),
        dark: Color(red: 0.988, green: 0.647, blue: 0.647))

    // Alert/Info
    static let alertInfoBg = Color(light:
        Color(red: 0.937, green: 0.965, blue: 1.000),
        dark: Color(red: 0.118, green: 0.227, blue: 0.541))
    static let alertInfoBorder = Color(light:
        Color(red: 0.231, green: 0.510, blue: 0.965),
        dark: Color(red: 0.376, green: 0.647, blue: 0.980))
    static let alertInfoText = Color(light:
        Color(red: 0.114, green: 0.306, blue: 0.847),
        dark: Color(red: 0.576, green: 0.773, blue: 0.992))
    static let alertInfoIcon = Color(light:
        Color(red: 0.114, green: 0.306, blue: 0.847),
        dark: Color(red: 0.576, green: 0.773, blue: 0.992))

    // MARK: - Figma Token: Button Colors
    static let tokenButtonPrimaryBg     = Color(red: 0.259, green: 0.220, blue: 1.000)
    static let tokenButtonPrimaryText   = Color.white
    static let tokenButtonSecondaryBg   = Color(red: 0.784, green: 1.000, blue: 0.000)
    static let tokenButtonSecondaryText = Color.black
    static let tokenButtonDisabledBg = Color(light:
        Color(red: 0.961, green: 0.961, blue: 0.961),
        dark: Color(red: 0.165, green: 0.165, blue: 0.165))
    static let tokenButtonDisabledText = Color(light:
        Color(red: 0.639, green: 0.639, blue: 0.639),
        dark: Color(red: 0.322, green: 0.322, blue: 0.322))

    // MARK: - Figma Token: Form Colors
    static let tokenFormInputBg = Color(light: Color.white,
        dark: Color(red: 0.039, green: 0.039, blue: 0.039))
    static let tokenFormInputBorder = Color(light:
        Color(red: 0.898, green: 0.898, blue: 0.898),
        dark: Color(red: 0.165, green: 0.165, blue: 0.165))

    // MARK: - Pet Theme Colors (16 non-green, distinct, high-contrast colors)
    static let petThemeCrimson   = Color(light: Color(hex: "C23616"), dark: Color(hex: "FF5252"))
    static let petThemeVermilion = Color(light: Color(hex: "E15F41"), dark: Color(hex: "FF793F"))
    static let petThemeOrange    = Color(light: Color(hex: "E67E22"), dark: Color(hex: "FF9F43"))
    static let petThemeAmber     = Color(light: Color(hex: "F39C12"), dark: Color(hex: "FDCB6E"))
    static let petThemeYellow    = Color(light: Color(hex: "F1C40F"), dark: Color(hex: "FFEAA7"))
    static let petThemeBrown     = Color(light: Color(hex: "8D6E63"), dark: Color(hex: "A1887F"))
    static let petThemeRust      = Color(light: Color(hex: "D35400"), dark: Color(hex: "E67E22"))
    static let petThemeBurgundy  = Color(light: Color(hex: "833471"), dark: Color(hex: "B33771"))
    static let petThemeMagenta   = Color(light: Color(hex: "C71585"), dark: Color(hex: "FF66CC"))
    static let petThemePink      = Color(light: Color(hex: "E84393"), dark: Color(hex: "FD79A8"))
    static let petThemePurple    = Color(light: Color(hex: "8A2BE2"), dark: Color(hex: "D980FA"))
    static let petThemeIndigo    = Color(light: Color(hex: "3C40C6"), dark: Color(hex: "575FCF"))
    static let petThemeViolet    = Color(light: Color(hex: "4834D4"), dark: Color(hex: "686DE0"))
    static let petThemeNavy      = Color(light: Color(hex: "192A56"), dark: Color(hex: "273C75"))
    static let petThemeBlue      = Color(light: Color(hex: "007AFF"), dark: Color(hex: "4DA1FF"))
    static let petThemeSkyBlue   = Color(light: Color(hex: "0ABDE3"), dark: Color(hex: "48DBFB"))

    // MARK: - Hex extraction
    func toHex() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
