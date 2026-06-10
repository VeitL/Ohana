//
//  OhanaDesignSystem.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - GO Motion Tokens
enum GoMotion {
    static let page: Animation = .interactiveSpring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.26)
    static let hero: Animation = .interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.22)
    static let fab: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.74, blendDuration: 0.18)
    static let feedback: Animation = .interactiveSpring(response: 0.24, dampingFraction: 0.82, blendDuration: 0.10)
    static let quick: Animation = .easeOut(duration: 0.18)
    static let reduced: Animation = .easeInOut(duration: 0.12)

    static let tap: Animation = .interactiveSpring(response: 0.18, dampingFraction: 0.84, blendDuration: 0.08)
    static let selection: Animation = .interactiveSpring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.16)
    static let stateChange: Animation = .interactiveSpring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.18)
    static let sheet: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.22)
    static let heroExpand: Animation = .interactiveSpring(response: 0.62, dampingFraction: 0.91, blendDuration: 0.18)
    static let heroCollapse: Animation = .interactiveSpring(response: 0.54, dampingFraction: 0.94, blendDuration: 0.14)
    static let heroAvatarParallax: Animation = .interactiveSpring(response: 0.50, dampingFraction: 0.84, blendDuration: 0.12)
    static let sheetEnter: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.22)
    static let rewardPop: Animation = .interactiveSpring(response: 0.30, dampingFraction: 0.72, blendDuration: 0.12)
    static let zStackHero: Animation = .interactiveSpring(response: 0.62, dampingFraction: 0.92, blendDuration: 0.18)
    static let zStackMenu: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.16)
    static let zStackPopup: Animation = .interactiveSpring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.20)

    static func staggerDelay(_ index: Int, step: Double = 0.035, maxDelay: Double = 0.24) -> Double {
        min(Double(max(index, 0)) * step, maxDelay)
    }
}

// MARK: - Global Coconut Balance Capsule
struct CoconutBalanceCapsule: View {
    @State private var previousCount: Int
    @State private var pulse = false
    @State private var contextHandoffPulse = false
    @State private var floatingDelta: Int? = nil
    @State private var floatingDeltaProgress: CGFloat = 1
    @State private var floatingDeltaToken = 0
    @State private var contextHandoffToken = 0
    private let balanceOverride: Int?
    private let showsDeltaAnimation: Bool
    private let deltaAnimationContext: String
    let onTap: () -> Void

    init(
        balance: Int? = nil,
        showsDeltaAnimation: Bool? = nil,
        deltaAnimationContext: String? = nil,
        onTap: @escaping () -> Void = {}
    ) {
        self.balanceOverride = balance
        self.showsDeltaAnimation = showsDeltaAnimation ?? true
        self.deltaAnimationContext = deltaAnimationContext ?? "global"
        self.onTap = onTap
        _previousCount = State(initialValue: balance ?? 0)
    }

    private var visibleCount: Int {
        balanceOverride ?? 0
    }

    private var deltaState: CoconutBalanceDeltaState {
        CoconutBalanceDeltaState(count: visibleCount, context: deltaAnimationContext)
    }

