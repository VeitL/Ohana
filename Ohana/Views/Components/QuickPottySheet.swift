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

    @State private var selectedType: PottyType = .perfectPoop
    @State private var date = Date()

    var body: some View {
        ZStack {
            ArkBackgroundView()
            VStack(spacing: 24) {
                // 标题
                HStack {
                    Text("噗噗打卡")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20)

                // 类型选择
                HStack(spacing: 12) {
                    ForEach(PottyType.allCases, id: \.rawValue) { type in
                        Button { selectedType = type } label: {
                            VStack(spacing: 8) {
                                Text(type.emoji).font(.system(size: 32))
                                Text(type.rawValue)
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(selectedType == type ? Color.arkInk : .primary.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(selectedType == type ? Color.goYellow : .white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selectedType == type ? Color.goYellow.opacity(0.6) : .white.opacity(0.1), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                // 时间选择
                UltimateGlassCard {
                    HStack {
                        Text("记录时间")
                            .font(OhanaFont.footnote(.bold))
                            .foregroundStyle(.primary.opacity(0.4))
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
                        Text("记录 \(selectedType.rawValue)")
                            .font(OhanaFont.headline(.black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goYellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func savePotty() {
        let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
        let isLitter = ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
        if isLitter {
            let log = PetCareLog(date: date, type: .litter, pet: pet, executorId: eid)
            modelContext.insert(log)
        } else {
            let log = PetPottyLog(date: date, type: selectedType, pet: pet, executorId: eid)
            modelContext.insert(log)
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        QuestManager.shared.awardAction(type: .potty(isLitter: isLitter), pet: pet, context: modelContext)
        dismiss()
    }
}
