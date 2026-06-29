//
//  AppBackgroundStyle.swift
//  Ohana
//

import SwiftUI

// MARK: - 背景风格枚举
enum AppBackgroundStyle: String, CaseIterable, Identifiable {
    case goDefault = "go_default"
    /// GO Focus 首页同款：冷静岛屿底色，可在子页复用。
    case goIsland = "go_island"
    case cleanBlueGray = "clean_blue_gray"
    case deepAmbient = "deep_ambient"
    case aurora
    case midnight
    case sunsetGlow = "sunset_glow"
    case sakuraMist = "sakura_mist"
    case forestGlade = "forest_glade"
    case paperCream = "paper_cream"
    case neonGrid = "neon_grid"
    case coastalFresh = "coastal_fresh"
    case lavenderDawn = "lavender_dawn"
    case mintFrost = "mint_frost"
    case peachCloud = "peach_cloud"
    case graphitePulse = "graphite_pulse"
    case customPhoto = "custom_photo"

    var id: String { rawValue }

    static var settingsOptions: [AppBackgroundStyle] {
        officialPairOptions + [.customPhoto]
    }

    static var officialPairOptions: [AppBackgroundStyle] {
        [
            .goIsland,
            .cleanBlueGray,
            .paperCream,
            .forestGlade,
            .deepAmbient,
            .aurora,
            .sakuraMist,
            .sunsetGlow,
            .coastalFresh,
            .lavenderDawn,
            .mintFrost,
            .peachCloud,
            .graphitePulse
        ]
    }

    var displayName: String {
        switch self {
        case .goDefault: "Go 默认"
        case .goIsland: "GO 岛屿"
        case .cleanBlueGray: "雾灰晨光"
        case .deepAmbient: "深邃光球"
        case .aurora: "极光"
        case .midnight: "午夜"
        case .sunsetGlow: "落日熔金"
        case .sakuraMist: "樱雾"
        case .forestGlade: "森谷"
        case .paperCream: "暖纸"
        case .neonGrid: "霓虹格"
        case .coastalFresh: "海岸清风"
        case .lavenderDawn: "薰衣草晨光"
        case .mintFrost: "薄荷霜"
        case .peachCloud: "桃云"
        case .graphitePulse: "石墨微光"
        case .customPhoto: "自定义照片"
        }
    }

    func localizedName(_ lang: String) -> String {
        switch self {
        case .goIsland:
            L10n(lang).tr(zh: "岛屿雾灰", en: "Island Mist", de: "Inselnebel")
        case .cleanBlueGray:
            L10n(lang).tr(zh: "雾灰晨光", en: "Morning Mist", de: "Morgennebel")
        case .paperCream:
            L10n(lang).tr(zh: "柔和纸面", en: "Soft Paper", de: "Weiches Papier")
        case .forestGlade:
            L10n(lang).tr(zh: "森林浅雾", en: "Forest Mist", de: "Waldnebel")
        case .deepAmbient:
            L10n(lang).tr(zh: "星云光感", en: "Nebula Glow", de: "Nebelglanz")
        case .aurora:
            L10n(lang).tr(zh: "极光柔幕", en: "Soft Aurora", de: "Sanfte Aurora")
        case .sakuraMist:
            L10n(lang).tr(zh: "樱雾紫", en: "Sakura Mist", de: "Sakura-Nebel")
        case .sunsetGlow:
            L10n(lang).tr(zh: "落日暖光", en: "Sunset Glow", de: "Abendrot")
        case .coastalFresh:
            L10n(lang).tr(zh: "海岸清风", en: "Coastal Fresh", de: "Küstenfrische")
        case .lavenderDawn:
            L10n(lang).tr(zh: "薰衣草晨光", en: "Lavender Dawn", de: "Lavendel-Morgen")
        case .mintFrost:
            L10n(lang).tr(zh: "薄荷霜", en: "Mint Frost", de: "Minzfrost")
        case .peachCloud:
            L10n(lang).tr(zh: "桃云", en: "Peach Cloud", de: "Pfirsichwolke")
        case .graphitePulse:
            L10n(lang).tr(zh: "石墨微光", en: "Graphite Pulse", de: "Graphitglanz")
        case .customPhoto:
            L10n(lang).tr(zh: "自定义照片", en: "Custom photo", de: "Eigenes Foto")
        default:
            displayName
        }
    }