    private var capsuleCore: some View {
        HStack(spacing: 3) {
            Text("🥥").font(OhanaFont.metric(size: 9, .medium))
            Text("\(visibleCount)")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .ohanaNumericMotion(visibleCount)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .frame(height: 26)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.goPrimary, in: Capsule())
        .scaleEffect(pulse ? 1.12 : (contextHandoffPulse ? 1.045 : 1.0))
        .overlay(alignment: .bottom) {
            if let delta = floatingDelta, delta != 0 {
                floatingDeltaLabel(delta)
                    .offset(y: floatingDeltaOffsetY)
                    .scaleEffect(pulse ? 1.035 : 1)
                    .opacity(floatingDeltaOpacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(GoMotion.feedback, value: pulse)
        .animation(GoMotion.feedback, value: contextHandoffPulse)
    }

    private var floatingDeltaOffsetY: CGFloat {
        let eased = floatingDeltaEase(floatingDeltaProgress)
        return 18 + (-22 - 18) * eased
    }

    private var floatingDeltaOpacity: Double {
        let eased = floatingDeltaEase(floatingDeltaProgress)
        return Double(max(0, 1 - eased))
    }

    private func floatingDeltaLabel(_ delta: Int) -> some View {
        let tint = delta > 0 ? Color.goLime : Color.goRed
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(OhanaFont.subheadline(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("🥥")
                .font(OhanaFont.caption())
        }
        .foregroundStyle(tint)
        .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4) // ui-v4: allow minimal floating balance delta
    }

    var body: some View {
        Button(action: onTap) {
            capsuleCore
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            previousCount = visibleCount
        }
        .onChange(of: deltaState) { oldValue, newValue in
            let delta = newValue.count - oldValue.count
            previousCount = newValue.count
            guard showsDeltaAnimation else {
                resetFloatingDelta()
                return
            }
            guard oldValue.context == newValue.context else {
                showContextHandoff()
                return
            }
            guard delta != 0 else { return }
            showFloatingDelta(delta)
        }
    }

    private func showFloatingDelta(_ delta: Int) {
        let isInFlight = floatingDelta != nil && floatingDeltaProgress < 1
        let nextDelta = (isInFlight ? (floatingDelta ?? 0) : 0) + delta
        floatingDelta = nextDelta == 0 ? delta : nextDelta
        floatingDeltaToken += 1
        let token = floatingDeltaToken

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            floatingDeltaProgress = 0
        }
        withAnimation(GoMotion.feedback) {
            pulse = true
        }
        withAnimation(.easeOut(duration: 1.12)) { // ui-v4: allow one-shot floating balance delta drift
            floatingDeltaProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard token == floatingDeltaToken else { return }
            withAnimation(GoMotion.feedback) {
                pulse = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.16) {
            guard token == floatingDeltaToken else { return }
            resetFloatingDelta()
        }
    }

    private func showContextHandoff() {
        resetFloatingDelta()
        contextHandoffToken += 1
        let token = contextHandoffToken
        withAnimation(GoMotion.feedback) {
            contextHandoffPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard token == contextHandoffToken else { return }
            withAnimation(GoMotion.feedback) {
                contextHandoffPulse = false
            }
        }
    }

    private func resetFloatingDelta() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            floatingDelta = nil
            pulse = false
            contextHandoffPulse = false
            floatingDeltaProgress = 1
        }
    }

    private func floatingDeltaEase(_ value: CGFloat) -> CGFloat {
        let x = min(max(value, 0), 1)
        return 1 - pow(1 - x, 3)
    }
}

private struct CoconutBalanceDeltaState: Equatable {
    let count: Int
    let context: String
}

// MARK: - Screen Compat（优先 UIWindowScene，避免直接读 UIScreen.main）
struct ScreenCompat {
    static var bounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let w = scene.windows.first(where: { $0.isKeyWindow }) {
                return w.bounds
            }
        }
        if let w = scenes.first?.windows.first {
            return w.bounds
        }
        return CGRect(x: 0, y: 0, width: 393, height: 852)
    }
    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }

#if os(iOS)
    /// 物理屏圆角半径（与 SpringBoard / 桌面玻璃一致）。优先 `_displayCornerRadius`； unavailable 时用短边比例估算。
    /// - Note: 公开 SDK 暂无 `UIScreen.displayCornerRadius` 成员时依赖 runtime key；若未来系统提供公开 API 可替换。
    static var displayCornerRadius: CGFloat {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
        if let r = screen?.value(forKey: "_displayCornerRadius") as? CGFloat, r > 1 {
            return r
        }
        let s = bounds.size
        let m = min(s.width, s.height)
        return max(46, m * 0.134)
    }
