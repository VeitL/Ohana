//
//  UltimateGlassCard.swift
//  Ohana
//

import SwiftUI

/// A view that wraps UIVisualEffectView to force a specific UIBlurEffect style
/// because SwiftUI's Material ignores `.environment(\.colorScheme)` overrides.
private struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    var colorScheme: UIUserInterfaceStyle // Added to force light/dark mode
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        // Force the trait collection on the view to guarantee it renders as requested
        // even if the system is in the opposite mode.
        view.overrideUserInterfaceStyle = colorScheme
        // For good measure, we can also use non-adaptive styles if it still fails,
        // but overriding userInterfaceStyle is the correct iOS 13+ way.
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Just update unconditionally as UIBlurEffect doesn't expose `style`
        uiView.effect = UIBlurEffect(style: blurStyle)
        uiView.overrideUserInterfaceStyle = colorScheme
    }
}

/// Configuration for inner elements (like TextFields, Tags, secondary backgrounds)
/// that sit directly on top of the `UltimateGlassCard`.
public struct InnerPillConfig {
    public var isDark: Bool
    
    public init(isDark: Bool) {
        self.isDark = isDark
    }
    
    public var bg: Color {
        isDark ? .white.opacity(0.1) : .black.opacity(0.04)
    }
    
    public var text: Color {
        // Slate 600 map -> roughly #475569
        isDark ? .white.opacity(0.8) : Color(hex: "475569")
    }
}

/// A standard tag component built for the Glass UI.
public struct InnerGlassTag: View {
    public var text: String
    public var isDark: Bool
    
    public init(text: String, isDark: Bool) {
        self.text = text
        self.isDark = isDark
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(InnerPillConfig(isDark: isDark).text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(InnerPillConfig(isDark: isDark).bg, in: Capsule())
    }
}

/// The core container for all cards and bento boxes in the Ohana UI V2 Guidelines.
/// Implements the full 8-layer Liquid Glass refraction system from the Ohana Design System V2.
public struct UltimateGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    public var isDarkMode: Bool
    public let content: () -> Content

    public init(isDarkMode: Bool? = nil, @ViewBuilder content: @escaping () -> Content) {
        if let explicit = isDarkMode {
            self.isDarkMode = explicit
            self.useExplicitMode = true
        } else {
            self.isDarkMode = true
            self.useExplicitMode = false
        }
        self.content = content
    }

    @State private var colorSchemeState: ColorScheme = .dark
    private var useExplicitMode: Bool

    private var actualMode: Bool {
        useExplicitMode ? isDarkMode : (colorSchemeState == .dark)
    }

    public var body: some View {
        content()
            .background { cardBackground }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onChange(of: colorScheme) { _, newScheme in
                if !useExplicitMode { colorSchemeState = newScheme }
            }
            .onAppear {
                if !useExplicitMode { colorSchemeState = colorScheme }
            }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if actualMode {
            darkBackground
        } else {
            lightBackground
        }
    }