    func localizedSubtitle(_ lang: String) -> String {
        switch self {
        case .goIsland:
            L10n(lang).tr(zh: "温和雾灰，保留一点岛屿层次", en: "Gentle mist gray with a little island depth", de: "Sanftes Nebelgrau mit etwas Inseltiefe")
        case .cleanBlueGray:
            L10n(lang).tr(zh: "更少蓝色，更耐看的日常底色", en: "Less blue, a calmer everyday base", de: "Weniger Blau, eine ruhigere Alltagsbasis")
        case .paperCream:
            L10n(lang).tr(zh: "温暖柔和，阅读舒适", en: "Warm, soft, comfortable to read", de: "Warm, weich, angenehm lesbar")
        case .forestGlade:
            L10n(lang).tr(zh: "自然、有氧、低压力", en: "Natural, airy, low-pressure", de: "Natürlich, luftig, entspannt")
        case .deepAmbient:
            L10n(lang).tr(zh: "更酷的光感背景", en: "Cooler ambient light style", de: "Kühler Lichtstil")
        case .aurora:
            L10n(lang).tr(zh: "清透青绿，适合轻松页面", en: "Clear teal tones for calm screens", de: "Klare Türkistöne für ruhige Seiten")
        case .sakuraMist:
            L10n(lang).tr(zh: "柔粉与紫雾，温柔但不甜腻", en: "Soft pink and violet without feeling sugary", de: "Sanftes Rosa und Violett ohne Kitsch")
        case .sunsetGlow:
            L10n(lang).tr(zh: "暖橙层次，适合奖励感", en: "Warm orange layers for reward moments", de: "Warme Orangetöne für Belohnungen")
        case .coastalFresh:
            L10n(lang).tr(zh: "海风蓝绿，浅色更清爽", en: "Blue-green sea air, crisp in light mode", de: "Blaugrüne Meeresluft, frisch im Hellmodus")
        case .lavenderDawn:
            L10n(lang).tr(zh: "低饱和紫蓝，安静高级", en: "Muted violet-blue, quiet and polished", de: "Gedämpftes Violettblau, ruhig und edel")
        case .mintFrost:
            L10n(lang).tr(zh: "低压力薄荷色，适合健康页", en: "Low-pressure mint tones for care pages", de: "Ruhige Minztöne für Pflegeseiten")
        case .peachCloud:
            L10n(lang).tr(zh: "温暖柔亮，适合家庭和奖励感", en: "Warm and bright for family and rewards", de: "Warm und hell für Familie und Belohnungen")
        case .graphitePulse:
            L10n(lang).tr(zh: "中性灰蓝，最克制耐看", en: "Neutral blue-gray, the most restrained option", de: "Neutrales Blaugrau, sehr zurückhaltend")
        case .customPhoto:
            L10n(lang).tr(zh: "上传一张全局背景", en: "Use your own app background", de: "Eigenes App-Hintergrundbild")
        default:
            ""
        }
    }

