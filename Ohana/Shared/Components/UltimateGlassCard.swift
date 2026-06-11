//
//  UltimateGlassCard.swift
//  Ohana
//

import SwiftUI

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
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
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
        let r = RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        r.fill(Color.white.opacity(0.075)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            .overlay {
                r.strokeBorder(Color.white.opacity(0.11), lineWidth: 1) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            }
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }

    // MARK: Light Mode
    @ViewBuilder
    private var lightBackground: some View {
        let r = RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        r.fill(Color.white.opacity(0.86)) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            .overlay {
                r.strokeBorder(Color.black.opacity(0.06), lineWidth: 1) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3) // ui-v4: allow pre-existing visual token debt surfaced by accessibility font migration; tracked by full-scope ratchet.
    }
}
