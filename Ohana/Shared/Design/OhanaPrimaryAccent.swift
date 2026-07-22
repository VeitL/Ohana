//
//  OhanaPrimaryAccent.swift
//  Ohana
//
//  Debug-only brand accent playground. Release builds always resolve to the
//  product defaults (Go Blue in light appearance and Go Lime in dark).
//

import Foundation
import SwiftUI

nonisolated enum OhanaPrimaryAccentAppearance: String, CaseIterable, Identifiable, Sendable {
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .light:
            l.tr(zh: "浅色", en: "Light", de: "Hell", es: "Claro", pt: "Claro", fr: "Clair", ja: "ライト", ko: "라이트", it: "Chiaro")
        case .dark:
            l.tr(zh: "深色", en: "Dark", de: "Dunkel", es: "Oscuro", pt: "Escuro", fr: "Sombre", ja: "ダーク", ko: "다크", it: "Scuro")
        }
    }
}

nonisolated enum OhanaPrimaryAccentCandidate: String, CaseIterable, Identifiable, Sendable {
    case blue
    case indigo
    case purple
    case pink
    case red
    case coral
    case orange
    case amber
    case lime
    case green
    case mint
    case teal
    case cyan

    var id: String { rawValue }

    var primaryHex: String {
        switch self {
        case .blue: "2563EB"
        case .indigo: "6366F1"
        case .purple: "A855F7"
        case .pink: "EC4899"
        case .red: "EF4444"
        case .coral: "FF6B5E"
        case .orange: "FF8C42"
        case .amber: "F59E0B"
        case .lime: "C8F34A"
        case .green: "22C55E"
        case .mint: "34D399"
        case .teal: "00D4AA"
        case .cyan: "06B6D4"
        }
    }

    var lighterHex: String {
        switch self {
        case .blue: "60A5FA"
        case .indigo: "818CF8"
        case .purple: "C084FC"
        case .pink: "F472B6"
        case .red: "F87171"
        case .coral: "FF9A91"
        case .orange: "FFB37A"
        case .amber: "FBBF24"
        case .lime: "E3FA97"
        case .green: "4ADE80"
        case .mint: "6EE7B7"
        case .teal: "5EEAD4"
        case .cyan: "67E8F9"
        }
    }

    var darkerHex: String {
        switch self {
        case .blue: "1D4ED8"
        case .indigo: "4F46E5"
        case .purple: "7E22CE"
        case .pink: "BE185D"
        case .red: "DC2626"
        case .coral: "D94A40"
        case .orange: "D96519"
        case .amber: "B45309"
        case .lime: "91B82E"
        case .green: "15803D"
        case .mint: "059669"
        case .teal: "0F9F87"
        case .cyan: "0891B2"
        }
    }

    /// Foreground chosen for the solid primary swatch, independent of the
    /// surrounding appearance. This keeps every debug candidate legible.
    var actionTextHex: String {
        switch self {
        case .blue, .indigo, .purple, .pink, .red:
            "FFFFFF"
        case .coral, .orange, .amber, .lime, .green, .mint, .teal, .cyan:
            "1A1A2E"
        }
    }

    var color: Color { Color(hex: primaryHex) }
    var actionTextColor: Color { Color(hex: actionTextHex) }

    func title(_ l: L10n) -> String {
        switch self {
        case .blue:
            l.tr(zh: "Go 蓝", en: "Go Blue", de: "Go-Blau", es: "Azul Go", pt: "Azul Go", fr: "Bleu Go", ja: "Goブルー", ko: "Go 블루", it: "Blu Go")
        case .indigo:
            l.tr(zh: "靛蓝", en: "Indigo", de: "Indigo", es: "Índigo", pt: "Índigo", fr: "Indigo", ja: "インディゴ", ko: "인디고", it: "Indaco")
        case .purple:
            l.tr(zh: "紫色", en: "Purple", de: "Violett", es: "Morado", pt: "Roxo", fr: "Violet", ja: "パープル", ko: "보라", it: "Viola")
        case .pink:
            l.tr(zh: "粉色", en: "Pink", de: "Pink", es: "Rosa", pt: "Rosa", fr: "Rose", ja: "ピンク", ko: "핑크", it: "Rosa")
        case .red:
            l.tr(zh: "红色", en: "Red", de: "Rot", es: "Rojo", pt: "Vermelho", fr: "Rouge", ja: "レッド", ko: "레드", it: "Rosso")
        case .coral:
            l.tr(zh: "珊瑚", en: "Coral", de: "Koralle", es: "Coral", pt: "Coral", fr: "Corail", ja: "コーラル", ko: "코랄", it: "Corallo")
        case .orange:
            l.tr(zh: "橙色", en: "Orange", de: "Orange", es: "Naranja", pt: "Laranja", fr: "Orange", ja: "オレンジ", ko: "오렌지", it: "Arancione")
        case .amber:
            l.tr(zh: "琥珀", en: "Amber", de: "Bernstein", es: "Ámbar", pt: "Âmbar", fr: "Ambre", ja: "アンバー", ko: "앰버", it: "Ambra")
        case .lime:
            l.tr(zh: "Go 青柠", en: "Go Lime", de: "Go-Limette", es: "Lima Go", pt: "Lima Go", fr: "Citron vert Go", ja: "Goライム", ko: "Go 라임", it: "Lime Go")
        case .green:
            l.tr(zh: "绿色", en: "Green", de: "Grün", es: "Verde", pt: "Verde", fr: "Vert", ja: "グリーン", ko: "그린", it: "Verde")
        case .mint:
            l.tr(zh: "薄荷", en: "Mint", de: "Minze", es: "Menta", pt: "Menta", fr: "Menthe", ja: "ミント", ko: "민트", it: "Menta")
        case .teal:
            l.tr(zh: "青绿", en: "Teal", de: "Türkis", es: "Verde azulado", pt: "Verde-azulado", fr: "Sarcelle", ja: "ティール", ko: "틸", it: "Verde acqua")
        case .cyan:
            l.tr(zh: "青色", en: "Cyan", de: "Cyan", es: "Cian", pt: "Ciano", fr: "Cyan", ja: "シアン", ko: "시안", it: "Ciano")
        }
    }
}

