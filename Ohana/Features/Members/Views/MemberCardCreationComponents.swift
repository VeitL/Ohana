//
//  MemberCardCreationComponents.swift
//  Ohana
//
//  Reusable input fields, pickers, card surfaces and media capture views
//  extracted from MemberCardCreationView.
//

import AVFoundation
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MemberNameInputField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let foreground: Color
    let placeholderForeground: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .default
        textField.returnKeyType = .done
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.font = .systemFont(ofSize: 17, weight: .bold)
        textField.adjustsFontForContentSizeCategory = true
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.text = $text
        if !context.coordinator.isEditing, textField.text != text {
            textField.text = text
        }
        textField.textColor = UIColor(foreground)
        textField.tintColor = UIColor(foreground)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor(placeholderForeground),
                .font: UIFont.systemFont(ofSize: 17, weight: .bold)
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isEditing = false
        private var latestText = ""

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            MemberCreationPerformance.event("Name Keystroke Received")
            latestText = sender.text ?? ""
            commitLatestText()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            MemberCreationPerformance.event("Name Editing Began")
            isEditing = true
            latestText = textField.text ?? ""
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            MemberCreationPerformance.event("Name Editing Ended")
            isEditing = false
            latestText = textField.text ?? ""
            commitLatestText()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            latestText = textField.text ?? ""
            commitLatestText()
            textField.resignFirstResponder()
            return true
        }

        private func commitLatestText() {
            guard text.wrappedValue != latestText else { return }
            let signpostID = MemberCreationPerformance.begin("Name Draft Commit")
            text.wrappedValue = latestText
            MemberCreationPerformance.end("Name Draft Commit", signpostID)
        }
    }
}

struct MemberCreationStepIndicator: View {
    let steps: [MemberCreationStep]
    let currentStep: MemberCreationStep
    let kind: MemberCreationKind
    let l: L10n
    let foreground: Color
    let secondaryForeground: Color
    let inactiveFill: Color

    private var currentIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(currentStep.title(kind: kind, l: l))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                Text("\(currentIndex + 1) / \(steps.count)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(secondaryForeground)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? Color.goPrimary : inactiveFill)
                        .frame(width: index == currentIndex ? 26 : 9, height: 7)
                        .animation(GoMotion.selection, value: currentIndex)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 42, alignment: .bottom)
    }
}

struct MemberCompactDateRow: View {
    let title: String
    let icon: String
    @Binding var isEnabled: Bool
    @Binding var date: Date
    let range: ClosedRange<Date>
    let foreground: Color
    let secondaryForeground: Color
    let fill: Color
    let stroke: Color
    let accent: Color

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            if isEnabled {
                iconDatePicker
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Toggle(title, isOn: $isEnabled)
                .labelsHidden()
                .tint(accent)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(fill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(stroke, lineWidth: 1)
        }
        .shadow(color: isEnabled ? accent.opacity(0.22) : Color.goCardWhite.opacity(0.06), radius: isEnabled ? 12 : 7, y: 4) // ui-v4: allow selected glass date row glow
        .animation(GoMotion.selection, value: isEnabled)
        .accessibilityElement(children: .contain)
    }

    private var iconDatePicker: some View {
        DatePicker("", selection: $date, in: range, displayedComponents: .date)
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, AppLanguage.effectiveLocale)
            .tint(accent)
            .font(OhanaFont.caption(.black))
            .foregroundStyle(foreground)
            .frame(minWidth: 118, maxWidth: 136, minHeight: 38, alignment: .trailing)
            .background(Color.goCardWhite.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(accent.opacity(0.34), lineWidth: 1)
            }
            .accessibilityLabel("\(title), \(formattedDate)")
    }
}

