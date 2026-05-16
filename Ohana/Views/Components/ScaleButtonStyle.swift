import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.965 : 1.0))
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? -0.018 : 0)
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.tap, value: configuration.isPressed)
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
