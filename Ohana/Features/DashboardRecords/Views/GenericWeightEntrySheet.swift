//
//  GenericWeightEntrySheet.swift
//  Ohana
//
//  Locale-aware weight entry sheet for pets and humans.
//

import SwiftData
import SwiftUI

private struct WeightEntryScrollHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct GenericWeightEntrySheet: View {
    enum Target {
        case pet(Pet)
        case human(Human)
    }

    let target: Target
    var petLedgerSource: CareLedgerSource = .detail
    var onSaved: (() -> Void)?
    var onRewarded: ((Int) -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var selectedRecorderHumanID: UUID?
    @State private var requiresRecorderSelection = false
    @State private var includesRecordTime = false
    @State private var weightUnit: String = "kg"
    @State private var adaptiveSheetHeight: CGFloat = 500
    @State private var scrollContentHeight: CGFloat = 0
    @State private var popupVisible = true
    @State private var isClosing = false
    @State private var isSaving = false
    @State private var popupDragOffset: CGFloat = 0
    @State private var latestPetWeightKg: Double?
    @State private var latestPetWeightLoadTask: Task<Void, Never>?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }

    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    private var accentColor: Color {
        Color.goPrimary
    }

    private var identityColor: Color {
        switch target {
        case let .pet(pet): Color(hex: pet.safeThemeColorHex)
        case .human: Color.goPrimary
        }
    }

    private var entityName: String {
        switch target {
        case let .pet(pet): pet.name
        case let .human(human): human.name
        }
    }

    private var parsedWeight: Double? {
        CountryDecimalInput.parse(weightText, countryCode: appCountry)
    }

    private var isValid: Bool {
        (parsedWeight ?? 0) > 0
    }

    private var recordDate: Date {
        let date = includesRecordTime ? selectedDate : Calendar.current.startOfDay(for: selectedDate)
        return min(date, Date())
    }

    private var weightInKgForBcs: Double? {
        guard let weight = parsedWeight, weight > 0 else { return nil }
        return weightUnit == "g" ? weight / 1000.0 : weight
    }

    private var autoBcsForPet: Int? {
        guard case let .pet(pet) = target, let kg = weightInKgForBcs else { return nil }
        return PetBodyConditionEstimator.suggestedBCS(for: pet, weightKg: kg)
    }