    func gradientColors(for colorScheme: ColorScheme) -> [Color] {
        switch self {
        case .goDefault:
            colorScheme == .dark
                ? [Color(hex: "0A0A0C"), Color(hex: "151716"), Color(hex: "10110F")]
                : [Color(hex: "F6F4EF"), Color(hex: "EDEAE2"), Color(hex: "E0DED5")]
        case .goIsland:
            colorScheme == .dark
                ? [Color(hex: "151716"), Color(hex: "10130F"), Color(hex: "080A08")]
                : [Color(hex: "F5F3ED"), Color(hex: "ECEAE2"), Color(hex: "E0DFD6")]
        case .cleanBlueGray:
            colorScheme == .dark
                ? [Color(hex: "111312"), Color(hex: "191C19"), Color(hex: "090A09")]
                : [Color(hex: "F2F2EF"), Color(hex: "E8E7E1"), Color(hex: "DADBD2")]
        case .paperCream:
            colorScheme == .dark
                ? [Color(hex: "1C1917"), Color(hex: "292524"), Color(hex: "1C1917")]
                : [Color(hex: "F4EEE5"), Color(hex: "E9DDCD"), Color(hex: "D9C7B3")]
        case .forestGlade:
            colorScheme == .dark
                ? [Color(hex: "052E1F"), Color(hex: "064E3B"), Color(hex: "021B14")]
                : [Color(hex: "E2F0E8"), Color(hex: "D0E3D8"), Color(hex: "BFD5CB")]
        case .deepAmbient:
            colorScheme == .dark
                ? [Color(hex: "040403"), Color(hex: "1A1B18"), Color(hex: "2A2922")]
                : [Color(hex: "F0EFEA"), Color(hex: "E4E2DB"), Color(hex: "D6D3CB")]
        case .aurora:
            colorScheme == .dark
                ? [Color(hex: "020617"), Color(hex: "0F766E"), Color(hex: "312E81")]
                : [Color(hex: "DDFCF6"), Color(hex: "C8F1EA"), Color(hex: "D8D7FA")]
        case .midnight:
            colorScheme == .dark
                ? [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "21262D")]
                : [Color(hex: "E3E8F1"), Color(hex: "D1D9E6"), Color(hex: "B9C4D3")]
        case .sunsetGlow:
            colorScheme == .dark
                ? [Color(hex: "1A0A12"), Color(hex: "7C2D12"), Color(hex: "581C1C")]
                : [Color(hex: "FDE8D6"), Color(hex: "F8C7B5"), Color(hex: "E9A5A5")]
        case .sakuraMist:
            colorScheme == .dark
                ? [Color(hex: "1A0B17"), Color(hex: "831843"), Color(hex: "4C1D95")]
                : [Color(hex: "F7E3EF"), Color(hex: "E9D5FF"), Color(hex: "FBCFE8")]
        case .neonGrid:
            colorScheme == .dark
                ? [Color(hex: "050510"), Color(hex: "0E7490"), Color(hex: "6D28D9")]
                : [Color(hex: "DBF6FF"), Color(hex: "C7D2FE"), Color(hex: "E9D5FF")]
        case .coastalFresh:
            colorScheme == .dark
                ? [Color(hex: "082F49"), Color(hex: "0E7490"), Color(hex: "0F172A")]
                : [Color(hex: "D7F3FA"), Color(hex: "C5E3EF"), Color(hex: "B6D5E4")]
        case .lavenderDawn:
            colorScheme == .dark
                ? [Color(hex: "1E1B4B"), Color(hex: "4C1D95"), Color(hex: "111827")]
                : [Color(hex: "ECE7FF"), Color(hex: "DDD6FE"), Color(hex: "C7D2FE")]
        case .mintFrost:
            colorScheme == .dark
                ? [Color(hex: "052E2B"), Color(hex: "115E59"), Color(hex: "0F172A")]
                : [Color(hex: "DDF7EF"), Color(hex: "CBEFDE"), Color(hex: "B9E3CF")]
        case .peachCloud:
            colorScheme == .dark
                ? [Color(hex: "3B1D16"), Color(hex: "7C2D12"), Color(hex: "111827")]
                : [Color(hex: "F9E2D2"), Color(hex: "F3C8B5"), Color(hex: "E8B4A2")]
        case .graphitePulse:
            colorScheme == .dark
                ? [Color(hex: "111827"), Color(hex: "374151"), Color(hex: "020617")]
                : [Color(hex: "D8DEE8"), Color(hex: "C8D1DD"), Color(hex: "B7C1CF")]
        case .customPhoto:
            colorScheme == .dark
                ? [Color(hex: "111312"), Color(hex: "20211D"), Color(hex: "4B4B43")]
                : [Color(hex: "F2F1EC"), Color(hex: "E6E4DC"), Color(hex: "D7D4CC")]
        }
    }

    var previewColors: [Color] {
        gradientColors(for: .dark)
    }
}
