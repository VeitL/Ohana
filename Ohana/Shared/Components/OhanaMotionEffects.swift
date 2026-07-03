import SwiftUI
#if os(iOS)
    import UIKit
#endif

enum OhanaFeedback {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let strongGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static var lastImpactAt: CFAbsoluteTime = 0
    private static var lastSelectionAt: CFAbsoluteTime = 0
    private static var lastNotificationAt: CFAbsoluteTime = 0

    static func light() {
        impact(.light)
    }

    static func medium() {
        impact(.medium)
    }

    static func strong() {
        impact(.heavy)
    }

    static func soft() {
        impact(.soft)
    }

    static func selection() {
        #if os(iOS)
            guard canPlayFeedback else { return }
            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastSelectionAt > 0.035 else { return }
            lastSelectionAt = now
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        #endif
    }

    static func success() {
        notification(.success)
    }

    static func warning() {
        notification(.warning)
    }

    static func error() {
        notification(.error)
    }

    static func prepareInteraction() {
        #if os(iOS)
            guard canPlayFeedback else { return }
            lightGenerator.prepare()
            mediumGenerator.prepare()
            softGenerator.prepare()
            selectionGenerator.prepare()
        #endif
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if os(iOS)
            guard canPlayFeedback else { return }
            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastImpactAt > 0.045 else { return }
            lastImpactAt = now
            let generator = impactGenerator(for: style)
            generator.impactOccurred()
            generator.prepare()
        #endif
    }

    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if os(iOS)
            guard canPlayFeedback else { return }
            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastNotificationAt > 0.20 else { return }
            lastNotificationAt = now
            notificationGenerator.notificationOccurred(type)
            notificationGenerator.prepare()
        #endif
    }

    private static var canPlayFeedback: Bool {
        AppWorkloadPolicy.shared.shouldPlayFeedback()
    }

    private static func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return lightGenerator
        case .medium:
            return mediumGenerator
        case .heavy:
            return strongGenerator
        case .soft:
            return softGenerator
        case .rigid:
            return mediumGenerator
        @unknown default:
            return mediumGenerator
        }
    }
}

private enum OhanaPopPhase: CaseIterable {
    case resting
    case lifted
    case settled

    var scale: CGFloat {
        switch self {
        case .resting: 1
        case .lifted: 1.08
        case .settled: 0.98
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .resting: 0
        case .lifted: -3
        case .settled: 0
        }
    }
}

private struct OhanaPhasePopModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Trigger
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled, !reduceMotion {
            content
                .phaseAnimator(OhanaPopPhase.allCases, trigger: trigger) { view, phase in
                    view
                        .scaleEffect(phase.scale)
                        .offset(y: phase.yOffset)
                } animation: { phase in
                    switch phase {
                    case .resting:
                        GoMotion.quick
                    case .lifted:
                        .bouncy(duration: 0.28, extraBounce: 0.26)
                    case .settled:
                        GoMotion.feedback
                    }
                }
        } else {
            content
                .animation(GoMotion.reduced, value: "\(trigger)")
        }
    }
}

private struct OhanaBreathingGlowModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accent: Color
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive, !reduceMotion {
            PhaseAnimator([false, true]) { phase in
                content
                    .shadow(color: accent.opacity(phase ? 0.26 : 0.08), radius: phase ? 18 : 8, x: 0, y: phase ? 8 : 3) // ui-v4: allow semantic attention glow
                    .scaleEffect(phase ? 1.006 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.9)
            }
        } else {
            content
        }
    }
}

private struct OhanaMarchingBorderModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dashPhase: CGFloat = 42
    let accent: Color
    let cornerRadius: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                if isActive {
                    shape
                        .strokeBorder(
                            accent.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [8, 8], dashPhase: dashPhase)
                        )
                        .allowsHitTesting(false)
                        .onAppear {
                            guard !reduceMotion else { return }
                            dashPhase = 42
                            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) { // ui-v4: allow continuous dashPhase attention border; smoothness: allow visible-only stroke phase loop gated by Reduce Motion.
                                dashPhase = -42
                            }
                        }
                }
            }
    }
}

