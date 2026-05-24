//
//  GenericWeightEntrySheet.swift
//  Ohana
//
//  Locale-aware weight entry sheet for pets and humans.
//

import SwiftUI
import SwiftData

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
    var onSaved: (() -> Void)? = nil
    var onRewarded: ((Int) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode

    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var includesRecordTime = false
    @State private var weightUnit: String = "kg"
    @State private var adaptiveSheetHeight: CGFloat = 500
    @State private var scrollContentHeight: CGFloat = 0
    @State private var popupVisible = false
    @State private var isClosing = false
    @State private var popupDragOffset: CGFloat = 0

    private var l: L10n { L10n(appLanguage) }

    private var popupAnimation: Animation {
        .interactiveSpring(response: 0.30, dampingFraction: 0.88, blendDuration: 0.12)
    }

    private var accentColor: Color {
        Color.goPrimary
    }

    private var identityColor: Color {
        switch target {
        case .pet(let pet): return Color(hex: pet.safeThemeColorHex)
        case .human: return Color.goPrimary
        }
    }

    private var entityName: String {
        switch target {
        case .pet(let pet): return pet.name
        case .human(let human): return human.name
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
        guard case .pet(let pet) = target, let kg = weightInKgForBcs else { return nil }
        return PetBodyConditionEstimator.suggestedBCS(for: pet, weightKg: kg)
    }

    private var quickWeights: [Double] {
        switch target {
        case .pet(let pet):
            let latest = pet.weightLogs.sorted { $0.date > $1.date }.first?.weightInKg
            let species = pet.species.lowercased()
            let defaults: [Double]
            if species.contains("cat") || pet.species.contains("猫") {
                defaults = [3.5, 4.5, 5.5]
            } else if species.contains("dog") || pet.species.contains("狗") {
                defaults = [5, 10, 20]
            } else {
                defaults = [0.5, 1, 2]
            }
            return uniqueWeights([latest].compactMap { $0 } + defaults)
        case .human(let human):
            let latest = human.weightLogs.sorted { $0.date > $1.date }.first?.weight
            return uniqueWeights([latest].compactMap { $0 } + [50, 60, 70])
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let minPanelHeight: CGFloat = 340
            let maxPanelHeight = max(minPanelHeight, proxy.size.height * 0.92)
            let scrollMaxHeight = max(190, maxPanelHeight - 152)
            let measuredScrollHeight = scrollContentHeight > 1 ? scrollContentHeight : min(330, scrollMaxHeight)
            let scrollHeight = min(measuredScrollHeight, scrollMaxHeight)
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
                            bcsBlock
                        }
                        .padding(.bottom, 10)
                        .background {
                            GeometryReader { contentProxy in
                                Color.clear
                                    .preference(
                                        key: WeightEntryScrollHeightKey.self,
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
                .shadow(color: Color.black.opacity(0.56), radius: 48, x: 0, y: -18) // ui-v4: allow confirmed inline popup lifted shadow
                .shadow(color: Color(hex: "0B102C").opacity(0.46), radius: 28, x: 0, y: 12) // ui-v4: allow confirmed inline popup lifted shadow
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
        .onPreferenceChange(WeightEntryScrollHeightKey.self) { height in
            guard height.isFinite, height > 0 else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                scrollContentHeight = height
            }
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
                .frame(width: 42, height: 42)
                .background(identityColor.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "记录体重", en: "Record weight", de: "Gewicht erfassen"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
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
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 11, weight: .semibold))
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

                unitPicker
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                ForEach(quickWeights, id: \.self) { weight in
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
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .semibold))
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
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    private var saveBar: some View {
        Button { save() } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(l.tr(zh: "保存体重记录", en: "Save weight", de: "Gewicht speichern"))
                    .font(OhanaFont.callout(.black))
            }
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isValid ? accentColor : accentColor.opacity(0.38), in: Capsule())
            .opacity(isValid ? 1 : 0.62)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isValid)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func infoRow<Trailing: View>(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(label)
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func bcsColor(_ score: Int) -> Color {
        switch score {
        case 1...3: return Color(hex: "4ECDC4")
        case 4...5: return Color.goPrimary
        case 6...7: return Color(hex: "FFD93D")
        default:    return Color(hex: "FF6B6B")
        }
    }

    private func bcsLabel(_ score: Int) -> String {
        switch score {
        case 1: return l.tr(zh: "极度消瘦", en: "Very thin", de: "Sehr dünn")
        case 2: return l.tr(zh: "消瘦", en: "Thin", de: "Dünn")
        case 3: return l.tr(zh: "偏瘦", en: "Slightly thin", de: "Etwas dünn")
        case 4: return l.tr(zh: "理想偏瘦", en: "Lean ideal", de: "Schlank ideal")
        case 5: return l.tr(zh: "理想体型", en: "Ideal", de: "Ideal")
        case 6: return l.tr(zh: "理想偏胖", en: "Slightly heavy", de: "Etwas schwer")
        case 7: return l.tr(zh: "偏胖", en: "Heavy", de: "Schwer")
        case 8: return l.tr(zh: "肥胖", en: "Obese", de: "Adipös")
        case 9: return l.tr(zh: "极度肥胖", en: "Very obese", de: "Stark adipös")
        default: return ""
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        switch target {
        case .pet(let pet):
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 42,
                showsBackground: false
            )
        case .human(let human):
            Group {
                if let data = human.avatarImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Text(human.avatarEmoji)
                        .font(.system(size: 28))
                }
            }
        }
    }

    private func save() {
        guard let weight = parsedWeight, weight > 0 else { return }
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let coconutBefore = QuestManager.shared.coconutCount

        switch target {
        case .pet(let pet):
            let bcs = autoBcsForPet ?? 0
            let log = PetWeightLog(date: recordDate, weight: weight, weightUnit: weightUnit, bcsScore: bcs, pet: pet, executorId: executorId)
            modelContext.insert(log)
            QuestManager.shared.awardAction(type: .weight, pet: pet, context: modelContext)
        case .human(let human):
            let log = HumanWeightLog(date: recordDate, weight: weight, human: human, executorId: executorId)
            modelContext.insert(log)
            human.weightLogs.append(log)
        }

        modelContext.safeSave()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let coconutDelta = max(0, QuestManager.shared.coconutCount - coconutBefore)
        onRewarded?(coconutDelta)
        onSaved?()
        closeSheet()
    }

    private func closeSheet() {
        if let onDismiss {
            guard !isClosing else { return }
            isClosing = true
            withAnimation(popupAnimation) {
                popupVisible = false
                popupDragOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                onDismiss()
            }
        } else {
            dismiss()
        }
    }
}
