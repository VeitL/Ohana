//
//  HumanHealthMetricEntrySheet.swift
//  Ohana
//
//  Inline popup for one human checkup metric value.
//

import SwiftData
import SwiftUI

private struct HealthMetricEntryScrollHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HumanHealthMetricEntrySheet: View {
    let human: Human
    let metric: HealthMetric
    var initialUnitCode: String
    var onSaved: ((HumanHealthMetricLog) -> Void)?
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var valueText = ""
    @State private var selectedUnitCode: String
    @State private var selectedDate = Date()
    @State private var includesRecordTime = false
    @State private var notes = ""
    @State private var selectedRecorderID: UUID?
    @State private var requiresRecorderSelection = false
    @State private var adaptiveSheetHeight: CGFloat = 520
    @State private var scrollContentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var isSaving = false
    @State private var popupDragOffset: CGFloat = 0
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(
        human: Human,
        metric: HealthMetric,
        initialUnitCode: String,
        onSaved: ((HumanHealthMetricLog) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.human = human
        self.metric = metric
        self.initialUnitCode = initialUnitCode
        self.onSaved = onSaved
        self.onDismiss = onDismiss
        _selectedUnitCode = State(initialValue: initialUnitCode)
    }

    private var l: L10n { L10n(appLanguage) }
    private var tint: Color { metric.category.color }

    private var selectedUnit: HealthMetricUnit {
        metric.unit(for: selectedUnitCode) ?? metric.defaultUnit(for: appCountry)
    }

    private var parsedValue: Double? {
        CountryDecimalInput.parse(valueText, countryCode: appCountry)
    }

    private var isValid: Bool {
        guard let parsedValue else { return false }
        return parsedValue > 0 && parsedValue.isFinite
    }

    private var inputFractionDigits: Int {
        let high = selectedUnit.normalHigh ?? 100
        if high <= 10 { return 3 }
        if high <= 100 { return 2 }
        return 1
    }

    private var recordDate: Date {
        let date = includesRecordTime ? selectedDate : Calendar.current.startOfDay(for: selectedDate)
        return min(date, Date())
    }

    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(metric.displayName(l))
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    valueBlock
                    EmbeddedDecimalKeypad(
                        text: $valueText,
                        countryCode: appCountry,
                        maxFractionDigits: inputFractionDigits,
                        accent: tint,
                        isMini: true,
                        showsSubmitButton: false,
                        onSubmit: {
                            if isValid { save() }
                        }
                    )
                    .padding(.horizontal, 20)
                    unitStrip
                    dateAndNotesBlock
                    QuickCareActionHumanPickerContainer(
                        selectedHumanID: $selectedRecorderID,
                        requiresSelection: $requiresRecorderSelection,
                        role: .recorder,
                        tint: tint
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    referenceBlock
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(l.tr(zh: "记录指标", en: "Record metric", de: "Wert erfassen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { close() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { save() }
                        .disabled(!isValid || isSaving || requiresRecorderSelection)
                        .accessibilityIdentifier("human-health-metric-entry-save-action")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .onAppear {
            selectedUnitCode = metric.unit(for: selectedUnitCode)?.code ?? metric.defaultUnit(for: appCountry).code
        }
        .onChange(of: valueText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(
                newValue,
                countryCode: appCountry,
                maxFractionDigits: inputFractionDigits
            )
            if sanitized != newValue {
                valueText = sanitized
            }
        }
        .onChange(of: selectedUnitCode) { _, _ in
            valueText = CountryDecimalInput.sanitize(
                valueText,
                countryCode: appCountry,
                maxFractionDigits: inputFractionDigits
            )
        }
        .onDisappear {
            commandQueue.cancelAll()
        }
    }

    private var popupBackdrop: some View {
        ZStack {
            Color.black.opacity(0.14) // ui-v4: allow inline popup scrim
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.22) // ui-v4: allow inline popup scrim gradient
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { close() }
    }

    private var popupDragHandle: some View {
        OhanaPopupDragHandle()
            .gesture(popupHandleDragGesture)
    }

    private var popupHandleDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                popupDragOffset = value.translation.height
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 56 || value.predictedEndTranslation.height > 108
                if shouldDismiss {
                    close()
                } else {
                    withAnimation(GoMotion.feedback) {
                        popupDragOffset = 0
                    }
                }
            }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: metric.category.systemImage)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "记录指标", en: "Record metric", de: "Wert erfassen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .accessibilityIdentifier("human-health-metric-entry-sheet-\(metric.key)")
                Text(metric.displayName(l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { close() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "number").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                Text(metric.displayName(l))
                    .font(OhanaFont.caption(.bold))
                Spacer()
                Text(l.tr(
                    zh: "小数 \(CountryDecimalInput.decimalSeparator(for: appCountry))",
                    en: "Decimal \(CountryDecimalInput.decimalSeparator(for: appCountry))",
                    de: "Dezimal \(CountryDecimalInput.decimalSeparator(for: appCountry))"
                ))
                .font(OhanaFont.caption2(.bold))
            }
            .foregroundStyle(Color.ohanaTertiaryText)
            .padding(.horizontal, 20)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(valueText.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: inputFractionDigits, countryCode: appCountry) : valueText)
                    .font(OhanaFont.metric(size: 52, .black))
                    .foregroundStyle(valueText.isEmpty ? Color.ohanaTertiaryText : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("human-health-metric-entry-value")

                Text(selectedUnit.label)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var unitStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metric.units) { unit in
                    let selected = unit.code == selectedUnit.code
                    Button {
                        withAnimation(GoMotion.feedback) {
                            selectedUnitCode = unit.code
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(unit.label)
                                .font(OhanaFont.subheadline(.black))
                            Text(unit.normalRangeLabel(includeUnit: false))
                                .font(OhanaFont.caption2(.bold))
                                .opacity(0.74)
                        }
                        .foregroundStyle(selected ? Color.arkInk : Color.ohanaPrimaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 96, alignment: .leading)
                        .goSelectableSurface(isSelected: selected, tint: tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var dateAndNotesBlock: some View {
        VStack(spacing: 10) {
            infoRow(icon: "calendar", label: l.tr(zh: "日期", en: "Date", de: "Datum")) {
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(tint)
                    .labelsHidden()
                    .environment(\.locale, AppLanguage.effectiveLocale)
            }

            infoRow(icon: "clock", label: l.tr(zh: "时间", en: "Time", de: "Zeit")) {
                HStack(spacing: 8) {
                    if includesRecordTime {
                        DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .tint(tint)
                            .labelsHidden()
                            .environment(\.locale, AppLanguage.effectiveLocale)
                    } else {
                        Text(l.tr(zh: "可选", en: "Optional", de: "Optional"))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Toggle("", isOn: $includesRecordTime.animation(GoMotion.feedback))
                        .labelsHidden()
                        .tint(tint)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                }
                TextField(l.tr(zh: "医院、空腹状态或报告说明", en: "Lab, fasting state, or report note", de: "Labor, nüchtern oder Berichtshinweis"), text: $notes, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2 ... 4)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("human-health-metric-entry-notes-input")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var referenceBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "target").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "参考范围", en: "Reference range", de: "Referenzbereich"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                Text(selectedUnit.normalRangeLabel())
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold))
                Text(isSaving
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : l.tr(zh: "保存指标", en: "Save metric", de: "Wert speichern")
                )
                .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .padding(.vertical, 14)
            .background(isValid && !isSaving ? Color.goPrimary : Color.goPrimary.opacity(0.38), in: Capsule())
            .opacity(isValid && !isSaving ? 1 : 0.62)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isValid || isSaving || requiresRecorderSelection)
        .accessibilityIdentifier("human-health-metric-entry-save-action")
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func infoRow(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(label)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .padding(.horizontal, 20)
    }

    @MainActor
    private func save() {
        guard !isSaving,
              !requiresRecorderSelection,
              let value = parsedValue,
              value > 0,
              value.isFinite else { return }
        isSaving = true
        let savedUnitCode = selectedUnit.code
        let savedDate = recordDate
        let savedNotes = notes
        let savedRecorderID = selectedRecorderID?.uuidString
        let command = DomainCommand.humanHealthMetric(humanID: human.id, metricKey: metric.key)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            guard let result = HumanCareCommandExecutor(context: modelContext, services: appServices).recordHealthMetric(
                human: human,
                metricKey: metric.key,
                unitCode: savedUnitCode,
                value: value,
                date: savedDate,
                notes: savedNotes,
                recordedByHumanId: savedRecorderID,
                note: "human.health.metric"
            ) else {
                isSaving = false
                return
            }
            onSaved?(result.log)
            close()
        }
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        onDismiss()
    }
}
