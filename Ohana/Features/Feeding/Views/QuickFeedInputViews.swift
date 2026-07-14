//
//  QuickFeedInputViews.swift
//  Ohana
//
//  Reusable input surfaces for the quick feeding detail flow.
//

import SwiftUI

struct QuickFeedFoodKindSegmentedControl: View {
    let selection: FeedFoodKind
    let title: (FeedFoodKind) -> String
    let tintForKind: (FeedFoodKind) -> Color
    let setSelection: (FeedFoodKind) -> Void

    var body: some View {
        Picker(
            "",
            selection: Binding(
                get: { selection },
                set: { setSelection($0) }
            )
        ) {
            ForEach(FeedFoodKind.allCases) { foodKind in
                Text(title(foodKind))
                    .tag(foodKind)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .tint(tintForKind(selection))
    }
}

struct QuickFeedTreatKindPicker: View {
    let selection: FeedTreatKind
    let title: (FeedTreatKind) -> String
    let tint: Color
    let onSelect: (FeedTreatKind) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(FeedTreatKind.allCases) { treatKind in
                Button {
                    onSelect(treatKind)
                } label: {
                    Label(title(treatKind), systemImage: treatKind.systemIconName)
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(selection == treatKind ? Color.arkInk : tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection == treatKind ? tint : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

struct QuickFeedBrandSuggestionChips: View {
    let brands: [String]
    let tint: Color
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(brands, id: \.self) { brand in
                    Button {
                        onSelect(brand)
                    } label: {
                        Text(brand)
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}

struct QuickFeedGramInput<Keypad: View, Chips: View>: View {
    let title: String
    @Binding var text: String
    let tint: Color
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onOpenNumberPad: () -> Void
    @ViewBuilder let keypad: () -> Keypad
    @ViewBuilder let chips: () -> Chips

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 10) {
                QuickFeedGramStepButton(systemName: "minus", tint: tint, action: onDecrease)
                Button(action: onOpenNumberPad) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text.isEmpty ? "50" : text)
                            .font(OhanaFont.adaptive(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(text.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
                QuickFeedGramStepButton(systemName: "plus", tint: tint, action: onIncrease)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)

            keypad()
            chips()
        }
    }
}

struct QuickFeedGramStepButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityAddTraits(.isButton)
    }
}

struct QuickFeedPlanMealGramEditor<Keypad: View>: View {
    let valueText: String
    let tint: Color
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onOpenNumberPad: () -> Void
    @ViewBuilder let keypad: () -> Keypad

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                QuickFeedGramStepButton(systemName: "minus", tint: tint, action: onDecrease)
                Button(action: onOpenNumberPad) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(valueText.isEmpty ? "50" : valueText)
                            .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(valueText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                            .monospacedDigit()
                        Text("g")
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ScaleButtonStyle())
                QuickFeedGramStepButton(systemName: "plus", tint: tint, action: onIncrease)
            }
            keypad()
        }
        .padding(10)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
    }
}

struct QuickFeedGramInputCompact<Keypad: View>: View {
    let title: String
    @Binding var text: String
    let tint: Color
    let onOpenNumberPad: () -> Void
    @ViewBuilder let keypad: () -> Keypad

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 5) {
                Button(action: onOpenNumberPad) {
                    Text(text.isEmpty ? "50" : text)
                        .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(text.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ScaleButtonStyle())
                Text("g")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
            keypad()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuickFeedQuickGramChips: View {
    let values: [Double]
    let title: (Double) -> String
    let tint: Color
    let onSelect: (Double) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        onSelect(value)
                    } label: {
                        Text(title(value))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}

struct QuickFeedPlanStepperCard<Control: View>: View {
    let title: String
    let value: String
    let tint: Color
    let control: Control

    init(
        title: String,
        value: String,
        tint: Color,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.value = value
        self.tint = tint
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack {
                Text(value)
                    .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                control
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuickFeedCompactNotice: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.control)
    }
}

struct QuickFeedErrorText: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.goRed)
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.row)
    }
}