#else
    static var displayCornerRadius: CGFloat {
        let s = bounds.size
        return max(46, min(s.width, s.height) * 0.134)
    }
#endif
}

// MARK: - Environment：屏幕圆角（Focus / 同心卡片等）

enum OhanaDisplayCornerRadiusKey: EnvironmentKey {
    static var defaultValue: CGFloat { ScreenCompat.displayCornerRadius }
}

extension EnvironmentValues {
    /// 设备显示圆角半径；默认与 `ScreenCompat.displayCornerRadius` 一致，可在预览中覆盖。
    var ohanaDisplayCornerRadius: CGFloat {
        get { self[OhanaDisplayCornerRadiusKey.self] }
        set { self[OhanaDisplayCornerRadiusKey.self] = newValue }
    }
}

// MARK: - Ohana Glass Modifier
struct OhanaGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var fillOpacity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.ohanaCardSurface.opacity(max(0.72, fillOpacity)))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
            }
    }
}

// MARK: - Card Modifiers
struct NeoWhiteCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.ohanaPrimaryText)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.ohanaCardSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// 与 GO Focus 首页区块一致；表面色跟随全局浅/深色偏好。
struct GoIslandModuleCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func goIslandModuleCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GoIslandModuleCardModifier(cornerRadius: cornerRadius))
    }
}

struct NeoDarkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.ohanaCardSurface)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Button Modifiers
struct CapsuleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(OhanaFont.headline(.semibold))
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 10)
            .background(Color.ohanaCardSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.ohanaCardStroke, lineWidth: 1))
    }
}

struct NeonCapsuleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(OhanaFont.headline(.bold))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 10)
            .background(Color.goPrimary, in: Capsule())
    }
}

struct CapsuleButtonDarkModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(OhanaFont.headline(.semibold))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.goPrimary, in: Capsule())
    }
}

// MARK: - Font Modifiers
struct HeroTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(OhanaFont.largeTitle(.heavy))
            .textCase(.lowercase)
    }
}

struct GiantMetricStyle: ViewModifier {
    var size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(OhanaFont.metric(size: size, .heavy))
    }
}

// MARK: - Go UI Card Modifiers
struct GoCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .background(color, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

struct GoBlueCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.goCardBlue, Color.goPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
            }
    }
}

struct GoTranslucentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

struct GoGlassBackground<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S
    
    func body(content: Content) -> some View {
        content
            .background(Color.ohanaControlFill.opacity(colorScheme == .dark ? 0.92 : 0.86), in: shape)
            .overlay {
                shape.strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
            }
    }
}

struct GoSelectableSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isSelected: Bool
    var tint: Color
    var shape: S

    private var surface: Color {
        if isSelected {
            return tint.opacity(colorScheme == .dark ? 0.22 : 0.18)
        }
        return Color.ohanaControlFill
    }

    private var border: Color {
        if isSelected {
            return tint.opacity(colorScheme == .dark ? 0.40 : 0.30)
        }
        return Color.clear
    }

    func body(content: Content) -> some View {
        content
            .background(surface, in: shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: 1)
            }
    }
}

