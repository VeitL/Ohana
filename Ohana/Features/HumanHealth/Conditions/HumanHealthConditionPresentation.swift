//
//  HumanHealthConditionPresentation.swift
//  Ohana
//

import SwiftUI

extension HumanHealthConditionCategory {
    func displayName(_ l: L10n) -> String {
        switch self {
        case .mentalHealth:
            l.tr(zh: "心理与情绪", en: "Mental & emotional", de: "Psyche & Emotionen")
        case .thyroid:
            l.tr(zh: "甲状腺", en: "Thyroid", de: "Schilddrüse")
        case .allergy:
            l.tr(zh: "过敏", en: "Allergy", de: "Allergie")
        case .hairAndScalp:
            l.tr(zh: "毛发与头皮", en: "Hair & scalp", de: "Haar & Kopfhaut")
        case .autoimmune:
            l.tr(zh: "免疫相关", en: "Immune-related", de: "Immunsystem")
        case .metabolic:
            l.tr(zh: "代谢", en: "Metabolic", de: "Stoffwechsel")
        case .cardiovascular:
            l.tr(zh: "心血管", en: "Cardiovascular", de: "Herz-Kreislauf")
        case .respiratory:
            l.tr(zh: "呼吸", en: "Respiratory", de: "Atmung")
        case .digestive:
            l.tr(zh: "消化", en: "Digestive", de: "Verdauung")
        case .neurological:
            l.tr(zh: "神经相关", en: "Neurological", de: "Neurologisch")
        case .musculoskeletal:
            l.tr(zh: "肌肉与骨骼", en: "Muscle & joint", de: "Muskeln & Gelenke")
        case .skin:
            l.tr(zh: "皮肤", en: "Skin", de: "Haut")
        case .other:
            l.tr(zh: "其他", en: "Other", de: "Sonstiges")
        }
    }

    var systemImage: String {
        switch self {
        case .mentalHealth: "brain.head.profile"
        case .thyroid: "waveform.path.ecg"
        case .allergy: "allergens.fill"
        case .hairAndScalp: "person.crop.circle.badge.questionmark"
        case .autoimmune: "shield.lefthalf.filled"
        case .metabolic: "chart.bar.xaxis"
        case .cardiovascular: "heart.fill"
        case .respiratory: "lungs.fill"
        case .digestive: "cross.case.fill"
        case .neurological: "bolt.heart.fill"
        case .musculoskeletal: "figure.strengthtraining.traditional"
        case .skin: "hand.raised.fill"
        case .other: "list.clipboard.fill"
        }
    }

    var tint: Color {
        switch self {
        case .mentalHealth: .goPurple
        case .thyroid: .goTeal
        case .allergy: .goOrange
        case .hairAndScalp: .goPurple
        case .autoimmune: .goBlue
        case .metabolic: .goYellow
        case .cardiovascular: .goRed
        case .respiratory: .goTeal
        case .digestive: .goTeal
        case .neurological: .goBlue
        case .musculoskeletal: .goOrange
        case .skin: .goPurple
        case .other: .goPrimary
        }
    }

    var defaultMetricKeys: [String] {
        switch self {
        case .thyroid:
            ["tsh", "ft4", "ft3", "tpo_ab"]
        case .hairAndScalp:
            ["ferritin", "vitamin_d", "tsh"]
        default:
            []
        }
    }

