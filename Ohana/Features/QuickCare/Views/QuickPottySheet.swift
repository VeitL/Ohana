//
//  QuickPottySheet.swift
//  Ohana
//
//  B67: 噗噗快捷打卡半屏 Sheet
//

import SwiftData
import SwiftUI

struct QuickPottySheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var selectedType: PottyType = .perfectPoop
    @State private var date = Date()
    @State private var isSaving = false

    private var l: L10n { L10n(appLanguage) }
    private var commandExecutor: QuickPottyCommandExecutor {
        QuickPottyCommandExecutor(
            context: modelContext,
            careEvents: appServices.careEvents,
            revisions: appServices.domainRevisions
        )
    }

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
                        Image(systemName: "xmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20)

                // 执行人胶囊
                HStack {
                    QuickCareExecutorPickerBarContainer(tint: Color.goYellow)
                    Spacer()
                }
                .padding(.horizontal, 20)

                // 类型选择
                HStack(spacing: 12) {
                    ForEach(PottyType.allCases, id: \.rawValue) { type in
                        Button { selectedType = type } label: {
                            VStack(spacing: 8) {
                                Text(type.emoji).font(OhanaFont.adaptive(size: 32)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                Text(type.localizedLabel(l))
                                    .font(OhanaFont.caption(.bold))
                                    .foregroundStyle(selectedType == type ? Color.arkInk : .primary.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(selectedType == type ? Color.goYellow : .white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
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
                        Text(selectedType.emoji).font(OhanaFont.adaptive(size: 16)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text(l.tr(zh: "记录 \(selectedType.localizedLabel(l))", en: "Log \(selectedType.localizedLabel(l))", de: "\(selectedType.localizedLabel(l)) loggen"))
                            .font(OhanaFont.headline(.black))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isSaving ? Color.goYellow.opacity(0.72) : Color.goYellow, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSaving)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onDisappear {
            isSaving = false
            commandQueue.cancelAll()
        }
    }

    private func savePotty() {
        guard !isSaving else { return }
        let eid = appServices.activeHumanSelection.currentHumanId
        let isLitter = ["猫", "兔子", "仓鼠", "龙猫", "豚鼠"].contains(pet.species)
        let action = isLitter ? CareType.litter.rawValue : selectedType.rawValue
        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(.quickCare(entityID: pet.id, action: action)) {
            let result = commandExecutor.record(
                petID: pet.id,
                selectedType: selectedType,
                isLitter: isLitter,
                executorId: eid,
                date: date
            )
            isSaving = false
            guard result != nil else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}
