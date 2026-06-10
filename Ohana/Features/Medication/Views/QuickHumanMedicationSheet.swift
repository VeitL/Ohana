//
//  QuickHumanMedicationSheet.swift
//  Ohana
//
//  Lightweight inline popup for adding a human medication plan.
//

import SwiftData
import SwiftUI

private struct QuickHumanMedicationHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum QuickHumanMedicationForm: String, CaseIterable, Identifiable {
    case tablet
    case liquid
    case powder
    case injection

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .tablet:
            l.tr(zh: "片剂", en: "Tablet", de: "Tablette")
        case .liquid:
            l.tr(zh: "液体", en: "Liquid", de: "Flüssig")
        case .powder:
            l.tr(zh: "粉剂", en: "Powder", de: "Pulver")
        case .injection:
            l.tr(zh: "注射", en: "Injection", de: "Injektion")
        }
    }

    var units: [String] {
        switch self {
        case .tablet:
            ["片", "粒", "mg"]
        case .liquid:
            ["ml", "滴"]
        case .powder:
            ["mg", "g", "勺"]
        case .injection:
            ["ml", "IU"]
        }
    }

    var icon: String {
        switch self {
        case .tablet: "pills.fill"
        case .liquid: "drop.fill"
        case .powder: "sparkles"
        case .injection: "syringe.fill"
        }
    }
}

private enum HumanMedicationQuickCatalog {
    static func names(for countryCode: String) -> [String] {
        switch AppCountry.normalize(countryCode) {
        case "US", "GB":
            ["Ibuprofen", "Acetaminophen", "Vitamin D", "Cetirizine", "Melatonin", "Omeprazole"]
        case "DE":
            ["Ibuprofen", "Paracetamol", "Vitamin D", "Cetirizin", "Magnesium", "Omeprazol"]
        case "JP":
            ["イブプロフェン", "アセトアミノフェン", "ビタミンD", "ロキソニン", "葛根湯", "整腸剤"]
        case "HK", "TW":
            ["布洛芬", "乙酰氨基酚", "維生素D", "益生菌", "褪黑素", "抗敏感藥"]
        default:
            ["布洛芬", "对乙酰氨基酚", "维生素D", "益生菌", "褪黑素", "抗过敏药"]
        }
    }
}