nonisolated struct OhanaResolvedPrimaryAccent: Equatable, Sendable {
    let preset: OhanaPrimaryAccentCandidate?
    let primaryHex: String
    let lighterHex: String
    let darkerHex: String
    let actionTextHex: String

    init(candidate: OhanaPrimaryAccentCandidate) {
        preset = candidate
        primaryHex = candidate.primaryHex
        lighterHex = candidate.lighterHex
        darkerHex = candidate.darkerHex
        actionTextHex = candidate.actionTextHex
    }

    init?(customHex: String) {
        guard let normalized = Self.normalizedHex(customHex) else { return nil }
        preset = nil
        primaryHex = normalized
        lighterHex = Self.mixedHex(normalized, with: "FFFFFF", amount: 0.30)
        darkerHex = Self.mixedHex(normalized, with: "000000", amount: 0.24)
        actionTextHex = Self.preferredForegroundHex(for: normalized)
    }

    var color: Color { Color(hex: primaryHex) }
    var lighterColor: Color { Color(hex: lighterHex) }
    var darkerColor: Color { Color(hex: darkerHex) }
    var actionTextColor: Color { Color(hex: actionTextHex) }
    var isCustom: Bool { preset == nil }

    func title(_ l: L10n) -> String {
        preset?.title(l) ?? l.tr(
            zh: "自定义",
            en: "Custom",
            de: "Eigene Farbe",
            es: "Personalizado",
            pt: "Personalizada",
            fr: "Personnalisée",
            ja: "カスタム",
            ko: "사용자 설정",
            it: "Personalizzato"
        )
    }

    private static func normalizedHex(_ hex: String) -> String? {
        let normalized = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .uppercased()
        guard normalized.count == 6, normalized.allSatisfy(\.isHexDigit) else { return nil }
        return normalized
    }

    private static func mixedHex(_ source: String, with target: String, amount: Double) -> String {
        let sourceChannels = channels(for: source)
        let targetChannels = channels(for: target)
        let clampedAmount = min(max(amount, 0), 1)
        var mixedChannels: [Int] = []
        for index in 0 ..< 3 {
            let sourceChannel = Double(sourceChannels[index])
            let targetChannel = Double(targetChannels[index])
            let mixedChannel = sourceChannel + (targetChannel - sourceChannel) * clampedAmount
            mixedChannels.append(Int(mixedChannel.rounded()))
        }
        return String(format: "%02X%02X%02X", mixedChannels[0], mixedChannels[1], mixedChannels[2])
    }

    private static func preferredForegroundHex(for backgroundHex: String) -> String {
        let backgroundLuminance = relativeLuminance(of: backgroundHex)
        let whiteContrast = 1.05 / (backgroundLuminance + 0.05)
        let inkLuminance = relativeLuminance(of: "1A1A2E")
        let inkContrast = (backgroundLuminance + 0.05) / (inkLuminance + 0.05)
        return inkContrast >= whiteContrast ? "1A1A2E" : "FFFFFF"
    }

    private static func relativeLuminance(of hex: String) -> Double {
        let values = channels(for: hex).map { value -> Double in
            let component = Double(value) / 255
            return component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2]
    }

    private static func channels(for hex: String) -> [Int] {
        [
            Int(hex.prefix(2), radix: 16) ?? 0,
            Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0,
            Int(hex.dropFirst(4).prefix(2), radix: 16) ?? 0
        ]
    }
}

