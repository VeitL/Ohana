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

// MARK: - Controlled Liquid Glass Chrome

private struct OhanaGlassIconButtonModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(ScaleButtonStyle())
                .background(Color.ohanaCardSurfaceElevated, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                }
        }
    }
}

private struct OhanaGlassProminentButtonModifier: ViewModifier {
    let tint: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(tint)
        } else {
            content
                .buttonStyle(ScaleButtonStyle())
                .background(tint, in: Capsule())
        }
    }
}

private struct OhanaGlassToolbarSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if #available(iOS 26.0, *), !reduceTransparency {
                    shape
                        .fill(.clear)
                        .glassEffect(
                            .regular
                                .tint(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.30 : 0.22))
                                .interactive(false),
                            in: shape
                        )
                } else {
                    shape.fill(Color.ohanaCardSurfaceElevated)
                }
            }
            .overlay {
                shape.strokeBorder(Color.ohanaGlassStroke.opacity(reduceTransparency ? 0.42 : 0.24), lineWidth: 1)
            }
    }
}

extension View {
    func ohanaGlassIconButton() -> some View {
        modifier(OhanaGlassIconButtonModifier())
    }

    func ohanaGlassProminentButton(tint: Color = Color.goPrimary) -> some View {
        modifier(OhanaGlassProminentButtonModifier(tint: tint))
    }

    func ohanaGlassToolbarSurface(cornerRadius: CGFloat = 28) -> some View {
        modifier(OhanaGlassToolbarSurfaceModifier(cornerRadius: cornerRadius))
    }
}

public struct OhanaPopupGlassSurface: View {
    var cornerRadius: CGFloat = 34
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(cornerRadius: CGFloat = 34) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if reduceTransparency {
                shape.fill(Color.ohanaCardSurfaceElevated)
            } else {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.interactive(false), in: shape)
            }

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
        .ohanaGlassIconButton()
        .accessibilityLabel(L10n(AppLanguage.code).tr(zh: "关闭", en: "Close", de: "Schließen"))
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
