//
//  QuickHumanExpenseSheet.swift
//  Ohana
//
//  V4 quick human expense popup.
//

import SwiftUI
import SwiftData

private struct QuickHumanExpenseContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct QuickHumanExpenseSheet: View {
    let human: Human
    var onSaved: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var adaptiveSheetHeight: CGFloat = 500
    @State private var contentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var popupDragOffset: CGFloat = 0

    private var l: L10n { L10n(appLanguage) }
    private var amount: Double? { CountryDecimalInput.parse(amountText, countryCode: appCountry) }
    private var isValid: Bool { (amount ?? 0) > 0 }
    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        GeometryReader { proxy in
            let minPanelHeight: CGFloat = 390
            let maxPanelHeight = max(minPanelHeight, proxy.size.height * 0.90)
            let scrollMaxHeight = max(230, maxPanelHeight - 142)
            let measuredHeight = contentHeight > 1 ? contentHeight : 320
            let scrollHeight = min(measuredHeight, scrollMaxHeight)
            let panelHeightEstimate = min(maxPanelHeight, max(adaptiveSheetHeight, minPanelHeight))
            let hiddenOffset = panelHeightEstimate + 72

            ZStack(alignment: .bottom) {
                popupBackdrop
                    .opacity(popupVisible ? 1 : 0)

                VStack(spacing: 0) {
                    popupDragHandle
                        .padding(.top, 4)
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            amountBlock
                            EmbeddedDecimalKeypad(
                                text: $amountText,
                                countryCode: appCountry,
                                maxFractionDigits: 2,
                                accent: Color.goPrimary,
                                isMini: true,
                                showsSubmitButton: false,
                                onSubmit: {
                                    if isValid { save() }
                                }
                            )
                            .padding(.horizontal, 22)
                            noteBlock
                            dateBlock
                        }
                        .padding(.bottom, 10)
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(
                                        key: QuickHumanExpenseContentHeightKey.self,
                                        value: contentProxy.size.height
                                    )
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(height: scrollHeight)

                    saveBar
                }
                .background { OhanaPopupGlassSurface(cornerRadius: 52) }
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .shadow(color: Color.black.opacity(0.56), radius: 48, x: 0, y: -18) // ui-v4: allow short popup liftedAlert shadow token
                .shadow(color: Color(hex: "0B102C").opacity(0.46), radius: 28, x: 0, y: 12) // ui-v4: allow short popup liftedAlert shadow token
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .offset(y: popupVisible ? popupDragOffset : hiddenOffset)
                .frame(maxHeight: maxPanelHeight, alignment: .bottom)
                .ohanaAdaptiveSheetContentHeight(
                    $adaptiveSheetHeight,
                    minHeight: minPanelHeight,
                    maxHeight: maxPanelHeight,
                    chromePadding: 18
                )
            }
        }
        .transition(.opacity)
        .allowsHitTesting(popupVisible && !isClosing)
        .animation(popupAnimation, value: popupVisible)
        .presentationBackground(.clear)
        .presentationDetents([.height(adaptiveSheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationContentInteraction(.scrolls)
        .onAppear {
            popupVisible = false
            isClosing = false
            DispatchQueue.main.async {
                withAnimation(popupAnimation) {
                    popupVisible = true
                }
            }
        }
        .onChange(of: amountText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(newValue, countryCode: appCountry, maxFractionDigits: 2)
            if sanitized != newValue {
                amountText = sanitized
            }
        }
        .onPreferenceChange(QuickHumanExpenseContentHeightKey.self) { height in
            guard height.isFinite, height > 0 else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                contentHeight = height
            }
        }
    }

    private var popupBackdrop: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.06), // ui-v4: allow short popup scrimGradient token
                Color.black.opacity(0.30) // ui-v4: allow short popup scrimGradient token
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { close() }
    }

    private var popupDragHandle: some View {
        OhanaPopupDragHandle()
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        popupDragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height > 70 || value.predictedEndTranslation.height > 130 {
                            close()
                        } else {
                            withAnimation(popupAnimation) { popupDragOffset = 0 }
                        }
                    }
            )
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.goPrimary.opacity(0.18))
                Image(systemName: AppCurrency.systemIconName)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "快速记账", en: "Quick Expense", de: "Schnelle Ausgabe"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(human.name)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            OhanaPopupCloseButton { close() }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "金额", en: "Amount", de: "Betrag"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(AppCurrency.symbol)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goPrimary)
                Text(amountText.isEmpty ? "0" : amountText)
                    .font(OhanaFont.metric(size: 44))
                    .foregroundStyle(amountText.isEmpty ? Color.ohanaTertiaryText : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
        .padding(.horizontal, 22)
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(l.tr(zh: "例如：咖啡、药品、交通", en: "Coffee, meds, transit", de: "Kaffee, Medikamente, Fahrt"), text: $note)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
        }
        .padding(.horizontal, 22)
    }

    private var dateBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(l.tr(zh: "日期", en: "Date", de: "Datum"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 22)
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .black))
                Text(l.tr(zh: "保存花费", en: "Save Expense", de: "Ausgabe speichern"))
                    .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isValid ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isValid)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(popupAnimation) {
            popupVisible = false
            popupDragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if let onDismiss {
                onDismiss()
            } else {
                dismiss()
            }
        }
    }

    @MainActor
    private func save() {
        guard let amount, amount > 0 else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = PetExpenseLog(
            date: date,
            amount: amount,
            category: .other,
            note: cleanNote,
            pet: nil,
            executorId: human.id.uuidString
        )
        modelContext.insert(log)
        modelContext.safeSave()

        let reward = QuestManager.shared.awardAction(type: .expense, pet: nil, context: modelContext)
        CareLedgerService.record(
            occurredAt: date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .human,
            subjectId: human.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.other.rawValue,
            amountValue: amount,
            amountUnit: "currency",
            note: cleanNote,
            source: .quickAction,
            legacyModelName: "PetExpenseLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            privacyFieldRaw: HumanPrivateField.expense.rawValue,
            context: modelContext
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSaved?()
        close()
    }
}