    private var quickWeights: [Double] {
        switch target {
        case let .pet(pet):
            let defaults: [Double] = if Pet.isCatSpecies(pet.species) {
                [3.5, 4.5, 5.5]
            } else if Pet.isDogSpecies(pet.species) {
                [5, 10, 20]
            } else {
                [0.5, 1, 2]
            }
            return uniqueWeights([latestPetWeightKg].compactMap(\.self) + defaults)
        case let .human(human):
            let latest = human.weightLogs.sorted { $0.date > $1.date }.first?.weight
            return uniqueWeights([latest].compactMap(\.self) + [50, 60, 70])
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(entityName)
                        .font(OhanaFont.subheadline(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    weightEntryBlock
                    EmbeddedDecimalKeypad(
                        text: $weightText,
                        countryCode: appCountry,
                        maxFractionDigits: weightUnit == "g" ? 0 : 2,
                        accent: accentColor,
                        isMini: true,
                        showsSubmitButton: false,
                        onSubmit: {
                            if isValid { save() }
                        }
                    )
                    .padding(.horizontal, 20)
                    quickWeightStrip
                    dateAndTargetBlock
                    QuickCareActionHumanPickerContainer(
                        selectedHumanID: $selectedRecorderHumanID,
                        requiresSelection: $requiresRecorderSelection,
                        role: .recorder,
                        tint: accentColor
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    bcsBlock
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier(sheetAccessibilityIdentifier)
            .navigationTitle(l.tr(zh: "记录体重", en: "Record weight", de: "Gewicht erfassen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel, role: .cancel) { closeSheet() }
                        .accessibilityIdentifier("ohana-sheet-close-action")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) { save() }
                        .disabled(!isValid || isSaving || requiresRecorderSelection)
                        .accessibilityIdentifier("generic-weight-entry-save-action")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .onAppear {
            isClosing = false
            scheduleLatestPetWeightLoad()
        }
        .onChange(of: weightText) { _, newValue in
            let sanitized = CountryDecimalInput.sanitize(
                newValue,
                countryCode: appCountry,
                maxFractionDigits: weightUnit == "g" ? 0 : 2
            )
            if sanitized != newValue {
                weightText = sanitized
            }
        }
        .onChange(of: weightUnit) { _, _ in
            weightText = CountryDecimalInput.sanitize(
                weightText,
                countryCode: appCountry,
                maxFractionDigits: weightUnit == "g" ? 0 : 2
            )
        }
        .onDisappear {
            latestPetWeightLoadTask?.cancel()
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
        .onTapGesture { closeSheet() }
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
                    closeSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        popupDragOffset = 0
                    }
                }
            }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarView
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(identityColor.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "记录体重", en: "Record weight", de: "Gewicht erfassen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .accessibilityIdentifier(sheetAccessibilityIdentifier)
                Text(entityName)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { closeSheet() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var weightEntryBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "scalemass.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(l.tr(zh: "体重", en: "Weight", de: "Gewicht"))
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
                Text(weightText.isEmpty ? (weightUnit == "g" ? "0" : CountryDecimalInput.placeholder(countryCode: appCountry)) : weightText)
                    .font(OhanaFont.metric(size: 52, .black))
                    .foregroundStyle(weightText.isEmpty ? Color.ohanaTertiaryText : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.45)
                    .accessibilityIdentifier(weightValueAccessibilityIdentifier)

                unitPicker
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var unitPicker: some View {
        HStack(spacing: 4) {
            ForEach(["kg", "g"], id: \.self) { unit in
                Button {
                    withAnimation(GoMotion.feedback) {
                        weightUnit = unit
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(unit)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(weightUnit == unit ? Color.arkInk : Color.ohanaSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .goSelectableSurface(isSelected: weightUnit == unit, tint: accentColor, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(3)
        .background(Color.ohanaCardSurface, in: Capsule())
    }

    private var quickWeightStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(quickWeights.enumerated()), id: \.element) { index, weight in
                    Button {
                        applyQuickWeight(weight)
                    } label: {
                        Text(CountryDecimalInput.format(weight, countryCode: appCountry, maxFractionDigits: 1) + " kg")
                            .font(OhanaFont.subheadline(.black))
                            .foregroundStyle(isQuickWeightSelected(weight) ? Color.arkInk : Color.ohanaPrimaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .goSelectableSurface(isSelected: isQuickWeightSelected(weight), tint: accentColor, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("generic-weight-entry-quick-weight-\(index)")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var dateAndTargetBlock: some View {
        VStack(spacing: 10) {
            infoRow(icon: "calendar", label: l.tr(zh: "日期", en: "Date", de: "Datum")) {
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(accentColor)
                    .labelsHidden()
                    .environment(\.locale, AppLanguage.effectiveLocale)
            }

            infoRow(icon: "clock", label: l.tr(zh: "时间", en: "Time", de: "Zeit")) {
                HStack(spacing: 8) {
                    if includesRecordTime {
                        DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .tint(accentColor)
                            .labelsHidden()
                            .environment(\.locale, AppLanguage.effectiveLocale)
                    } else {
                        Text(l.tr(zh: "可选", en: "Optional", de: "Optional"))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Toggle("", isOn: $includesRecordTime.animation(GoMotion.feedback))
                        .labelsHidden()
                        .tint(accentColor)
                }
            }

            infoRow(icon: "person.crop.circle.fill", label: l.tr(zh: "对象", en: "For", de: "Für")) {
                Text(entityName)
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var bcsBlock: some View {
        if case .pet = target {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("BCS")
                        .font(OhanaFont.caption(.bold))
                    Spacer()
                }
                .foregroundStyle(Color.ohanaTertiaryText)

                if let bcs = autoBcsForPet {
                    HStack(spacing: 12) {
                        Text("\(bcs)")
                            .font(OhanaFont.metric(size: 30, .black))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 48, height: 48)
                            .background(bcsColor(bcs), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(bcsLabel(bcs))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(l.tr(
                                zh: "根据品种、年龄与本次体重估算",
                                en: "Estimated from breed, age, and this weight",
                                de: "Aus Rasse, Alter und Gewicht geschätzt"
                            ))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    Text(l.tr(
                        zh: "输入有效体重后显示体型评分",
                        en: "Enter a valid weight to see body score",
                        de: "Gültiges Gewicht eingeben, um den Körperwert zu sehen"
                    ))
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: isSaving ? "hourglass" : "checkmark.circle.fill")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(isSaving
                    ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
                    : l.tr(zh: "保存体重记录", en: "Save weight", de: "Gewicht speichern")
                )
                .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isValid && !isSaving ? accentColor : accentColor.opacity(0.38), in: Capsule())
            .opacity(isValid || isSaving ? 1 : 0.62)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isValid || isSaving || requiresRecorderSelection)
        .accessibilityLabel(isSaving
            ? l.tr(zh: "保存中", en: "Saving", de: "Speichert")
            : l.tr(zh: "保存体重记录", en: "Save weight", de: "Gewicht speichern")
        )
        .accessibilityIdentifier("generic-weight-entry-save-action")
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
                .font(OhanaFont.adaptive(size: 13, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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

    private func uniqueWeights(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        for value in values where value > 0 {
            let rounded = (value * 10).rounded() / 10
            if !result.contains(where: { abs($0 - rounded) < 0.05 }) {
                result.append(rounded)
            }
            if result.count >= 4 { break }
        }
        return result
    }

    private var sheetAccessibilityIdentifier: String {
        switch target {
        case .pet:
            "generic-weight-entry-sheet-pet"
        case .human:
            "generic-weight-entry-sheet-human"
        }
    }

    private var weightValueAccessibilityIdentifier: String {
        switch target {
        case .pet:
            "generic-weight-entry-value-pet"
        case .human:
            "generic-weight-entry-value-human"
        }
    }

    private func applyQuickWeight(_ kg: Double) {
        withAnimation(GoMotion.feedback) {
            weightUnit = "kg"
            weightText = CountryDecimalInput.format(kg, countryCode: appCountry, maxFractionDigits: 1)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func isQuickWeightSelected(_ kg: Double) -> Bool {
        guard weightUnit == "kg", let parsedWeight else { return false }
        return abs(parsedWeight - kg) < 0.05
    }

    private func scheduleLatestPetWeightLoad() {
        guard case let .pet(pet) = target else { return }
        latestPetWeightLoadTask?.cancel()
        let petID = pet.id
        latestPetWeightLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            latestPetWeightKg = PetWeightLedgerRouteMetrics.latestWeightKg(petID: petID, context: modelContext)
            latestPetWeightLoadTask = nil
        }
    }

    private func bcsColor(_ score: Int) -> Color {
        switch score {
        case 1 ... 3: Color(hex: "4ECDC4")
        case 4 ... 5: Color.goPrimary
        case 6 ... 7: Color(hex: "FFD93D")
        default: Color(hex: "FF6B6B")
        }
    }

    private func bcsLabel(_ score: Int) -> String {
        switch score {
        case 1: l.tr(zh: "极度消瘦", en: "Very thin", de: "Sehr dünn")
        case 2: l.tr(zh: "消瘦", en: "Thin", de: "Dünn")
        case 3: l.tr(zh: "偏瘦", en: "Slightly thin", de: "Etwas dünn")
        case 4: l.tr(zh: "理想偏瘦", en: "Lean ideal", de: "Schlank ideal")
        case 5: l.tr(zh: "理想体型", en: "Ideal", de: "Ideal")
        case 6: l.tr(zh: "理想偏胖", en: "Slightly heavy", de: "Etwas schwer")
        case 7: l.tr(zh: "偏胖", en: "Heavy", de: "Schwer")
        case 8: l.tr(zh: "肥胖", en: "Obese", de: "Adipös")
        case 9: l.tr(zh: "极度肥胖", en: "Very obese", de: "Stark adipös")
        default: ""
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        switch target {
        case let .pet(pet):
            PetAvatarPortraitView(
                pet: pet,
                fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 42,
                showsBackground: false
            )
        case let .human(human):
            HumanAvatarPipelineView(
                human: human,
                size: 42,
                fallbackScale: 0.67,
                showsBackground: false
            )
        }
    }

    private func save() {
        guard !isSaving,
              !requiresRecorderSelection,
              let weight = parsedWeight,
              weight > 0 else { return }
        isSaving = true
        let executorId = selectedRecorderHumanID?.uuidString
        let savedDate = recordDate
        let savedUnit = weightUnit
        let savedBcs = autoBcsForPet ?? 0

        switch target {
        case let .pet(pet):
            let command = DomainCommand.weightEntry(entityID: pet.id, entityKind: "pet")
            commandQueue.enqueue(command) {
                do {
                    let result = try DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordPetWeight(
                        pet: pet,
                        weight: weight,
                        date: savedDate,
                        executorId: executorId,
                        weightUnit: savedUnit,
                        bcsScore: savedBcs,
                        awardsReward: true,
                        ledgerSource: petLedgerSource,
                        command: command,
                        note: "weight.entry"
                    )
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onRewarded?(result.coconutDelta)
                    onSaved?()
                    closeSheet()
                } catch {
                    isSaving = false
                    appServices.domainRevisions.publishFailure(command: command, error: error)
                }
            }
        case let .human(human):
            let command = DomainCommand.weightEntry(entityID: human.id, entityKind: "human")
            commandQueue.enqueue(command) {
                do {
                    let result = try DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordHumanWeight(
                        human: human,
                        weight: weight,
                        date: savedDate,
                        executorId: executorId,
                        command: command,
                        note: "weight.entry"
                    )
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onRewarded?(result.coconutDelta)
                    onSaved?()
                    closeSheet()
                } catch {
                    isSaving = false
                    appServices.domainRevisions.publishFailure(command: command, error: error)
                }
            }
        }
    }

    private func closeSheet() {
        if let onDismiss {
            guard !isClosing else { return }
            isClosing = true
            onDismiss()
        } else {
            dismiss()
        }
    }
}

enum PetWeightLedgerRouteMetrics {
    @MainActor
    static func latestWeightKg(petID: UUID, context: ModelContext) -> Double? {
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        let subjectID = petID.uuidString
        let weightKind = CareLedgerEventKind.weight.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubjectKind &&
                    event.subjectId == subjectID &&
                    event.eventKind == weightKind
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        do {
            return try context.fetch(descriptor).first { $0.amountValue > 0 }?.amountValue
        } catch {
            OhanaLog.warning(
                "Latest pet weight ledger fetch failed: \(error.localizedDescription)",
                category: "DashboardRecords"
            )
            return nil
        }
    }
}
