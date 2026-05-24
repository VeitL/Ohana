//
//  OhanaHomeStyle.swift
//  Ohana
//
//  Selectable real home implementations.
//

import Foundation

enum OhanaHomeStyle: String, CaseIterable, Identifiable {
    case verticalSolid = "verticalSolid"
    case walletV3 = "walletV3"
    case walletV2 = "walletV2"

    static let storageKey = "ohana_home_style"
    static let defaultStyle: OhanaHomeStyle = .verticalSolid
    static let verticalDefaultMigrationKey = "ohana_home_style_vertical_default_migrated"

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .walletV3:
            l.tr(zh: "Wallet 首页 V3", en: "Wallet Home V3", de: "Wallet-Start V3")
        case .walletV2:
            l.tr(zh: "Wallet 首页 V2", en: "Wallet Home V2", de: "Wallet-Start V2")
        case .verticalSolid:
            l.tr(zh: "竖版实色", en: "Portrait Solid", de: "Hochformat Solide")
        }
    }

    func subtitle(_ l: L10n) -> String {
        switch self {
        case .walletV3:
            l.tr(zh: "Wallet 卡片堆，对照旧样式", en: "Wallet card stack for comparison", de: "Wallet-Kartenstapel zum Vergleich")
        case .walletV2:
            l.tr(zh: "上一版 Wallet 首页，可用于对比", en: "Previous Wallet home for comparison", de: "Vorherige Wallet-Startseite zum Vergleich")
        case .verticalSolid:
            l.tr(zh: "默认首页，真实数据竖版卡片", en: "Default home with real portrait cards", de: "Standardstart mit echten Hochformatkarten")
        }
    }
}
