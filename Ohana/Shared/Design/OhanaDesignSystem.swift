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
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .fill(Color.ohanaCardSurface)
            }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
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

    func goGlassBackground(_ shape: some InsettableShape) -> some View {
        modifier(GoGlassBackground(shape: shape))
    }

    func goSelectableSurface(
        isSelected: Bool,
        tint: Color,
        in shape: some InsettableShape
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
    var color: Color = .ohanaDivider

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

// MARK: - Ohana Sheet Wrapper
struct OhanaSheetPageScaffold<Leading: View, Trailing: View, Content: View, Floating: View>: View {
    let title: String
    var subtitle: String?
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
    var color: Color = .ohanaDivider

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

// MARK: - Noise Texture View
struct NoiseTextureView: View {
    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let area = max(1, size.width * size.height)
            let baselineArea: CGFloat = 390 * 844
            let density = min(1.25, max(0.45, area / baselineArea))
            let pointCount = Int(640 * density)

            for index in 0 ..< pointCount {
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
                .background(Color.ohanaCardSurfaceElevated.opacity(0.92), in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
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