    // MARK: Dark Mode — 8层 Liquid Glass 折射系统
    @ViewBuilder
    private var darkBackground: some View {
        let r = RoundedRectangle(cornerRadius: 24, style: .continuous)
        r.fill(.ultraThinMaterial)
            .overlay { darkL2(r) }
            .overlay { darkL3(r) }
            .overlay { darkL4(r) }
            .overlay { darkL5(r) }
            .overlay { darkL6blue }
            .overlay { darkL6red }
            .overlay(alignment: .top) { darkL7 }
            .overlay(alignment: .topLeading) { darkL8 }
            .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 10)
            .shadow(color: Color.white.opacity(0.06), radius: 30, x: 0, y: 20)
    }

    private func darkL2(_ r: RoundedRectangle) -> some View {
        r.fill(Color.white.opacity(0.05))
    }

    private func darkL3(_ r: RoundedRectangle) -> some View {
        r.fill(LinearGradient(stops: [
            .init(color: .white.opacity(0.07), location: 0),
            .init(color: .clear,               location: 0.07),
            .init(color: .clear,               location: 0.93),
            .init(color: .white.opacity(0.04), location: 1),
        ], startPoint: .top, endPoint: .bottom))
    }

    private func darkL4(_ r: RoundedRectangle) -> some View {
        r.fill(RadialGradient(
            colors: [.clear, .black.opacity(0.07)],
            center: .center, startRadius: 0, endRadius: 160
        )).blendMode(.multiply)
    }

    private func darkL5(_ r: RoundedRectangle) -> some View {
        r.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
    }

    private var darkL6blue: some View {
        RoundedRectangle(cornerRadius: 24.5, style: .continuous)
            .strokeBorder(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.07), lineWidth: 1.0)
    }

    private var darkL6red: some View {
        RoundedRectangle(cornerRadius: 23.5, style: .continuous)
            .strokeBorder(Color(red: 1.0, green: 0.3, blue: 0.2).opacity(0.05), lineWidth: 0.5)
    }

    private var darkL7: some View {
        Capsule()
            .fill(LinearGradient(stops: [
                .init(color: .clear,               location: 0),
                .init(color: .white.opacity(0.50), location: 0.3),
                .init(color: .white.opacity(0.55), location: 0.5),
                .init(color: .white.opacity(0.50), location: 0.7),
                .init(color: .clear,               location: 1),
            ], startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.5)
            .padding(.horizontal, 20)
            .padding(.top, 1)
    }

    private var darkL8: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                center: .center, startRadius: 0, endRadius: 55
            ))
            .frame(width: 110, height: 70)
            .offset(x: -12, y: -18)
            .blur(radius: 8)
            .allowsHitTesting(false)
    }

    // MARK: Light Mode — 强制 Light Blur + 白色渐变折射
    @ViewBuilder
    private var lightBackground: some View {
        let r = RoundedRectangle(cornerRadius: 24, style: .continuous)
        ZStack {
            VisualEffectBlur(blurStyle: .light, colorScheme: .light)
            LinearGradient(
                colors: [.white.opacity(0.68), .white.opacity(0.28)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .clipShape(r)
        .overlay { lightL3(r) }
        .overlay { lightL4(r) }
        .overlay { lightL5(r) }
        .overlay { lightL6 }
        .overlay(alignment: .top) { lightL7 }
        .overlay(alignment: .topLeading) { lightL8 }
        .shadow(color: .black.opacity(0.08), radius: 32, x: 0, y: 16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private func lightL3(_ r: RoundedRectangle) -> some View {
        r.fill(RadialGradient(
            colors: [.clear, .white.opacity(0.18)],
            center: .center, startRadius: 48, endRadius: 160
        )).blendMode(.screen)
    }

    private func lightL4(_ r: RoundedRectangle) -> some View {
        r.fill(RadialGradient(
            colors: [.clear, .black.opacity(0.045)],
            center: .center, startRadius: 0, endRadius: 160
        )).blendMode(.multiply)
    }

    private func lightL5(_ r: RoundedRectangle) -> some View {
        r.strokeBorder(LinearGradient(
            colors: [.white.opacity(0.75), .white.opacity(0.25)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ), lineWidth: 0.5)
    }

    private var lightL6: some View {
        RoundedRectangle(cornerRadius: 24.5, style: .continuous)
            .strokeBorder(Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.04), lineWidth: 1.0)
    }

    private var lightL7: some View {
        Capsule()
            .fill(LinearGradient(stops: [
                .init(color: .clear,               location: 0),
                .init(color: .white.opacity(0.88), location: 0.25),
                .init(color: .white.opacity(0.88), location: 0.75),
                .init(color: .clear,               location: 1),
            ], startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
            .padding(.top, 1)
    }

    private var lightL8: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [.white.opacity(0.42), .white.opacity(0.14), .clear],
                center: .center, startRadius: 0, endRadius: 65
            ))
            .frame(width: 130, height: 80)
            .offset(x: -10, y: -20)
            .blur(radius: 10)
            .allowsHitTesting(false)
    }
}
