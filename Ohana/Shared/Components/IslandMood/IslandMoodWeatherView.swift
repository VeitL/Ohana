//
//  IslandMoodWeatherView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI

enum IslandMood: Equatable {
    case calm
    case breezy
    case storm
    case celebrate // 解锁成就 / 今日遛狗 >5km / 里程碑日
    case plantBreeze // 植物浇水后的生态联动特效
    case cloudy // 适度焦虑：连断打卡 / 漏药 / 多日未护理
}

struct WeatherParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var emoji: String
    var opacity: Double
    var scale: CGFloat
    var speed: CGFloat
}

struct IslandMoodWeatherView: View {
    let mood: IslandMood

    @State private var particles: [WeatherParticle] = []
    @State private var timer: Timer?
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppServices.self) private var appServices
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var shouldRunParticles: Bool {
        mood != .calm &&
            !reduceMotion &&
            workloadPolicy.ambientMotionBudget(isVisible: isVisible).allowsMotion
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(OhanaFont.adaptive(size: 16))
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                isVisible = true
                updateParticles(in: geo.size)
            }
            .onDisappear {
                isVisible = false
                stopParticles()
                particles.removeAll()
            }
            .onChange(of: mood) { _, _ in
                updateParticles(in: geo.size, reset: true)
            }
            .onChange(of: shouldRunParticles) { _, _ in
                updateParticles(in: geo.size, reset: true)
            }
        }
        .allowsHitTesting(false)
    }

    private func updateParticles(in size: CGSize, reset: Bool = false) {
        stopParticles()
        if reset {
            particles.removeAll()
        }
        guard shouldRunParticles else { return }
        startParticles(in: size)
    }

    private func startParticles(in size: CGSize) {
        guard shouldRunParticles, timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.linear(duration: 3)) { // ui-v4: allow AppWorkloadPolicy-gated particle drift uses constant falling motion.
                addParticle(in: size)
                removeOldParticles()
            }
        }
    }

    private func stopParticles() {
        timer?.invalidate()
        timer = nil
    }

    private func addParticle(in size: CGSize) {
        guard particles.count < 20 else { return }

        let emojis: [String]
        switch mood {
        case .calm: return
        case .breezy: emojis = ["✨", "🌸", "🌺", "🌼"]
        case .storm: emojis = ["⚡️", "🌩️", "💧"]
        case .celebrate: emojis = ["🎉", "🌟", "✨", "🎊", "⭐️", "💫"]
        case .plantBreeze: emojis = ["🍃", "🌿", "🌱", "🍀", "🌸", "💚"]
        case .cloudy: emojis = ["🌥️", "🌫", "☁️", "💭"]
        }

        let particle = WeatherParticle(
            x: CGFloat.random(in: 0 ... size.width),
            y: -20,
            emoji: emojis.randomElement() ?? "✨",
            opacity: Double.random(in: 0.3 ... 0.7),
            scale: CGFloat.random(in: 0.6 ... 1.2),
            speed: CGFloat.random(in: 1 ... 3)
        )
        particles.append(particle)

        // 动画移动到底部
        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
            particles[index].y = size.height + 20
            particles[index].x += CGFloat.random(in: -50 ... 50)
            particles[index].opacity = 0
        }
    }

    private func removeOldParticles() {
        particles.removeAll { $0.opacity <= 0.05 }
    }
}