struct QuickHumanMedicationSheet: View {
    let human: Human
    var onSaved: (() -> Void)?
    var onManage: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var medicationName = ""
    @State private var form: QuickHumanMedicationForm = .tablet
    @State private var doseAmount = "1"
    @State private var doseUnit = "片"
    @State private var reminderEnabled = true
    @State private var frequency: MedicationFrequency = .daily
    @State private var firstDoseTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var adaptiveSheetHeight: CGFloat = 540
    @State private var contentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var isSaving = false
    @State private var popupDragOffset: CGFloat = 0
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var canSave: Bool { !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var composedDosage: String {
        let amount = doseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !amount.isEmpty else { return "" }
        return "\(amount) \(doseUnit)"
    }

    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        GeometryReader { proxy in
            let minPanelHeight: CGFloat = 470
            let maxPanelHeight = max(minPanelHeight, proxy.size.height * 0.90)
            let scrollMaxHeight = max(290, maxPanelHeight - 142)
            let measuredHeight = contentHeight > 1 ? contentHeight : 380
            let scrollHeight = min(measuredHeight, scrollMaxHeight)
            let panelHeightEstimate = min(maxPanelHeight, max(adaptiveSheetHeight, minPanelHeight))
            let hiddenOffset = panelHeightEstimate + 72

            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: popupVisible) {
                popupBackdrop
                    .opacity(popupVisible ? 1 : 0)

                VStack(spacing: 0) {
                    popupDragHandle
                        .padding(.top, 4)
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            nameBlock
                            formAndDoseBlock
                            reminderBlock
                            noteBlock
                        }
                        .padding(.bottom, 10)
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(key: QuickHumanMedicationHeightKey.self, value: contentProxy.size.height)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .frame(height: scrollHeight)

                    saveBar
                }
                .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.inlinePopup) }
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.inlinePopup, style: .continuous))
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
        .onChange(of: form) { _, newValue in
            if !newValue.units.contains(doseUnit) {
                doseUnit = newValue.units[0]
            }
        }
        .onPreferenceChange(QuickHumanMedicationHeightKey.self) { height in
            guard height.isFinite, height > 0 else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                contentHeight = height
            }
        }
        .onDisappear {
            commandQueue.cancelAll()
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
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(Color.goPrimary.opacity(0.18))
                Image(systemName: "pill.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 19, weight: .black))
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "添加药物", en: "Add Medication", de: "Medikament hinzufügen"))
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

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "药品名称", en: "Medication name", de: "Medikamentenname"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(l.tr(zh: "例如：维生素 D", en: "e.g. Vitamin D", de: "z. B. Vitamin D"), text: $medicationName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.body(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HumanMedicationQuickCatalog.names(for: appCountry), id: \.self) { option in
                        Button {
                            withAnimation(GoMotion.feedback) { medicationName = option }
                        } label: {
                            Text(option)
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(medicationName == option ? Color.arkInk : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(medicationName == option ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private var formAndDoseBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "剂型与剂量", en: "Form and dose", de: "Form und Dosis"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)

            HStack(spacing: 8) {
                ForEach(QuickHumanMedicationForm.allCases) { item in
                    Button {
                        withAnimation(GoMotion.feedback) { form = item }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(OhanaFont.adaptive(size: 14, weight: .black))
                            Text(item.title(l))
                                .font(OhanaFont.caption2(.black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(form == item ? Color.arkInk : Color.ohanaPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(form == item ? Color.goPrimary : Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            HStack(spacing: 10) {
                InlineNumericInput(
                    text: $doseAmount,
                    placeholder: "1",
                    maxFractionDigits: 2,
                    accent: Color.goPrimary,
                    step: 0.5,
                    valueFont: OhanaFont.title3(.black),
                    fill: Color.ohanaCardSurface,
                    cornerRadius: OhanaRadius.controlLarge,
                    horizontalPadding: 8,
                    verticalPadding: 8
                )
                .frame(width: 98)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(form.units, id: \.self) { unit in
                            Button {
                                withAnimation(GoMotion.feedback) { doseUnit = unit }
                            } label: {
                                Text(unit)
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(doseUnit == unit ? Color.arkInk : Color.ohanaPrimaryText)
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .background(doseUnit == unit ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private var reminderBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $reminderEnabled.animation(GoMotion.feedback)) {
                Label(l.tr(zh: "添加提醒", en: "Add reminder", de: "Erinnerung hinzufügen"), systemImage: "bell.badge.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .tint(Color.goPrimary)

            if reminderEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([MedicationFrequency.daily, .twiceDaily, .threeTimesDaily, .weekly], id: \.self) { option in
                            Button {
                                withAnimation(GoMotion.feedback) { frequency = option }
                            } label: {
                                Text(option.displayTitle(l: l))
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(frequency == option ? Color.arkInk : Color.ohanaPrimaryText)
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .background(frequency == option ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }

                HStack {
                    Label(l.tr(zh: "首次时间", en: "First dose", de: "Erste Einnahme"), systemImage: "clock.fill")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    DatePicker("", selection: $firstDoseTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .padding(.horizontal, 22)
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "备注（可选）", en: "Note (optional)", de: "Notiz (optional)"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(l.tr(zh: "例如：饭后、睡前", en: "After meal, before bed", de: "Nach dem Essen, vor dem Schlafen"), text: $notes) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        }
        .padding(.horizontal, 22)
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                Text(isSaving
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : l.tr(zh: "保存药物", en: "Save Medication", de: "Medikament speichern")
                )
                .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canSave && !isSaving ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSave || isSaving)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    @MainActor
    private func save() {
        let cleanedName = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSaving, !cleanedName.isEmpty else { return }
        isSaving = true

        let selectedFrequency = reminderEnabled ? frequency : MedicationFrequency.asNeeded
        let minute = HumanMedicationSchedulePlan.minuteOfDay(from: firstDoseTime)
        let metadata = reminderEnabled
            ? HumanMedicationScheduleMetadata(
                doseMinutes: doseMinutes(for: selectedFrequency, firstMinute: minute),
                weeklyWeekday: selectedFrequency == .weekly ? Calendar.current.component(.weekday, from: startDate) : nil
            )
            : nil
        let savedNotes = HumanMedicationScheduleMetadata.composeNotes(visibleNotes: notes, metadata: metadata)
        let savedDosage = composedDosage
        let savedFirstDoseTime = firstDoseTime
        let savedStartDate = startDate
        let shouldScheduleReminders = reminderEnabled
        let command = DomainCommand.quickHumanMedication(humanID: human.id)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        commandQueue.enqueue(command) {
            guard HumanCareCommandExecutor(context: modelContext, services: appServices).createQuickMedication(
                human: human,
                name: cleanedName,
                dosage: savedDosage,
                frequency: selectedFrequency,
                firstDoseTime: savedFirstDoseTime,
                startDate: savedStartDate,
                colorHex: "FF6B8A",
                notes: savedNotes,
                reminderEnabled: shouldScheduleReminders,
                note: "quick.human.medication"
            ) != nil else {
                isSaving = false
                return
            }
            onSaved?()
            close()
        }
    }

    private func doseMinutes(for frequency: MedicationFrequency, firstMinute: Int) -> [Int] {
        switch frequency {
        case .daily, .weekly:
            [firstMinute]
        case .twiceDaily:
            HumanMedicationScheduleMetadata.normalizedDoseMinutes([firstMinute, firstMinute + 12 * 60])
        case .threeTimesDaily:
            HumanMedicationScheduleMetadata.normalizedDoseMinutes([firstMinute, firstMinute + 6 * 60, firstMinute + 12 * 60])
        case .asNeeded, .custom:
            []
        }
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(popupAnimation) {
            popupVisible = false
            popupDragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss?()
        }
    }
}
