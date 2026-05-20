//
//  ExpandedQuickActionMenuPolicy.swift
//  Ohana
//
//  Copy and option decisions for expanded-card quick action menus.
//

import SwiftUI

enum ExpandedQuickActionMenuPolicy {
    static func petOptions(for item: QuickActionItem, l: L10n) -> [ExpandedQuickMenuOption] {
        switch item.actionType {
        case "groom":
            return [
                ExpandedQuickMenuOption(id: "bath", icon: "drop.fill", title: l.tr(zh: "洗澡", en: "Bath", de: "Bad"), tint: Color.goBlue),
                ExpandedQuickMenuOption(id: "teeth", icon: "mouth.fill", title: l.tr(zh: "刷牙", en: "Teeth", de: "Zähne"), tint: Color.goTeal),
                ExpandedQuickMenuOption(id: "nails", icon: "scissors", title: l.tr(zh: "剪甲", en: "Nails", de: "Krallen"), tint: Color.goPurple),
                ExpandedQuickMenuOption(id: "brushing", icon: "comb.fill", title: l.tr(zh: "梳毛", en: "Brush", de: "Bürsten"), tint: Color.goYellow),
                ExpandedQuickMenuOption(id: "ears", icon: "ear.fill", title: l.tr(zh: "清耳", en: "Ears", de: "Ohren"), tint: Color.goOrange)
            ]
        case "potty":
            return [
                ExpandedQuickMenuOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill", title: l.tr(zh: "完美", en: "Good", de: "Gut"), tint: Color(hex: "8B6914")),
                ExpandedQuickMenuOption(id: PottyType.softPoop.rawValue, icon: "circle.dashed", title: l.tr(zh: "软便", en: "Soft", de: "Weich"), tint: Color.goYellow),
                ExpandedQuickMenuOption(id: PottyType.liquidPoop.rawValue, icon: "exclamationmark.triangle.fill", title: l.tr(zh: "水便", en: "Loose", de: "Flüssig"), tint: Color.goRed),
                ExpandedQuickMenuOption(id: PottyType.pee.rawValue, icon: "drop.fill", title: l.tr(zh: "尿尿", en: "Pee", de: "Pipi"), tint: Color.goBlue)
            ]
        default:
            return []
        }
    }

    static func petPrimaryTitle(
        for item: QuickActionItem,
        pet: Pet,
        isSingleUseDone: Bool,
        hasOptions: Bool,
        l: L10n
    ) -> String {
        if isSingleUseDone {
            return l.tr(zh: "今日已完成", en: "Done today", de: "Heute erledigt")
        }
        if hasOptions {
            return l.tr(zh: "选择类型", en: "Choose type", de: "Typ wählen")
        }
        if item.actionType == "medication" {
            return l.tr(zh: "添加药物", en: "Add medication", de: "Medikament hinzufügen")
        }
        switch ExpandedQuickActionLogic.petTapRoute(for: item, pet: pet) {
        case .waterManagement:
            return l.tr(zh: "打开水管理", en: "Open water", de: "Wasser öffnen")
        case .health:
            return l.tr(zh: "打开健康", en: "Open health", de: "Gesundheit öffnen")
        case .weight, .expense, .moment:
            return l.tr(zh: "快速记录", en: "Quick record", de: "Schnell erfassen")
        case .perform(let actionType):
            return actionType == "walk"
                ? l.tr(zh: "开始遛狗", en: "Start walk", de: "Gassi starten")
                : l.tr(zh: "快速打卡", en: "Quick check-in", de: "Schnell abhaken")
        case .none:
            return l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
    }

    static func petDetailTitle(for item: QuickActionItem, l: L10n) -> String? {
        switch item.actionType {
        case "feed": return l.tr(zh: "查看粮食记录", en: "Feeding details", de: "Futterdetails")
        case "water", "waterChange", "filterClean": return l.tr(zh: "查看水管理", en: "Water details", de: "Wasserdetails")
        case "walk": return l.tr(zh: "查看遛狗", en: "Walk details", de: "Gassi-Details")
        case "play": return l.tr(zh: "查看陪玩", en: "Play details", de: "Spiel-Details")
        case "potty", "litter": return l.tr(zh: "查看便便管理", en: "Potty details", de: "Toiletten-Details")
        case "groom", "cageCleaning", "freeFlight", "misting", "substrateChange": return l.tr(zh: "查看护理", en: "Care details", de: "Pflege-Details")
        case "medication": return l.tr(zh: "设置用药", en: "Medication settings", de: "Medikamente")
        case "health": return nil
        case "weight": return l.tr(zh: "查看体重", en: "Weight details", de: "Gewicht-Details")
        case "expense": return l.tr(zh: "查看花费", en: "Expense details", de: "Ausgaben-Details")
        case "moment": return l.tr(zh: "查看记录中心", en: "Moments hub", de: "Momente")
        default: return nil
        }
    }

    static func humanPrimaryTitle(for item: QuickActionItem, l: L10n) -> String {
        switch ExpandedQuickActionLogic.humanTapRoute(actionType: item.actionType, isLocked: false) {
        case .weightQuick, .workoutQuick, .medicationAdd, .noteQuick, .expenseQuick:
            return l.tr(zh: "快速记录", en: "Quick record", de: "Schnell erfassen")
        case .allFeatures:
            return l.tr(zh: "打开全部功能", en: "Open all", de: "Alles öffnen")
        default:
            return l.tr(zh: "打开", en: "Open", de: "Öffnen")
        }
    }

    static func humanDetailTitle(for item: QuickActionItem, l: L10n) -> String? {
        switch item.actionType {
        case "humanWeight": return l.tr(zh: "查看体重", en: "Weight history", de: "Gewicht")
        case "humanWorkout": return l.tr(zh: "查看运动", en: "Workout history", de: "Training")
        case "humanMedication": return l.tr(zh: "查看用药", en: "Medication", de: "Medikation")
        case "humanNote": return l.tr(zh: "查看备注", en: "Notes", de: "Notizen")
        case "humanExpense": return l.tr(zh: "查看花费", en: "Expenses", de: "Ausgaben")
        default: return nil
        }
    }
}
