//
//  OhanaDesignSystem.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

// MARK: - Global Coconut Balance Capsule
struct CoconutBalanceCapsule: View {
    @State private var questManager = QuestManager.shared
    let onTap: () -> Void
    
    init(onTap: @escaping () -> Void = {}) {
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text("🥥").font(.system(size: 13))
                Text("\(questManager.coconutCount)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: questManager.coconutCount)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(height: 30)
            .fixedSize(horizontal: true, vertical: false)
            .background(Color.goLime, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen Compat
struct ScreenCompat {
    static var bounds: CGRect {
        UIScreen.main.bounds
    }
    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }
}

// MARK: - Ohana Glass Modifier
struct OhanaGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var fillOpacity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.20),
                                .white.opacity(0.04),
                                .white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Card Modifiers
struct NeoWhiteCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
    }
}

struct NeoDarkCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.arkCardDark)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Button Modifiers
struct CapsuleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

struct NeonCapsuleButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "E0FF00"), in: Capsule())
            .shadow(color: Color(hex: "E0FF00").opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

struct CapsuleButtonDarkModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.arkInk, in: Capsule())
    }
}

// MARK: - Font Modifiers
struct HeroTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .textCase(.lowercase)
    }
}

struct GiantMetricStyle: ViewModifier {
    var size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .heavy, design: .rounded))
    }
}

// MARK: - Go UI Card Modifiers
struct GoCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
    }
}

struct GoTranslucentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.goDarkBlue.opacity(0.82),
                                Color.goDeepNavy.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.08))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.13), lineWidth: 1)
            }
    }
}

struct GoGlassBackground<S: InsettableShape>: ViewModifier {
    var shape: S
    
    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.goDarkBlue.opacity(0.82),
                                Color.goDeepNavy.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        shape
                            .fill(.ultraThinMaterial.opacity(0.08))
                    )
            }
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 24, y: -6)
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
        font(.system(size: size, weight: .heavy, design: .rounded))
    }
    
    func arkMetricSM(size: CGFloat = 40) -> some View {
        font(.system(size: size, weight: .heavy, design: .rounded))
    }
    
    // MARK: - Go UI Style Extensions
    func goCard(color: Color = .white, cornerRadius: CGFloat = 24) -> some View {
        modifier(GoCardModifier(cornerRadius: cornerRadius, color: color))
    }
    
    func goBlueCard(cornerRadius: CGFloat = 24) -> some View {
        modifier(GoBlueCardModifier(cornerRadius: cornerRadius))
    }
    
    func goTranslucentCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GoTranslucentCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Go Dashed Divider
struct GoDashedDivider: View {
    var color: Color = .white.opacity(0.2)
    
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedIndex = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        if selectedIndex == index {
                            Text(tab.label)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(selectedIndex == index ? Color.goPrimary : .gray)
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
            }
        }
        .padding(6)
        .goGlassBackground(Capsule())
    }
}

// MARK: - Ohana Sheet Wrapper
struct OhanaSheetWrapper<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                ScrollView {
                    content()
                        .padding(.horizontal, 16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Dashed Divider
struct OhanaDashedDivider: View {
    var color: Color = .white.opacity(0.25)
    
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
    static func largeTitle(_ weight: Font.Weight = .black) -> Font {
        .system(size: 34, weight: weight, design: .rounded)
    }
    static func title(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 24, weight: weight, design: .rounded)
    }
    static func title2(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 20, weight: weight, design: .rounded)
    }
    static func title3(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 17, weight: weight, design: .rounded)
    }
    static func headline(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 16, weight: weight, design: .rounded)
    }
    static func body(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 15, weight: weight, design: .rounded)
    }
    static func callout(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 14, weight: weight, design: .rounded)
    }
    static func subheadline(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 13, weight: weight, design: .rounded)
    }
    static func footnote(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 12, weight: weight, design: .rounded)
    }
    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 11, weight: weight, design: .rounded)
    }
    static func caption2(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 10, weight: weight, design: .rounded)
    }
    static func metric(size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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
                    Image(systemName: "xmark")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(style.textColor.opacity(0.6))
                }
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
        Canvas { context, size in
            for _ in 0..<3000 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let opacity = Double.random(in: 0.02...0.08)
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
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
                        .font(.system(size: phase == .bouncing ? 72 : 36))
                        .scaleEffect(phase == .bouncing ? 1.0 : 0.2)
                        .opacity(phase == .flying ? 0 : 1)
                        .offset(y: phase == .flying ? -300 : 0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: phase)

                    if phase == .bouncing {
                        Text("+\(amount) 🥥")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goLime)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))

                        if let lbl = label {
                            Text(lbl)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .transition(.opacity)
                        }
                    }
                }
                .padding(32)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .onChange(of: trigger) { _, newVal in
            guard newVal else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { phase = .bouncing }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeIn(duration: 0.4)) { phase = .flying }
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

