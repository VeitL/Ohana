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

    private var useExplicitMode: Bool

    private var surfaceColorScheme: ColorScheme {
        useExplicitMode ? (isDarkMode ? .dark : .light) : colorScheme
    }

    public var body: some View {
        content()
            .background { cardBackground }
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        return shape
            .fill(Color.ohanaCardSurface)
            .overlay {
                shape.strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
            .environment(\.colorScheme, surfaceColorScheme)
    }
}