// MARK: - View Extensions
extension View {
    func ohanaGlassStyle(cornerRadius: CGFloat = 32, fillOpacity: CGFloat = 0.12) -> some View {
        modifier(OhanaGlassModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity))
    }
    
    func neoWhiteCard(cornerRadius: CGFloat = 32) -> some View {
        modifier(NeoWhiteCardModifier(cornerRadius: cornerRadius))
    }
    
    func neoDarkCard() -> some View {
        modifier(NeoDarkCardModifier())
    }
    
    func capsuleButton() -> some View {
        modifier(CapsuleButtonModifier())
    }
    
    func neonCapsuleButton() -> some View {
        modifier(NeonCapsuleButtonModifier())
    }
    
    func goGlassBackground<S: InsettableShape>(_ shape: S) -> some View {
        modifier(GoGlassBackground(shape: shape))
    }

    func goSelectableSurface<S: InsettableShape>(
        isSelected: Bool,
        tint: Color,
        in shape: S
    ) -> some View {
        modifier(GoSelectableSurface(isSelected: isSelected, tint: tint, shape: shape))
    }
    
    func capsuleButtonDark() -> some View {
        modifier(CapsuleButtonDarkModifier())
    }
    
    func heroTitleStyle() -> some View {
        modifier(HeroTitleStyle())
    }
    
    func giantMetricStyle(size: CGFloat = 60) -> some View {
        modifier(GiantMetricStyle(size: size))
    }
    
    func arkMetric(size: CGFloat = 80) -> some View {
        font(OhanaFont.metric(size: size, .heavy))
    }
    
    func arkMetricSM(size: CGFloat = 40) -> some View {
        font(OhanaFont.metric(size: size, .heavy))
    }
    
    // MARK: - Go UI Style Extensions
    func goCard(color: Color = Color.ohanaCardSurface, cornerRadius: CGFloat = 24) -> some View {
        modifier(GoCardModifier(cornerRadius: cornerRadius, color: color))
    }
    
    func goBlueCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(GoBlueCardModifier(cornerRadius: cornerRadius))
    }

    /// Preferred V4 name for the solid flat business-card surface.
    func goSolidCardSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(GoTranslucentCardModifier(cornerRadius: cornerRadius))
    }
    
    func goTranslucentCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GoTranslucentCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Go Dashed Divider
struct GoDashedDivider: View {
    var color: Color = Color.ohanaDivider
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(color)
        }
        .frame(height: 1)
    }
}

// MARK: - Go Bottom Tab Bar
struct GoBottomTabBar: View {
    let tabs: [(icon: String, label: String)]
    @Binding var selectedIndex: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(GoMotion.feedback) {
                        selectedIndex = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(OhanaFont.headline(.semibold))
                        if selectedIndex == index {
                            Text(tab.label)
                                .font(OhanaFont.callout(.bold))
                        }
                    }
                    .foregroundStyle(selectedIndex == index ? Color.goPrimary : Color.ohanaSecondaryText)
                    .padding(.horizontal, selectedIndex == index ? 20 : 16)
                    .padding(.vertical, 12)
                    .background {
                        if selectedIndex == index {
                            Capsule()
                                .fill(Color.goPrimary.opacity(0.12))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(6)
        .goGlassBackground(Capsule())
    }
}

// MARK: - Ohana Sheet Wrapper
struct OhanaSheetPageScaffold<Leading: View, Trailing: View, Content: View, Floating: View>: View {
    let title: String
    var subtitle: String? = nil
    var showsCloseButton: Bool = true
    let onClose: () -> Void
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content
    @ViewBuilder let floating: () -> Floating

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                fixedHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .zIndex(2)

                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 128)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
            }

            floating()
                .padding(.trailing, 18)
                .padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fixedHeader: some View {
        HStack(spacing: 12) {
            leading()

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            Spacer(minLength: 8)
            trailing()

            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark") // a11y: allow close button has localized label; icon hidden below
                        .font(OhanaFont.body(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
        }
    }
}

struct OhanaSheetWrapper<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        OhanaSheetPageScaffold(
            title: title,
            onClose: onDismiss,
            leading: { EmptyView() },
            trailing: { EmptyView() },
            content: {
                content()
            },
            floating: { EmptyView() }
        )
        .presentationBackground {
            Color.clear
        }
    }
}

