//
//  LiquidGlassButton.swift
//  Ohana
//

import SwiftUI

/// A premium, high-gloss button component that implements a "Liquid Droplet" effect.
/// Inspired by modern glassmorphism and liquid design systems.
struct LiquidGlassButton<Content: View>: View {
    var isPressed: Bool
    var isDone: Bool = false
    var cornerRadius: CGFloat = 18
    var tintColor: Color? = nil
    let content: Content
    
    init(isPressed: Bool, isDone: Bool = false, cornerRadius: CGFloat = 18, tintColor: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.isPressed = isPressed
        self.isDone = isDone
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.content = content()
    }
    
    private var baseColor: Color {
        tintColor ?? (isDone ? Color.goPrimary : Color.black)
    }
    
    var body: some View {
        ZStack {
            // Layer 1: Base Glass Material
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: baseColor.opacity(0.12), radius: 8, x: 0, y: 4)
            
            // Layer 2: Color Tint
            if isDone || tintColor != nil {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseColor.opacity(0.1))
            }
            
            // Layer 3: Inner Shadow (Top-Left Light)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity((isDone || tintColor != nil) ? 0.9 : 0.6), lineWidth: 2)
                .blur(radius: 0.5)
                .offset(x: 1.5, y: 1.5)
                .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // Layer 4: Inner Shadow (Bottom-Right Dark)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(baseColor.opacity(0.4), lineWidth: 2.5)
                .blur(radius: 1.5)
                .offset(x: -1.5, y: -1.5)
                .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // Layer 5: Surface Gloss
            LinearGradient(
                colors: [.white.opacity(0.3), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // Layer 6: Outer Border
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(baseColor.opacity(0.5), lineWidth: 0.5)

            // Content
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .scaleEffect(isPressed ? 0.90 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        HStack(spacing: 20) {
            LiquidGlassButton(isPressed: false) {
                Image(systemName: "drop.fill")
                    .font(.title2)
            }
            .frame(width: 60, height: 60)
            
            LiquidGlassButton(isPressed: false, isDone: true) {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .foregroundStyle(Color.goPrimary)
            }
            .frame(width: 60, height: 60)
        }
    }
}
