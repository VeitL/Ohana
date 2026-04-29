//
//  UltimateGlassCard.swift
//  Ohana
//

import SwiftUI

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

/// The core container for legacy cards and bento boxes, backed by the current Go Focus surface.
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

    // MARK: Dark Mode
    @ViewBuilder
    private var darkBackground: some View {
        let r = RoundedRectangle(cornerRadius: 24, style: .continuous)
        r.fill(Color.white.opacity(0.075))
            .overlay {
                r.strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3)
    }

    // MARK: Light Mode
    @ViewBuilder
    private var lightBackground: some View {
        let r = RoundedRectangle(cornerRadius: 24, style: .continuous)
        r.fill(Color.white.opacity(0.86))
            .overlay {
                r.strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

}
