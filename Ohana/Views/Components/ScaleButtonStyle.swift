import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(pressScale(isPressed: configuration.isPressed))
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .opacity(isEnabled ? (configuration.isPressed ? 0.96 : 1.0) : 0.55)
            .brightness(configuration.isPressed ? -0.014 : 0)
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.tap, value: configuration.isPressed)
            .animation(GoMotion.reduced, value: isEnabled)
    }

    private func pressScale(isPressed: Bool) -> CGFloat {
        guard !reduceMotion, isEnabled else { return 1 }
        return isPressed ? 0.955 : 1
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
                            .frame(width: 22, height: 22)
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
