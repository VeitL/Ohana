//
//  StreakFlameParticles.swift
//  Ohana
//
//  首页简化 · 可爱化：连击 ≥ 7 时在连击胶囊右上角喷一小片火苗粒子
//

import SwiftUI

struct StreakFlameParticles: View {
    @State private var phase: Double = 0

    private let particles: [Particle] = [
        Particle(emoji: "✨", delay: 0.0, dx: 4,  dyMax: -10),
        Particle(emoji: "🔥", delay: 0.4, dx: -6, dyMax: -12),
        Particle(emoji: "✨", delay: 0.8, dx: 8,  dyMax: -8),
    ]

    private struct Particle {
        let emoji: String
        let delay: Double
        let dx: CGFloat
        let dyMax: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { i in
                let p = particles[i]
                let progress = max(0, (phase + 1 - p.delay).truncatingRemainder(dividingBy: 1.6) / 1.6)
                Text(p.emoji)
                    .font(.system(size: 7))
                    .opacity(1 - progress)
                    .offset(x: p.dx * CGFloat(progress), y: p.dyMax * CGFloat(progress))
            }
        }
        .frame(width: 14, height: 14)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