private struct OhanaPingModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1
    let trigger: Trigger
    let accent: Color
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled, !reduceMotion {
                    Circle()
                        .strokeBorder(accent.opacity(0.5), lineWidth: 2)
                        .scaleEffect(0.72 + phase * 1.25)
                        .opacity(1 - phase)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard isEnabled, !reduceMotion else { return }
                phase = 0
                withAnimation(GoMotion.feedback) {
                    phase = 1
                }
            }
    }
}

private struct OhanaShineModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.7
    let trigger: Trigger
    let cornerRadius: CGFloat
    let isEnabled: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                if isEnabled, !reduceMotion {
                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)
                        LinearGradient(
                            colors: [
                                Color.ohanaPrimaryText.opacity(0),
                                Color.ohanaPrimaryText.opacity(0.28),
                                Color.ohanaPrimaryText.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: width * 0.34, height: proxy.size.height * 1.75)
                        .rotationEffect(.degrees(24))
                        .offset(x: width * phase, y: -proxy.size.height * 0.36)
                    }
                    .mask(shape)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard isEnabled, !reduceMotion else { return }
                phase = -0.7
                withAnimation(GoMotion.page) {
                    phase = 1.38
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
                    phase = -0.7
                }
            }
    }
}

private struct OhanaShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size _: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0))
    }
}

private struct OhanaShakeModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakePhase: CGFloat = 0
    let trigger: Trigger
    let amount: CGFloat
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .modifier(OhanaShakeEffect(amount: isEnabled && !reduceMotion ? amount : 0, animatableData: shakePhase))
            .onChange(of: trigger) { _, _ in
                guard isEnabled, !reduceMotion else { return }
                withAnimation(GoMotion.feedback) {
                    shakePhase += 1
                }
            }
    }
}

private struct OhanaSelectionMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isSelected: Bool
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (isSelected ? scale : 1))
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.selection, value: isSelected)
    }
}

private struct OhanaStateMotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? GoMotion.reduced : GoMotion.stateChange, value: value)
    }
}

private struct OhanaNumericMotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    let value: Value

    private var animation: Animation {
        guard !reduceMotion,
              workloadPolicy.shouldRunInteractionAnimation(isVisible: true) else {
            return GoMotion.reduced
        }
        return GoMotion.feedback
    }

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(animation, value: value)
    }
}

enum OhanaContextHandoffDirection {
    case neutral
    case fromLeading
    case fromTrailing
    case fromTop
    case fromBottom

    var offset: CGSize {
        switch self {
        case .neutral:
            .zero
        case .fromLeading:
            CGSize(width: -12, height: 0)
        case .fromTrailing:
            CGSize(width: 12, height: 0)
        case .fromTop:
            CGSize(width: 0, height: -10)
        case .fromBottom:
            CGSize(width: 0, height: 10)
        }
    }
}

private struct OhanaContextHandoffModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var progress: CGFloat = 1
    @State private var handoffToken = 0

    let value: Value
    let direction: OhanaContextHandoffDirection
    let isVisible: Bool
    let initialScale: CGFloat

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: isVisible)
    }

    func body(content: Content) -> some View {
        let clampedProgress = min(max(progress, 0), 1)
        let offset = direction.offset
        content
            .opacity(canAnimate ? Double(0.90 + 0.10 * clampedProgress) : 1)
            .scaleEffect(canAnimate ? initialScale + (1 - initialScale) * clampedProgress : 1)
            .offset(
                x: canAnimate ? offset.width * (1 - clampedProgress) : 0,
                y: canAnimate ? offset.height * (1 - clampedProgress) : 0
            )
            .animation(canAnimate ? GoMotion.stateChange : GoMotion.reduced, value: progress)
            .onChange(of: value) { _, _ in
                runHandoff()
            }
    }

    private func runHandoff() {
        guard canAnimate else {
            progress = 1
            return
        }

        handoffToken += 1
        let token = handoffToken
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            progress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame {
            guard token == handoffToken else { return }
            withAnimation(GoMotion.stateChange) {
                progress = 1
            }
        }
    }
}

private struct OhanaStaggeredMenuItemModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    let isVisible: Bool
    let index: Int
    let total: Int
    let anchor: UnitPoint

    private var canAnimate: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var delay: Double {
        let visibleIndex = max(total - 1 - index, 0)
        return isVisible
            ? GoMotion.staggerDelay(visibleIndex, step: 0.052, maxDelay: 0.28)
            : GoMotion.staggerDelay(index, step: 0.032, maxDelay: 0.18)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(canAnimate ? (isVisible ? 1 : 0.68) : 1, anchor: anchor)
            .opacity(isVisible ? 1 : 0)
            .offset(y: canAnimate ? (isVisible ? 0 : 22) : 0)
            .animation(canAnimate ? GoMotion.fab.delay(delay) : GoMotion.reduced, value: isVisible)
    }
}

private struct OhanaInlineMenuMotionModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    let trigger: Trigger

    func body(content: Content) -> some View {
        let canAnimate = !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
        content
            .transition(.ohanaInlineMenu)
            .animation(canAnimate ? GoMotion.selection : GoMotion.reduced, value: "\(trigger)")
    }
}

extension AnyTransition {
    static var ohanaPop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.86).combined(with: .opacity),
            removal: .scale(scale: 0.94).combined(with: .opacity)
        )
    }

    static var ohanaSoftBlur: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }

    static var ohanaInlineMenu: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.92)),
            removal: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.96))
        )
    }
}

extension View {
    func ohanaPhasePop(trigger: some Equatable, enabled: Bool = true) -> some View {
        modifier(OhanaPhasePopModifier(trigger: trigger, enabled: enabled))
    }

    func ohanaBreathingGlow(accent: Color = Color.goPrimary, isActive: Bool = true) -> some View {
        modifier(OhanaBreathingGlowModifier(accent: accent, isActive: isActive))
    }

    func ohanaMarchingBorder(accent: Color, cornerRadius: CGFloat = 22, isActive: Bool = true) -> some View {
        modifier(OhanaMarchingBorderModifier(accent: accent, cornerRadius: cornerRadius, isActive: isActive))
    }

    func ohanaSymbolPulse(trigger: some Equatable) -> some View {
        symbolEffect(.bounce.byLayer, value: trigger)
            .symbolEffect(.pulse.byLayer, value: trigger)
    }

    func ohanaNumericMotion(_ value: some Equatable) -> some View {
        modifier(OhanaNumericMotionModifier(value: value))
    }

    func ohanaSelectionMotion(isSelected: Bool, scale: CGFloat = 1.012) -> some View {
        modifier(OhanaSelectionMotionModifier(isSelected: isSelected, scale: scale))
    }

    func ohanaStateMotion(_ value: some Equatable) -> some View {
        modifier(OhanaStateMotionModifier(value: value))
    }

    func ohanaContextHandoff(
        _ value: some Equatable,
        direction: OhanaContextHandoffDirection = .neutral,
        isVisible: Bool = true,
        initialScale: CGFloat = 0.988
    ) -> some View {
        modifier(
            OhanaContextHandoffModifier(
                value: value,
                direction: direction,
                isVisible: isVisible,
                initialScale: initialScale
            )
        )
    }

    func ohanaStaggeredMenuItem(isVisible: Bool, index: Int, total: Int, anchor: UnitPoint = .bottomTrailing) -> some View {
        modifier(OhanaStaggeredMenuItemModifier(isVisible: isVisible, index: index, total: total, anchor: anchor))
    }

    func ohanaInlineMenuMotion(trigger: some Equatable) -> some View {
        modifier(OhanaInlineMenuMotionModifier(trigger: trigger))
    }

    func ohanaPing(trigger: some Equatable, accent: Color = Color.goPrimary, isEnabled: Bool = true) -> some View {
        modifier(OhanaPingModifier(trigger: trigger, accent: accent, isEnabled: isEnabled))
    }

    func ohanaShine(trigger: some Equatable, cornerRadius: CGFloat = 22, isEnabled: Bool = true) -> some View {
        modifier(OhanaShineModifier(trigger: trigger, cornerRadius: cornerRadius, isEnabled: isEnabled))
    }

    func ohanaShake(trigger: some Equatable, amount: CGFloat = 7, isEnabled: Bool = true) -> some View {
        modifier(OhanaShakeModifier(trigger: trigger, amount: amount, isEnabled: isEnabled))
    }
}