// MARK: - Ohana Unified UI Components (Phase 60)

public struct OhanaStandardCardModifier: ViewModifier {
    var isDarkMode: Bool
    var cornerRadius: CGFloat
    
    public func body(content: Content) -> some View {
        UltimateGlassCard(isDarkMode: isDarkMode) {
            content
        }
    }
}

public extension View {
    func ohanaStandardCard(isDarkMode: Bool, cornerRadius: CGFloat = 20) -> some View {
        modifier(OhanaStandardCardModifier(isDarkMode: isDarkMode, cornerRadius: cornerRadius))
    }
}

// 自动读取 colorScheme 的版本
public struct AutoOhanaStandardCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    
    public func body(content: Content) -> some View {
        content.modifier(OhanaStandardCardModifier(isDarkMode: colorScheme == .dark, cornerRadius: cornerRadius))
    }
}

public extension View {
    func ohanaStandardCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(AutoOhanaStandardCardModifier(cornerRadius: cornerRadius))
    }
}

/// Icon Button Style B — subtle gradient bg, colored icon, no border
public struct OhanaIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    public init(icon: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [color.opacity(0.2), color.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
    }
}

/// Alert Style D — solid color capsule/toast
public struct OhanaAlertBanner: View {
    let icon: String
    let message: String
    let bg: Color
    let fg: Color
    
    public init(icon: String, message: String, bg: Color, fg: Color) {
        self.icon = icon
        self.message = message
        self.bg = bg
        self.fg = fg
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(fg)
            Text(message).font(OhanaFont.callout(.bold)).foregroundStyle(fg)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(bg, in: Capsule())
    }
}

/// Tag Style C — dot + weighted background
public struct OhanaChip: View {
    let label: String
    let color: Color
    let selected: Bool
    var isDarkMode: Bool
    let action: (() -> Void)?
    
    public init(label: String, color: Color, selected: Bool, isDarkMode: Bool, action: (() -> Void)? = nil) {
        self.label = label
        self.color = color
        self.selected = selected
        self.isDarkMode = isDarkMode
        self.action = action
    }
    
    public var body: some View {
        let chipContent = HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(OhanaFont.callout(.bold))
                .foregroundStyle(selected ? (isDarkMode ? .white : Color.arkInk) : (isDarkMode ? .white.opacity(0.5) : Color.arkInk.opacity(0.5)))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            isDarkMode ? (selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                      : (selected ? color.opacity(0.12) : Color.black.opacity(0.04)),
            in: RoundedRectangle(cornerRadius: 10)
        )
        
        if let action = action {
            Button(action: action) { chipContent }
        } else {
            chipContent
        }
    }
}

/// QA Card Glass Style
public struct OhanaQACard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isDarkMode: Bool
    
    public init(title: String, value: String, icon: String, color: Color, isDarkMode: Bool) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.isDarkMode = isDarkMode
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 24, weight: .bold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(OhanaFont.title2(.black)).foregroundStyle(isDarkMode ? .white : Color.arkInk)
                Text(title).font(OhanaFont.caption2(.bold)).foregroundStyle(isDarkMode ? .white.opacity(0.5) : Color.arkInk.opacity(0.5))
            }
        }
        .frame(width: 130, alignment: .leading)
        .padding(16)
        .ohanaStandardCard(isDarkMode: isDarkMode)
    }
}
