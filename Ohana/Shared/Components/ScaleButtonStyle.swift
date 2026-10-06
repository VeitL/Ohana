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
    var pressedScale: CGFloat = 0.985
    var pressedOffset: CGFloat = 0
    var pressedOpacity: Double = 0.92
    var addsDepth: Bool = false
    var triggersHaptic: Bool = true

    private var allowsSpatialFeedback: Bool {
        !reduceMotion && AppWorkloadPolicy.shared.shouldRunInteractionAnimation()
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressScale)
            .offset(y: pressOffset)
            .opacity(pressOpacity)
            .if(addsDepth) { view in
                view.shadow( // ui-v4: allow opt-in semantic press depth
                    color: Color.arkInk.opacity(isPressed && isEnabled && allowsSpatialFeedback ? 0.06 : 0),
                    radius: isPressed && isEnabled && allowsSpatialFeedback ? 3 : 0,
                    y: isPressed && isEnabled && allowsSpatialFeedback ? 1 : 0
                )
            }
            .animation(allowsSpatialFeedback ? GoMotion.tap : GoMotion.reduced, value: isPressed)
            .onChange(of: isPressed) { _, newValue in
                guard newValue, isEnabled else { return }
                triggerPressHaptic()
            }
    }

    private var pressScale: CGFloat {
        guard allowsSpatialFeedback, isEnabled else { return 1 }
        return isPressed ? pressedScale : 1
    }

    private var pressOffset: CGFloat {
        guard allowsSpatialFeedback, isEnabled else { return 0 }
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
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isVisible = false

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation()
    }

    func body(content: Content) -> some View {
        content
            // Content stays readable and interactive during a reveal, including
            // recycled rows. SwiftUI cancels the pending task on disappearance.
            .opacity(isVisible || !canAnimate ? 1 : 0.92)
            .offset(y: isVisible || !canAnimate ? 0 : 6)
            .task(id: canAnimate) {
                guard !isVisible else { return }
                guard canAnimate else {
                    isVisible = true
                    return
                }

                let delay = GoMotion.staggerDelay(index)
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                withAnimation(GoMotion.page) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func ohanaSmoothAppear(index: Int = 0) -> some View {
        modifier(OhanaSmoothAppearModifier(index: index))
    }
}
