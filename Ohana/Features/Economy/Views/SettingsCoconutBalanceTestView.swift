//
//  SettingsCoconutBalanceTestView.swift
//  Ohana
//
//  Developer coconut balance test tool split out of SettingsView.
//

import SwiftData
import SwiftUI

struct CoconutBalanceTestContentView: View {
    let humans: [Human]
    let walletAccounts: [CoconutAccount]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @State private var selectedHumanId = ""
    @State private var amountText = ""
    @State private var message = ""
    @State private var isApplying = false
    @State private var selectionSyncTask: Task<Void, Never>?

    private var l: L10n { L10n(appLanguage) }

    private var selectedHuman: Human? {
        humans.first { $0.id.uuidString == selectedHumanId }
    }

    private var currentDisplayAmount: Int {
        if let selectedHuman {
            return displayAmount(for: selectedHuman)
        }
        return walletAccounts.reduce(0) { $0 + $1.balance }
    }

    private var parsedAmount: Int {
        max(0, Int(amountText.filter(\.isNumber)) ?? 0)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    currentBalancePanel
                    memberPicker
                    amountPanel
                    quickPresets
                    applyButton

                    if !message.isEmpty {
                        Text(message)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .accessibilityIdentifier("coconut-balance-result-message")
                    }

                    Text(l.tr(
                        zh: "测试工具会把所选成员余额和旧版全岛兼容总数同步到同一个值，便于验证商店、财富页和首页椰子显示。",
                        en: "This test tool syncs the selected member balance and legacy island total to the same value so shop, wealth, and home displays are easy to verify.",
                        de: "Dieses Testwerkzeug setzt Mitgliedskonto und alten Insel-Gesamtwert auf denselben Wert, damit Shop, Vermögen und Startseite leicht prüfbar sind."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 42)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("coconut-balance-test-screen")
        .onAppear(perform: configureInitialSelection)
        .onDisappear {
            selectionSyncTask?.cancel()
            selectionSyncTask = nil
        }
        .onChange(of: selectedHumanId) { _, newValue in
            scheduleSelectionSync(for: newValue)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "椰子数量测试", en: "Coconut balance test", de: "Kokosnuss-Teststand"))
                    .font(OhanaFont.largeTitle(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "开发者工具", en: "Developer tool", de: "Entwicklerwerkzeug"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("coconut-balance-close-action")
        }
    }

    private var currentBalancePanel: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 22, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 48, height: 48)
                .background(Color.goYellow.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(selectedHuman))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "当前余额", en: "Current balance", de: "Aktueller Stand"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text("\(currentDisplayAmount)🥥")
                .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .contentTransition(.numericText())
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .animation(GoMotion.feedback, value: currentDisplayAmount)
    }

    @ViewBuilder
    private var memberPicker: some View {
        if humans.isEmpty {
            emptyStateRow(
                icon: "person.crop.circle.badge.exclamationmark",
                title: l.tr(zh: "还没有人类成员", en: "No human members yet", de: "Noch keine Menschen"),
                subtitle: l.tr(zh: "现在只会修改旧版全岛兼容总数。", en: "Only the legacy island total will be changed.", de: "Nur der alte Insel-Gesamtwert wird geändert.")
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(l.tr(zh: "选择成员", en: "Choose member", de: "Mitglied wählen"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(humans) { human in
                            memberChip(human)
                        }
                    }
                }
            }
        }
    }

    private var amountPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "目标数量", en: "Target amount", de: "Zielbetrag"))
            InlineNumericInput(
                text: $amountText,
                placeholder: "0",
                unit: "🥥",
                maxFractionDigits: 0,
                accent: Color.goYellow,
                step: 50,
                valueFont: .system(size: 44, weight: .black, design: .rounded),
                unitFont: .system(size: 28, weight: .black),
                fill: Color.ohanaControlFill,
                cornerRadius: OhanaRadius.cardSoft,
                horizontalPadding: 16,
                verticalPadding: 12
            )
        }
    }

    private var quickPresets: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "快速设置", en: "Quick presets", de: "Schnellwerte"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach([0, 100, 500, 1000, 5000, 10000, 50000, 100_000], id: \.self) { value in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            amountText = "\(value)"
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text("\(value)🥥")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("coconut-balance-preset-\(value)")
                }
            }
        }
    }

    private var applyButton: some View {
        Button {
            applyAmount()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                Text(l.tr(zh: "应用测试数量", en: "Apply test balance", de: "Testwert anwenden"))
            }
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isApplying)
        .opacity(isApplying ? 0.72 : 1)
        .accessibilityIdentifier("coconut-balance-apply-action")
    }

    private func memberChip(_ human: Human) -> some View {
        let selected = human.id.uuidString == selectedHumanId
        return Button {
            selectedHumanId = human.id.uuidString
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 8) {
                avatar(for: human)
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName(human))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text("\(displayAmount(for: human))🥥")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(selected ? Color.ohanaPrimaryActionText.opacity(0.72) : Color.ohanaSecondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func avatar(for human: Human) -> some View {
        HumanAvatarPipelineView(
            human: human,
            size: 30,
            fallbackScale: 0.53,
            backgroundOpacity: 0.18
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .tracking(1.1)
    }

    private func emptyStateRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func configureInitialSelection() {
        if selectedHumanId.isEmpty {
            selectedHumanId = humans.first(where: { $0.id.uuidString == currentActiveHumanId })?.id.uuidString
                ?? humans.first?.id.uuidString
                ?? ""
        }
        amountText = "\(currentDisplayAmount)"
    }

    private func scheduleSelectionSync(for humanId: String) {
        selectionSyncTask?.cancel()
        selectionSyncTask = OhanaFrameScheduler.runAfterNextFrame {
            guard selectedHumanId == humanId else { return }
            amountText = "\(currentDisplayAmount)"
            message = ""
            selectionSyncTask = nil
        }
    }

    private func applyAmount() {
        guard !isApplying else { return }
        let amount = parsedAmount
        let human = selectedHuman
        let actorName = human.map { displayName($0) }
        isApplying = true

        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            let result = SettingsCommandExecutor(context: modelContext, services: appServices).applyCoconutBalanceTest(
                amount: amount,
                human: human,
                title: l.tr(zh: "测试调整椰子数量", en: "Test coconut balance adjustment", de: "Testanpassung Kokosnüsse"),
                actorName: actorName,
                note: "settings.coconut.test"
            )

            withAnimation(GoMotion.feedback) {
                amountText = "\(result.amount)"
                message = l.tr(
                    zh: "已设置为 \(result.amount)🥥",
                    en: "Set to \(result.amount)🥥",
                    de: "Auf \(result.amount)🥥 gesetzt"
                )
            }
            isApplying = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func displayName(_ human: Human?) -> String {
        guard let human else {
            return l.tr(zh: "全岛兼容总数", en: "Legacy island total", de: "Alter Insel-Gesamtwert")
        }
        let trimmed = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? l.tr(zh: "成员", en: "Member", de: "Mitglied") : trimmed
    }

    private func displayAmount(for human: Human) -> Int {
        walletAccounts.first { $0.ownerKind == .human && $0.ownerId == human.id.uuidString }?.balance
            ?? human.coconutBalance
    }
}
