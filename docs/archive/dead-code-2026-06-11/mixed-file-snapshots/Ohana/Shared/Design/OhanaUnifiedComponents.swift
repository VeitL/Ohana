//
//  OhanaUnifiedComponents.swift
//  Ohana
//
//  Standard cards, popup chrome, chips, QA cards, and adaptive sheet helpers.
//

import SwiftUI

// MARK: - Ohana Unified UI Components (Phase 60)

public struct OhanaStandardCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }
}

public extension View {
    func ohanaStandardCard(isDarkMode _: Bool, cornerRadius: CGFloat = 20) -> some View {
        modifier(OhanaStandardCardModifier(cornerRadius: cornerRadius))
    }
}

// 自动读取 colorScheme 的版本
public struct AutoOhanaStandardCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content.modifier(OhanaStandardCardModifier(cornerRadius: cornerRadius))
    }
}

public extension View {
    func ohanaStandardCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(AutoOhanaStandardCardModifier(cornerRadius: cornerRadius))
    }
}

public struct OhanaPopupGlassSurface: View {
    var cornerRadius: CGFloat = 34
    @Environment(\.colorScheme) private var colorScheme

    public init(cornerRadius: CGFloat = 34) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(false), in: shape)

            shape
                .fill(Color.ohanaPopupSurfaceFill)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20), // ui-v4: allow native glass sheen
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.26 : 0.03) // ui-v4: allow native glass depth tint
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)
            .allowsHitTesting(false)

            shape
                .strokeBorder(Color.ohanaPopupSurfaceStroke, lineWidth: colorScheme == .dark ? 1.0 : 0.8)
                .allowsHitTesting(false)

            shape
                .strokeBorder(Color.ohanaPopupSurfaceHighlight, lineWidth: 1)
                .blendMode(.screen)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
    }
}

struct OhanaPopupDragHandle: View {
    var tint: Color

    init(tint: Color = Color.ohanaPrimaryText.opacity(0.22)) {
        self.tint = tint
    }

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(tint)
                .frame(width: 48, height: 5)
                .padding(.top, 4)
        }
        .frame(width: 112, height: 28, alignment: .top)
        .contentShape(Rectangle())
    }
}

struct OhanaPopupCloseButton: View {
    var tint: Color
    var action: () -> Void

    init(tint: Color = Color.ohanaPrimaryText, action: @escaping () -> Void) {
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark") // a11y: allow popup close button has localized label; icon hidden below
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
    }
}

/// Icon Button Style B — plain monochrome glyph, no colored tile
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
                .font(OhanaFont.headline(.bold))
                .foregroundStyle(Color.ohanaFunctionalIcon)
                .frame(width: 44, height: 44)
                .background(
                    Color.ohanaControlFill,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.row)
                )
        }
        .buttonStyle(ScaleButtonStyle())
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
            Image(systemName: icon).font(OhanaFont.callout(.bold)).foregroundStyle(fg)
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
            Circle().fill(color).frame(width: 6, height: 6) // a11y: allow decorative color swatch; hidden from accessibility below
                .accessibilityHidden(true)
            Text(label).font(OhanaFont.callout(.bold))
                .foregroundStyle(selected ? Color.ohanaPrimaryText : Color.ohanaSecondaryText)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            selected ? color.opacity(0.14) : Color.ohanaControlFill,
            in: RoundedRectangle(cornerRadius: OhanaRadius.badge)
        )

        if let action {
            Button(action: action) { chipContent }
                .buttonStyle(ScaleButtonStyle())
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
            Image(systemName: icon).font(OhanaFont.title(.bold)).foregroundStyle(Color.ohanaFunctionalIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(OhanaFont.title2(.black)).foregroundStyle(Color.ohanaPrimaryText)
                Text(title).font(OhanaFont.caption2(.bold)).foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .frame(width: 130, alignment: .leading)
        .padding(16)
        .ohanaStandardCard(isDarkMode: isDarkMode)
    }
}

// MARK: - Adaptive Sheet Height

private struct OhanaAdaptiveSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

public extension View {
    func ohanaAdaptiveSheetContentHeight(
        _ height: Binding<CGFloat>,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        chromePadding: CGFloat = 70
    ) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: OhanaAdaptiveSheetHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
            }
        }
        .onPreferenceChange(OhanaAdaptiveSheetHeightPreferenceKey.self) { rawHeight in
            let clampedHeight = min(max(rawHeight + chromePadding, minHeight), maxHeight)
            guard clampedHeight.isFinite, clampedHeight > 0 else { return }
            DispatchQueue.main.async {
                guard abs(height.wrappedValue - clampedHeight) > 6 else { return }
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    height.wrappedValue = clampedHeight
                }
            }
        }
    }
}