extension View {
    /// Standard presentation chrome for long Ohana sheet pages.
    ///
    /// The page content itself should use `OhanaSheetPageScaffold` (fixed title/close
    /// chrome, hidden navigation bar, elastic vertical content). This modifier keeps
    /// the host sheet behavior consistent across entry points.
    func ohanaSheetPagePresentation(
        detents: Set<PresentationDetent> = OhanaSheetDetents.full,
        cornerRadius: CGFloat = OhanaRadius.sheetPage
    ) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(cornerRadius)
            .presentationBackground(Color.clear)
            .presentationContentInteraction(.scrolls)
    }

    /// Standard presentation chrome for compact account/security pickers that are
    /// still system sheets rather than inline popups.
    func ohanaCompactSheetPresentation(
        detents: Set<PresentationDetent>,
        cornerRadius: CGFloat = OhanaRadius.sheetCompact
    ) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(cornerRadius)
            .presentationBackground(Color.clear)
    }
}

// MARK: - Dashed Divider
struct OhanaDashedDivider: View {
    var color: Color = Color.ohanaDivider
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundStyle(color)
        }
        .frame(height: 1)
    }
}

// MARK: - Capsule Bar Shape
struct CapsuleBarShape: Shape {
    var cornerRadius: CGFloat = 4
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return path
    }
}

// MARK: - Ohana Font System (SF Pro Rounded, always use these)
enum OhanaFont {
    static func adaptive(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        let style: Font.TextStyle
        switch size {
        case ..<11:
            style = .caption2
        case ..<13:
            style = .caption
        case ..<15:
            style = .footnote
        case ..<17:
            style = .callout
        case ..<20:
            style = .headline
        case ..<23:
            style = .title3
        case ..<28:
            style = .title2
        case ..<34:
            style = .title
        default:
            style = .largeTitle
        }
        return .system(style, design: design).weight(weight)
    }

    static func largeTitle(_ weight: Font.Weight = .black) -> Font {
        adaptive(size: 34, weight: weight, design: .rounded)
    }
    static func title(_ weight: Font.Weight = .bold) -> Font {
        adaptive(size: 24, weight: weight, design: .rounded)
    }
    static func title2(_ weight: Font.Weight = .bold) -> Font {
        adaptive(size: 20, weight: weight, design: .rounded)
    }
    static func title3(_ weight: Font.Weight = .semibold) -> Font {
        adaptive(size: 17, weight: weight, design: .rounded)
    }
    static func headline(_ weight: Font.Weight = .bold) -> Font {
        adaptive(size: 16, weight: weight, design: .rounded)
    }
    static func body(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 15, weight: weight, design: .rounded)
    }
    static func callout(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 14, weight: weight, design: .rounded)
    }
    static func subheadline(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 13, weight: weight, design: .rounded)
    }
    static func footnote(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 12, weight: weight, design: .rounded)
    }
    static func caption(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 11, weight: weight, design: .rounded)
    }
    static func caption2(_ weight: Font.Weight = .medium) -> Font {
        adaptive(size: 10, weight: weight, design: .rounded)
    }
    static func metric(size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        adaptive(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Alert Banner (Figma Design System Tokens)
enum AlertStyle {
    case success, warning, error, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }
    var bg: Color {
        switch self {
        case .success: return .alertSuccessBg
        case .warning: return .alertWarningBg
        case .error:   return .alertErrorBg
        case .info:    return .alertInfoBg
        }
    }
    var border: Color {
        switch self {
        case .success: return .alertSuccessBorder
        case .warning: return .alertWarningBorder
        case .error:   return .alertErrorBorder
        case .info:    return .alertInfoBorder
        }
    }
    var textColor: Color {
        switch self {
        case .success: return .alertSuccessText
        case .warning: return .alertWarningText
        case .error:   return .alertErrorText
        case .info:    return .alertInfoText
        }
    }
    var iconColor: Color {
        switch self {
        case .success: return .alertSuccessIcon
        case .warning: return .alertWarningIcon
        case .error:   return .alertErrorIcon
        case .info:    return .alertInfoIcon
        }
    }
}

struct AlertBanner: View {
    let style: AlertStyle
    let message: String
    var title: String? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.icon)
                .font(OhanaFont.headline(.semibold))
                .foregroundStyle(style.iconColor)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(style.textColor)
                }
                Text(message)
                    .font(OhanaFont.subheadline())
                    .foregroundStyle(style.textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark") // a11y: allow toast dismiss button has localized label; icon hidden below
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(style.textColor.opacity(0.6))
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(style.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style.border, lineWidth: 1)
        )
    }
}

