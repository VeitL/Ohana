//
//  CrewRosterEditorControls.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

struct CrewRosterEditorTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CrewRosterEditorLabel(title: title, icon: icon)
            TextField(title, text: $text, axis: axis) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goCardWhite)
                .textFieldStyle(.plain)
                .lineLimit(axis == .vertical ? 2 ... 4 : 1 ... 1)
                .padding(.horizontal, 12)
                .padding(.vertical, axis == .vertical ? 11 : 10)
                .background(Color.goCardWhite.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
        }
        .padding(12)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}

struct CrewRosterEditorMenuRow: View {
    let title: String
    let icon: String
    @Binding var selection: String
    let options: [String]
    var optionTitle: ((String) -> String)? = nil

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: icon)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(displayTitle(for: option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func displayTitle(for option: String) -> String {
        if let optionTitle {
            return optionTitle(option)
        }
        return option.isEmpty || option == "未填写"
            ? l.tr(zh: "未填写", en: "Not set", de: "Nicht festgelegt")
            : option
    }
}

struct CrewRosterEditorSegmentedRow: View {
    let title: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: "slider.horizontal.3")
            Picker(title, selection: $selection) {
                ForEach(options, id: \.0) { key, value in
                    Text(value).tag(key)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}

struct CrewRosterEditorToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            CrewRosterEditorLabel(title: title, icon: icon)
        }
        .tint(Color.goPrimary)
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}

struct CrewRosterEditorDateToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    @Binding var date: Date
    var upperBound: Date?

    var body: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $isOn) {
                CrewRosterEditorLabel(title: title, icon: icon)
            }
            .tint(Color.goPrimary)

            if isOn {
                if let upperBound {
                    DatePicker(title, selection: $date, in: ...upperBound, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                } else {
                    DatePicker(title, selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                }
            }
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .animation(GoMotion.feedback, value: isOn)
    }
}

struct CrewRosterEditorStepperRow: View {
    let title: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: icon)
            Spacer(minLength: 8)
            Stepper(value: $value, in: range) {
                Text("\(value) \(unit)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .monospacedDigit()
            }
            .labelsHidden()
            Text("\(value) \(unit)")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goCardWhite)
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}

struct CrewRosterThemeSwatchRow: View {
    let title: String
    @Binding var selectedHex: String

    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }
    private var themeHexes: [String] {
        PetThemeColor.allCases.map(\.hexValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: "paintpalette.fill")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(themeHexes, id: \.self) { hex in
                    Button {
                        selectedHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            if selectedHex.uppercased() == hex.uppercased() {
                                Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                                    .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(WalletPetCardTheme.prefersDarkForeground(for: hex) ? Color.arkInk : Color.goCardWhite)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"))
                }
            }
        }
        .padding(12)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }
}

struct CrewRosterEditorLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 18)
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goCardWhite.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}