struct MemberCompactMBTIBar: View {
    @Binding var energy: String
    @Binding var information: String
    @Binding var decision: String
    @Binding var lifestyle: String
    let foreground: Color
    let onSelectionChanged: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var result: String {
        [energy, information, decision, lifestyle].map { $0.isEmpty ? "-" : $0 }.joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("MBTI")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(foreground.opacity(0.70))
                Spacer()
                Text(result)
                    .font(OhanaFont.callout(.black))
                    .monospaced()
                    .foregroundStyle(result.contains("-") ? foreground.opacity(0.58) : foreground)
            }
            HStack(spacing: 7) {
                dimensionMenu(title: "I/E", first: "I", second: "E", selection: $energy)
                dimensionMenu(title: "S/N", first: "S", second: "N", selection: $information)
                dimensionMenu(title: "T/F", first: "T", second: "F", selection: $decision)
                dimensionMenu(title: "J/P", first: "J", second: "P", selection: $lifestyle)
            }
        }
    }

    private func dimensionMenu(title: String, first: String, second: String, selection: Binding<String>) -> some View {
        Menu {
            Button(first) { select(first, selection: selection) }
            Button(second) { select(second, selection: selection) }
            Button(l.tr(zh: "清空", en: "Clear", de: "Leeren"), role: .destructive) { select("", selection: selection) }
        } label: {
            Text(selection.wrappedValue.isEmpty ? title : selection.wrappedValue)
                .font(OhanaFont.caption(.black))
                .monospaced()
                .foregroundStyle(selection.wrappedValue.isEmpty ? foreground.opacity(0.72) : Color.arkInk)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(selection.wrappedValue.isEmpty ? Color.ohanaControlFill : Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func select(_ value: String, selection: Binding<String>) {
        withAnimation(GoMotion.selection) {
            selection.wrappedValue = value
        }
        onSelectionChanged()
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct MemberCompactCityPicker: View {
    let country: String
    @Binding var city: String
    @Binding var usesCustomCity: Bool

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var cities: [String] {
        country.isEmpty ? [] : PetBreedDatabase.cities(for: country)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                if cities.isEmpty {
                    Button(l.tr(zh: "先选择现居国家", en: "Choose residence first", de: "Zuerst Wohnland wählen")) {}
                } else {
                    ForEach(cities, id: \.self) { option in
                        Button(localizedCity(option)) {
                            if option == "其他" {
                                usesCustomCity = true
                                city = ""
                            } else {
                                usesCustomCity = false
                                city = option
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(l.tr(zh: "城市", en: "City", de: "Stadt"))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Text(cityValueText)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                .frame(height: 42)
                .padding(.horizontal, 12)
                .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())

            if usesCustomCity {
                TextField(l.tr(zh: "自定义城市", en: "Custom city", de: "Eigene Stadt"), text: $city) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .textInputAutocapitalization(.words)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
        }
    }

    private var cityValueText: String {
        if country.isEmpty {
            return l.tr(zh: "先选国家", en: "Choose country", de: "Land wählen")
        }
        if usesCustomCity {
            return city.isEmpty ? l.tr(zh: "自定义", en: "Custom", de: "Eigen") : city
        }
        return city.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : localizedCity(city)
    }

    private func localizedCity(_ value: String) -> String {
        value == "其他" ? l.tr(zh: "其他", en: "Other", de: "Andere") : value
    }
}

struct MemberDateInputBlock: View {
    let title: String
    let subtitle: String
    let toggleTitle: String
    let icon: String
    @Binding var isEnabled: Bool
    @Binding var date: Date
    let range: ClosedRange<Date>

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var isExpanded = false

    private var l: L10n { L10n(appLanguage) }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(subtitle)
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle(toggleTitle, isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Color.goPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))

            if isEnabled {
                Button {
                    withAnimation(GoMotion.selection) {
                        isExpanded.toggle()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l.tr(zh: "已选择日期", en: "Selected date", de: "Ausgewähltes Datum"))
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.ohanaSecondaryText)
                            Text(formattedDate)
                                .font(OhanaFont.title3(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 64)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())

                if isExpanded {
                    DatePicker("", selection: $date, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .environment(\.locale, AppLanguage.effectiveLocale)
                        .tint(Color.goPrimary)
                        .padding(12)
                        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if !newValue {
                withAnimation(GoMotion.selection) {
                    isExpanded = false
                }
            }
        }
    }
}

struct MemberMBTIChoiceGrid: View {
    @Binding var energy: String
    @Binding var information: String
    @Binding var decision: String
    @Binding var lifestyle: String
    let onSelectionChanged: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var displayResult: String {
        [energy, information, decision, lifestyle]
            .map { $0.isEmpty ? "-" : $0 }
            .joined()
    }

    private var dimensionColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 138), spacing: 8),
            GridItem(.flexible(minimum: 138), spacing: 8)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("MBTI")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(displayResult)
                    .font(OhanaFont.title3(.black))
                    .monospaced()
                    .foregroundStyle(displayResult.contains("-") ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
            }
            LazyVGrid(columns: dimensionColumns, spacing: 8) {
                dimensionBlock(
                    title: l.tr(zh: "能量", en: "Energy", de: "Energie"),
                    first: ("I", l.tr(zh: "内向", en: "Introvert", de: "Introvertiert")),
                    second: ("E", l.tr(zh: "外向", en: "Extravert", de: "Extravertiert")),
                    selection: $energy
                )
                dimensionBlock(
                    title: l.tr(zh: "信息", en: "Information", de: "Information"),
                    first: ("S", l.tr(zh: "实感", en: "Sensing", de: "Sensorisch")),
                    second: ("N", l.tr(zh: "直觉", en: "Intuition", de: "Intuition")),
                    selection: $information
                )
                dimensionBlock(
                    title: l.tr(zh: "判断", en: "Decision", de: "Entscheidung"),
                    first: ("T", l.tr(zh: "思考", en: "Thinking", de: "Denken")),
                    second: ("F", l.tr(zh: "情感", en: "Feeling", de: "Fühlen")),
                    selection: $decision
                )
                dimensionBlock(
                    title: l.tr(zh: "生活", en: "Lifestyle", de: "Lebensstil"),
                    first: ("J", l.tr(zh: "判断", en: "Judging", de: "Geplant")),
                    second: ("P", l.tr(zh: "感知", en: "Perceiving", de: "Spontan")),
                    selection: $lifestyle
                )
            }
        }
    }

    private func dimensionBlock(
        title: String,
        first: (String, String),
        second: (String, String),
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(spacing: 6) {
                mbtiOption(first.0, label: first.1, selection: selection)
                mbtiOption(second.0, label: second.1, selection: selection)
            }
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func mbtiOption(_ letter: String, label: String, selection: Binding<String>) -> some View {
        let isSelected = selection.wrappedValue == letter
        return Button {
            withAnimation(GoMotion.selection) {
                selection.wrappedValue = letter
            }
            onSelectionChanged()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Text(letter)
                    .font(OhanaFont.callout(.black))
                    .monospaced()
                Text(label)
                    .font(OhanaFont.caption(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isSelected ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct MemberCityPicker: View {
    let country: String
    @Binding var city: String
    @Binding var usesCustomCity: Bool

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }
    private var cities: [String] {
        country.isEmpty ? [] : PetBreedDatabase.cities(for: country)
    }

    private var cityColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 94), spacing: 7)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cities.isEmpty {
                Text(l.tr(zh: "先选择现居国家", en: "Choose a country first", de: "Zuerst ein Land wählen"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ohanaControlFill, in: Capsule())
            } else {
                LazyVGrid(columns: cityColumns, spacing: 7) {
                    ForEach(cities, id: \.self) { option in
                        cityButton(option)
                    }
                }
            }

            if usesCustomCity {
                TextField(l.tr(zh: "自定义城市", en: "Custom city", de: "Eigene Stadt"), text: $city) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .textInputAutocapitalization(.words)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
        }
    }

    private func cityButton(_ option: String) -> some View {
        let isOther = option == "其他"
        let isSelected = isOther ? usesCustomCity : city == option && !usesCustomCity
        return Button {
            withAnimation(GoMotion.selection) {
                if isOther {
                    usesCustomCity = true
                    city = ""
                } else {
                    usesCustomCity = false
                    city = city == option ? "" : option
                }
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(localizedCity(option))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func localizedCity(_ value: String) -> String {
        value == "其他" ? l.tr(zh: "其他", en: "Other", de: "Andere") : value
    }
}

struct MemberCreationJoinHandoffModifier: ViewModifier {
    let progress: CGFloat
    let reduceMotion: Bool

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    private var easedProgress: CGFloat {
        let p = clampedProgress
        return p * p * (3 - 2 * p)
    }

    func body(content: Content) -> some View {
        let p = easedProgress
        let scale = reduceMotion ? mix(1, 0.82, p) : mix(1, HomeJoinHandoffMotion.scale, p)
        let y = reduceMotion ? mix(0, 10, p) : mix(0, HomeJoinHandoffMotion.y, p)
        let rotation = reduceMotion ? Double(0) : Double(mix(0, HomeJoinHandoffMotion.rotation, p))
        let flip = reduceMotion ? Double(0) : Double(mix(0, HomeJoinHandoffMotion.flip, p))
        let opacity = reduceMotion ? Double(mix(1, 0.68, p)) : Double(mix(1, HomeJoinHandoffMotion.opacity, p))

        content
            .rotationEffect(.degrees(rotation))
            .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
            .scaleEffect(scale, anchor: .center)
            .offset(y: y)
            .opacity(opacity)
            .zIndex(progress > 0 ? 20 : 0)
    }

    private func mix(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

struct MemberCreationJoinHandoffCard: View {
    let snapshot: MemberCardRenderSnapshot

    private var accent: Color {
        Color(hex: snapshot.themeColorHex)
    }

    private var prefersDarkText: Bool {
        WalletPetCardTheme.prefersDarkForeground(for: snapshot.themeColorHex)
    }

    private var primaryText: Color {
        prefersDarkText ? Color.arkInk : Color.goCardWhite
    }

    private var secondaryText: Color {
        primaryText.opacity(0.66)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                .fill(cardGradient)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.title)
                            .font(.system(size: min(max(width * 0.115, 32), 46), weight: .black, design: .rounded))
                            .foregroundStyle(primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.62)
                        Text(snapshot.subtitle)
                            .font(OhanaFont.callout(.bold))
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 22)
                }
                .overlay {
                    avatar(width: width, height: height)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                        Text(snapshot.statusText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(primaryText.opacity(prefersDarkText ? 0.10 : 0.14), in: Capsule())
                    .padding(18)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                        .strokeBorder(Color.goCardWhite.opacity(0.24), lineWidth: 1)
                }
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.mix(with: .white, by: 0.14),
                accent,
                accent.mix(with: .black, by: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func avatar(width: CGFloat, height: CGFloat) -> some View {
        if let image = snapshot.avatarImage, snapshot.avatarSource == .customImage, !snapshot.avatarIsTransparent {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Color.arkInk.opacity(0.10), Color.arkInk.opacity(0.52)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else if let image = snapshot.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.68, height: height * 0.48)
                .position(x: width * 0.52, y: height * 0.53)
        } else {
            Image(systemName: snapshot.fallbackSymbol)
                .font(.system(size: min(width * 0.32, 110), weight: .black))
                .foregroundStyle(primaryText.opacity(0.86))
                .frame(width: width * 0.58, height: height * 0.42)
                .position(x: width * 0.54, y: height * 0.53)
        }
    }
}