nonisolated enum OhanaPrimaryAccentPreferences {
    static let lightStorageKey = "ohana_debug_primary_accent_light.v1"
    static let darkStorageKey = "ohana_debug_primary_accent_dark.v1"
    static let customStoragePrefix = "custom:"
    static let defaultLight: OhanaPrimaryAccentCandidate = .blue
    static let defaultDark: OhanaPrimaryAccentCandidate = .lime

    static func candidate(
        for appearance: OhanaPrimaryAccentAppearance,
        lightRawValue: String?,
        darkRawValue: String?,
        allowsDeveloperOverride: Bool
    ) -> OhanaPrimaryAccentCandidate {
        let fallback = appearance == .light ? defaultLight : defaultDark
        guard allowsDeveloperOverride else { return fallback }
        let rawValue = appearance == .light ? lightRawValue : darkRawValue
        return rawValue.flatMap(OhanaPrimaryAccentCandidate.init(rawValue:)) ?? fallback
    }

    static func resolvedAccent(
        for appearance: OhanaPrimaryAccentAppearance,
        lightRawValue: String?,
        darkRawValue: String?,
        allowsDeveloperOverride: Bool
    ) -> OhanaResolvedPrimaryAccent {
        let fallback = appearance == .light ? defaultLight : defaultDark
        guard allowsDeveloperOverride else { return OhanaResolvedPrimaryAccent(candidate: fallback) }

        let rawValue = appearance == .light ? lightRawValue : darkRawValue
        if let rawValue, let preset = OhanaPrimaryAccentCandidate(rawValue: rawValue) {
            return OhanaResolvedPrimaryAccent(candidate: preset)
        }
        if let rawValue,
           rawValue.hasPrefix(customStoragePrefix),
           let custom = OhanaResolvedPrimaryAccent(customHex: String(rawValue.dropFirst(customStoragePrefix.count))) {
            return custom
        }
        return OhanaResolvedPrimaryAccent(candidate: fallback)
    }

    static func customStorageRawValue(hex: String) -> String? {
        guard let accent = OhanaResolvedPrimaryAccent(customHex: hex) else { return nil }
        return customStoragePrefix + accent.primaryHex
    }

    static func currentAccent(for appearance: OhanaPrimaryAccentAppearance) -> OhanaResolvedPrimaryAccent {
        resolvedAccent(
            for: appearance,
            lightRawValue: UserDefaults.standard.string(forKey: lightStorageKey),
            darkRawValue: UserDefaults.standard.string(forKey: darkStorageKey),
            allowsDeveloperOverride: developerOverridesAllowed
        )
    }

    @MainActor static var adaptivePrimaryColor: Color {
        adaptiveColor(\.primaryHex)
    }

    @MainActor static var adaptiveLighterColor: Color {
        adaptiveColor(\.lighterHex)
    }

    @MainActor static var adaptiveDarkerColor: Color {
        adaptiveColor(\.darkerHex)
    }

    @MainActor static var adaptiveActionTextColor: Color {
        adaptiveColor(\.actionTextHex)
    }

    @MainActor static func adaptivePrimaryColor(lightRawValue: String, darkRawValue: String) -> Color {
        adaptiveColor(
            \.primaryHex,
            lightRawValue: lightRawValue,
            darkRawValue: darkRawValue
        )
    }

    @MainActor private static func adaptiveColor(_ keyPath: KeyPath<OhanaResolvedPrimaryAccent, String>) -> Color {
        adaptiveColor(
            keyPath,
            lightRawValue: UserDefaults.standard.string(forKey: lightStorageKey),
            darkRawValue: UserDefaults.standard.string(forKey: darkStorageKey)
        )
    }

    @MainActor private static func adaptiveColor(
        _ keyPath: KeyPath<OhanaResolvedPrimaryAccent, String>,
        lightRawValue: String?,
        darkRawValue: String?
    ) -> Color {
        let light = resolvedAccent(
            for: .light,
            lightRawValue: lightRawValue,
            darkRawValue: darkRawValue,
            allowsDeveloperOverride: developerOverridesAllowed
        )
        let dark = resolvedAccent(
            for: .dark,
            lightRawValue: lightRawValue,
            darkRawValue: darkRawValue,
            allowsDeveloperOverride: developerOverridesAllowed
        )
        return Color(
            light: Color(hex: light[keyPath: keyPath]),
            dark: Color(hex: dark[keyPath: keyPath])
        )
    }

    private static var developerOverridesAllowed: Bool {
        #if DEBUG
            let processInfo = ProcessInfo.processInfo
            let environment = processInfo.environment
            let isAutomatedTest = environment["XCTestConfigurationFilePath"] != nil
                || environment["XCTestBundlePath"] != nil
                || environment["XCTestSessionIdentifier"] != nil
                || processInfo.arguments.contains("-OHANA_UI_TESTS")
            return !isAutomatedTest
        #else
            return false
        #endif
    }
}