    func suggestedTags(_ l: L10n) -> [String] {
        switch self {
        case .mentalHealth:
            [
                l.tr(zh: "焦虑", en: "Anxiety", de: "Angst"),
                l.tr(zh: "情绪低落", en: "Low mood", de: "Niedrige Stimmung"),
                l.tr(zh: "精力变化", en: "Energy change", de: "Energie verändert"),
                l.tr(zh: "注意力", en: "Focus", de: "Konzentration")
            ]
        case .thyroid:
            [
                l.tr(zh: "疲劳", en: "Fatigue", de: "Müdigkeit"),
                l.tr(zh: "怕冷或怕热", en: "Cold or heat sensitivity", de: "Kälte- oder Hitzeempfindlich"),
                l.tr(zh: "心悸", en: "Palpitations", de: "Herzklopfen"),
                l.tr(zh: "体重变化", en: "Weight change", de: "Gewichtsveränderung")
            ]
        case .allergy:
            [
                l.tr(zh: "鼻塞", en: "Congestion", de: "Verstopfte Nase"),
                l.tr(zh: "喷嚏", en: "Sneezing", de: "Niesen"),
                l.tr(zh: "眼痒", en: "Itchy eyes", de: "Juckende Augen"),
                l.tr(zh: "皮疹", en: "Rash", de: "Ausschlag")
            ]
        case .hairAndScalp:
            [
                l.tr(zh: "脱发增加", en: "More shedding", de: "Mehr Haarausfall"),
                l.tr(zh: "头皮痒", en: "Itchy scalp", de: "Juckende Kopfhaut"),
                l.tr(zh: "头屑", en: "Flaking", de: "Schuppen"),
                l.tr(zh: "发际变化", en: "Hairline change", de: "Haaransatz verändert")
            ]
        default:
            []
        }
    }
}

extension HumanHealthTrackingStatus {
    func displayName(_ l: L10n) -> String {
        switch self {
        case .active:
            l.tr(zh: "正在关注", en: "Active", de: "Aktiv")
        case .monitoring:
            l.tr(zh: "持续观察", en: "Monitoring", de: "Beobachtung")
        case .stable:
            l.tr(zh: "自评稳定", en: "Self-reported stable", de: "Selbst eingeschätzt stabil")
        case .resolved:
            l.tr(zh: "已结束追踪", en: "Tracking ended", de: "Tracking beendet")
        }
    }

    var tint: Color {
        switch self {
        case .active: .goOrange
        case .monitoring: .goBlue
        case .stable: .goTeal
        case .resolved: .ohanaTertiaryText
        }
    }
}

extension HumanMedicationResponse {
    func displayName(_ l: L10n) -> String {
        switch self {
        case .unknown:
            l.tr(zh: "未记录", en: "Not recorded", de: "Nicht erfasst")
        case .helpful:
            l.tr(zh: "自觉有帮助", en: "Felt helpful", de: "Als hilfreich empfunden")
        case .neutral:
            l.tr(zh: "暂未感觉变化", en: "No felt change", de: "Keine gefühlte Änderung")
        case .worse:
            l.tr(zh: "自觉更不适", en: "Felt worse", de: "Als schlechter empfunden")
        }
    }
}

extension HumanHealthSeverityTrend {
    func displayName(_ l: L10n) -> String {
        switch self {
        case .insufficientData:
            l.tr(zh: "记录不足", en: "Not enough data", de: "Zu wenige Daten")
        case .improving:
            l.tr(zh: "近期较轻", en: "Lighter recently", de: "Zuletzt leichter")
        case .stable:
            l.tr(zh: "近期相近", en: "Similar recently", de: "Zuletzt ähnlich")
        case .worsening:
            l.tr(zh: "近期较重", en: "Heavier recently", de: "Zuletzt stärker")
        }
    }

    var tint: Color {
        switch self {
        case .insufficientData: .ohanaTertiaryText
        case .improving: .goTeal
        case .stable: .goBlue
        case .worsening: .goOrange
        }
    }
}

enum HumanHealthSeverityLabel {
    static func text(for value: Int, l: L10n) -> String {
        switch max(0, min(10, value)) {
        case 0: l.tr(zh: "无不适", en: "No impact", de: "Keine Belastung")
        case 1 ... 3: l.tr(zh: "轻微", en: "Mild", de: "Leicht")
        case 4 ... 6: l.tr(zh: "中等", en: "Moderate", de: "Mittel")
        case 7 ... 8: l.tr(zh: "明显", en: "High", de: "Deutlich")
        default: l.tr(zh: "很强", en: "Very high", de: "Sehr stark")
        }
    }
}
