//
//  ConfettiModifier.swift
//  Ohana
//
//  模块1：满屏撒花动画（纯 SwiftUI，无第三方依赖）

import SwiftUI

// MARK: - Confetti Particle
private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let xStart: CGFloat
    let color: Color
    let rotation: Double
    let size: CGFloat
    let delay: Double
    let speed: Double
    let shape: Int   // 0=rect, 1=circle, 2=star
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animating = false

    private let colors: [Color] = [
        .goPrimary, .goYellow, .goTeal, .goOrange, .goRed, .white, Color(hex: "FF69B4")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiPiece(particle: p, screenHeight: geo.size.height, animating: animating)
                }
            }
            .onAppear {
                particles = (0..<80).map { _ in
                    ConfettiParticle(
                        xStart: CGFloat.random(in: 0...geo.size.width),
                        color: colors.randomElement()!,
                        rotation: Double.random(in: 0...360),
                        size: CGFloat.random(in: 6...14),
                        delay: Double.random(in: 0...0.8),
                        speed: Double.random(in: 1.2...2.4),
                        shape: Int.random(in: 0...2)
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    animating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat
    let animating: Bool

    var body: some View {
        Group {
            switch particle.shape {
            case 0:
                Rectangle()
                    .fill(particle.color)
                    .frame(width: particle.size * 0.6, height: particle.size)
            case 1:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            default:
                Image(systemName: "star.fill")
                    .resizable()
                    .foregroundStyle(particle.color)
                    .frame(width: particle.size, height: particle.size)
            }
        }
        .rotationEffect(.degrees(animating ? particle.rotation + 720 : particle.rotation))
        .offset(
            x: particle.xStart,
            y: animating ? screenHeight + 50 : -50
        )
        .opacity(animating ? 0 : 1)
        .animation(
            .easeIn(duration: particle.speed)
            .delay(particle.delay),
            value: animating
        )
    }
}

// MARK: - Confetti ViewModifier
struct ConfettiOverlayModifier: ViewModifier {
    @Binding var isShowing: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isShowing {
                ConfettiView()
                    .ignoresSafeArea()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            isShowing = false
                        }
                    }
            }
        }
    }
}

extension View {
    func confettiOverlay(isShowing: Binding<Bool>) -> some View {
        modifier(ConfettiOverlayModifier(isShowing: isShowing))
    }
}
