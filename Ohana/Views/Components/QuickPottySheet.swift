//
//  QuickPottySheet.swift
//  Ohana
//
//  B67: 噗噗快捷打卡半屏 Sheet
//

import SwiftUI
import SwiftData

struct QuickPottySheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @State private var selectedType: PottyType = .perfectPoop
    @State private var date = Date()

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 24) {
                // 标题
                HStack {
                    Text(l.tr(zh: "噗噗打卡", en: "Poop check-in", de: "Häufchen-Check-in"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20)

                // 执行人胶囊
                HStack {
                    ExecutorPickerBar(tint: Color.goYellow)
                    Spacer()
                }
                .padding(.horizontal, 20)

                // 类型选择
                HStack(spacing: 12) {
                    ForEach(PottyType.allCases, id: \.rawValue) { type in
                        Button { selectedType = type } label: {
                            VStack(spacing: 8) {
                                Text(type.emoji).font(.system(size: 32))
                                Text(type.localizedLabel(l))
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(selectedType == type ? Color.arkInk : .primary.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(selectedType == type ? Color.goYellow : .white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selectedType == type ? Color.goYellow.opacity(0.6) : .white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)

                // 时间选择
                UltimateGlassCard {
                    HStack {
                        Text(l.tr(zh: "记录时间", en: "Log time", de: "Zeit"))
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .tint(Color.goYellow)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .padding(.horizontal, 20)

                // 记录按钮
                Button { savePotty() } label: {
                    HStack(spacing: 8) {
                        Text(selectedType.emoji).font(.system(size: 16))
                        Text(l.tr(zh: "记录 \(selectedType.localizedLabel(l))", en: "Log \(selectedType.localizedLabel(l))", de: "\(selectedType.localizedLabel(l)) loggen"))
                            .font(OhanaFont.headline(.black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goYellow, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func savePotty() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let isLitter = ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
        if isLitter {
            CareEventService.recordCare(pet: pet, type: .litter, context: modelContext, executorId: eid, reward: .potty(isLitter: true), date: date)
        } else {
            CareEventService.recordPotty(pet: pet, type: selectedType, context: modelContext, executorId: eid, date: date)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