// MARK: - Noise Texture View
struct NoiseTextureView: View {
    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let area = max(1, size.width * size.height)
            let baselineArea: CGFloat = 390 * 844
            let density = min(1.25, max(0.45, area / baselineArea))
            let pointCount = Int(640 * density)

            for index in 0..<pointCount {
                let x = CGFloat(Self.unitNoise(index, salt: 17)) * size.width
                let y = CGFloat(Self.unitNoise(index, salt: 71)) * size.height
                let opacity = 0.018 + Self.unitNoise(index, salt: 131) * 0.045
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private static func unitNoise(_ index: Int, salt: UInt64) -> Double {
        var value = UInt64(index + 1) &* 0x9E37_79B9_7F4A_7C15 &+ salt
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value & 0xFFFF) / Double(UInt16.max)
    }
}

// MARK: - Coconut Reward Overlay Modifier
/// 全局椰子奖励弹跳动效 modifier
/// 用法：.coconutRewardOverlay(trigger: $showReward, amount: 50)
struct CoconutRewardModifier: ViewModifier {
    @Binding var trigger: Bool
    var amount: Int
    var label: String?

    @State private var phase: AnimPhase = .hidden

    enum AnimPhase { case hidden, bouncing, flying }

    func body(content: Content) -> some View {
        content.overlay(alignment: .center) {
            if phase != .hidden {
                VStack(spacing: 6) {
                    Text("🥥")
                        .font(OhanaFont.metric(size: phase == .bouncing ? 72 : 36, .heavy))
                        .scaleEffect(phase == .bouncing ? 1.0 : 0.2)
                        .opacity(phase == .flying ? 0 : 1)
                        .offset(y: phase == .flying ? -300 : 0)
                        .animation(GoMotion.fab, value: phase)

                    if phase == .bouncing {
                        Text("+\(amount) 🥥")
                            .font(OhanaFont.metric(size: 28, .black))
                            .foregroundStyle(Color.goPrimary)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))

                        if let lbl = label {
                            Text(lbl)
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(32)
                .background(Color.ohanaCardSurfaceElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .onChange(of: trigger) { _, newVal in
            guard newVal else { return }
            withAnimation(GoMotion.fab) { phase = .bouncing }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(GoMotion.fab) { phase = .flying }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                phase = .hidden
                trigger = false
            }
        }
    }
}

// MARK: - Coconut Balance Toolbar Modifier
struct CoconutBalanceToolbarModifier: ViewModifier {
    let onTap: () -> Void
    
    init(onTap: @escaping () -> Void = {}) {
        self.onTap = onTap
    }
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CoconutBalanceCapsule(onTap: onTap)
                }
            }
    }
}

extension View {
    /// 在任意视图上叠加椰子奖励弹跳动效
    /// - Parameters:
    ///   - trigger: 传入 @State Bool，设为 true 触发动画，动画结束后自动重置为 false
    ///   - amount: 奖励数量
    ///   - label: 可选副标题
    func coconutRewardOverlay(trigger: Binding<Bool>, amount: Int, label: String? = nil) -> some View {
        self.modifier(CoconutRewardModifier(trigger: trigger, amount: amount, label: label))
    }
    
    /// 为 NavigationStack 页面添加椰子余额胶囊到 toolbar
    /// - Parameter onTap: 点击胶囊时的回调，默认打开 CoconutLogView
    func withCoconutToolbar(onTap: @escaping () -> Void = {}) -> some View {
        self.modifier(CoconutBalanceToolbarModifier(onTap: onTap))
    }
}
