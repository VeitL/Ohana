//
//  MilestoneCelebrationOverlay.swift
//  Ohana
//
//  里程碑全屏庆典 — daysTogether 命中 100/365/500/1000 天时弹出
//

import SwiftUI
import SwiftData

// MARK: - 里程碑配置
struct MilestoneConfig {
    let days: Int
    let emoji: String
    let title: String
    let subtitle: String
    let accentColor: Color

    static let milestones: [MilestoneConfig] = [
        MilestoneConfig(days: 100,  emoji: "🎉", title: "百日之交",  subtitle: "相伴 100 天！感谢每一次陪伴",       accentColor: .goPrimary),
        MilestoneConfig(days: 365,  emoji: "🌟", title: "一周年纪念", subtitle: "整整一年！你们的故事刚刚开始",     accentColor: .goYellow),
        MilestoneConfig(days: 500,  emoji: "💎", title: "500 天传奇", subtitle: "500 天里程碑，你们是最棒的搭档！",  accentColor: .goCardCyan),
        MilestoneConfig(days: 1000, emoji: "👑", title: "千日王冠",  subtitle: "1000 天！这段缘分已经成为传说",     accentColor: .goOrange),
    ]

    static func match(days: Int) -> MilestoneConfig? {
        milestones.first { $0.days == days }
    }
}

// MARK: - 庆典粒子
private struct CelebParticle: Identifiable {
    let id = UUID()
    let emoji: String
    var x: CGFloat = CGFloat.random(in: 0...1)
    var delay: Double = Double.random(in: 0...0.8)
    var duration: Double = Double.random(in: 1.2...2.2)
    var size: CGFloat = CGFloat.random(in: 14...28)
}

// MARK: - 全屏庆典 View
struct MilestoneCelebrationOverlay: View {
    let pet: Pet
    let milestone: MilestoneConfig
    let onDismiss: () -> Void

    @State private var particles: [CelebParticle] = []
    @State private var particleOffsets: [UUID: CGFloat] = [:]
    @State private var particleOpacities: [UUID: Double] = [:]
    @State private var cardScale: CGFloat = 0.6
    @State private var cardOpacity: Double = 0
    @State private var glowPulse: Bool = false
    @State private var isVisible = false
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared

    @AppStorage("shop_equip_fx_firework") private var equipFxFirework: Bool = false

    private var shouldRunGlow: Bool {
        workloadPolicy.shouldRunRepeatingAnimation(isVisible: isVisible)
    }
    
    private var particleEmojis: [String] {
        equipFxFirework ? ["🎆", "🎇", "✨", "🎊", "🌟"] : ["🎉","✨","🌟","🎊","🥥","💫","🎈","🌈","⭐️"]
    }

    var body: some View {
        ZStack {
            // 全屏暗色底
            Color.arkInk.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // 粒子雨
            GeometryReader { geo in
                ForEach(particles) { p in
                    Text(p.emoji)
                        .font(OhanaFont.metric(size: p.size, .medium))
                        .position(
                            x: p.x * geo.size.width,
                            y: particleOffsets[p.id] ?? -40
                        )
                        .opacity(particleOpacities[p.id] ?? 1.0)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 主卡片
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // 光晕背景
                    Circle()
                        .fill(RadialGradient(
                            colors: [milestone.accentColor.opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 180
                        ))
                        .frame(width: 360, height: 360)
                        .scaleEffect(shouldRunGlow && glowPulse ? 1.15 : 1.0)
                        .animation(shouldRunGlow ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : GoMotion.reduced, value: glowPulse)

                    VStack(spacing: 20) {
                        // 宠物头像
                        PetAvatarPortraitView(
                            imageData: pet.avatarImageData,
                            fallbackText: pet.avatarEmoji.isEmpty ? pet.speciesEmoji : pet.avatarEmoji,
                            themeColor: milestone.accentColor,
                            size: 110,
                            backgroundOpacity: 0.2,
                            transparentScale: 0.78
                        )

                        // 大 emoji
                        Text(milestone.emoji)
                            .font(.system(size: 56))

                        // 天数
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(milestone.days)")
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(milestone.accentColor)
                            Text("天")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        }

                        // 标题
                        Text(milestone.title)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)

                        // 副标题
                        Text(milestone.subtitle)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // 宠物名
                        Text(pet.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(milestone.accentColor.opacity(0.8))
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(milestone.accentColor.opacity(0.15), in: Capsule())
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.ohanaCardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .strokeBorder(milestone.accentColor.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                    .shadow(color: milestone.accentColor.opacity(0.5), radius: 40, x: 0, y: 10) // ui-v4: allow celebratory reward glow
                }

                Spacer()

                // 关闭按钮
                Button(action: onDismiss) {
                    Text("太棒了！")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 48).padding(.vertical, 16)
                        .background(milestone.accentColor, in: Capsule())
                        .shadow(color: milestone.accentColor.opacity(0.6), radius: 16, x: 0, y: 6) // ui-v4: allow celebratory reward CTA lift
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, 52)
            }
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            isVisible = true
            spawnParticles()
            withAnimation(GoMotion.hero) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            glowPulse = shouldRunGlow
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        .onDisappear {
            isVisible = false
            glowPulse = false
        }
        .onChange(of: shouldRunGlow) { _, canRun in
            glowPulse = canRun
        }
    }

    private func spawnParticles() {
        particles = (0..<24).map { _ in
            CelebParticle(emoji: particleEmojis.randomElement()!)
        }
        for p in particles {
            particleOffsets[p.id] = -40
            particleOpacities[p.id] = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + p.delay) {
                withAnimation(.linear(duration: p.duration)) { // ui-v4: allow one-shot particle fall with per-particle duration
                    particleOffsets[p.id] = ScreenCompat.height + 40
                }
                withAnimation(.easeIn(duration: p.duration * 0.4).delay(p.duration * 0.6)) { // ui-v4: allow one-shot particle fade with per-particle duration
                    particleOpacities[p.id] = 0
                }
            }
        }
    }
}

// MARK: - 里程碑检查 ViewModifier
struct MilestoneCheckModifier: ViewModifier {
    let pets: [Pet]
    @AppStorage("celebratedMilestoneDays") private var celebratedRaw: String = ""
    @State private var pendingMilestone: (Pet, MilestoneConfig)? = nil
    @State private var showCelebration = false

    private var celebratedSet: Set<String> {
        Set(celebratedRaw.split(separator: ",").map(String.init))
    }

    func body(content: Content) -> some View {
        content
            .onAppear { checkMilestones() }
            .onChange(of: pets.map { $0.daysTogether }) { _, _ in checkMilestones() }
            .fullScreenCover(isPresented: $showCelebration) {
                if let (pet, ms) = pendingMilestone {
                    MilestoneCelebrationOverlay(pet: pet, milestone: ms) {
                        markCelebrated(pet: pet, days: ms.days)
                        showCelebration = false
                    }
                }
            }
    }

    private func checkMilestones() {
        for pet in pets {
            let days = pet.daysTogether
            guard let ms = MilestoneConfig.match(days: days) else { continue }
            let key = "\(pet.id.uuidString)-\(days)"
            if !celebratedSet.contains(key) {
                pendingMilestone = (pet, ms)
                showCelebration = true
                return
            }
        }
    }

    private func markCelebrated(pet: Pet, days: Int) {
        var current = celebratedSet
        current.insert("\(pet.id.uuidString)-\(days)")
        celebratedRaw = current.joined(separator: ",")
    }
}

extension View {
    func milestoneCheck(pets: [Pet]) -> some View {
        modifier(MilestoneCheckModifier(pets: pets))
    }
}
