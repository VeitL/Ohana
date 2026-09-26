//
//  HomeQuickActionOptionCatalog.swift
//  Ohana
//
//  Shared subtype choices for member-card and toolbar quick records.
//

import Foundation

nonisolated struct HomeQuickActionOption: Identifiable, Equatable, Sendable {
    let id: String
    let icon: String
    let title: String
    let colorToken: DomainColorToken
}

nonisolated enum HomeQuickActionOptionCatalog {
    static func hasOptions(for actionType: String) -> Bool {
        switch actionType {
        case "groom", "potty", "health": true
        default: false
        }
    }

    static func options(
        for actionType: String,
        localization l: L10n
    ) -> [HomeQuickActionOption] {
        switch actionType {
        case "groom":
            [
                option(id: "bath", icon: "drop.fill", title: l.tr(zh: "洗澡", en: "Bath", de: "Bad"), color: .hex("2563EB")),
                option(id: "teeth", icon: "mouth.fill", title: l.tr(zh: "刷牙", en: "Teeth", de: "Zähne"), color: .goTeal),
                option(id: "nails", icon: "scissors", title: l.tr(zh: "剪甲", en: "Nails", de: "Krallen"), color: .goPurple),
                option(id: "brushing", icon: "comb.fill", title: l.tr(zh: "梳毛", en: "Brush", de: "Bürsten"), color: .goYellow),
                option(id: "ears", icon: "ear.fill", title: l.tr(zh: "清耳", en: "Ears", de: "Ohren"), color: .goOrange)
            ]
        case "potty":
            [
                option(
                    id: PottyType.perfectPoop.rawValue,
                    icon: "seal.fill",
                    title: l.tr(zh: "完美", en: "Good", de: "Gut"),
                    color: .goYellow
                ),
                option(
                    id: PottyType.softPoop.rawValue,
                    icon: "circle.dashed",
                    title: l.tr(zh: "软便", en: "Soft", de: "Weich"),
                    color: .goYellow
                ),
                option(
                    id: PottyType.liquidPoop.rawValue,
                    icon: "exclamationmark.triangle.fill",
                    title: l.tr(zh: "水便", en: "Loose", de: "Flüssig"),
                    color: .goRed
                ),
                option(
                    id: PottyType.pee.rawValue,
                    icon: "drop.fill",
                    title: l.tr(zh: "尿尿", en: "Pee", de: "Pipi"),
                    color: .hex("2563EB")
                )
            ]
        case "health":
            [
                option(
                    id: "vaccine",
                    icon: "syringe.fill",
                    title: l.tr(zh: "疫苗", en: "Vaccine", de: "Impfung"),
                    color: .goTeal
                ),
                option(
                    id: "deworming",
                    icon: "shield.lefthalf.filled",
                    title: l.tr(zh: "驱虫", en: "Deworm", de: "Entwurmen"),
                    color: .goPurple
                ),
                option(
                    id: "visit",
                    icon: "stethoscope",
                    title: l.tr(zh: "体检", en: "Visit", de: "Besuch"),
                    color: .hex("2563EB")
                )
            ]
        default:
            []
        }
    }

    private static func option(
        id: String,
        icon: String,
        title: String,
        color: DomainColorToken
    ) -> HomeQuickActionOption {
        HomeQuickActionOption(id: id, icon: icon, title: title, colorToken: color)
    }
}
