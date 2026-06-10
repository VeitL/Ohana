//
//  OverviewQuickActionPopovers.swift
//  Ohana
//
//  Lightweight popovers used by GoQuickActionCard.
//

import SwiftUI

// MARK: - Groom Popover (紧凑气泡弹出)
struct GroomPopoverContent: View {
    let onSelect: (String) -> Void
    var themeColor: Color = Color.goPrimary
    @Environment(\.dismiss) private var dismiss

    private struct GroomOption: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private let options: [GroomOption] = [
        GroomOption(id: "bath",     icon: "drop.fill",   label: "洗澡"),
        GroomOption(id: "teeth",    icon: "mouth.fill",  label: "刷牙"),
        GroomOption(id: "nails",    icon: "scissors",    label: "剪甲"),
        GroomOption(id: "brushing", icon: "comb.fill",   label: "梳毛"),
        GroomOption(id: "ears",     icon: "ear.fill",    label: "清耳"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(OhanaFont.adaptive(size: 24, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(themeColor)
                            .frame(width: 48, height: 48)
                        Text(LocalizedStringKey(opt.label))
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Potty Popover (便便类型选择气泡)
struct PottyPopoverContent: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct PottyOption: Identifiable {
        let id: String
        let icon: String
        let label: String
        let colorHex: String
    }

    private let options: [PottyOption] = [
        PottyOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill",                    label: "完美", colorHex: "8B6914"),
        PottyOption(id: PottyType.softPoop.rawValue,    icon: "circle.dashed",                label: "软便", colorHex: "F59E0B"),
        PottyOption(id: PottyType.liquidPoop.rawValue,  icon: "exclamationmark.triangle.fill", label: "水便", colorHex: "EF4444"),
        PottyOption(id: PottyType.pee.rawValue,         icon: "drop.fill",                    label: "尿尿", colorHex: "06B6D4"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(OhanaFont.adaptive(size: 24, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaFunctionalIcon)
                            .frame(width: 48, height: 48)
                        Text(LocalizedStringKey(opt.label))
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Health Popover (健康快速记录选项气泡)
struct HealthPopoverContent: View {
    let onSelect: (String) -> Void
    var petThemeColorHex: String? = nil
    @Environment(\.dismiss) private var dismiss

    private struct HealthOption: Identifiable {
        let id: String
        let icon: String
        let label: String
        let colorHex: String
    }

    private let options: [HealthOption] = [
        HealthOption(id: "symptom",    icon: "exclamationmark.triangle.fill", label: "症状",   colorHex: "EF4444"),
        HealthOption(id: "vaccine",    icon: "syringe.fill",                  label: "疫苗",   colorHex: "10B981"),
        HealthOption(id: "deworming",  icon: "pills.fill",                    label: "驱虫",   colorHex: "8B5CF6"),
        HealthOption(id: "visit",      icon: "stethoscope",                   label: "就诊",   colorHex: "F59E0B"),
        HealthOption(id: "heatCycle",  icon: "heart.circle.fill",            label: "生理期", colorHex: "EC4899"),
    ]

    private var themeColor: Color {
        petThemeColorHex.map { Color(hex: $0) } ?? Color.goPrimary
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(OhanaFont.adaptive(size: 24, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaFunctionalIcon)
                            .frame(width: 48, height: 48)
                        Text(opt.label)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
