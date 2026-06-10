//
//  QuickWeightSheet.swift
//  Ohana
//
//  Quick Access 快速添加体重弹窗
//

import SwiftUI
import SwiftData

struct QuickWeightSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices

    @State private var weightText: String = ""
    @State private var recordDate: Date = Date()
    @State private var didSave = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @AppStorage("currentActiveHumanId") private var activeHumanIdRaw = ""

    private var parsedWeight: Double? { CountryDecimalInput.parse(weightText, countryCode: AppCountry.code) }
    private var isValid: Bool {
        guard let v = parsedWeight, v > 0, v < 200 else { return false }
        return true
    }

    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }

    var body: some View {
        VStack(spacing: 0) {
                // ── 顶栏
                HStack {
                    // 宠物头像 + 名字
                    HStack(spacing: 10) {
                        PetAvatarPortraitView(
                            imageData: pet.avatarImageData,
                            fallbackText: pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji,
                            themeColor: themeColor,
                            size: 40,
                            backgroundOpacity: 0.22
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pet.name)
                                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text("记录体重")
                                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

                // ── 体重大数字输入卡
                InlineNumericInput(
                    text: $weightText,
                    placeholder: CountryDecimalInput.placeholder(countryCode: AppCountry.code),
                    unit: "kg",
                    maxFractionDigits: 1,
                    accent: themeColor,
                    step: 0.1,
                    valueFont: .system(size: 58, weight: .black, design: .rounded),
                    unitFont: .system(size: 24, weight: .black, design: .rounded),
                    fill: Color.ohanaCardSurfaceElevated,
                    cornerRadius: 28,
                    horizontalPadding: 18,
                    verticalPadding: 18
                )
                .padding(.horizontal, 20)

                // ── 上次体重提示
                if let last = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                        Text("上次记录：\(last.weight, specifier: "%.1f") kg")
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                    .padding(.top, 10)
                }

                Spacer(minLength: 20)

                // ── 日期选择
                HStack(spacing: 10) {
                    Image(systemName: "calendar").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    Text("记录日期")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                    Spacer()
                    DatePicker("", selection: $recordDate, in: ...Date(), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(themeColor)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .goGlassBackground(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)

                // ── 保存按钮
                Button { saveWeight() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: didSave ? "checkmark.circle.fill" : "scalemass.fill")
                            .font(OhanaFont.adaptive(size: 16, weight: .bold))
                        Text(didSave ? "已保存 ✓" : "保存记录")
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        didSave ? Color.goTeal : (isValid ? themeColor : themeColor.opacity(0.35)),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                }
                .disabled(!isValid || didSave)
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
        .background(Color.ohanaCardSurface)
        .presentationBackground(.clear)
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private func saveWeight() {
        guard let v = parsedWeight, v > 0 else { return }
        let executorId = activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
        let command = DomainCommand.quickWeight(petID: pet.id)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        didSave = true
        commandQueue.enqueue(command) {
            DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordPetWeight(
                pet: pet,
                weight: v,
                date: recordDate,
                executorId: executorId,
                command: command,
                note: "quick.weight"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        }
    }
}
