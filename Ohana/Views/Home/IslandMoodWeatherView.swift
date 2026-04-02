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
    case celebrate   // 解锁成就 / 今日遛狗 >5km / 里程碑日
    case plantBreeze // 植物浇水后的生态联动特效
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
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: 16))
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                startParticles(in: geo.size)
            }
            .onDisappear {
                stopParticles()
            }
            .onChange(of: mood) { _, newMood in
                stopParticles()
                particles.removeAll()
                if newMood != .calm {
                    startParticles(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func startParticles(in size: CGSize) {
        guard mood != .calm else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.linear(duration: 3)) {
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
        case .breezy:      emojis = ["✨", "🌸", "🌺", "🌼"]
        case .storm:       emojis = ["⚡️", "🌩️", "💧"]
        case .celebrate:   emojis = ["🎉", "🌟", "✨", "🎊", "⭐️", "💫"]
        case .plantBreeze: emojis = ["🍃", "🌿", "🌱", "🍀", "🌸", "💚"]
        }
        
        let particle = WeatherParticle(
            x: CGFloat.random(in: 0...size.width),
            y: -20,
            emoji: emojis.randomElement() ?? "✨",
            opacity: Double.random(in: 0.3...0.7),
            scale: CGFloat.random(in: 0.6...1.2),
            speed: CGFloat.random(in: 1...3)
        )
        particles.append(particle)
        
        // 动画移动到底部
        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
            particles[index].y = size.height + 20
            particles[index].x += CGFloat.random(in: -50...50)
            particles[index].opacity = 0
        }
    }
    
    private func removeOldParticles() {
        particles.removeAll { $0.opacity <= 0.05 }
    }
}

// MARK: - Mood Calculator
struct IslandMoodCalculator {
    static func calculate(pets: [Pet], pendingReminders: [Reminder], plants: [Plant] = []) -> IslandMood {
        // 紧急食物不足 → storm
        for pet in pets {
            if pet.dailyPortionGrams > 0 && pet.remainingFoodDays <= 3 && pet.remainingFoodDays > 0 {
                return .storm
            }
        }

        // 证件即将到期 → storm
        for pet in pets {
            if pet.documents.contains(where: { $0.isExpired }) {
                return .storm
            }
        }

        // 今日遛狗距离 >= 5km → celebrate
        let todayWalkKm = pets.flatMap { $0.walkLogs }.filter {
            Calendar.current.isDateInToday($0.startDate)
        }.reduce(0.0) { $0 + $1.distanceMeters }
        if todayWalkKm >= 5000 {
            return .celebrate
        }

        // 今天是某宠物的 homeDate 里程碑日（100/365/500/730/1000 天）→ celebrate
        let milestones = [100, 365, 500, 730, 1000, 1095]
        for pet in pets {
            if milestones.contains(pet.daysTogether) {
                return .celebrate
            }
        }

        // 今天刚有第一次遛狗记录 → celebrate
        let firstEverWalk = pets.flatMap { $0.walkLogs }
            .sorted(by: { $0.startDate < $1.startDate })
            .first
        if let first = firstEverWalk, Calendar.current.isDateInToday(first.startDate) {
            return .celebrate
        }

        // 今天是某只宠物的到家纪念日（homeDate 周年）→ celebrate
        let today = Date()
        let todayComps = Calendar.current.dateComponents([.month, .day], from: today)
        for pet in pets {
            if let homeDate = pet.homeDate {
                let homeComps = Calendar.current.dateComponents([.month, .day], from: homeDate)
                if homeComps.month == todayComps.month && homeComps.day == todayComps.day
                    && pet.daysTogether > 0 {
                    return .celebrate
                }
            }
        }

        // 今日所有待完成提醒都已完成（至少有1条）→ celebrate
        let allReminders = pendingReminders
        let todayReminders = allReminders.filter {
            Calendar.current.isDateInToday($0.scheduledAt)
        }
        if !todayReminders.isEmpty && todayReminders.allSatisfy({ $0.isCompleted }) {
            return .celebrate
        }

        // 今日任意植物浇水 → plantBreeze（绿叶/花瓣粒子，生态联动）
        let wateredToday = plants.contains { plant in
            if let d = plant.lastWateredDate { return Calendar.current.isDateInToday(d) }
            return false
        }
        if wateredToday {
            return .plantBreeze
        }

        // 今日有已完成提醒 → breezy
        let todayCompleted = pendingReminders.contains { reminder in
            reminder.isCompleted && Calendar.current.isDateInToday(reminder.completedAt ?? .distantPast)
        }
        if todayCompleted {
            return .breezy
        }

        return .calm
    }
}
