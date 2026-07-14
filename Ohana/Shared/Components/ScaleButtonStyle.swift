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
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(Color.goPrimary)
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
