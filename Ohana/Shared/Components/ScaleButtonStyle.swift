import SwiftUI
#if os(iOS)
    import UIKit
#endif

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var triggersHaptic = true
    var addsDepth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(
                OhanaButtonPressFeedbackModifier(
                    isPressed: configuration.isPressed,
                    isEnabled: isEnabled,
                    addsDepth: addsDepth,
                    triggersHaptic: triggersHaptic
                )
            )
            .animation(GoMotion.reduced, value: isEnabled)
    }
}

struct OhanaButtonPressFeedbackModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPressed: Bool
    let isEnabled: Bool
    var pressedScale: CGFloat = 0.972
    var pressedOffset: CGFloat = 0.7
    var pressedOpacity: Double = 0.985
    var addsDepth: Bool = false
    var triggersHaptic: Bool = true
    @State private var wasPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressScale)
            .offset(y: pressOffset)
            .opacity(pressOpacity)
            .brightness(isPressed && isEnabled ? -0.010 : 0)
            .shadow( // ui-v4: allow semantic press depth for all V4 buttons
                color: Color.arkInk.opacity(addsDepth && isPressed && isEnabled && !reduceMotion ? 0.10 : 0),
                radius: addsDepth && isPressed && isEnabled && !reduceMotion ? 5 : 0,
                x: 0,
                y: addsDepth && isPressed && isEnabled && !reduceMotion ? 2 : 0
            )
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.tap, value: isPressed)
            .onChange(of: isPressed) { _, newValue in
                guard newValue, isEnabled, !wasPressed else {
                    wasPressed = newValue
                    return
                }
                wasPressed = true
                triggerPressHaptic()
            }
    }

    private var pressScale: CGFloat {
        guard !reduceMotion, isEnabled else { return 1 }
        return isPressed ? pressedScale : 1
    }

    private var pressOffset: CGFloat {
        guard !reduceMotion, isEnabled else { return 0 }
        return isPressed ? pressedOffset : 0
    }

    private var pressOpacity: Double {
        guard isEnabled else { return 0.55 }
        return isPressed ? pressedOpacity : 1
    }

    private func triggerPressHaptic() {
        #if os(iOS)
            guard triggersHaptic else { return }
            OhanaFeedback.soft()
        #endif
    }
}

struct OhanaPillToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.selection) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                configuration.label

                Capsule()
                    .fill(trackFill(isOn: configuration.isOn))
                    .frame(width: 50, height: 28)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.ohanaPrimaryText)
                            .frame(width: 22, height: 22) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            .shadow( // ui-v4: allow switch thumb depth for state clarity
                                color: Color.arkInk.opacity(configuration.isOn ? 0.18 : 0.10),
                                radius: configuration.isOn ? 7 : 4,
                                x: 0,
                                y: configuration.isOn ? 3 : 1
                            )
                            .padding(3)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                configuration.isOn ? Color.goPrimary.opacity(0.55) : Color.ohanaGlassStroke.opacity(0.9),
                                lineWidth: 1
                            )
                    }
                    .animation(reduceMotion ? GoMotion.reduced : GoMotion.selection, value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
    }

    private func trackFill(isOn: Bool) -> Color {
        if isOn {
            return Color.goPrimary
        }
        return Color.ohanaControlFill
    }
}

private struct OhanaSmoothAppearModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .scaleEffect(isVisible ? 1 : 0.98)
            .onAppear {
                if reduceMotion {
                    isVisible = true
                    return
                }

                let delay = GoMotion.staggerDelay(index)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(GoMotion.page) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    func ohanaSmoothAppear(index: Int = 0) -> some View {
        modifier(OhanaSmoothAppearModifier(index: index))
    }
}
